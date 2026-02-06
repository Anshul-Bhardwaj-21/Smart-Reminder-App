const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const AWS = require('aws-sdk');
const config = require('../config/environment');
const logger = require('../utils/logger');

class BackupService {
  constructor() {
    this.s3 = new AWS.S3({
      accessKeyId: config.aws.accessKeyId,
      secretAccessKey: config.aws.secretAccessKey
    });
    this.backupDir = path.join(__dirname, '../../backups');
  }

  async createBackup() {
    try {
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const filename = `backup-${timestamp}.gz`;
      const filepath = path.join(this.backupDir, filename);

      // Ensure backup directory exists
      if (!fs.existsSync(this.backupDir)) {
        fs.mkdirSync(this.backupDir, { recursive: true });
      }

      // Create MongoDB dump
      await this._executeCommand(
        `mongodump --uri="${config.mongoUri}" --archive="${filepath}" --gzip`
      );

      // Upload to S3
      await this._uploadToS3(filepath, filename);

      // Clean up local file
      fs.unlinkSync(filepath);

      logger.info(`Backup completed: ${filename}`);
      return filename;
    } catch (error) {
      logger.error('Backup creation failed:', error);
      throw error;
    }
  }

  async _executeCommand(command) {
    return new Promise((resolve, reject) => {
      exec(command, (error, stdout, stderr) => {
        if (error) {
          reject(error);
        } else {
          resolve(stdout);
        }
      });
    });
  }

  async _uploadToS3(filepath, filename) {
    const fileStream = fs.createReadStream(filepath);
    
    const uploadParams = {
      Bucket: config.aws.backupBucket,
      Key: `mongodb-backups/${filename}`,
      Body: fileStream
    };

    return this.s3.upload(uploadParams).promise();
  }
}

module.exports = new BackupService(); 