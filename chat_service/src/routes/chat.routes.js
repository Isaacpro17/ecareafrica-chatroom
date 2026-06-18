const express = require('express');
const router = express.Router();
const { authenticate, requireRole } = require('../middleware/auth.middleware');
const chatController = require('../controllers/chat.controller');
const statusController = require('../controllers/status.controller');
const { registerDeviceToken } = require('../services/notification.service');

// All chat routes require authentication
router.use(authenticate);

// ── Threads ───────────────────────────────────────────────────────────────────
router.get('/threads',                    chatController.getThreads);
router.post('/threads',                   chatController.createThread);
router.get('/threads/:threadId/messages', chatController.getMessages);
router.put('/threads/:threadId/mute',     chatController.muteThread);

// ── Messages ──────────────────────────────────────────────────────────────────
router.post('/messages',                  chatController.sendMessage);
router.put('/messages/:messageId',        chatController.editMessage);
router.put('/messages/:messageId/read',   chatController.markSeen);
// NOTE: DELETE /messages is intentionally NOT implemented (PRD policy)

// ── Broadcast ─────────────────────────────────────────────────────────────────
router.post('/broadcast',                 requireRole('teacher'), chatController.sendBroadcast);
router.get('/broadcast/:broadcastId',     requireRole('teacher'), chatController.getBroadcast);

// ── Search ────────────────────────────────────────────────────────────────────
router.get('/search',                     chatController.search);

// ── Status / Presence ─────────────────────────────────────────────────────────
router.put('/status/heartbeat',           statusController.heartbeat);
router.get('/status/:userId',             statusController.getUserStatus);

// ── Settings ──────────────────────────────────────────────────────────────────
router.put('/settings/mute-all',          chatController.muteAll);

// ── User context (all roles) ──────────────────────────────────────────────────
// Returns the full resolved user context — called by the splash screen on login
router.get('/me',                         chatController.getMe);

// ── Parent-specific ───────────────────────────────────────────────────────────
router.get('/children',                   requireRole('parent'), chatController.getChildren);
router.get('/teachers',                   requireRole('parent'), chatController.getTeachersForChild);

// ── Student-specific ──────────────────────────────────────────────────────────
router.get('/student/teachers',           requireRole('student'), chatController.getStudentTeachers);

// ── Unread count ──────────────────────────────────────────────────────────────
router.get('/unread-count',               chatController.getUnreadCount);

// ── Device token registration (called by Flutter on session start) ────────────
router.post('/device-token', async (req, res) => {
  try {
    const { sub: userId, school_id: schoolId, role: userRole } = req.user;
    const { device_token, device_platform } = req.body;

    if (!device_token || !device_platform) {
      return res.status(400).json({
        error: 'INVALID_REQUEST',
        message: 'device_token and device_platform are required.',
      });
    }
    if (!['android', 'ios'].includes(device_platform)) {
      return res.status(400).json({
        error: 'INVALID_REQUEST',
        message: "device_platform must be 'android' or 'ios'.",
      });
    }

    await registerDeviceToken(userId, schoolId, userRole, device_token, device_platform);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
});

module.exports = router;
