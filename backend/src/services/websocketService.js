const WebSocket = require('ws');
const jwt = require('jsonwebtoken');
const config = require('../config/environment');
const logger = require('../utils/logger');

class WebSocketService {
  constructor(server) {
    this.wss = new WebSocket.Server({ server });
    this.clients = new Map(); // Map to store client connections

    this.wss.on('connection', this.handleConnection.bind(this));
  }

  handleConnection(ws, req) {
    try {
      const token = req.url.split('token=')[1];
      const decoded = jwt.verify(token, config.jwtSecret);
      
      this.clients.set(decoded.id, ws);

      ws.on('message', (message) => this.handleMessage(decoded.id, message));
      ws.on('close', () => this.handleClose(decoded.id));
      
      logger.info(`Client connected: ${decoded.id}`);
    } catch (error) {
      logger.error('WebSocket connection error:', error);
      ws.close();
    }
  }

  handleMessage(userId, message) {
    try {
      const data = JSON.parse(message);
      // Handle different message types
      switch (data.type) {
        case 'task_update':
          this.broadcastTaskUpdate(userId, data.payload);
          break;
        case 'notification':
          this.sendNotification(userId, data.payload);
          break;
        // Add more message types as needed
      }
    } catch (error) {
      logger.error('WebSocket message handling error:', error);
    }
  }

  handleClose(userId) {
    this.clients.delete(userId);
    logger.info(`Client disconnected: ${userId}`);
  }

  broadcastTaskUpdate(userId, task) {
    const message = JSON.stringify({
      type: 'task_update',
      payload: task
    });

    this.clients.forEach((client, clientId) => {
      if (client.readyState === WebSocket.OPEN && clientId !== userId) {
        client.send(message);
      }
    });
  }

  sendNotification(userId, notification) {
    const client = this.clients.get(userId);
    if (client && client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify({
        type: 'notification',
        payload: notification
      }));
    }
  }
}

module.exports = WebSocketService; 