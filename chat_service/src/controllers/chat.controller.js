const { query, getClient } = require('../db/pool');
const { v4: uuidv4 } = require('uuid');
const { getUserContext } = require('../services/user_context.service');
const { publishFirebaseEvent } = require('../services/firebase.service');
const { sendPushNotification } = require('../services/notification.service');
const { logger } = require('../utils/logger');

// ── GET /chat/threads ─────────────────────────────────────────────────────────
async function getThreads(req, res) {
  try {
    const { sub: userId, school_id: schoolId, role } = req.user;

    let whereClause;
    let params;

    if (role === 'parent') {
      whereClause = 't.parent_id = $1 AND t.school_id = $2';
      params = [userId, schoolId];
    } else if (role === 'teacher') {
      whereClause = 't.teacher_id = $1 AND t.school_id = $2';
      params = [userId, schoolId];
    } else if (role === 'student') {
      whereClause = 't.student_id = $1 AND t.school_id = $2 AND t.thread_initiator = $3';
      params = [userId, schoolId, 'student'];
    } else {
      return res.status(403).json({ error: 'FORBIDDEN' });
    }

    const result = await query(
      `SELECT t.*,
              m.content          AS last_message_preview,
              m.message_type     AS last_message_type,
              COALESCE(
                (SELECT COUNT(*) FROM chat_message_status s
                 WHERE s.message_id IN (
                   SELECT id FROM chat_messages WHERE thread_id = t.id
                 ) AND s.user_id = $${params.length + 1} AND s.status != 'seen'),
                0
              )::int             AS unread_count,
              cas.is_online,
              cas.last_seen_at
       FROM   chat_threads t
       LEFT JOIN LATERAL (
         SELECT content, message_type FROM chat_messages
         WHERE thread_id = t.id ORDER BY sent_at DESC LIMIT 1
       ) m ON TRUE
       LEFT JOIN chat_active_status cas ON (
         CASE WHEN $${params.length + 2} = 'parent' THEN cas.user_id = t.teacher_id
              WHEN $${params.length + 2} = 'teacher' THEN cas.user_id = t.parent_id
              ELSE cas.user_id = t.teacher_id END
       )
       WHERE  ${whereClause}
       ORDER  BY t.last_message_at DESC NULLS LAST`,
      [...params, userId, role]
    );

    res.json({ data: result.rows });
  } catch (err) {
    logger.error('getThreads error:', err);
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

// ── POST /chat/threads ────────────────────────────────────────────────────────
async function createThread(req, res) {
  try {
    const { sub: userId, school_id: schoolId } = req.user;
    const { teacher_id, student_id, thread_type = 'direct', thread_initiator, parent_id } = req.body;

    logger.info(`createThread called: userId=${userId} schoolId=${schoolId} teacherId=${teacher_id} studentId=${student_id} role=${req.user.role}`);

    if (!teacher_id || !student_id) {
      return res.status(400).json({ error: 'INVALID_REQUEST', message: 'teacher_id and student_id are required.' });
    }

    const initiator = thread_initiator || (req.user.role === 'student' ? 'student' : 'parent');
    const pId = parent_id || (req.user.role === 'parent' ? userId : null);

    logger.info(`createThread params: schoolId=${schoolId} type=${thread_type} initiator=${initiator} pId=${pId} teacherId=${teacher_id} studentId=${student_id} createdBy=${userId}`);

    const result = await query(
      `INSERT INTO chat_threads
         (school_id, thread_type, thread_initiator, parent_id, teacher_id, student_id, created_by, updated_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $7)
       ON CONFLICT (parent_id, teacher_id, student_id, thread_initiator)
       DO UPDATE SET updated_at = NOW()
       RETURNING *`,
      [schoolId, thread_type, initiator, pId, teacher_id, student_id, userId]
    );

    logger.info(`createThread success: threadId=${result.rows[0]?.id}`);
    res.status(200).json({ data: result.rows[0] });
  } catch (err) {
    logger.error('createThread error message:', err.message);
    logger.error('createThread error detail:', err.detail);
    logger.error('createThread error code:', err.code);
    res.status(500).json({ error: 'SERVER_ERROR', message: err.message });
  }
}

// ── GET /chat/threads/:threadId/messages ──────────────────────────────────────
async function getMessages(req, res) {
  try {
    const { sub: userId, school_id: schoolId } = req.user;
    const { threadId } = req.params;
    const page  = parseInt(req.query.page  || '1');
    const limit = parseInt(req.query.limit || '30');
    const offset = (page - 1) * limit;

    const threadCheck = await query(
      `SELECT id FROM chat_threads
       WHERE id = $1 AND school_id = $2
         AND (parent_id = $3 OR teacher_id = $3 OR student_id = $3)`,
      [threadId, schoolId, userId]
    );
    if (threadCheck.rows.length === 0) {
      return res.status(403).json({ error: 'FORBIDDEN' });
    }

    const result = await query(
      `SELECT m.*,
              s.status   AS delivery_status,
              s.seen_at
       FROM   chat_messages m
       LEFT JOIN chat_message_status s
              ON s.message_id = m.id AND s.user_id = $3
       WHERE  m.thread_id = $1 AND m.school_id = $2
       ORDER  BY m.sent_at ASC
       LIMIT  $4 OFFSET $5`,
      [threadId, schoolId, userId, limit, offset]
    );

    res.json({ data: result.rows, page, limit });
  } catch (err) {
    logger.error('getMessages error:', err);
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

// ── POST /chat/messages ───────────────────────────────────────────────────────
async function sendMessage(req, res) {
  const client = await getClient();
  try {
    await client.query('BEGIN');

    const { sub: senderId, school_id: schoolId, role: senderRole } = req.user;
    const { thread_id, message_type = 'text', content, media_local_ref,
            media_type, media_size_bytes, original_filename } = req.body;

    if (!thread_id) {
      return res.status(400).json({ error: 'INVALID_REQUEST', message: 'thread_id is required.' });
    }

    const threadRes = await client.query(
      `SELECT * FROM chat_threads WHERE id = $1 AND school_id = $2`,
      [thread_id, schoolId]
    );
    if (threadRes.rows.length === 0) {
      return res.status(404).json({ error: 'THREAD_NOT_FOUND' });
    }
    const thread = threadRes.rows[0];

    const msgId = uuidv4();
    const msgRes = await client.query(
      `INSERT INTO chat_messages
         (id, school_id, thread_id, sender_id, sender_role, message_type,
          content, media_local_ref, media_type, media_size_bytes, original_filename,
          created_by, updated_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$4,$4)
       RETURNING *`,
      [msgId, schoolId, thread_id, senderId, senderRole, message_type,
       content, media_local_ref, media_type, media_size_bytes, original_filename]
    );
    const message = msgRes.rows[0];

    await client.query(
      `UPDATE chat_threads SET last_message_at = NOW(), updated_by = $1 WHERE id = $2`,
      [senderId, thread_id]
    );

    await client.query(
      `INSERT INTO chat_message_status (message_id, user_id, school_id, status)
       VALUES ($1, $2, $3, 'sent')
       ON CONFLICT (message_id, user_id) DO NOTHING`,
      [msgId, senderId, schoolId]
    );

    await client.query('COMMIT');

    const recipientId = senderRole === 'teacher'
      ? (thread.parent_id || thread.student_id)
      : thread.teacher_id;

    setImmediate(async () => {
      try {
        await publishFirebaseEvent(schoolId, thread_id, msgId);
        await sendPushNotification(recipientId, schoolId, {
          title: `New message`,
          body: content ? content.slice(0, 80) : `[${message_type}]`,
          data: { thread_id, message_id: msgId },
        });
        // SMS is not used for chat — push notifications only (SMS reserved for OTP)
      } catch (e) {
        logger.error('Post-send async error:', e);
      }
    });

    res.status(201).json({ data: message });
  } catch (err) {
    await client.query('ROLLBACK');
    logger.error('sendMessage error:', err);
    res.status(500).json({ error: 'SERVER_ERROR' });
  } finally {
    client.release();
  }
}

// ── PUT /chat/messages/:messageId ─────────────────────────────────────────────
async function editMessage(req, res) {
  try {
    const { sub: userId, school_id: schoolId } = req.user;
    const { messageId } = req.params;
    const { content } = req.body;

    if (!content || !content.trim()) {
      return res.status(400).json({ error: 'INVALID_REQUEST', message: 'content is required.' });
    }

    const msgRes = await query(
      `SELECT * FROM chat_messages WHERE id = $1 AND school_id = $2 AND sender_id = $3`,
      [messageId, schoolId, userId]
    );
    if (msgRes.rows.length === 0) {
      return res.status(403).json({ error: 'FORBIDDEN' });
    }

    const msg = msgRes.rows[0];
    const minutesSinceSent = (Date.now() - new Date(msg.sent_at).getTime()) / 60000;
    if (minutesSinceSent > 5) {
      return res.status(422).json({
        error: 'EDIT_WINDOW_EXPIRED',
        message: 'This message can no longer be edited — the 5-minute window has passed.',
      });
    }

    if (msg.message_type !== 'text') {
      return res.status(400).json({
        error: 'INVALID_REQUEST',
        message: 'Only text messages can be edited.',
      });
    }

    const updated = await query(
      `UPDATE chat_messages
       SET content = $1, is_edited = TRUE, edited_at = NOW(), updated_by = $2, updated_at = NOW()
       WHERE id = $3
       RETURNING *`,
      [content.trim(), userId, messageId]
    );

    res.json({ data: updated.rows[0] });
  } catch (err) {
    logger.error('editMessage error:', err);
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

// ── PUT /chat/messages/:messageId/read ────────────────────────────────────────
async function markSeen(req, res) {
  try {
    const { sub: userId, school_id: schoolId } = req.user;
    const { messageId } = req.params;

    await query(
      `INSERT INTO chat_message_status (message_id, user_id, school_id, status, seen_at)
       VALUES ($1, $2, $3, 'seen', NOW())
       ON CONFLICT (message_id, user_id) DO UPDATE
       SET status = 'seen', seen_at = NOW(), updated_at = NOW()`,
      [messageId, userId, schoolId]
    );

    res.json({ success: true });
  } catch (err) {
    logger.error('markSeen error:', err);
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

// ── POST /chat/broadcast ──────────────────────────────────────────────────────
async function sendBroadcast(req, res) {
  const client = await getClient();
  try {
    const { sub: teacherId, school_id: schoolId } = req.user;
    const { class_ids, message_type = 'text', content } = req.body;

    if (!class_ids || !Array.isArray(class_ids) || class_ids.length === 0) {
      return res.status(400).json({ error: 'INVALID_REQUEST', message: 'class_ids array is required.' });
    }
    if (!content && message_type === 'text') {
      return res.status(400).json({ error: 'INVALID_REQUEST', message: 'content is required for text broadcasts.' });
    }

    const ctx = await getUserContext(teacherId, schoolId, req.headers.authorization?.slice(7));
    const parentIds = new Set();

    for (const cls of (ctx.classes || [])) {
      if (class_ids.includes(cls.class_id)) {
        for (const student of (cls.students || [])) {
          for (const pid of (student.parent_ids || [])) {
            parentIds.add(pid);
          }
        }
      }
    }

    await client.query('BEGIN');

    const broadcastId = uuidv4();
    await client.query(
      `INSERT INTO chat_broadcasts
         (id, school_id, teacher_id, class_ids, total_parents_targeted, created_by)
       VALUES ($1, $2, $3, $4, $5, $3)`,
      [broadcastId, schoolId, teacherId, JSON.stringify(class_ids), parentIds.size]
    );

    const msgId = uuidv4();
    await client.query(
      `INSERT INTO chat_messages
         (id, school_id, thread_id, sender_id, sender_role, message_type,
          content, is_broadcast, broadcast_id, created_by, updated_by)
       SELECT $1,$2,t.id,$3,'teacher',$4,$5,TRUE,$6,$3,$3
       FROM   chat_threads t
       WHERE  t.teacher_id = $3 AND t.school_id = $2
       LIMIT  1`,
      [msgId, schoolId, teacherId, message_type, content, broadcastId]
    );

    await client.query('COMMIT');

    setImmediate(async () => {
      let pushCount = 0;

      for (const parentId of parentIds) {
        try {
          await query(
            `INSERT INTO chat_threads
               (school_id, thread_type, thread_initiator, parent_id, teacher_id,
                student_id, broadcast_id, created_by, updated_by)
             VALUES ($1,'broadcast','parent',$2,$3,
               (SELECT student_id FROM chat_threads WHERE teacher_id=$3 AND parent_id=$2 LIMIT 1),
               $4,$3,$3)
             ON CONFLICT DO NOTHING
             RETURNING id`,
            [schoolId, parentId, teacherId, broadcastId]
          );

          await sendPushNotification(parentId, schoolId, {
            title: `📢 Class Announcement`,
            body: content ? content.slice(0, 80) : '[Broadcast]',
            data: { broadcast_id: broadcastId },
          });
          pushCount++;
          // SMS not used for broadcast — push notifications only
        } catch (e) {
          logger.error(`Broadcast delivery failed for parent ${parentId}:`, e);
        }
      }

      await query(
        `UPDATE chat_broadcasts
         SET push_sent_count=$1, status=$2, updated_at=NOW()
         WHERE id=$3`,
        [pushCount, 'completed', broadcastId]
      );
    });

    res.status(202).json({
      data: { broadcast_id: broadcastId, total_parents: parentIds.length },
      message: 'Broadcast queued — delivery in progress.',
    });
  } catch (err) {
    await client.query('ROLLBACK');
    logger.error('sendBroadcast error:', err);
    res.status(500).json({ error: 'SERVER_ERROR' });
  } finally {
    client.release();
  }
}

// ── GET /chat/broadcast/:broadcastId ─────────────────────────────────────────
async function getBroadcast(req, res) {
  try {
    const { school_id: schoolId } = req.user;
    const result = await query(
      `SELECT * FROM chat_broadcasts WHERE id = $1 AND school_id = $2`,
      [req.params.broadcastId, schoolId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'NOT_FOUND' });
    }
    res.json({ data: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

// ── GET /chat/search ──────────────────────────────────────────────────────────
async function search(req, res) {
  try {
    const { sub: userId, school_id: schoolId } = req.user;
    const { q, scope, thread_id } = req.query;

    if (!q || q.trim().length < 2) {
      return res.status(400).json({ error: 'INVALID_REQUEST', message: 'Query must be at least 2 characters.' });
    }

    let sql, params;

    if (scope === 'global' || !thread_id) {
      sql = `SELECT m.*, t.id AS thread_id
             FROM   chat_messages m
             JOIN   chat_threads t ON t.id = m.thread_id
             WHERE  m.school_id = $1
               AND  (t.parent_id = $2 OR t.teacher_id = $2 OR t.student_id = $2)
               AND  to_tsvector('english', coalesce(m.content,'')) @@ plainto_tsquery('english', $3)
             ORDER  BY m.sent_at DESC
             LIMIT  50`;
      params = [schoolId, userId, q.trim()];
    } else {
      sql = `SELECT m.*
             FROM   chat_messages m
             JOIN   chat_threads t ON t.id = m.thread_id
             WHERE  m.thread_id = $1 AND m.school_id = $2
               AND  (t.parent_id = $3 OR t.teacher_id = $3 OR t.student_id = $3)
               AND  to_tsvector('english', coalesce(m.content,'')) @@ plainto_tsquery('english', $4)
             ORDER  BY m.sent_at DESC
             LIMIT  50`;
      params = [thread_id, schoolId, userId, q.trim()];
    }

    const result = await query(sql, params);
    res.json({ data: result.rows });
  } catch (err) {
    logger.error('search error:', err);
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

// ── PUT /chat/threads/:threadId/mute ─────────────────────────────────────────
async function muteThread(req, res) {
  res.json({ success: true });
}

// ── PUT /chat/settings/mute-all ───────────────────────────────────────────────
async function muteAll(req, res) {
  res.json({ success: true });
}

// ── GET /chat/me ─────────────────────────────────────────────────────────────
async function getMe(req, res) {
  try {
    const { sub: userId, school_id: schoolId } = req.user;
    const ctx = await getUserContext(userId, schoolId, req.headers.authorization?.slice(7));
    res.json({ data: ctx });
  } catch (err) {
    logger.error('getMe error:', err);
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

// ── GET /chat/children ────────────────────────────────────────────────────────
async function getChildren(req, res) {
  try {
    const { sub: userId, school_id: schoolId } = req.user;
    const ctx = await getUserContext(userId, schoolId, req.headers.authorization?.slice(7));
    res.json({ data: ctx.children || [] });
  } catch (err) {
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

// ── GET /chat/teachers ────────────────────────────────────────────────────────
async function getTeachersForChild(req, res) {
  try {
    const { sub: userId, school_id: schoolId } = req.user;
    const { student_id } = req.query;
    const ctx = await getUserContext(userId, schoolId, req.headers.authorization?.slice(7));
    const child = (ctx.children || []).find((c) => c.student_id === student_id);
    res.json({ data: child ? child.teachers : [] });
  } catch (err) {
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

// ── GET /chat/student/teachers ────────────────────────────────────────────────
async function getStudentTeachers(req, res) {
  try {
    const { sub: userId, school_id: schoolId } = req.user;
    const ctx = await getUserContext(userId, schoolId, req.headers.authorization?.slice(7));
    res.json({ data: ctx.teachers || [] });
  } catch (err) {
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

// ── GET /chat/unread-count ────────────────────────────────────────────────────
async function getUnreadCount(req, res) {
  try {
    const { sub: userId, school_id: schoolId } = req.user;
    const result = await query(
      `SELECT COUNT(*) AS total
       FROM   chat_message_status s
       JOIN   chat_messages m ON m.id = s.message_id
       WHERE  s.user_id = $1 AND m.school_id = $2 AND s.status != 'seen'`,
      [userId, schoolId]
    );
    res.json({ data: { unread_count: parseInt(result.rows[0].total) } });
  } catch (err) {
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
}

module.exports = {
  getMe,
  getThreads, createThread, getMessages, sendMessage,
  editMessage, markSeen, sendBroadcast, getBroadcast,
  search, muteThread, muteAll, getChildren,
  getTeachersForChild, getStudentTeachers, getUnreadCount,
};