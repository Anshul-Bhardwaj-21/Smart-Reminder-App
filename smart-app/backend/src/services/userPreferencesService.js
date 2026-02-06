const User = require('../models/User');
const CacheService = require('./cacheService');
const logger = require('../utils/logger');

class UserPreferencesService {
  constructor() {
    this.cache = CacheService;
    this.defaultPreferences = {
      theme: 'light',
      language: 'en',
      notifications: {
        email: true,
        push: true,
        taskReminders: true,
        dailyDigest: false,
        soundEnabled: true
      },
      taskDefaults: {
        defaultDuration: 30, // minutes
        defaultPriority: 'medium',
        defaultReminder: 15, // minutes before
        useLocationServices: true
      },
      privacy: {
        shareTaskStats: false,
        publicProfile: false,
        showActivityStatus: true
      },
      accessibility: {
        fontSize: 'medium',
        highContrast: false,
        reduceMotion: false
      },
      productivity: {
        pomodoroDuration: 25,
        shortBreakDuration: 5,
        longBreakDuration: 15,
        tasksBeforeLongBreak: 4
      }
    };
  }

  async getUserPreferences(userId) {
    try {
      const cacheKey = `user:${userId}:preferences`;
      let preferences = await this.cache.get(cacheKey);

      if (!preferences) {
        const user = await User.findById(userId).select('preferences');
        preferences = this._mergeWithDefaults(user.preferences);
        await this.cache.set(cacheKey, preferences);
      }

      return preferences;
    } catch (error) {
      logger.error('Error fetching user preferences:', error);
      throw error;
    }
  }

  async updatePreferences(userId, updates) {
    try {
      const currentPreferences = await this.getUserPreferences(userId);
      const updatedPreferences = this._deepMerge(currentPreferences, updates);

      // Validate preferences
      this._validatePreferences(updatedPreferences);

      // Update database
      await User.findByIdAndUpdate(userId, {
        preferences: updatedPreferences
      });

      // Update cache
      const cacheKey = `user:${userId}:preferences`;
      await this.cache.set(cacheKey, updatedPreferences);

      return updatedPreferences;
    } catch (error) {
      logger.error('Error updating user preferences:', error);
      throw error;
    }
  }

  async resetPreferences(userId, category = null) {
    try {
      let updatedPreferences;

      if (category) {
        const currentPreferences = await this.getUserPreferences(userId);
        updatedPreferences = {
          ...currentPreferences,
          [category]: this.defaultPreferences[category]
        };
      } else {
        updatedPreferences = this.defaultPreferences;
      }

      await User.findByIdAndUpdate(userId, {
        preferences: updatedPreferences
      });

      const cacheKey = `user:${userId}:preferences`;
      await this.cache.set(cacheKey, updatedPreferences);

      return updatedPreferences;
    } catch (error) {
      logger.error('Error resetting user preferences:', error);
      throw error;
    }
  }

  _mergeWithDefaults(userPreferences) {
    return this._deepMerge(this.defaultPreferences, userPreferences || {});
  }

  _deepMerge(target, source) {
    const merged = { ...target };

    Object.keys(source).forEach(key => {
      if (source[key] && typeof source[key] === 'object') {
        merged[key] = this._deepMerge(merged[key] || {}, source[key]);
      } else {
        merged[key] = source[key];
      }
    });

    return merged;
  }

  _validatePreferences(preferences) {
    // Validate theme
    if (!['light', 'dark', 'system'].includes(preferences.theme)) {
      throw new Error('Invalid theme preference');
    }

    // Validate notification settings
    if (typeof preferences.notifications !== 'object') {
      throw new Error('Invalid notification preferences');
    }

    // Validate productivity settings
    const { productivity } = preferences;
    if (productivity) {
      if (productivity.pomodoroDuration < 1 || productivity.pomodoroDuration > 60) {
        throw new Error('Invalid pomodoro duration');
      }
      if (productivity.tasksBeforeLongBreak < 1 || productivity.tasksBeforeLongBreak > 10) {
        throw new Error('Invalid tasks before long break');
      }
    }

    // Add more validation as needed
  }
}

module.exports = new UserPreferencesService(); 