const express = require('express');
const router = express.Router();
const videoController = require('../controllers/video_controller');

// Recording routes
router.post('/recording/start', videoController.startRecording);
router.post('/recording/stop', videoController.stopRecording);
router.post('/recording/mark-ball', videoController.markBall);

// Buffer routes
router.get('/buffer/status', videoController.getBufferStatus);
router.get('/buffer/clips', videoController.getBufferedClips);

// Clips routes
router.post('/clips/select', videoController.selectClipForReview);
router.get('/clips/uploaded', videoController.getUploadedClips);
router.get('/video/stream/:clipId', videoController.streamVideo);

module.exports = router;
