const axios = require('axios');
const { query } = require('../db/pool');
const { logger } = require('../utils/logger');

/**
 * Enqueue an SMS for a user (resolves phone from user-context cache).
 * Phone numbers are NEVER stored in the chat DB — resolved at send time only.
 */
async function enqueueSms(recipientUserId, schoolId, messageId, messageText) {
  try {
    // Resolve phone from user-context cache
    const cacheRes = await query(
      `SELECT context_json FROM chat_user_context_cache
       WHERE user_id = $1 AND school_id = $2 AND expires_at > NOW()
       LIMIT 1`,
      [recipientUserId, schoolId]
    );

    let phone = null;
    if (cacheRes.rows.length > 0) {
      const ctx = cacheRes.rows[0].context_json;
      phone = ctx.phone || ctx.parent_phone || null;
    }

    if (!phone) {
      logger.warn(`No phone found for user ${recipientUserId} — SMS skipped`);
      return;
    }

    // Log SMS record (pending)
    const logRes = await query(
      `INSERT INTO chat_sms_logs
         (school_id, message_id, recipient_user_id, status)
       VALUES ($1, $2, $3, 'pending')
       RETURNING id`,
      [schoolId, messageId, recipientUserId]
    );
    const logId = logRes.rows[0].id;

    // Send SMS
    await sendSmsRaw(phone, `New message: ${messageText.slice(0, 100)}. Open Netrack to reply.`);

    // Update log to sent
    await query(
      `UPDATE chat_sms_logs SET status = 'sent', sent_at = NOW() WHERE id = $1`,
      [logId]
    );
  } catch (err) {
    logger.error(`enqueueSms failed for user ${recipientUserId}:`, err);
  }
}

/**
 * Send an SMS directly to a phone number.
 * Phone number is used once and never persisted.
 */
async function sendSmsRaw(phone, message) {
  if (process.env.USE_MOCK_BRIDGE === 'true') {
    logger.info(`[MOCK SMS] To: ${phone.slice(0, 6)}**** | Message: ${message}`);
    return { success: true, mock: true };
  }

  try {
    const response = await axios.post(
      process.env.SMS_GATEWAY_URL,
      { to: phone, message, from: 'Netrack' },
      {
        headers: { 'X-API-Key': process.env.SMS_GATEWAY_API_KEY },
        timeout: 10000,
      }
    );
    return { success: true, response: response.data };
  } catch (err) {
    logger.error(`SMS gateway error for ${phone.slice(0, 6)}****:`, err.message);
    throw err;
  }
}

module.exports = { enqueueSms, sendSmsRaw };
