const express = require('express');
const router = express.Router();
const { authenticate, requireRole } = require('../middleware/auth.middleware');
const studentController = require('../controllers/student.controller');

// Roll number search — teacher only
router.get('/search', authenticate, requireRole('teacher'), studentController.searchByRollNumber);

module.exports = router;
