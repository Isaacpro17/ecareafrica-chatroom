require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const { logger } = require('./utils/logger');
const { connectDB } = require('./db/pool');
const { initFirebase } = require('./services/firebase.service');

// Route imports
const authRoutes    = require('./routes/auth.routes');
const chatRoutes    = require('./routes/chat.routes');
const studentRoutes = require('./routes/student.routes');
const adminRoutes   = require('./routes/admin.routes');
const devRoutes     = require('./routes/dev.routes');

const app = express();

// ── Security middleware ────────────────────────────────────────────────────────
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Chat-Service-Key'],
}));

// ── Rate limiting ─────────────────────────────────────────────────────────────
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'RATE_LIMITED', message: 'Too many requests.' },
});
app.use(limiter);

// ── Body parsing ──────────────────────────────────────────────────────────────
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// ── Request logging ───────────────────────────────────────────────────────────
app.use((req, _res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    ip: req.ip,
    userAgent: req.get('User-Agent'),
  });
  next();
});

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/auth',    authRoutes);
app.use('/chat',    chatRoutes);
app.use('/students', studentRoutes);
app.use('/admin',   adminRoutes);

// Dev-only routes (test token endpoint)
if (process.env.NODE_ENV === 'development') {
  app.use('/dev', devRoutes);
  logger.warn('⚠️  Dev routes enabled — disable in production!');
}

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'netrack-chat-service', version: '1.0.0' });
});

// ── 404 handler ───────────────────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ error: 'NOT_FOUND', message: 'Endpoint not found.' });
});

// ── Global error handler ──────────────────────────────────────────────────────
app.use((err, _req, res, _next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({
    error: 'SERVER_ERROR',
    message: 'An internal error occurred.',
  });
});

// ── Bootstrap ─────────────────────────────────────────────────────────────────
async function bootstrap() {
  try {
    await connectDB();
    logger.info('✅ PostgreSQL connected');

    await initFirebase();
    logger.info('✅ Firebase Admin initialized');

    const PORT = process.env.PORT || 3000;
    app.listen(PORT, () => {
      logger.info(`🚀 Netrack Chat Service running on port ${PORT}`);
      logger.info(`   Environment: ${process.env.NODE_ENV}`);
      logger.info(`   Mock bridge: ${process.env.USE_MOCK_BRIDGE}`);
    });
  } catch (err) {
    logger.error('Failed to start server:', err);
    process.exit(1);
  }
}

bootstrap();

module.exports = app; // for testing
