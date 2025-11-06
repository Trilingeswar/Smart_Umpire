module.exports = {
  port: process.env.PORT || 3000,
  
  // AWS Configuration
  aws: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    region: process.env.AWS_REGION || 'eu-north-1',
    bucketName: process.env.S3_BUCKET_NAME || 'cricket-umpire-permanent',
  },

  // FFmpeg Configuration
  ffmpeg: {
    bufferDir: './buffer',
    segmentDuration: 30, // seconds
    maxBufferClips: 5,
    videoCodec: 'libx264',
    resolution: '1280x720',
    fps: 30,
  },

  // Buffer Configuration
  buffer: {
    maxSize: 500, // MB
    cleanupInterval: 60000, // 1 minute
  },
};
