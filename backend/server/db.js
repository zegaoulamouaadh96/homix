const { Pool, types } = require("pg");

// Parse int8 values (for COUNT(*), etc.) as JavaScript numbers.
types.setTypeParser(20, (value) => Number(value));

function convertPlaceholders(sql) {
  let index = 0;
  let inSingleQuote = false;
  let inDoubleQuote = false;
  let out = "";

  for (let i = 0; i < sql.length; i += 1) {
    const ch = sql[i];

    if (ch === "'" && !inDoubleQuote) {
      inSingleQuote = !inSingleQuote;
      out += ch;
      continue;
    }

    if (ch === '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote;
      out += ch;
      continue;
    }

    if (ch === "?" && !inSingleQuote && !inDoubleQuote) {
      index += 1;
      out += `$${index}`;
      continue;
    }

    out += ch;
  }

  return out;
}

function translateSql(sql) {
  return convertPlaceholders(sql)
    .replace(/datetime\('now'\)/gi, "NOW()")
    .replace(/datetime\(\"now\"\)/gi, "NOW()");
}

async function openDb() {
  const connectionString = process.env.DATABASE_URL || "postgres://app:app123@localhost:5432/smarthome";
  const pool = new Pool({ connectionString });
  await pool.query("SELECT 1");
  return pool;
}

function saveDb() {
  // PostgreSQL persists on its own; kept for compatibility with existing calls.
}

async function initDb(db) {
  await db.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      email TEXT UNIQUE,
      phone TEXT UNIQUE,
      password_hash TEXT NOT NULL,
      full_name TEXT,
      family_role TEXT,
      profile_image_url TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS homes (
      id SERIAL PRIMARY KEY,
      home_code TEXT UNIQUE NOT NULL,
      name TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS home_members (
      home_id INTEGER REFERENCES homes(id) ON DELETE CASCADE,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      role TEXT NOT NULL CHECK (role IN ('owner','admin','resident','guest')),
      is_active SMALLINT DEFAULT 1 CHECK (is_active IN (0, 1)),
      PRIMARY KEY (home_id, user_id)
    );

    CREATE TABLE IF NOT EXISTS devices (
      id SERIAL PRIMARY KEY,
      home_id INTEGER REFERENCES homes(id) ON DELETE CASCADE,
      device_id TEXT NOT NULL,
      name TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'custom',
      location TEXT DEFAULT '',
      metadata TEXT DEFAULT '{}',
      is_active SMALLINT DEFAULT 1 CHECK (is_active IN (0, 1)),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(home_id, device_id)
    );

    CREATE TABLE IF NOT EXISTS device_states (
      device_key TEXT PRIMARY KEY,
      home_id INTEGER REFERENCES homes(id) ON DELETE CASCADE,
      device_id TEXT NOT NULL,
      state TEXT NOT NULL,
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS events (
      id SERIAL PRIMARY KEY,
      home_id INTEGER REFERENCES homes(id) ON DELETE CASCADE,
      device_id TEXT,
      type TEXT NOT NULL,
      payload TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS one_time_codes (
      id SERIAL PRIMARY KEY,
      home_id INTEGER REFERENCES homes(id) ON DELETE CASCADE,
      code_hash TEXT NOT NULL,
      scope_device_id TEXT,
      expires_at TIMESTAMPTZ NOT NULL,
      used_at TIMESTAMPTZ,
      created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS reauth_tokens (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      token_hash TEXT NOT NULL,
      expires_at TIMESTAMPTZ NOT NULL,
      used_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS face_challenges (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
      challenge_type TEXT NOT NULL,
      token_hash TEXT NOT NULL,
      expires_at TIMESTAMPTZ NOT NULL,
      used_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS user_face_encodings (
      id SERIAL PRIMARY KEY,
      user_id INTEGER UNIQUE REFERENCES users(id) ON DELETE CASCADE,
      encoding_json TEXT NOT NULL,
      challenge_type TEXT,
      confidence_score REAL DEFAULT 0,
      liveness_verified SMALLINT DEFAULT 0 CHECK (liveness_verified IN (0, 1)),
      anti_spoof_verified SMALLINT DEFAULT 0 CHECK (anti_spoof_verified IN (0, 1)),
      status TEXT DEFAULT 'active',
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS face_recognition_logs (
      id SERIAL PRIMARY KEY,
      user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      home_id INTEGER REFERENCES homes(id) ON DELETE SET NULL,
      device_id TEXT,
      attempt_type TEXT NOT NULL,
      challenge_requested TEXT,
      challenge_passed SMALLINT CHECK (challenge_passed IN (0, 1)),
      liveness_status TEXT,
      anti_spoof_status TEXT,
      distance REAL,
      result TEXT NOT NULL,
      reason TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS clients (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      phone TEXT DEFAULT '',
      email TEXT DEFAULT '',
      address TEXT DEFAULT '',
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS orders (
      id SERIAL PRIMARY KEY,
      client_id INTEGER REFERENCES clients(id) ON DELETE SET NULL,
      client_name TEXT DEFAULT '',
      phone TEXT DEFAULT '',
      address TEXT DEFAULT '',
      package_type TEXT DEFAULT 'basic',
      status TEXT DEFAULT 'pending',
      home_id INTEGER REFERENCES homes(id) ON DELETE SET NULL,
      contact_method TEXT DEFAULT '',
      contact TEXT DEFAULT '',
      home_type TEXT DEFAULT '',
      doors INTEGER DEFAULT 0,
      windows INTEGER DEFAULT 0,
      cameras INTEGER DEFAULT 0,
      notes TEXT DEFAULT '',
      source TEXT DEFAULT '',
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS sales (
      id SERIAL PRIMARY KEY,
      home_id INTEGER REFERENCES homes(id) ON DELETE SET NULL,
      amount INTEGER DEFAULT 0,
      notes TEXT DEFAULT '',
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS support_tickets (
      id SERIAL PRIMARY KEY,
      home_id INTEGER REFERENCES homes(id) ON DELETE SET NULL,
      issue TEXT DEFAULT '',
      status TEXT DEFAULT 'open',
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS installations (
      id SERIAL PRIMARY KEY,
      home_id INTEGER REFERENCES homes(id) ON DELETE SET NULL,
      status TEXT DEFAULT 'scheduled',
      install_date TIMESTAMPTZ,
      notes TEXT DEFAULT '',
      completed_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS admin_config (
      id SERIAL PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      name TEXT DEFAULT 'المسؤول'
    );

    CREATE TABLE IF NOT EXISTS admin_staff (
      id SERIAL PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      full_name TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'staff',
      is_active SMALLINT DEFAULT 1 CHECK (is_active IN (0, 1)),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      last_login_at TIMESTAMPTZ
    );

    INSERT INTO admin_config(username, password, name)
    VALUES('admin', 'homix2026', 'المسؤول')
    ON CONFLICT (username) DO NOTHING;

    ALTER TABLE homes ADD COLUMN IF NOT EXISTS client_id INTEGER REFERENCES clients(id) ON DELETE SET NULL;
    ALTER TABLE homes ADD COLUMN IF NOT EXISTS wilaya TEXT DEFAULT '';
    ALTER TABLE homes ADD COLUMN IF NOT EXISTS city TEXT DEFAULT '';
    ALTER TABLE homes ADD COLUMN IF NOT EXISTS address TEXT DEFAULT '';
    ALTER TABLE homes ADD COLUMN IF NOT EXISTS package_type TEXT DEFAULT 'basic';
    ALTER TABLE homes ADD COLUMN IF NOT EXISTS activated SMALLINT DEFAULT 0;
    ALTER TABLE homes ADD COLUMN IF NOT EXISTS activated_at TIMESTAMPTZ;

    ALTER TABLE devices ADD COLUMN IF NOT EXISTS name TEXT NOT NULL DEFAULT 'Device';
    ALTER TABLE devices ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'custom';
    ALTER TABLE devices ADD COLUMN IF NOT EXISTS location TEXT DEFAULT '';
    ALTER TABLE devices ADD COLUMN IF NOT EXISTS metadata TEXT DEFAULT '{}';
    ALTER TABLE devices ADD COLUMN IF NOT EXISTS is_active SMALLINT DEFAULT 1;

    ALTER TABLE installations ADD COLUMN IF NOT EXISTS install_date TIMESTAMPTZ;
    ALTER TABLE installations ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT '';
    ALTER TABLE installations ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

    CREATE INDEX IF NOT EXISTS idx_devices_home ON devices(home_id);
    CREATE INDEX IF NOT EXISTS idx_devices_home_category ON devices(home_id, category);
    CREATE INDEX IF NOT EXISTS idx_face_challenges_user ON face_challenges(user_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_face_logs_home ON face_recognition_logs(home_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_face_logs_user ON face_recognition_logs(user_id, created_at DESC);
  `);
}

async function queryAll(db, sql, params = []) {
  const result = await db.query(translateSql(sql), params);
  return result.rows;
}

async function queryOne(db, sql, params = []) {
  const rows = await queryAll(db, sql, params);
  return rows[0] || null;
}

async function exec(db, sql, params = []) {
  const result = await db.query(translateSql(sql), params);
  return {
    changes: result.rowCount || 0,
    lastId: result.rows?.[0]?.id || 0,
  };
}

module.exports = { openDb, initDb, saveDb, queryAll, queryOne, exec };
