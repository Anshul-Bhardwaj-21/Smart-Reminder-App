const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');
const Redis = require('ioredis');
const config = require('../config/environment');

const redisClient = new Redis(config.redisUrl);

const createRateLimiter = (options = {}) => {
  return rateLimit({
    store: new RedisStore({
      client: redisClient,
      prefix: 'rate-limit:',
    }),
    windowMs: options.windowMs || 15 * 60 * 1000, // 15 minutes
    max: options.max || 100, // Limit each IP to 100 requests per windowMs
    message: {
      success: false,
      message: 'Too many requests, please try again later.'
    },
    standardHeaders: true,
    legacyHeaders: false,
    ...options
  });
};

// Different rate limiters for different routes
exports.apiLimiter = createRateLimiter();

exports.authLimiter = createRateLimiter({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 5, // 5 attempts per hour
  message: {
    success: false,
    message: 'Too many login attempts, please try again later.'
  }
});

exports.createTaskLimiter = createRateLimiter({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 50 // 50 task creations per hour
}); 