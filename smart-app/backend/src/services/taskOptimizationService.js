const Task = require('../models/Task');
const LocationService = require('./locationService');
const TaskPriorityService = require('./taskPriorityService');
const logger = require('../utils/logger');

class TaskOptimizationService {
  constructor() {
    this.locationService = LocationService;
    this.priorityService = TaskPriorityService;
  }

  async optimizeTaskSchedule(userId, date) {
    try {
      const tasks = await this._getTasksForDate(userId, date);
      if (tasks.length === 0) return [];

      const optimizedSchedule = await this._createOptimizedSchedule(tasks);
      await this._updateTaskSchedules(optimizedSchedule);

      return optimizedSchedule;
    } catch (error) {
      logger.error('Task schedule optimization failed:', error);
      throw error;
    }
  }

  async _getTasksForDate(userId, date) {
    const startOfDay = new Date(date.setHours(0, 0, 0, 0));
    const endOfDay = new Date(date.setHours(23, 59, 59, 999));

    return Task.find({
      userId,
      startTime: { $gte: startOfDay, $lte: endOfDay },
      status: { $in: ['pending', 'in_progress'] }
    }).sort({ priority: -1, startTime: 1 });
  }

  async _createOptimizedSchedule(tasks) {
    const optimizedTasks = [];
    let currentTime = new Date(tasks[0].startTime);

    for (let i = 0; i < tasks.length; i++) {
      const task = tasks[i];
      const nextTask = tasks[i + 1];

      // Calculate optimal duration and break time
      const duration = await this._calculateOptimalDuration(task);
      const breakTime = nextTask ? await this._calculateBreakTime(task, nextTask) : 0;

      // Update task times
      const optimizedTask = {
        ...task.toObject(),
        startTime: new Date(currentTime),
        endTime: new Date(currentTime.getTime() + duration)
      };

      optimizedTasks.push(optimizedTask);
      currentTime = new Date(optimizedTask.endTime.getTime() + breakTime);
    }

    return optimizedTasks;
  }

  async _calculateOptimalDuration(task) {
    const baselineDuration = task.endTime - task.startTime;
    const complexityFactor = await this._getComplexityFactor(task);
    const userPerformanceFactor = await this._getUserPerformanceFactor(task.userId);

    return baselineDuration * complexityFactor * userPerformanceFactor;
  }

  async _calculateBreakTime(currentTask, nextTask) {
    try {
      if (currentTask.location && nextTask.location) {
        const travelTime = await this.locationService.calculateTravelTime(
          currentTask.location,
          nextTask.location
        );
        return travelTime.duration * 1000; // Convert to milliseconds
      }
      
      // Default break time based on task priority
      const breakTimes = {
        high: 10 * 60000, // 10 minutes
        medium: 15 * 60000, // 15 minutes
        low: 20 * 60000 // 20 minutes
      };
      
      return breakTimes[currentTask.priority] || breakTimes.medium;
    } catch (error) {
      logger.warn('Error calculating break time, using default:', error);
      return 15 * 60000; // 15 minutes default
    }
  }

  async _getComplexityFactor(task) {
    const factors = {
      subtasks: task.subtasks?.length || 0,
      description: task.description?.length || 0,
      attachments: task.attachments?.length || 0,
      priority: task.priority
    };

    let complexityScore = 1;
    
    if (factors.subtasks > 0) complexityScore += 0.1 * factors.subtasks;
    if (factors.description > 200) complexityScore += 0.1;
    if (factors.attachments > 0) complexityScore += 0.05 * factors.attachments;
    if (factors.priority === 'high') complexityScore += 0.2;

    return Math.min(complexityScore, 2); // Cap at 2x duration
  }

  async _getUserPerformanceFactor(userId) {
    try {
      const completedTasks = await Task.find({
        userId,
        status: 'completed',
        actualCompletionTime: { $exists: true }
      }).limit(10);

      if (completedTasks.length === 0) return 1;

      const performanceRatio = completedTasks.reduce((sum, task) => {
        const estimated = task.endTime - task.startTime;
        const actual = task.actualCompletionTime;
        return sum + (actual / estimated);
      }, 0) / completedTasks.length;

      return Math.max(0.5, Math.min(1.5, performanceRatio));
    } catch (error) {
      logger.error('Error calculating user performance:', error);
      return 1;
    }
  }

  async _updateTaskSchedules(optimizedSchedule) {
    const updates = optimizedSchedule.map(task => {
      return Task.findByIdAndUpdate(task._id, {
        startTime: task.startTime,
        endTime: task.endTime,
        optimized: true
      }, { new: true });
    });

    await Promise.all(updates);
  }
}

module.exports = new TaskOptimizationService(); 