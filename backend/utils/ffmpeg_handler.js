const ffmpeg = require('fluent-ffmpeg');
const path = require('path');
const fs = require('fs').promises;
const { v4: uuidv4 } = require('uuid');

const BUFFER_DIR = path.join(__dirname, '../buffer');
const CLIPS_DIR = path.join(__dirname, '../clips');
const SEGMENT_DURATION = 30; // seconds per ball clip

// Ensure match-specific directories exist
async function ensureMatchDirs(matchName) {
    const matchBufferDir = path.join(BUFFER_DIR, matchName);
    const matchClipsDir = path.join(CLIPS_DIR, matchName);

    try {
        await fs.mkdir(matchBufferDir, { recursive: true });
        await fs.mkdir(matchClipsDir, { recursive: true });
    } catch (error) {
        console.error('Error creating match directories:', error);
    }
}

let currentProcessCam1 = null;
let currentProcessCam2 = null;
let recordingStartTime = null;

// Ensure buffer directory exists
async function ensureBufferDir() {
    try {
        await fs.mkdir(BUFFER_DIR, { recursive: true });
    } catch (error) {
        console.error('Error creating buffer directory:', error);
    }
}

// Ensure clips directory exists
async function ensureClipsDir() {
    try {
        await fs.mkdir(CLIPS_DIR, { recursive: true });
    } catch (error) {
        console.error('Error creating clips directory:', error);
    }
}

// Generate ball name based on ball number
function getBallName(ballNumber) {
    if (ballNumber <= 120) {
        const over = Math.floor((ballNumber - 1) / 6);
        const ballInOver = ((ballNumber - 1) % 6) + 1;
        return `${over}.${ballInOver}`;
    } else {
        return '20';
    }
}

// Start capturing from two cameras simultaneously
const { spawn } = require('child_process');

exports.startCapture = async (matchName) => {
    await ensureBufferDir();
    await ensureMatchDirs(matchName);

    return new Promise((resolve, reject) => {
        recordingStartTime = Date.now();

        const matchBufferDir = path.join(BUFFER_DIR, matchName);

        // Camera 1 (IP camera)
        const outputPathCam1 = path.join(matchBufferDir, 'cam1.mp4');
        const ffmpegArgsCam1 = [
            '-f', 'mjpeg',
            '-i', 'http://172.16.125.249:8080/video', // Camera 1 stream URL
            '-c:v', 'libx264',
            '-profile:v', 'baseline',
            '-level', '3.0',
            '-preset', 'ultrafast',
            '-tune', 'zerolatency',
            '-pix_fmt', 'yuv420p',
            '-an',
            '-f', 'mpegts',
            outputPathCam1
        ];

        // Camera 2 (laptop webcam)
        const outputPathCam2 = path.join(matchBufferDir, 'cam2.mp4');
        const ffmpegArgsCam2 = [
            '-f', 'mjpeg',
            '-i', 'http://172.16.124.237:8080/video',  // Camera 2 stream URL
            '-c:v', 'libx264',
            '-profile:v', 'baseline',
            '-level', '3.0',
            '-preset', 'ultrafast',
            '-tune', 'zerolatency',
            '-pix_fmt', 'yuv420p',
            '-an',
            '-f', 'mpegts',
            outputPathCam2
        ];

        // Start both processes
        currentProcessCam1 = spawn('ffmpeg', ffmpegArgsCam1);
        currentProcessCam2 = spawn('ffmpeg', ffmpegArgsCam2);

        let processesStarted = 0;

        const checkBothStarted = () => {
            processesStarted++;
            if (processesStarted === 2) {
                console.log('Both FFmpeg processes started');
                resolve();
            } else if (processesStarted === 1) {
                // If only one process started after a delay, still resolve
                setTimeout(() => {
                    if (processesStarted < 2) {
                        console.log(`Only ${processesStarted} FFmpeg process(es) started, but proceeding...`);
                        resolve();
                    }
                }, 5000); // Wait 5 seconds for the second process
            }
        };

        // Handle Camera 1
        currentProcessCam1.stdout.on('data', (data) => {
            console.log(`FFmpeg Cam1 stdout: ${data}`);
        });
        currentProcessCam1.stderr.on('data', (data) => {
            console.error(`FFmpeg Cam1 stderr: ${data}`);
        });
        currentProcessCam1.on('error', (err) => {
            console.error('FFmpeg Cam1 error:', err);
            // Don't reject immediately, let Cam2 try to start
        });
        currentProcessCam1.on('spawn', () => {
            console.log('FFmpeg Cam1 started');
            checkBothStarted();
        });
        currentProcessCam1.on('close', (code) => {
            console.log(`FFmpeg Cam1 exited with code ${code}`);
            currentProcessCam1 = null;
        });

        // Handle Camera 2
        currentProcessCam2.stdout.on('data', (data) => {
            console.log(`FFmpeg Cam2 stdout: ${data}`);
        });
        currentProcessCam2.stderr.on('data', (data) => {
            console.error(`FFmpeg Cam2 stderr: ${data}`);
        });
        currentProcessCam2.on('error', (err) => {
            console.error('FFmpeg Cam2 error:', err);
            // Don't reject immediately, let Cam1 try to start
        });
        currentProcessCam2.on('spawn', () => {
            console.log('FFmpeg Cam2 started');
            checkBothStarted();
        });
        currentProcessCam2.on('close', (code) => {
            console.log(`FFmpeg Cam2 exited with code ${code}`);
            currentProcessCam2 = null;
        });
    });
};

// Stop capture
exports.stopCapture = () => {
    return new Promise((resolve) => {
        let processesStopped = 0;

        const checkBothStopped = () => {
            processesStopped++;
            if (processesStopped === 2) {
                console.log('Both FFmpeg processes stopped');
                resolve();
            }
        };

        if (currentProcessCam1) {
            currentProcessCam1.on('end', () => {
                console.log('FFmpeg Cam1 stopped');
                currentProcessCam1 = null;
                checkBothStopped();
            });
            currentProcessCam1.kill('SIGINT');
        } else {
            checkBothStopped();
        }

        if (currentProcessCam2) {
            currentProcessCam2.on('end', () => {
                console.log('FFmpeg Cam2 stopped');
                currentProcessCam2 = null;
                checkBothStopped();
            });
            currentProcessCam2.kill('SIGINT');
        } else {
            checkBothStopped();
        }
    });
};

// Create clip from buffer (extract from startTime to endTime)
exports.createClipFromBuffer = async (ballNumber, startTime, endTime, camera, matchName) => {
    await ensureClipsDir();
    await ensureMatchDirs(matchName);
    const clipId = uuidv4();
    const ballName = getBallName(ballNumber);
    const filename = `${ballName}_${camera}_${clipId}.mp4`;
    const matchClipsDir = path.join(CLIPS_DIR, matchName);
    const outputPath = path.join(matchClipsDir, filename);
    const matchBufferDir = path.join(BUFFER_DIR, matchName);
    const inputPath = path.join(matchBufferDir, `${camera}.mp4`);

    const duration = endTime - startTime;

    return new Promise((resolve, reject) => {
        ffmpeg(inputPath)
            .seekInput(startTime)
            .duration(duration)
            .videoCodec('libx264')
            .addOptions(['-preset', 'medium', '-crf', '20', '-profile:v', 'main', '-level', '3.1'])
            .videoBitrate('1500k')
            .size('1280x720')
            .fps(30)
            .audioCodec('aac')
            .audioBitrate('128k')
            .audioFrequency(44100)
            .output(outputPath)
            .on('end', async () => {
                const stats = await fs.stat(outputPath);

                resolve({
                    id: clipId,
                    filename: filename,
                    localPath: outputPath,
                    s3Url: null,
                    timestamp: new Date().toISOString(),
                    duration: duration,
                    isUploaded: false,
                    ballNumber: ballName,
                    camera: camera,
                    size: stats.size,
                });
            })
            .on('error', (err) => {
                console.error('Error creating clip:', err);
                reject(err);
            })
            .run();
    });
};

// Delete clip
exports.deleteClip = async (filePath) => {
    try {
        await fs.unlink(filePath);
        console.log(`Deleted clip: ${filePath}`);
    } catch (error) {
        console.error('Error deleting clip:', error);
    }
};

// Get total buffer size
exports.getBufferSize = async (matchName) => {
    try {
        const matchBufferDir = path.join(BUFFER_DIR, matchName);
        const files = await fs.readdir(matchBufferDir);
        let totalSize = 0;

        for (const file of files) {
            // Only count camera buffer files
            if (file.startsWith('cam') && file.endsWith('.mp4')) {
                const filePath = path.join(matchBufferDir, file);
                const stats = await fs.stat(filePath);
                totalSize += stats.size;
            }
        }

        return Math.round(totalSize / (1024 * 1024)); // MB
    } catch (error) {
        console.error('Error calculating buffer size:', error);
        return 0;
    }
};
