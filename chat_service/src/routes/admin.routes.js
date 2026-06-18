const express = require('express');
const router = express.Router();
const { authenticate, requireServiceKey } = require('../middleware/auth.middleware');
const { invalidateCache } = require('../services/user_context.service');

// Cache invalidation webhook — called by main Netrack system when user data changes
router.post('/cache/invalidate', requireServiceKey, async (req, res) => {
  const { user_id, school_id } = req.body;
  if (!user_id || !school_id) {
    return res.status(400).json({ error: 'INVALID_REQUEST' });
  }
  await invalidateCache(user_id, school_id);
  res.json({ success: true });
});

// Enable chatroom for a school
router.post('/schools/:schoolId/enable', authenticate, async (req, res) => {
  // TODO: implement school feature flag
  res.json({ success: true, school_id: req.params.schoolId });
});

module.exports = router;
