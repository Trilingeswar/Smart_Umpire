/**
 * Simulates the updated "Mark Ball" workflow with Pause/Resume mechanism.
 * Processes a sequence of events (MARK, PAUSE, RESUME) with timestamps.
 *
 * @param {Array<{time: number, action: string}>} events - Array of events, each with time and action ('MARK', 'PAUSE', 'RESUME')
 * @returns {Object} - Object containing clips and pauseResumeLog
 */
function simulateMarkBallWorkflow(events) {
    let isRecording = true;
    let lastCheckpoint = null;
    const clips = [];
    const pauseResumeLog = [];

    for (const event of events) {
        const { time, action } = event;

        if (action === 'MARK') {
            if (lastCheckpoint !== null) {
                // Pause recording
                if (isRecording) {
                    pauseResumeLog.push({ time, action: 'pause' });
                    isRecording = false;
                }
                // Save clip
                clips.push({ start: lastCheckpoint, end: time });
                // Resume recording
                pauseResumeLog.push({ time, action: 'resume' });
                isRecording = true;
            }
            // Set new checkpoint
            lastCheckpoint = time;
        } else if (action === 'PAUSE') {
            if (isRecording) {
                pauseResumeLog.push({ time, action: 'pause' });
                isRecording = false;
            }
        } else if (action === 'RESUME') {
            if (!isRecording) {
                pauseResumeLog.push({ time, action: 'resume' });
                isRecording = true;
            }
        }
    }

    return { clips, pauseResumeLog };
}

// Example usage
const events = [
    { time: 10, action: 'MARK' },   // First mark, no clip
    { time: 20, action: 'MARK' },   // Clip 10-20, pause/resume
    { time: 25, action: 'PAUSE' },  // Manual pause
    { time: 30, action: 'RESUME' }, // Manual resume
    { time: 35, action: 'MARK' },   // Clip 20-35, pause/resume
    { time: 50, action: 'MARK' }    // Clip 35-50, pause/resume
];

const result = simulateMarkBallWorkflow(events);
console.log('Video clips:', result.clips);
console.log('Pause/Resume log:', result.pauseResumeLog);

module.exports = { simulateMarkBallWorkflow };