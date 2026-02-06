const Task = require('../models/Task');
const UserActivityService = require('./userActivityService');
const MLService = require('./mlService');
const logger = require('../utils/logger');

class TaskRecommendationService {
  constructor() {
    this.userActivityService = UserActivityService;
    this.mlService = MLService;
  }

  async generateRecommendations(userId) {
    try {
      const [
        userPatterns,
        completedTasks,
        productiveHours
      ] = await Promise.all([
        this._analyzeUserPatterns(userId),
        this._getCompletedTasksAnalysis(userId),
        this._getProductiveHours(userId)
      ]);

      const recommendations = {
        scheduleSuggestions: await this._generateScheduleSuggestions(
          userPatterns,
          productiveHours
        ),
        taskPriorities: await this._suggestTaskPriorities(completedTasks),
        timeManagement: this._generateTimeManagementTips(userPatterns),
        productivity: await this._generateProductivityInsights(userId)
      };

      return recommendations;
    } catch (error) {
      logger.error('Error generating recommendations:', error);
      throw error;
    }
  }

  async _analyzeUserPatterns(userId) {
    try {
      const activities = await this.userActivityService.getUserActivities(userId, {
        startDate: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) // Last 30 days
      });

      const patterns = {
        taskCompletionTimes: {},
        preferredWorkingHours: new Set(),
        commonTaskTypes: {},
        breakPatterns: []
      };

      activities.forEach(activity => {
        if (activity.type === 'task_completed') {
          const hour = new Date(activity.timestamp).getHours();
          patterns.preferredWorkingHours.add(hour);
          
          const taskType = activity.details.taskType;
          patterns.commonTaskTypes[taskType] = (patterns.commonTaskTypes[taskType] || 0) + 1;
        }
      });

      return patterns;
    } catch (error) {
      logger.error('Error analyzing user patterns:', error);
      throw error;
    }
  }

  async _getCompletedTasksAnalysis(userId) {
    try {
      const completedTasks = await Task.find({
        userId,
        status: 'completed',
        completedAt: { 
          $gte: new Date(Date.now() - 90 * 24 * 60 * 60 * 1000) // Last 90 days
        }
      });

      return completedTasks.reduce((analysis, task) => {
        const duration = task.completedAt - task.startTime;
        const category = task.category || 'uncategorized';
        
        if (!analysis[category]) {
          analysis[category] = {
            count: 0,
            avgDuration: 0,
            successRate: 0
          };
        }

        analysis[category].count++;
        analysis[category].avgDuration = 
          (analysis[category].avgDuration * (analysis[category].count - 1) + duration) 
          / analysis[category].count;
        
        return analysis;
      }, {});
    } catch (error) {
      logger.error('Error analyzing completed tasks:', error);
      throw error;
    }
  }

  async _getProductiveHours(userId) {
    try {
      const completedTasks = await Task.find({
        userId,
        status: 'completed',
        completedAt: { $exists: true }
      }).sort('-completedAt').limit(100);

      const hourlyProductivity = Array(24).fill(0);
      const hourlyTaskCount = Array(24).fill(0);

      completedTasks.forEach(task => {
        const hour = new Date(task.completedAt).getHours();
        const efficiency = this._calculateTaskEfficiency(task);
        
        hourlyProductivity[hour] += efficiency;
        hourlyTaskCount[hour]++;
      });

      return hourlyProductivity.map((productivity, hour) => ({
        hour,
        productivity: hourlyTaskCount[hour] ? productivity / hourlyTaskCount[hour] : 0
      })).sort((a, b) => b.productivity - a.productivity);
    } catch (error) {
      logger.error('Error calculating productive hours:', error);
      throw error;
    }
  }

  async _generateScheduleSuggestions(userPatterns, productiveHours) {
    const suggestions = [];
    const topProductiveHours = productiveHours.slice(0, 5);

    // Suggest optimal working hours
    suggestions.push({
      type: 'optimal_hours',
      message: 'Your most productive hours are:',
      hours: topProductiveHours.map(h => ({
        hour: h.hour,
        productivity: h.productivity
      }))
    });

    // Suggest task grouping
    if (userPatterns.commonTaskTypes) {
      const taskGroups = Object.entries(userPatterns.commonTaskTypes)
        .sort(([,a], [,b]) => b - a)
        .slice(0, 3);

      suggestions.push({
        type: 'task_grouping',
        message: 'Consider grouping similar tasks:',
        groups: taskGroups.map(([type, count]) => ({
          type,
          frequency: count
        }))
      });
    }

    return suggestions;
  }

  async _suggestTaskPriorities(completedTasks) {
    const priorities = [];
    
    Object.entries(completedTasks).forEach(([category, stats]) => {
      if (stats.count >= 5) { // Only suggest for categories with enough data
        priorities.push({
          category,
          suggestedPriority: this._calculateCategoryPriority(stats),
          reasoning: this._generatePriorityReasoning(stats)
        });
      }
    });

    return priorities;
  }

  _generateTimeManagementTips(userPatterns) {
    const tips = [];
    
    // Analyze work patterns
    const workingHours = Array.from(userPatterns.preferredWorkingHours);
    if (workingHours.length > 8) {
      tips.push({
        type: 'work_distribution',
        message: 'Consider consolidating your work hours for better focus'
      });
    }

    // Add more specific tips based on patterns
    return tips;
  }

  _calculateTaskEfficiency(task) {
    const estimatedDuration = task.endTime - task.startTime;
    const actualDuration = task.completedAt - task.startTime;
    
    return estimatedDuration / actualDuration;
  }

  _calculateCategoryPriority(stats) {
    const efficiency = stats.successRate / 100;
    const frequency = Math.min(stats.count / 20, 1); // Normalize to 0-1
    
    return (efficiency * 0.7 + frequency * 0.3);
  }

  _generatePriorityReasoning(stats) {
    const reasons = [];
    
    if (stats.successRate > 80) {
      reasons.push('High success rate');
    }
    if (stats.count > 10) {
      reasons.push('Frequently occurring');
    }
    if (stats.avgDuration < 30 * 60 * 1000) { // Less than 30 minutes
      reasons.push('Quick to complete');
    }

    return reasons;
  }
}

module.exports = new TaskRecommendationService(); 