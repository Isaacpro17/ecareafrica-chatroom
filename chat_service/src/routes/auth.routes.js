const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');

// Student OTP authentication (public — no JWT required)
router.post('/student/request-otp', authController.requestStudentOtp);
router.post('/student/verify-otp',  authController.verifyStudentOtp);

module.exports = router;
