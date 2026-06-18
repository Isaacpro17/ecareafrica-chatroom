/**
 * Development-only routes.
 * These are ONLY mounted when NODE_ENV=development.
 * NEVER expose these in production.
 */
const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');

/**
 * POST /dev/auth/test-token
 * Body: { user_id, school_id, role }
 * Returns a valid JWT for testing without needing the real Netrack auth system.
 */
router.post('/auth/test-token', (req, res) => {
  const { user_id, school_id, role } = req.body;

  if (!user_id || !school_id || !role) {
    return res.status(400).json({
      error: 'INVALID_REQUEST',
      message: 'user_id, school_id, and role are required.',
    });
  }

  const validRoles = ['parent', 'teacher', 'student'];
  if (!validRoles.includes(role)) {
    return res.status(400).json({
      error: 'INVALID_REQUEST',
      message: `role must be one of: ${validRoles.join(', ')}`,
    });
  }

  const payload = {
    sub: user_id,
    user_id,
    school_id,
    role,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60, // 7 days
  };

  const token = jwt.sign(payload, process.env.JWT_SECRET);

  return res.json({
    token,
    payload,
    note: 'DEV ONLY — This endpoint does not exist in production.',
  });
});

module.exports = router;
