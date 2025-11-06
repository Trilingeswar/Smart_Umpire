const AWS = require('aws-sdk');
const fs = require('fs');
const path = require('path');

// Configure AWS
const s3 = new AWS.S3({
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    region: process.env.AWS_REGION || 'eu-north-1',
});

const BUCKET_NAME = process.env.S3_BUCKET_NAME || 'cricket-umpire-permanent';

// Upload file to S3
exports.uploadToS3 = async (filePath, filename) => {
    return new Promise((resolve, reject) => {
        // Check if file exists
        if (!fs.existsSync(filePath)) {
            reject(new Error(`File does not exist: ${filePath}`));
            return;
        }

        const fileContent = fs.readFileSync(filePath);

        const params = {
            Bucket: BUCKET_NAME,
            Key: `clips/${filename}`,
            Body: fileContent,
            ContentType: 'video/mp4',
        };

        // Set bucket policy for public read access instead of ACL
        const bucketPolicy = {
            Version: '2012-10-17',
            Statement: [
                {
                    Sid: 'PublicReadGetObject',
                    Effect: 'Allow',
                    Principal: '*',
                    Action: 's3:GetObject',
                    Resource: `arn:aws:s3:::${BUCKET_NAME}/clips/*`
                }
            ]
        };

        console.log(`Starting S3 upload for ${filename}...`);

        s3.upload(params, async (err, data) => {
            if (err) {
                console.error('S3 upload error:', err);
                reject(err);
            } else {
                console.log(`Uploaded to S3: ${data.Location}`);

                // Set bucket policy for public access
                try {
                    await s3.putBucketPolicy({
                        Bucket: BUCKET_NAME,
                        Policy: JSON.stringify(bucketPolicy)
                    }).promise();
                    console.log('Bucket policy updated for public access');
                } catch (policyErr) {
                    console.warn('Could not set bucket policy:', policyErr.message);
                    // Don't fail the upload if policy setting fails
                }

                resolve(data.Location);
            }
        });
    });
};

// Delete file from S3
exports.deleteFromS3 = async (filename) => {
    const params = {
        Bucket: BUCKET_NAME,
        Key: `clips/${filename}`,
    };

    return new Promise((resolve, reject) => {
        s3.deleteObject(params, (err, data) => {
            if (err) {
                console.error('S3 delete error:', err);
                reject(err);
            } else {
                console.log(`Deleted from S3: ${filename}`);
                resolve(data);
            }
        });
    });
};

// List all uploaded files
exports.listS3Files = async () => {
    const params = {
        Bucket: BUCKET_NAME,
        Prefix: 'clips/',
    };

    return new Promise((resolve, reject) => {
        s3.listObjectsV2(params, (err, data) => {
            if (err) {
                console.error('S3 list error:', err);
                reject(err);
            } else {
                resolve(data.Contents);
            }
        });
    });
};
