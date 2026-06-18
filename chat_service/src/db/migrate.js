/**
 * Database migration — creates all 8 chat service tables.
 * Run: node src/db/migrate.js
 */
require('dotenv').config();
const { pool } = require('./pool');
const { logger } = require('../utils/logger');

const migrations = [
  // ── 1. chat_threads ──────────────────────────────────────────────────────
  `CREATE TABLE IF NOT EXISTS chat_threads (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id         UUID        NOT NULL,
    thread_type       VARCHAR(20) NOT NULL CHECK (thread_type IN ('direct','broadcast')),
    thread_initiator  VARCHAR(20) NOT NULL CHECK (thread_initiator IN ('parent','student')),
    parent_id         UUID,
    teacher_id        UUID        NOT NULL,
    student_id        UUID        NOT NULL,
    class_id          UUID,
    broadcast_id      UUID,
    last_message_at   TIMESTAMPTZ,
    status            VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived')),
    created_by        UUID        NOT NULL,
    updated_by        UUID        NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (parent_id, teacher_id, student_id, thread_initiator)
  )`,

  // ── 2. chat_messages ─────────────────────────────────────────────────────
  `CREATE TABLE IF NOT EXISTS chat_messages (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id         UUID        NOT NULL,
    thread_id         UUID        NOT NULL REFERENCES chat_threads(id),
    sender_id         UUID        NOT NULL,
    sender_role       VARCHAR(20) NOT NULL CHECK (sender_role IN ('parent','teacher','student')),
    message_type      VARCHAR(20) NOT NULL CHECK (message_type IN ('text','image','document','voice','system')),
    content           TEXT,
    media_local_ref   TEXT,
    media_type        VARCHAR(100),
    media_size_bytes  BIGINT,
    original_filename VARCHAR(255),
    is_broadcast      BOOLEAN     NOT NULL DEFAULT FALSE,
    broadcast_id      UUID,
    is_edited         BOOLEAN     NOT NULL DEFAULT FALSE,
    edited_at         TIMESTAMPTZ,
    sent_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by        UUID        NOT NULL,
    updated_by        UUID        NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,

  // ── 3. chat_message_status ───────────────────────────────────────────────
  `CREATE TABLE IF NOT EXISTS chat_message_status (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id   UUID        NOT NULL REFERENCES chat_messages(id),
    user_id      UUID        NOT NULL,
    school_id    UUID        NOT NULL,
    status       VARCHAR(20) NOT NULL CHECK (status IN ('sent','delivered','seen')),
    delivered_at TIMESTAMPTZ,
    seen_at      TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (message_id, user_id)
  )`,

  // ── 4. chat_broadcasts ───────────────────────────────────────────────────
  `CREATE TABLE IF NOT EXISTS chat_broadcasts (
    id                     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id              UUID        NOT NULL,
    teacher_id             UUID        NOT NULL,
    class_ids              JSONB       NOT NULL DEFAULT '[]',
    total_parents_targeted INTEGER     NOT NULL DEFAULT 0,
    push_sent_count        INTEGER     NOT NULL DEFAULT 0,
    sms_sent_count         INTEGER     NOT NULL DEFAULT 0,
    sms_failed_count       INTEGER     NOT NULL DEFAULT 0,
    broadcast_message_id   UUID        REFERENCES chat_messages(id),
    status                 VARCHAR(30) NOT NULL DEFAULT 'processing'
                           CHECK (status IN ('processing','completed','partial_failed','failed')),
    created_by             UUID        NOT NULL,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,

  // ── 5. chat_active_status ────────────────────────────────────────────────
  `CREATE TABLE IF NOT EXISTS chat_active_status (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID        NOT NULL UNIQUE,
    school_id    UUID        NOT NULL,
    is_online    BOOLEAN     NOT NULL DEFAULT FALSE,
    last_seen_at TIMESTAMPTZ,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,

  // ── 6. chat_user_device_tokens ───────────────────────────────────────────
  `CREATE TABLE IF NOT EXISTS chat_user_device_tokens (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL,
    school_id       UUID        NOT NULL,
    user_role       VARCHAR(20) NOT NULL CHECK (user_role IN ('parent','teacher','student')),
    device_token    TEXT        NOT NULL,
    device_platform VARCHAR(10) NOT NULL CHECK (device_platform IN ('android','ios')),
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    last_used_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, device_token)
  )`,

  // ── 7. chat_user_context_cache ───────────────────────────────────────────
  `CREATE TABLE IF NOT EXISTS chat_user_context_cache (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    cache_key    VARCHAR(200) NOT NULL UNIQUE,
    school_id    UUID         NOT NULL,
    user_id      UUID         NOT NULL,
    user_role    VARCHAR(20)  NOT NULL,
    context_json JSONB        NOT NULL,
    expires_at   TIMESTAMPTZ  NOT NULL,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
  )`,

  // ── 8. chat_sms_logs ─────────────────────────────────────────────────────
  `CREATE TABLE IF NOT EXISTS chat_sms_logs (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id         UUID        NOT NULL,
    message_id        UUID        REFERENCES chat_messages(id),
    recipient_user_id UUID        NOT NULL,
    status            VARCHAR(20) NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending','sent','delivered','failed')),
    provider_response TEXT,
    sent_at           TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )`,

  // ── Indexes ───────────────────────────────────────────────────────────────
  `CREATE INDEX IF NOT EXISTS idx_chat_messages_thread_sent
     ON chat_messages (thread_id, sent_at DESC)`,
  `CREATE INDEX IF NOT EXISTS idx_chat_messages_school
     ON chat_messages (school_id)`,
  `CREATE INDEX IF NOT EXISTS idx_chat_threads_parent_school
     ON chat_threads (parent_id, school_id)`,
  `CREATE INDEX IF NOT EXISTS idx_chat_threads_teacher_school
     ON chat_threads (teacher_id, school_id)`,
  `CREATE INDEX IF NOT EXISTS idx_chat_active_status_user
     ON chat_active_status (user_id)`,
  `CREATE INDEX IF NOT EXISTS idx_chat_context_cache_key
     ON chat_user_context_cache (cache_key)`,
  `CREATE INDEX IF NOT EXISTS idx_chat_context_cache_expires
     ON chat_user_context_cache (expires_at)`,

  // Full-text search on message content
  `CREATE INDEX IF NOT EXISTS idx_chat_messages_content_fts
     ON chat_messages USING gin(to_tsvector('english', coalesce(content, '')))`,
];

async function migrate() {
  const client = await pool.connect();
  try {
    logger.info('Running migrations…');
    for (const sql of migrations) {
      await client.query(sql);
    }
    logger.info(`✅ ${migrations.length} migrations applied successfully.`);
  } catch (err) {
    logger.error('Migration failed:', err);
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

migrate().catch(() => process.exit(1));
