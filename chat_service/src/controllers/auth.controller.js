const jwt = require('jsonwebtoken');
const path = require('path');
const fs = require('fs');
const { query } = require('../db/pool');
const { getUserContext } = require('../services/user_context.service');
const { sendSmsRaw } = require('../services/sms.service');
const { logger } = require('../utils/logger');

// In-memory OTP store (use Redis in production)
const otpStore = new Map(); // key: studentId → { otp, expiresAt, parentPhone }

function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function getMockStudentRecord(student_id) {
  const mockDir = path.join(__dirname, '../../mock-data');
  const files = fs.readdirSync(mockDir).filter(f => f.includes('student'));

  for (const file of files) {
    const data = JSON.parse(fs.readFileSync(path.join(mockDir, file), 'utf8'));
    if (data.student_id === student_id || data.user_id === student_id) {
      return {
        student_id: data.student_id || data.user_id,
        full_name: data.full_name,
        school_id: data.school_id,
        class_id: data.class_id,
        section: data.section,
        parent_phone: data.parent_phone,
      };
    }
  }

  // Fallback with proper UUIDs
  return {
    student_id,
    full_name: 'Test Student',
    school_id: '00000000-0000-0000-0000-000000000001',
    class_id: '00000000-0000-0000-0004-000000000001',
    section: 'A',
    parent_phone: '+250700000000',
  };
}

// ── POST /auth/student/request-otp ───────────────────────────────────────────
async function requestStudentOtp(req, res) {
  try {
    const { student_id } = req.body;
    if (!student_id) {
      return res.status(400).json({
        error: 'INVALID_REQUEST',
        message: 'student_id is required.',
      });
    }

    let parentPhone;
    let studentRecord;

    if (process.env.USE_MOCK_BRIDGE === 'true') {
      studentRecord = getMockStudentRecord(student_id);
      parentPhone = studentRecord.parent_phone;
    } else {
      try {
        const axios = require('axios');
        const res2 = await axios.get(
          `${process.env.MAIN_API_BASE_URL}/api/internal/student-auth`,
          {
            params: { admission_number: student_id },
            headers: { 'X-Chat-Service-Key': process.env.CHAT_SERVICE_KEY },
            timeout: 5000,
          }
        );
        studentRecord = res2.data;
        parentPhone = studentRecord.parent_phone;
      } catch (err) {
        if (err.response?.status === 404) {
          return res.status(404).json({
            error: 'STUDENT_NOT_FOUND',
            message: 'Student ID not found.',
          });
        }
        throw err;
      }
    }

    if (!parentPhone) {
      return res.status(404).json({
        error: 'PARENT_PHONE_MISSING',
        message: 'No OTP can be sent — parent phone not on record. Contact school admin.',
      });
    }

    const otp = generateOtp();
    const expiresAt = Date.now() + parseInt(process.env.OTP_EXPIRES_MINUTES || '10') * 60 * 1000;

    otpStore.set(student_id, { otp, expiresAt, parentPhone, studentRecord });

    const smsBody = `Your student ${studentRecord.full_name} is logging into Netrack. OTP: ${otp}. Valid for 10 minutes.`;
    await sendSmsRaw(parentPhone, smsBody);

    logger.info(`OTP sent for student ${student_id} to ${parentPhone.slice(0, 6)}****`);

    res.json({
      success: true,
      message: 'OTP sent to parent phone.',
    });
  } catch (err) {
    logger.error('requestStudentOtp error:', err);
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

// ── POST /auth/student/verify-otp ────────────────────────────────────────────
async function verifyStudentOtp(req, res) {
  try {
    const { student_id, otp } = req.body;
    if (!student_id || !otp) {
      return res.status(400).json({
        error: 'INVALID_REQUEST',
        message: 'student_id and otp are required.',
      });
    }

    const stored = otpStore.get(student_id);
    if (!stored) {
      return res.status(401).json({
        error: 'OTP_INVALID',
        message: 'No OTP found for this student. Please request a new one.',
      });
    }

    if (Date.now() > stored.expiresAt) {
      otpStore.delete(student_id);
      return res.status(401).json({
        error: 'OTP_INVALID',
        message: 'OTP has expired. Please request a new one.',
      });
    }

    if (stored.otp !== otp.trim()) {
      return res.status(401).json({
        error: 'OTP_INVALID',
        message: 'Incorrect OTP. Check the SMS sent to your parent\'s phone and try again.',
      });
    }

    otpStore.delete(student_id);
    const { studentRecord } = stored;

    const payload = {
      sub: studentRecord.student_id,
      user_id: studentRecord.student_id,
      student_id: studentRecord.student_id,
      school_id: studentRecord.school_id,
      role: 'student',
      class_id: studentRecord.class_id,
      section: studentRecord.section,
    };

    const token = jwt.sign(payload, process.env.JWT_SECRET, {
      expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    });

    logger.info(`Student JWT issued for ${studentRecord.student_id}`);

    res.json({ token, role: 'student' });
  } catch (err) {
    logger.error('verifyStudentOtp error:', err);
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

module.exports = { requestStudentOtp, verifyStudentOtp };