const Task = require('../models/Task');
const MLService = require('./mlService');
const logger = require('../utils/logger');

class TaskPriorityService {
  constructor() {
    this.mlService = MLService;
  }

  async calculateTaskPriority(task) {
    try {
      const factors = {
        deadline: this._calculateDeadlineFactor(task),
        complexity: this._calculateComplexityFactor(task),
        importance: await this._calculateImportanceFactor(task),
        userPreference: await this._getUserPreferenceFactor(task.userId)
      };

      const priority = this._computePriorityScore(factors);
      return this._mapPriorityToLevel(priority);
    } catch (error) {
      logger.error('Error calculating task priority:', error);
      throw error;
    }
  }

  _calculateDeadlineFactor(task) {
    if (!task.endTime) return 0.5;

    const now = new Date();
    const deadline = new Date(task.endTime);
    const timeLeft = deadline - now;
    const daysDiff = timeLeft / (1000 * 60 * 60 * 24);

    if (daysDiff < 0) return 1;
    if (daysDiff < 1) return 0.9;
    if (daysDiff < 3) return 0.7;
    if (daysDiff < 7) return 0.5;
    return 0.3;
  }

  _calculateComplexityFactor(task) {
    let complexity = 0;
    
    // Add points for various factors
    if (task.description && task.description.length > 200) complexity += 0.2;
    if (task.subtasks && task.subtasks.length > 0) complexity += 0.3;
    if (task.attachments && task.attachments.length > 0) complexity += 0.2;
    if (task.dependencies && task.dependencies.length > 0) complexity += 0.3;

    return Math.min(complexity, 1);
  }

  async _calculateImportanceFactor(task) {
    try {
      const mlPrediction = await this.mlService.predictTaskPriority(task);
      return mlPrediction.confidence;
    } catch (error) {
      logger.warn('ML prediction failed, using fallback:', error);
      return 0.5; // Fallback value
    }
  }

  async _getUserPreferenceFactor(userId) {
    try {
      const userTasks = await Task.find({ userId, status: 'completed' })
        .sort({ completedAt: -1 })
        .limit(10);

      if (userTasks.length === 0) return 0.5;

      const avgPriority = userTasks.reduce((sum, task) => {
        return sum + this._getPriorityValue(task.priority);
      }, 0) / userTasks.length;

      return avgPriority;
    } catch (error) {
      logger.error('Error calculating user preference:', error);
      return 0.5;
    }
  }

  _computePriorityScore(factors) {
    const weights = {
      deadline: 0.4,
      complexity: 0.2,
      importance: 0.3,
      userPreference: 0.1
    };

    return Object.entries(factors).reduce((score, [factor, value]) => {
      return score + (value * weights[factor]);
    }, 0);
  }

  _mapPriorityToLevel(score) {
    if (score >= 0.8) return 'high';
    if (score >= 0.4) return 'medium';
    return 'low';
  }

  _getPriorityValue(priority) {
    const values = { low: 0.3, medium: 0.6, high: 0.9 };
    return values[priority] || 0.5;
  }
}

module.exports = new TaskPriorityService(); 