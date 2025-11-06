require('dotenv').config();

const NodeMediaServer = require('node-media-server');

const express = require('express');
const cors = require('cors');
const path = require('path');
const videoRoutes = require('./routes/video_routes');

const app = express();
const PORT = process.env.PORT || 3000;

// RTMP Server Configuration
const config = {
  rtmp: {
    port: 1935,
    chunk_size: 60000,
    gop_cache: true, 
    ping: 30,
    ping_timeout: 60
  },
  http: {
    port: 8000,
    allow_origin: '*'
  },
};

const nms = new NodeMediaServer(config);
nms.run();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Static files (for serving videos)
app.use('/videos', express.static(path.join(__dirname, 'buffer')));

// Routes
app.use('/api', videoRoutes);

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'OK', message: 'Server is running' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://172.16.126.162:${PORT}`);
});

module.exports = app;
