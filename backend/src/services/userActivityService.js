const mongoose = require('mongoose');
const logger = require('../utils/logger');

const ActivitySchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  type: {
    type: String,
    required: true,
    enum: ['task_created', 'task_completed', 'task_updated', 'login', 'settings_changed']
  },
  details: {
    type: mongoose.Schema.Types.Mixed,
    required: true
  },
  timestamp: {
    type: Date,
    default: Date.now
  },
  metadata: {
    device: String,
    platform: String,
    location: {
      latitude: Number,
      longitude: Number
    }
  }
});

const Activity = mongoose.model('Activity', ActivitySchema);

class UserActivityService {
  async trackActivity(userId, type, details, metadata = {}) {
    try {
      const activity = await Activity.create({
        userId,
        type,
        details,
        metadata
      });

      await this._analyzeUserBehavior(userId);
      return activity;
    } catch (error) {
      logger.error('Error tracking user activity:', error);
      throw error;
    }
  }

  async getUserActivities(userId, options = {}) {
    try {
      const query = { userId };
      
      if (options.type) {
        query.type = options.type;
      }
      
      if (options.startDate) {
        query.timestamp = { $gte: new Date(options.startDate) };
      }
      
      if (options.endDate) {
        query.timestamp = { 
          ...query.timestamp,
          $lte: new Date(options.endDate)
        };
      }

      return await Activity.find(query)
        .sort({ timestamp: -1 })
        .limit(options.limit || 50)
        .skip(options.skip || 0);
    } catch (error) {
      logger.error('Error fetching user activities:', error);
      throw error;
    }
  }

  async getActivityStats(userId) {
    try {
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const stats = await Activity.aggregate([
        {
          $match: {
            userId: new mongoose.Types.ObjectId(userId),
            timestamp: { $gte: thirtyDaysAgo }
          }
        },
        {
          $group: {
            _id: {
              type: '$type',
              day: { $dateToString: { format: '%Y-%m-%d', date: '$timestamp' } }
            },
            count: { $sum: 1 }
          }
        },
        {
          $group: {
            _id: '$_id.type',
            dailyStats: {
              $push: {
                date: '$_id.day',
                count: '$count'
              }
            },
            totalCount: { $sum: '$count' }
          }
        }
      ]);

      return this._formatActivityStats(stats);
    } catch (error) {
      logger.error('Error getting activity stats:', error);
      throw error;
    }
  }

  async _analyzeUserBehavior(userId) {
    try {
      const recentActivities = await this.getUserActivities(userId, {
        limit: 100
      });

      // Analyze patterns and update user preferences
      const patterns = this._identifyPatterns(recentActivities);
      await this._updateUserPreferences(userId, patterns);
    } catch (error) {
      logger.warn('Error analyzing user behavior:', error);
    }
  }

  _identifyPatterns(activities) {
    // Implementation of pattern recognition logic
    // Returns object with identified patterns
  }

  async _updateUserPreferences(userId, patterns) {
    // Implementation of updating user preferences based on patterns
  }

  _formatActivityStats(stats) {
    const formattedStats = {};
    
    stats.forEach(stat => {
      formattedStats[stat._id] = {
        totalCount: stat.totalCount,
        dailyStats: stat.dailyStats.sort((a, b) => 
          new Date(a.date) - new Date(b.date)
        )
      };
    });

    return formattedStats;
  }
}

module.exports = new UserActivityService(); 