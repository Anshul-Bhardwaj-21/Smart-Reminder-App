const mongoose = require('mongoose');

const taskSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  title: {
    type: String,
    required: true
  },
  description: String,
  startTime: Date,
  endTime: Date,
  location: {
    lat: Number,
    lng: Number,
    address: String
  },
  priority: {
    type: String,
    enum: ['low', 'medium', 'high'],
    default: 'medium'
  },
  status: {
    type: String,
    enum: ['pending', 'in_progress', 'completed', 'cancelled'],
    default: 'pending'
  },
  reminders: [{
    time: Date,
    type: String,
    message: String,
    status: {
      type: String,
      enum: ['pending', 'sent', 'cancelled'],
      default: 'pending'
    }
  }]
}, { timestamps: true });

module.exports = mongoose.model('Task', taskSchema); 