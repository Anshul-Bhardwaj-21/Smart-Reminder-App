const admin = require('firebase-admin');
const logger = require('../utils/logger');

class NotificationService {
  constructor() {
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId: process.env.FIREBASE_PROJECT_ID
      });
    }
  }

  async scheduleTaskReminders(task) {
    try {
      for (const reminder of task.reminders) {
        await this.scheduleNotification({
          userId: task.userId,
          title: `Reminder: ${task.title}`,
          body: reminder.message || task.description,
          scheduledTime: reminder.time,
          data: {
            taskId: task._id.toString(),
            type: 'task_reminder'
          }
        });
      }
    } catch (error) {
      logger.error('Error scheduling reminders:', error);
      throw error;
    }
  }

  async scheduleNotification({ userId, title, body, scheduledTime, data }) {
    try {
      const userRef = await admin.firestore().collection('users').doc(userId.toString());
      const userDoc = await userRef.get();
      
      if (!userDoc.exists || !userDoc.data().fcmToken) {
        throw new Error('User FCM token not found');
      }

      const message = {
        notification: {
          title,
          body
        },
        data: {
          ...data,
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        },
        token: userDoc.data().fcmToken
      };

      if (scheduledTime > Date.now()) {
        await admin.messaging().sendToDevice(
          userDoc.data().fcmToken,
          message,
          { timeToLive: Math.floor((scheduledTime - Date.now()) / 1000) }
        );
      }
    } catch (error) {
      logger.error('Error sending notification:', error);
      throw error;
    }
  }
}

module.exports = { NotificationService }; 