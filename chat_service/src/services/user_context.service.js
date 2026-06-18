const axios = require('axios');
const { query } = require('../db/pool');
const { logger } = require('../utils/logger');
const path = require('path');
const fs = require('fs');

const CACHE_TTL_MINUTES = 30;

// UUID → filename mapping
const MOCK_FILE_MAP = {
  '00000000-0000-0000-0001-000000000001': 'user-context-parent-p-001.json',
  '00000000-0000-0000-0001-000000000002': 'user-context-parent-p-002.json',
  '00000000-0000-0000-0001-000000000003': 'user-context-parent-p-003.json',
  '00000000-0000-0000-0002-000000000001': 'user-context-teacher-t-001.json',
  '00000000-0000-0000-0002-000000000002': 'user-context-teacher-t-002.json',
  '00000000-0000-0000-0002-000000000003': 'user-context-teacher-t-003.json',
  '00000000-0000-0000-0003-000000000001': 'user-context-student-s-001.json',
};

async function getUserContext(userId, schoolId, token) {
  if (process.env.USE_MOCK_BRIDGE === 'true') {
    const context = await getMockContext(userId, schoolId);
    if (!context) {
      throw new Error('Could not resolve user context from mock data.');
    }
    return context;
  }

  const cacheKey = `user_context:${schoolId}:${userId}`;

  const cached = await query(
    `SELECT context_json FROM chat_user_context_cache
     WHERE cache_key = $1 AND expires_at > NOW()`,
    [cacheKey]
  );

  if (cached.rows.length > 0) {
    return cached.rows[0].context_json;
  }

  const context = await fetchFromBridge(token);

  if (!context) {
    throw new Error('Could not resolve user context.');
  }

  const expiresAt = new Date(Date.now() + CACHE_TTL_MINUTES * 60 * 1000);
  await query(
    `INSERT INTO chat_user_context_cache
       (cache_key, school_id, user_id, user_role, context_json, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6)
     ON CONFLICT (cache_key) DO UPDATE SET
       context_json = EXCLUDED.context_json,
       expires_at   = EXCLUDED.expires_at,
       updated_at   = NOW()`,
    [cacheKey, schoolId, userId, context.role, context, expiresAt]
  );

  return context;
}

async function fetchFromBridge(token) {
  try {
    const res = await axios.get(
      `${process.env.MAIN_API_BASE_URL}/api/internal/user-context`,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'X-Chat-Service-Key': process.env.CHAT_SERVICE_KEY,
        },
        timeout: 5000,
      }
    );
    return res.data;
  } catch (err) {
    logger.error('Bridge call failed:', err.message);
    throw err;
  }
}

async function getMockContext(userId, schoolId) {
  const mockDir = path.join(__dirname, '../../mock-data');

  // Look up file by UUID
  const filename = MOCK_FILE_MAP[userId];
  if (filename) {
    const filePath = path.join(mockDir, filename);
    if (fs.existsSync(filePath)) {
      const raw = fs.readFileSync(filePath, 'utf8');
      return JSON.parse(raw);
    }
  }

  // Fallback with proper UUIDs
  logger.warn(`No mock file found for userId: ${userId} — using fallback`);
  return {
    user_id: userId,
    school_id: schoolId,
    role: 'parent',
    full_name: 'Test User',
    children: [
      {
        student_id: '00000000-0000-0000-0003-000000000001',
        full_name: 'John Doe',
        class_id: '00000000-0000-0000-0004-000000000001',
        section: 'A',
        teachers: [
          {
            teacher_id: '00000000-0000-0000-0002-000000000001',
            user_id: '00000000-0000-0000-0002-000000000001',
            full_name: 'David Mugisha',
            subject: 'English',
            is_online: false,
          },
          {
            teacher_id: '00000000-0000-0000-0002-000000000002',
            user_id: '00000000-0000-0000-0002-000000000002',
            full_name: 'Sarah Uwimana',
            subject: 'Mathematics',
            is_online: true,
          },
        ],
      },
    ],
  };
}

async function invalidateCache(userId, schoolId) {
  const cacheKey = `user_context:${schoolId}:${userId}`;
  await query(
    'DELETE FROM chat_user_context_cache WHERE cache_key = $1',
    [cacheKey]
  );
  logger.info(`Cache invalidated for ${cacheKey}`);
}

module.exports = { getUserContext, invalidateCache };