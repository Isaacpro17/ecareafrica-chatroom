const { query } = require('../db/pool');
const { sendFcmToToken } = require('./firebase.service');
const { logger } = require('../utils/logger');

/**
 * Send a push notification to all active device tokens for a user.
 * Automatically purges expired/invalid tokens.
 */
async function sendPushNotification(userId, schoolId, { title, body, data = {} }) {
  try {
    // Get all active device tokens for this user
    const tokensRes = await query(
      `SELECT id, device_token FROM chat_user_device_tokens
       WHERE user_id = $1 AND school_id = $2 AND is_active = TRUE`,
      [userId, schoolId]
    );

    if (tokensRes.rows.length === 0) {
      logger.debug(`No device tokens for user ${userId}`);
      return;
    }

    const expiredIds = [];

    for (const row of tokensRes.rows) {
      const result = await sendFcmToToken(row.device_token, title, body, data);
      if (result.expired) {
        expiredIds.push(row.id);
      } else {
        // Update last_used_at
        await query(
          `UPDATE chat_user_device_tokens SET last_used_at = NOW() WHERE id = $1`,
          [row.id]
        );
      }
    }

    // Purge expired tokens
    if (expiredIds.length > 0) {
      await query(
        `UPDATE chat_user_device_tokens SET is_active = FALSE WHERE id = ANY($1)`,
        [expiredIds]
      );
      logger.info(`Purged ${expiredIds.length} expired FCM tokens for user ${userId}`);
    }
  } catch (err) {
    logger.error(`sendPushNotification failed for user ${userId}:`, err);
  }
}

/**
 * Register or refresh a device token for a user.
 * Called by the Flutter app on session start.
 */
async function registerDeviceToken(userId, schoolId, userRole, deviceToken, platform) {
  await query(
    `INSERT INTO chat_user_device_tokens
       (user_id, school_id, user_role, device_token, device_platform, last_used_at)
     VALUES ($1, $2, $3, $4, $5, NOW())
     ON CONFLICT (user_id, device_token) DO UPDATE
     SET is_active = TRUE, last_used_at = NOW(), updated_at = NOW()`,
    [userId, schoolId, userRole, deviceToken, platform]
  );
}

module.exports = { sendPushNotification, registerDeviceToken };
