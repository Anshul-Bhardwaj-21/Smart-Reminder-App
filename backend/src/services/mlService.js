const tf = require('@tensorflow/tfjs-node');
const logger = require('../utils/logger');

class MLService {
  constructor() {
    this.model = null;
    this.initialized = false;
  }

  async initialize() {
    try {
      // Load pre-trained model
      this.model = await tf.loadLayersModel('file://./models/task_analysis_model/model.json');
      this.initialized = true;
      logger.info('ML model loaded successfully');
    } catch (error) {
      logger.error('Error loading ML model:', error);
      throw error;
    }
  }

  async predictTaskPriority(task) {
    if (!this.initialized) {
      throw new Error('ML Service not initialized');
    }

    try {
      // Prepare input features
      const features = this._extractFeatures(task);
      
      // Make prediction
      const prediction = await this.model.predict(features).array();
      
      // Convert prediction to priority level
      return this._convertToPriority(prediction[0]);
    } catch (error) {
      logger.error('Error predicting task priority:', error);
      throw error;
    }
  }

  async estimateCompletionTime(task) {
    if (!this.initialized) {
      throw new Error('ML Service not initialized');
    }

    try {
      const features = this._extractTimeFeatures(task);
      const prediction = await this.model.predict(features).array();
      return Math.round(prediction[0][0]); // Estimated minutes
    } catch (error) {
      logger.error('Error estimating completion time:', error);
      throw error;
    }
  }

  _extractFeatures(task) {
    // Implementation of feature extraction
    // Return tensor of task features
  }

  _extractTimeFeatures(task) {
    // Implementation of time-related feature extraction
  }

  _convertToPriority(prediction) {
    const priorities = ['low', 'medium', 'high'];
    return priorities[prediction.indexOf(Math.max(...prediction))];
  }
}

module.exports = new MLService(); 