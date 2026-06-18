const admin = require('firebase-admin');
const { logger } = require('../utils/logger');

let firebaseApp;

function initFirebase() {
  if (firebaseApp) return Promise.resolve();

  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
  const isMockMode =
    !process.env.FIREBASE_PROJECT_ID ||
    process.env.FIREBASE_PROJECT_ID === 'your-firebase-project-id' ||
    !privateKey ||
    privateKey.includes('YOUR_KEY_HERE');

  if (isMockMode) {
    logger.warn('⚠️  Firebase not configured — running in mock mode. Real-time events and push notifications are disabled.');
    return Promise.resolve();
  }

  firebaseApp = admin.initializeApp({
    credential: admin.credential.cert({
      projectId:   process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey,
    }),
    databaseURL: process.env.FIREBASE_DATABASE_URL,
  });

  logger.info('✅ Firebase Admin SDK initialized');
  return Promise.resolve();
}

/**
 * Publish a lightweight event to Firebase Realtime Database.
 * Flutter apps listen to this path and fetch the full message from the REST API.
 * Message content is NEVER stored in Firebase.
 */
async function publishFirebaseEvent(schoolId, threadId, messageId) {
  if (!firebaseApp) return;
  const db = admin.database(firebaseApp);
  const ref = db.ref(`schools/${schoolId}/threads/${threadId}/events`);
  await ref.push({
    message_id: messageId,
    timestamp: admin.database.ServerValue.TIMESTAMP,
  });
}

/**
 * Update user presence in Firebase.
 */
async function setPresence(schoolId, userId, isOnline) {
  if (!firebaseApp) return;
  const db = admin.database(firebaseApp);
  const ref = db.ref(`schools/${schoolId}/presence/${userId}`);
  await ref.set({
    is_online: isOnline,
    last_seen: admin.database.ServerValue.TIMESTAMP,
  });
}

/**
 * Send FCM push notification to a device token.
 */
async function sendFcmToToken(deviceToken, title, body, data = {}) {
  if (!firebaseApp) return { success: false, skipped: true };
  const message = {
    token: deviceToken,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)])
    ),
    android: {
      priority: 'high',
      notification: {
        channelId: 'netrack_chat_channel',
        color: '#1565C0',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
  };

  try {
    const response = await admin.messaging(firebaseApp).send(message);
    return { success: true, messageId: response };
  } catch (err) {
    if (err.code === 'messaging/registration-token-not-registered') {
      return { success: false, expired: true };
    }
    throw err;
  }
}

module.exports = { initFirebase, publishFirebaseEvent, setPresence, sendFcmToToken };