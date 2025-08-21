const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const { createProxyMiddleware } = require('http-proxy-middleware');
const redis = require('redis');
const jwt = require('jsonwebtoken');
const winston = require('winston');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Logger configuration
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' })
  ]
});

// Redis client
let redisClient;
try {
  redisClient = redis.createClient({
    url: process.env.REDIS_URL || 'redis://redis:6379'
  });
  redisClient.connect();
  redisClient.on('error', (err) => logger.error('Redis error:', err));
} catch (error) {
  logger.error('Failed to connect to Redis:', error);
}

// Middleware
app.use(helmet());
app.use(compression());
app.use(cors({
  origin: ['http://localhost', 'http://localhost:3000', 'http://localhost:80'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Cart-Token']
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// Request logging
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    timestamp: new Date().toISOString()
  });
  
  // Debug route matching
  logger.debug(`Route debugging: method=${req.method}, path="${req.path}", originalUrl="${req.originalUrl}", url="${req.url}"`);
  
  next();
});

// JWT Authentication middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_SECRET_KEY || 'your-secret-key', (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

// Service URLs
const services = {
  auth: process.env.AUTH_SERVICE_URL || 'http://auth-service:5001',
  product: process.env.PRODUCT_SERVICE_URL || 'http://product-service:5002',
  cart: process.env.CART_SERVICE_URL || 'http://cart-service:5003',
  payment: process.env.PAYMENT_SERVICE_URL || 'http://payment-service:5004',
  order: process.env.ORDER_SERVICE_URL || 'http://order-service:5005'
};

// Proxy configurations
const createProxy = (target, pathRewrite = {}) => createProxyMiddleware({
  target,
  changeOrigin: true,
  pathRewrite,
  onError: (err, req, res) => {
    logger.error(`Proxy error for ${req.path}:`, err);
    res.status(503).json({ error: 'Service temporarily unavailable' });
  },
  onProxyReq: (proxyReq, req, res) => {
    // Forward user info if authenticated
    if (req.user) {
      proxyReq.setHeader('X-User-ID', req.user.id);
      proxyReq.setHeader('X-User-Email', req.user.email);
    }
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    services: {
      redis: redisClient?.isReady ? 'connected' : 'disconnected'
    }
  });
});

// API Gateway routes

// Product routes (public access) - moved to top
app.get('/api/products', (req, res) => {
  logger.info('Simple product route hit!');
  res.json({ message: 'Product route working' });
});

// Authentication routes (no auth required)
app.use('/api/auth', createProxy(services.auth, { '^/api/auth': '' }));

// Product routes (public access)
app.use('/api/products', createProxy(services.product, { '^/api/products': '/products' }));

// Cart routes (mixed access - some endpoints require auth)
app.use('/api/cart', (req, res, next) => {
  // Check if cart token is present for guest users
  const cartToken = req.headers['x-cart-token'];
  const authHeader = req.headers['authorization'];
  
  if (!authHeader && !cartToken) {
    return res.status(401).json({ error: 'Authentication or cart token required' });
  }
  
  // If auth header is present, validate it
  if (authHeader) {
    return authenticateToken(req, res, next);
  }
  
  // If only cart token, proceed without authentication
  next();
}, createProxy(services.cart, { '^/api/cart': '' }));

// Payment routes (authentication required)
app.use('/api/payments', authenticateToken, createProxy(services.payment, { '^/api/payments': '' }));

// Order routes (authentication required)
app.use('/api/orders', authenticateToken, createProxy(services.order, { '^/api/orders': '' }));

// Catch-all for undefined routes
app.use('/api/*', (req, res) => {
  logger.warn(`Catch-all route matched: ${req.method} ${req.path} - Original URL: ${req.originalUrl}`);
  res.status(404).json({ error: 'API endpoint not found' });
});

// Global error handler
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({ 
    error: 'Internal server error',
    requestId: req.id 
  });
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, shutting down gracefully');
  
  if (redisClient) {
    await redisClient.quit();
  }
  
  process.exit(0);
});

process.on('SIGINT', async () => {
  logger.info('SIGINT received, shutting down gracefully');
  
  if (redisClient) {
    await redisClient.quit();
  }
  
  process.exit(0);
});

app.listen(PORT, '0.0.0.0', () => {
  logger.info(`API Gateway running on port ${PORT}`);
  logger.info('Service endpoints:', services);
});

module.exports = app;
