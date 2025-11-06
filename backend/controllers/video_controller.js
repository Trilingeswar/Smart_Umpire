const ffmpegHandler = require('../utils/ffmpeg_handler');
const awsUploader = require('../utils/aws_uploader');
const fs = require('fs').promises;
const path = require('path');

// In-memory state (use Redis in production)
let recordingState = {
    isRecording: false,
    currentBall: 0,
    bufferedClips: [],
    uploadedClips: [],
    totalBufferSize: 500, // MB
    usedBufferSize: 0,
    recordingStartTime: null,
    lastMarkTime: 0,
    matchName: null,
};

const MAX_BUFFER_CLIPS = 5;

// Start recording from laptop webcam
exports.startRecording = async (req, res) => {
    try {
        if (recordingState.isRecording) {
            return res.status(400).json({ message: 'Already recording' });
        }

        const { matchName } = req.body;
        if (!matchName) {
            return res.status(400).json({ message: 'Match name is required' });
        }

        recordingState.matchName = matchName;
        await ffmpegHandler.startCapture(matchName);
        recordingState.isRecording = true;
        recordingState.currentBall = 0;
        recordingState.recordingStartTime = Date.now();
        recordingState.lastMarkTime = 0;

        res.json({
            success: true,
            message: 'Recording started',
            status: recordingState,
        });
    } catch (error) {
        console.error('Error starting recording:', error);
        res.status(500).json({ error: error.message });
    }
};

// Stop recording
exports.stopRecording = async (req, res) => {
    try {
        if (!recordingState.isRecording) {
            return res.status(400).json({ message: 'Not currently recording' });
        }

        await ffmpegHandler.stopCapture();
        recordingState.isRecording = false;

        res.json({
            success: true,
            message: 'Recording stopped',
            status: recordingState,
        });
    } catch (error) {
        console.error('Error stopping recording:', error);
        res.status(500).json({ error: error.message });
    }
};

// Mark ball event (create clip segments for both cameras)
exports.markBall = async (req, res) => {
    try {
        if (!recordingState.isRecording) {
            return res.status(400).json({ message: 'Not currently recording' });
        }

        recordingState.currentBall++;

        const currentTime = Date.now();
        const startTime = recordingState.lastMarkTime;
        const endTime = (currentTime - recordingState.recordingStartTime) / 1000; // Convert to seconds

        // Create clips for both cameras
        const clips = [];

        try {
            const clipDataCam1 = await ffmpegHandler.createClipFromBuffer(
                recordingState.currentBall,
                startTime,
                endTime,
                'cam1',
                recordingState.matchName
            );
            clips.push(clipDataCam1);
        } catch (error) {
            console.error('Failed to create Cam1 clip:', error.message);
        }

        try {
            const clipDataCam2 = await ffmpegHandler.createClipFromBuffer(
                recordingState.currentBall,
                startTime,
                endTime,
                'cam2',
                recordingState.matchName
            );
            clips.push(clipDataCam2);
        } catch (error) {
            console.error('Failed to create Cam2 clip:', error.message);
        }

        // Add to buffered clips
        recordingState.bufferedClips.push(...clips);

        // Maintain rolling buffer (keep last 5 balls x 2 cameras = 10 clips)
        const maxClips = MAX_BUFFER_CLIPS * 2;
        while (recordingState.bufferedClips.length > maxClips) {
            const removedClip = recordingState.bufferedClips.shift();
            // Delete old clip file
            await ffmpegHandler.deleteClip(removedClip.localPath);
        }

        // Update last mark time
        recordingState.lastMarkTime = endTime;

        // Update buffer size
        recordingState.usedBufferSize = await ffmpegHandler.getBufferSize(recordingState.matchName);

        res.json({
            success: true,
            message: `Ball ${recordingState.currentBall} marked`,
            clips: clips,
            status: recordingState,
        });
    } catch (error) {
        console.error('Error marking ball:', error);
        res.status(500).json({ error: error.message });
    }
};

// Get buffer status
exports.getBufferStatus = (req, res) => {
    const maxClips = MAX_BUFFER_CLIPS * 2; // Account for 2 cameras
    const percentageUsed = Math.round((recordingState.bufferedClips.length / maxClips) * 100);

    res.json({
        totalBufferSize: maxClips,
        usedBufferSize: recordingState.bufferedClips.length,
        percentageUsed: percentageUsed,
        numberOfClips: recordingState.bufferedClips.length,
        isRecording: recordingState.isRecording,
        currentBall: `Ball ${recordingState.currentBall}`,
    });
};

// Get buffered clips
exports.getBufferedClips = (req, res) => {
    res.json({
        clips: recordingState.bufferedClips,
    });
};

// Select clip for review and upload to S3
exports.selectClipForReview = async (req, res) => {
    try {
        const { clipId } = req.body;

        const clip = recordingState.bufferedClips.find((c) => c.id === clipId);

        if (!clip) {
            return res.status(404).json({ message: 'Clip not found' });
        }

        // Upload to AWS S3
        const s3Url = await awsUploader.uploadToS3(clip.localPath, clip.filename);

        // Update clip data
        clip.s3Url = s3Url;
        clip.isUploaded = true;

        // Add to uploaded clips
        if (!recordingState.uploadedClips.find((c) => c.id === clipId)) {
            recordingState.uploadedClips.push(clip);
        }

        res.json(clip);
    } catch (error) {
        console.error('Error selecting clip:', error);
        res.status(500).json({ error: error.message });
    }
};

// Get uploaded clips
exports.getUploadedClips = (req, res) => {
    res.json({
        clips: recordingState.uploadedClips,
    });
};

// Stream video
exports.streamVideo = async (req, res) => {
    try {
        const { clipId } = req.params;

        const clip = recordingState.bufferedClips.find((c) => c.id === clipId) ||
            recordingState.uploadedClips.find((c) => c.id === clipId);

        if (!clip) {
            return res.status(404).json({ message: 'Clip not found' });
        }

        const videoPath = clip.localPath || path.join(__dirname, '../clips', recordingState.matchName || '', clip.filename);
        console.log('Video path:', videoPath);
        console.log('Clip data:', clip);
        const stat = await fs.stat(videoPath);
        const fileSize = stat.size;
        const range = req.headers.range;

        if (range) {
            const parts = range.replace(/bytes=/, '').split('-');
            const start = parseInt(parts[0], 10);
            const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
            const chunksize = end - start + 1;

            const readStream = require('fs').createReadStream(videoPath, { start, end });

            const head = {
                'Content-Range': `bytes ${start}-${end}/${fileSize}`,
                'Accept-Ranges': 'bytes',
                'Content-Length': chunksize,
                'Content-Type': 'video/mp4',
            };

            res.writeHead(206, head);
            readStream.pipe(res);
        } else {
            const head = {
                'Content-Length': fileSize,
                'Content-Type': 'video/mp4',
            };

            res.writeHead(200, head);
            require('fs').createReadStream(videoPath).pipe(res);
        }
    } catch (error) {
        console.error('Error streaming video:', error);
        res.status(500).json({ error: error.message });
    }
};
