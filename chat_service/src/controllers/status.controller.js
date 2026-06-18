const { query } = require('../db/pool');
const { logger } = require('../utils/logger');

// ── PUT /chat/status/heartbeat ────────────────────────────────────────────────
async function heartbeat(req, res) {
  try {
    const { sub: userId, school_id: schoolId } = req.user;

    await query(
      `INSERT INTO chat_active_status (user_id, school_id, is_online, last_seen_at)
       VALUES ($1, $2, TRUE, NOW())
       ON CONFLICT (user_id) DO UPDATE
       SET is_online = TRUE, last_seen_at = NOW(), updated_at = NOW()`,
      [userId, schoolId]
    );

    res.json({ success: true });
  } catch (err) {
    logger.error('heartbeat error:', err);
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

// ── GET /chat/status/:userId ──────────────────────────────────────────────────
async function getUserStatus(req, res) {
  try {
    const { school_id: schoolId } = req.user;
    const { userId } = req.params;

    const result = await query(
      `SELECT is_online, last_seen_at
       FROM   chat_active_status
       WHERE  user_id = $1 AND school_id = $2`,
      [userId, schoolId]
    );

    if (result.rows.length === 0) {
      return res.json({ data: { is_online: false, last_seen_at: null } });
    }

    // Never return phone number — only online status
    const { is_online, last_seen_at } = result.rows[0];
    res.json({ data: { is_online, last_seen_at } });
  } catch (err) {
    logger.error('getUserStatus error:', err);
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

module.exports = { heartbeat, getUserStatus };
