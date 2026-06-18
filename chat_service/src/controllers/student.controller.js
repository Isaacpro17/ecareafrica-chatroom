const { getUserContext } = require('../services/user_context.service');
const { logger } = require('../utils/logger');

// ── GET /students/search?roll_number= ────────────────────────────────────────
async function searchByRollNumber(req, res) {
  try {
    const { sub: teacherId, school_id: schoolId } = req.user;
    const { roll_number } = req.query;

    if (!roll_number || roll_number.trim().length < 1) {
      return res.status(400).json({
        error: 'INVALID_REQUEST',
        message: 'roll_number query parameter is required.',
      });
    }

    // Get teacher context to search within their assigned students only
    const ctx = await getUserContext(
      teacherId, schoolId,
      req.headers.authorization?.slice(7)
    );

    const query = roll_number.trim().toLowerCase();
    const results = [];

    for (const cls of (ctx.classes || [])) {
      for (const student of (cls.students || [])) {
        const admNo = (student.admission_number || '').toLowerCase();
        const name  = (student.full_name || '').toLowerCase();

        if (admNo.includes(query) || name.includes(query)) {
          // Build contact list: parent(s) + student
          const contacts = [];

          // Parent contacts (from parent_ids in context)
          for (const parentId of (student.parent_ids || [])) {
            contacts.push({
              id: parentId,
              type: 'parent',
              name: `Parent of ${student.full_name}`,
              relationship: 'Parent/Guardian',
              teacher_id: teacherId,
            });
          }

          // Student contact
          contacts.push({
            id: student.student_id,
            type: 'student',
            name: student.full_name,
            relationship: 'Student',
            teacher_id: teacherId,
          });

          results.push({
            student_id: student.student_id,
            full_name: student.full_name,
            admission_number: student.admission_number,
            class_name: cls.class_name,
            section: cls.section,
            contacts,
          });
        }
      }
    }

    if (results.length === 0) {
      return res.status(404).json({
        error: 'STUDENT_NOT_FOUND',
        message: `No student found for "${roll_number}".`,
        suggestions: [], // Could add fuzzy suggestions here
      });
    }

    res.json({ data: results });
  } catch (err) {
    logger.error('searchByRollNumber error:', err);
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

module.exports = { searchByRollNumber };
