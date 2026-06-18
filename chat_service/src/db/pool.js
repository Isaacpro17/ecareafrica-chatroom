const { Pool } = require('pg');
const { logger } = require('../utils/logger');

const pool = new Pool({
  host:     process.env.DB_HOST     || 'localhost',
  port:     parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME     || 'netrack_chat',
  user:     process.env.DB_USER     || 'chat_user',
  password: process.env.DB_PASSWORD || '',
  max:      parseInt(process.env.DB_POOL_MAX || '20'),
  idleTimeoutMillis: parseInt(process.env.DB_POOL_IDLE_TIMEOUT || '30000'),
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  logger.error('Unexpected PostgreSQL pool error:', err);
});

async function connectDB() {
  const client = await pool.connect();
  await client.query('SELECT 1');
  client.release();
}

/**
 * Execute a parameterized query.
 * @param {string} text  - SQL query with $1, $2 placeholders
 * @param {Array}  params - Query parameters
 */
async function query(text, params) {
  const start = Date.now();
  const res = await pool.query(text, params);
  const duration = Date.now() - start;
  if (duration > 1000) {
    logger.warn(`Slow query (${duration}ms): ${text}`);
  }
  return res;
}

/**
 * Get a client for transactions.
 */
async function getClient() {
  return pool.connect();
}

module.exports = { pool, connectDB, query, getClient };
