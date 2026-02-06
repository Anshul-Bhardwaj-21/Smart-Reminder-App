const Task = require('../models/Task');
const logger = require('../utils/logger');

class AnalyticsService {
  async getTaskCompletionStats(userId, timeRange) {
    try {
      const startDate = this._getStartDate(timeRange);
      
      const stats = await Task.aggregate([
        {
          $match: {
            userId,
            createdAt: { $gte: startDate },
            status: { $in: ['completed', 'cancelled'] }
          }
        },
        {
          $group: {
            _id: '$status',
            count: { $sum: 1 },
            averageCompletionTime: {
              $avg: {
                $subtract: ['$updatedAt', '$createdAt']
              }
            }
          }
        }
      ]);

      return this._formatStats(stats);
    } catch (error) {
      logger.error('Error getting task completion stats:', error);
      throw error;
    }
  }

  async getProductivityTrends(userId) {
    try {
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      return await Task.aggregate([
        {
          $match: {
            userId,
            status: 'completed',
            completedAt: { $gte: thirtyDaysAgo }
          }
        },
        {
          $group: {
            _id: {
              $dateToString: { format: '%Y-%m-%d', date: '$completedAt' }
            },
            tasksCompleted: { $sum: 1 }
          }
        },
        { $sort: { '_id': 1 } }
      ]);
    } catch (error) {
      logger.error('Error getting productivity trends:', error);
      throw error;
    }
  }

  _getStartDate(timeRange) {
    const date = new Date();
    switch (timeRange) {
      case 'week':
        date.setDate(date.getDate() - 7);
        break;
      case 'month':
        date.setMonth(date.getMonth() - 1);
        break;
      case 'year':
        date.setFullYear(date.getFullYear() - 1);
        break;
      default:
        date.setDate(date.getDate() - 30);
    }
    return date;
  }

  _formatStats(stats) {
    return {
      completed: stats.find(s => s._id === 'completed')?.count || 0,
      cancelled: stats.find(s => s._id === 'cancelled')?.count || 0,
      averageCompletionTime: Math.round(
        stats.find(s => s._id === 'completed')?.averageCompletionTime / (1000 * 60) || 0
      ) // Convert to minutes
    };
  }
}

module.exports = new AnalyticsService(); 