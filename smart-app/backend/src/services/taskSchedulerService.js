const schedule = require('node-schedule');
const Task = require('../models/Task');
const NotificationService = require('./notificationService');
const logger = require('../utils/logger');

class TaskSchedulerService {
  constructor() {
    this.notificationService = new NotificationService();
    this.jobs = new Map();
  }

  async initialize() {
    try {
      // Load all upcoming tasks and schedule them
      const upcomingTasks = await Task.find({
        startTime: { $gt: new Date() },
        status: 'pending'
      });

      upcomingTasks.forEach(task => this.scheduleTask(task));
      logger.info(`Initialized scheduler with ${upcomingTasks.length} tasks`);
    } catch (error) {
      logger.error('Task scheduler initialization failed:', error);
      throw error;
    }
  }

  scheduleTask(task) {
    try {
      // Schedule task start notification
      const startJob = schedule.scheduleJob(task.startTime, async () => {
        await this.notificationService.sendNotification({
          userId: task.userId,
          title: 'Task Starting',
          body: `Task "${task.title}" is starting now`,
          data: { taskId: task._id.toString() }
        });
        
        await Task.findByIdAndUpdate(task._id, { status: 'in_progress' });
      });

      // Schedule task end notification
      if (task.endTime) {
        const endJob = schedule.scheduleJob(task.endTime, async () => {
          await this.notificationService.sendNotification({
            userId: task.userId,
            title: 'Task Due',
            body: `Task "${task.title}" is due now`,
            data: { taskId: task._id.toString() }
          });
        });

        this.jobs.set(`${task._id}-end`, endJob);
      }

      this.jobs.set(`${task._id}-start`, startJob);
      logger.info(`Scheduled task: ${task._id}`);
    } catch (error) {
      logger.error(`Error scheduling task ${task._id}:`, error);
      throw error;
    }
  }

  cancelTaskSchedule(taskId) {
    try {
      const startJob = this.jobs.get(`${taskId}-start`);
      const endJob = this.jobs.get(`${taskId}-end`);

      if (startJob) {
        startJob.cancel();
        this.jobs.delete(`${taskId}-start`);
      }

      if (endJob) {
        endJob.cancel();
        this.jobs.delete(`${taskId}-end`);
      }

      logger.info(`Cancelled schedule for task: ${taskId}`);
    } catch (error) {
      logger.error(`Error cancelling task schedule ${taskId}:`, error);
      throw error;
    }
  }

  async rescheduleTask(task) {
    try {
      this.cancelTaskSchedule(task._id);
      this.scheduleTask(task);
      logger.info(`Rescheduled task: ${task._id}`);
    } catch (error) {
      logger.error(`Error rescheduling task ${task._id}:`, error);
      throw error;
    }
  }
}

module.exports = new TaskSchedulerService(); 