const express = require("express");
const multer = require("multer");
const { z } = require("zod");
const bcrypt = require("bcrypt");
const crypto = require("crypto");
const jwt = require("jsonwebtoken");
const { signToken, requireAuth, sha256, hashPassword, verifyPassword } = require("./auth");
const { queryAll, queryOne, exec, saveDb } = require("./db");

// Multer: in-memory storage for image uploads
const upload = multer({ storage: multer.memoryStorage() });

// Wrap async route handlers to forward errors to Express error handler
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

module.exports = function routes({ db, mqttClient }) {
  const r = express.Router();

  const DEVICE_CATEGORIES = new Set([
    "camera",
    "door",
    "window",
    "seismic",
    "motion",
    "smoke",
    "flood",
    "glass",
    "custom",
  ]);

  function normalizeCategory(raw) {
    const value = String(raw || "custom").trim().toLowerCase();
    if (DEVICE_CATEGORIES.has(value)) return value;
    return "custom";
  }

  function inferCategoryFromDeviceId(deviceId = "") {
    const id = String(deviceId).toLowerCase();
    if (id.includes("cam")) return "camera";
    if (id.includes("door")) return "door";
    if (id.includes("window")) return "window";
    if (id.includes("seismic") || id.includes("vibration") || id.includes("quake")) return "seismic";
    if (id.includes("motion")) return "motion";
    if (id.includes("smoke")) return "smoke";
    if (id.includes("flood") || id.includes("water")) return "flood";
    if (id.includes("glass")) return "glass";
    return "custom";
  }

  function defaultDeviceName(category, index) {
    const labels = {
      camera: "كاميرا",
      door: "باب",
      window: "نافذة",
      seismic: "حساس زلازل",
      motion: "حساس حركة",
      smoke: "حساس دخان",
      flood: "حساس فيضان",
      glass: "حساس كسر زجاج",
      custom: "جهاز",
    };
    return `${labels[category] || "جهاز"} ${index}`;
  }

  function parseJson(value, fallback = {}) {
    try {
      if (value == null) return fallback;
      if (typeof value === "object") return value;
      return JSON.parse(value);
    } catch {
      return fallback;
    }
  }

  function applyCommandToState(currentState, cmd, value) {
    const state = { ...(currentState || {}) };
    state.online = true;
    state.last_command = cmd;
    state.last_command_at = new Date().toISOString();

    switch (cmd) {
      case "UNLOCK_DOOR":
        state.locked = false;
        state.open = true;
        break;
      case "LOCK_DOOR":
        state.locked = true;
        state.open = false;
        break;
      case "OPEN_DOOR":
        state.open = true;
        break;
      case "CLOSE_DOOR":
        state.open = false;
        break;
      case "OPEN_WINDOW":
        state.open = true;
        break;
      case "CLOSE_WINDOW":
        state.open = false;
        break;
      case "ARM_SENSOR":
        state.armed = true;
        break;
      case "DISARM_SENSOR":
        state.armed = false;
        break;
      case "TRIGGER_ALARM":
        state.triggered = true;
        break;
      case "RESET_ALARM":
        state.triggered = false;
        break;
      default:
        if (value !== undefined) state.value = value;
        break;
    }

    return state;
  }

  async function getHomeRole(homeId, userId) {
    const me = await queryOne(
      db,
      "SELECT role FROM home_members WHERE home_id=? AND user_id=? AND is_active=1",
      [homeId, userId]
    );
    return me?.role || null;
  }

  async function ensureDefaultDevices(homeId) {
    const count = await queryOne(
      db,
      "SELECT COUNT(*) AS c FROM devices WHERE home_id=? AND is_active=1",
      [homeId]
    );

    if ((count?.c || 0) > 0) return;

    const defaults = [
      { device_id: "camera_1", name: defaultDeviceName("camera", 1), category: "camera", location: "المدخل" },
      { device_id: "seismic_1", name: defaultDeviceName("seismic", 1), category: "seismic", location: "المدخل" },
      { device_id: "seismic_2", name: defaultDeviceName("seismic", 2), category: "seismic", location: "غرفة المعيشة" },
      { device_id: "seismic_3", name: defaultDeviceName("seismic", 3), category: "seismic", location: "المطبخ" },
      { device_id: "seismic_4", name: defaultDeviceName("seismic", 4), category: "seismic", location: "المرآب" },
    ];

    for (const d of defaults) {
      await exec(
        db,
        "INSERT INTO devices(home_id, device_id, name, category, location, metadata) VALUES(?,?,?,?,?,?) ON CONFLICT (home_id, device_id) DO NOTHING",
        [homeId, d.device_id, d.name, d.category, d.location, JSON.stringify({ source: "default" })]
      );
    }

    saveDb();
  }

  r.post("/auth/register", wrap(async (req, res) => {
    const schema = z
      .object({
        email: z.string().email().optional(),
        phone: z.string().optional(),
        password: z.string().min(6)
      })
      .refine((x) => x.email || x.phone, { message: "phone_or_email_required" });

    const b = schema.parse(req.body);
    const password_hash = await hashPassword(b.password);

    const result = await exec(db,
      "INSERT INTO users(email,phone,password_hash) VALUES(?,?,?) RETURNING id",
      [b.email || null, b.phone || null, password_hash]
    );
    saveDb();

    const userId = result.lastId;
    const token = signToken(userId);
    res.json({ ok: true, token, user_id: userId });
  }));

  r.post("/auth/login", wrap(async (req, res) => {
    const schema = z
      .object({
        email: z.string().email().optional(),
        phone: z.string().optional(),
        password: z.string()
      })
      .refine((x) => x.email || x.phone, { message: "phone_or_email_required" });

    const b = schema.parse(req.body);

    const u = await queryOne(db, "SELECT * FROM users WHERE email=? OR phone=? LIMIT 1",
      [b.email || null, b.phone || null]
    );
    if (!u) return res.status(401).json({ ok: false, error: "bad_credentials" });

    const ok = await verifyPassword(b.password, u.password_hash);
    if (!ok) return res.status(401).json({ ok: false, error: "bad_credentials" });

    const token = signToken(u.id);
    res.json({ ok: true, token, user_id: u.id });
  }));

  r.post("/admin/create-home", wrap(async (req, res) => {
    const schema = z.object({ home_code: z.string().min(4), name: z.string().optional() });
    const b = schema.parse(req.body);
    const result = await exec(db, "INSERT INTO homes(home_code,name) VALUES(?,?) RETURNING id",
      [b.home_code, b.name || null]
    );
    const home = await queryOne(db, "SELECT * FROM homes WHERE id=?", [result.lastId]);
    saveDb();
    res.json({ ok: true, home });
  }));

  r.post("/homes/pair", requireAuth, wrap(async (req, res) => {
    const schema = z.object({ home_code: z.string().min(4) });
    const { home_code } = schema.parse(req.body);
    const normalizedCode = home_code.trim().toUpperCase();

    const home = await queryOne(db, "SELECT * FROM homes WHERE home_code=?", [normalizedCode]);
    if (!home) return res.status(404).json({ ok: false, error: "home_not_found" });
    if (home.activated !== 1) {
      return res.status(403).json({ ok: false, error: "home_not_activated" });
    }

    const c = await queryOne(db, "SELECT COUNT(*) AS c FROM home_members WHERE home_id=?", [home.id]);
    const role = c.c === 0 ? "owner" : "resident";

    // عند تغيير المنزل، نجعل المنزل الجديد فقط هو المنزل النشط للمستخدم.
    await exec(db, "UPDATE home_members SET is_active=0 WHERE user_id=? AND home_id<>?", [req.userId, home.id]);

    await exec(db,
      "INSERT INTO home_members(home_id,user_id,role) VALUES(?,?,?) ON CONFLICT (home_id,user_id) DO UPDATE SET is_active=1",
      [home.id, req.userId, role]
    );
    await ensureDefaultDevices(home.id);
    saveDb();

    res.json({ ok: true, home_id: home.id, role, home_code: home.home_code });
  }));

  r.get("/homes/:homeId/members/count", requireAuth, wrap(async (req, res) => {
    const homeId = Number(req.params.homeId);
    const q = await queryOne(db,
      "SELECT COUNT(*) AS count FROM home_members WHERE home_id=? AND is_active=1",
      [homeId]
    );
    res.json({ ok: true, count: q.count });
  }));

  r.post("/reauth", requireAuth, wrap(async (req, res) => {
    const token = crypto.randomBytes(16).toString("hex");
    const token_hash = sha256(token);
    const expiresAt = new Date(Date.now() + 30 * 1000).toISOString();

    await exec(db,
      "INSERT INTO reauth_tokens(user_id, token_hash, expires_at) VALUES (?,?,?)",
      [req.userId, token_hash, expiresAt]
    );
    saveDb();

    res.json({ ok: true, reauth_token: token, expires_in_sec: 30 });
  }));

  async function consumeReauth(userId, token) {
    const token_hash = sha256(token);
    const row = await queryOne(db,
      "SELECT * FROM reauth_tokens WHERE user_id=? AND token_hash=? AND used_at IS NULL AND expires_at > datetime('now') LIMIT 1",
      [userId, token_hash]
    );
    if (!row) return false;
    await exec(db, "UPDATE reauth_tokens SET used_at=datetime('now') WHERE id=?", [row.id]);
    saveDb();
    return true;
  }

  async function listDevicesForHome(homeId) {
    await ensureDefaultDevices(homeId);

    const rows = await queryAll(
      db,
      `SELECT d.device_id, d.name, d.category, d.location, d.metadata, d.is_active, d.created_at,
              ds.state, ds.updated_at
       FROM devices d
       LEFT JOIN device_states ds ON ds.home_id=d.home_id AND ds.device_id=d.device_id
       WHERE d.home_id=? AND d.is_active=1
       ORDER BY d.created_at ASC, d.id ASC`,
      [homeId]
    );

    return rows.map((d) => ({
      ...d,
      metadata: parseJson(d.metadata, {}),
      state: parseJson(d.state, {}),
    }));
  }

  const listDevicesHandler = wrap(async (req, res) => {
    const homeId = Number(req.params.homeId);
    const role = await getHomeRole(homeId, req.userId);
    if (!role) return res.status(403).json({ ok: false, error: "not_in_home" });

    const devices = await listDevicesForHome(homeId);
    res.json({ ok: true, devices });
  });

  r.get("/homes/:homeId/devices", requireAuth, listDevicesHandler);
  r.get("/homes/:homeId/devices/catalog", requireAuth, listDevicesHandler);

  r.post("/homes/:homeId/devices", requireAuth, wrap(async (req, res) => {
    const homeId = Number(req.params.homeId);
    const role = await getHomeRole(homeId, req.userId);
    if (!role) return res.status(403).json({ ok: false, error: "not_in_home" });
    if (!["owner", "admin", "resident"].includes(role)) {
      return res.status(403).json({ ok: false, error: "no_permission" });
    }

    const schema = z.object({
      name: z.string().min(2),
      category: z.string().min(2),
      location: z.string().optional(),
      device_id: z.string().optional(),
      metadata: z.record(z.any()).optional(),
    });
    const b = schema.parse(req.body);

    const category = normalizeCategory(b.category);
    const generatedId = `${category}_${Date.now().toString(36)}`;
    const deviceId = String(b.device_id || generatedId)
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9_-]/g, "_");

    if (!deviceId) {
      return res.status(400).json({ ok: false, error: "validation_error" });
    }

    const insert = await exec(
      db,
      "INSERT INTO devices(home_id, device_id, name, category, location, metadata) VALUES(?,?,?,?,?,?) RETURNING id",
      [homeId, deviceId, b.name.trim(), category, b.location || "", JSON.stringify(b.metadata || {})]
    );

    const device = await queryOne(
      db,
      "SELECT device_id, name, category, location, metadata, is_active, created_at FROM devices WHERE id=?",
      [insert.lastId]
    );

    saveDb();
    res.json({ ok: true, device: { ...device, metadata: parseJson(device.metadata, {}) } });
  }));

  r.put("/homes/:homeId/devices/:deviceId", requireAuth, wrap(async (req, res) => {
    const homeId = Number(req.params.homeId);
    const deviceId = String(req.params.deviceId);
    const role = await getHomeRole(homeId, req.userId);
    if (!role) return res.status(403).json({ ok: false, error: "not_in_home" });
    if (!["owner", "admin", "resident"].includes(role)) {
      return res.status(403).json({ ok: false, error: "no_permission" });
    }

    const schema = z.object({
      name: z.string().min(2).optional(),
      category: z.string().min(2).optional(),
      location: z.string().optional(),
      metadata: z.record(z.any()).optional(),
    });
    const b = schema.parse(req.body);

    const existing = await queryOne(
      db,
      "SELECT * FROM devices WHERE home_id=? AND device_id=? AND is_active=1",
      [homeId, deviceId]
    );
    if (!existing) return res.status(404).json({ ok: false, error: "device_not_found" });

    await exec(
      db,
      "UPDATE devices SET name=?, category=?, location=?, metadata=? WHERE home_id=? AND device_id=?",
      [
        b.name?.trim() || existing.name,
        b.category ? normalizeCategory(b.category) : existing.category,
        b.location ?? existing.location,
        JSON.stringify(b.metadata ?? parseJson(existing.metadata, {})),
        homeId,
        deviceId,
      ]
    );

    const device = await queryOne(
      db,
      "SELECT device_id, name, category, location, metadata, is_active, created_at FROM devices WHERE home_id=? AND device_id=?",
      [homeId, deviceId]
    );

    saveDb();
    res.json({ ok: true, device: { ...device, metadata: parseJson(device.metadata, {}) } });
  }));

  r.delete("/homes/:homeId/devices/:deviceId", requireAuth, wrap(async (req, res) => {
    const homeId = Number(req.params.homeId);
    const deviceId = String(req.params.deviceId);
    const role = await getHomeRole(homeId, req.userId);
    if (!role) return res.status(403).json({ ok: false, error: "not_in_home" });
    if (!["owner", "admin"].includes(role)) {
      return res.status(403).json({ ok: false, error: "no_permission" });
    }

    await exec(
      db,
      "UPDATE devices SET is_active=0 WHERE home_id=? AND device_id=?",
      [homeId, deviceId]
    );
    saveDb();

    res.json({ ok: true });
  }));

  r.post("/homes/:homeId/devices/:deviceId/command", requireAuth, wrap(async (req, res) => {
    const homeId = Number(req.params.homeId);
    const deviceId = req.params.deviceId;

    const schema = z.object({
      cmd: z.string(),
      value: z.any().optional(),
      reauth_token: z.string().optional()
    });
    const b = schema.parse(req.body);

    const role = await getHomeRole(homeId, req.userId);
    if (!role) return res.status(403).json({ ok: false, error: "not_in_home" });

    const device = await queryOne(
      db,
      "SELECT d.device_id, d.category, ds.state FROM devices d LEFT JOIN device_states ds ON ds.home_id=d.home_id AND ds.device_id=d.device_id WHERE d.home_id=? AND d.device_id=? AND d.is_active=1",
      [homeId, deviceId]
    );
    if (!device) return res.status(404).json({ ok: false, error: "device_not_found" });

    const dangerous = ["UNLOCK_DOOR", "OPEN_WINDOW"];
    if (dangerous.includes(b.cmd)) {
      if (!b.reauth_token) return res.status(401).json({ ok: false, error: "reauth_required" });
      const ok = await consumeReauth(req.userId, b.reauth_token);
      if (!ok) return res.status(401).json({ ok: false, error: "reauth_invalid_or_expired" });
      if (!(role === "owner" || role === "admin")) {
        return res.status(403).json({ ok: false, error: "no_permission" });
      }
    }

    const hc = await queryOne(db, "SELECT home_code FROM homes WHERE id=?", [homeId]);
    const homeCode = hc.home_code;

    mqttClient.publish(
      `home/${homeCode}/device/${deviceId}/cmd`,
      JSON.stringify({ cmd: b.cmd, value: b.value ?? null }),
      { qos: 1 }
    );

    const nextState = applyCommandToState(parseJson(device.state, {}), b.cmd, b.value);
    await exec(
      db,
      "INSERT INTO device_states(device_key, home_id, device_id, state, updated_at) VALUES(?,?,?,?,datetime('now')) ON CONFLICT (device_key) DO UPDATE SET state=excluded.state, updated_at=datetime('now')",
      [`${homeId}:${deviceId}`, homeId, deviceId, JSON.stringify(nextState)]
    );

    await exec(db, "INSERT INTO events(home_id, device_id, type, payload) VALUES(?,?,?,?)",
      [homeId, deviceId, "command_sent", JSON.stringify({ cmd: b.cmd, value: b.value ?? null })]
    );
    saveDb();

    res.json({ ok: true });
  }));

  r.post("/homes/:homeId/guest-codes", requireAuth, wrap(async (req, res) => {
    const homeId = Number(req.params.homeId);
    const schema = z.object({
      code: z.string().min(4),
      minutes: z.number().int().min(1).max(1440),
      scope_device_id: z.string().optional()
    });
    const b = schema.parse(req.body);

    const me = await queryOne(db, "SELECT role FROM home_members WHERE home_id=? AND user_id=?",
      [homeId, req.userId]
    );
    const role = me?.role;
    if (!role || (role !== "owner" && role !== "admin")) {
      return res.status(403).json({ ok: false, error: "no_permission" });
    }

    const code_hash = await bcrypt.hash(b.code, 12);
    const expiresAt = new Date(Date.now() + b.minutes * 60 * 1000).toISOString();

    await exec(db,
      "INSERT INTO one_time_codes(home_id, code_hash, scope_device_id, expires_at, created_by) VALUES(?,?,?,?,?)",
      [homeId, code_hash, b.scope_device_id || null, expiresAt, req.userId]
    );
    saveDb();

    res.json({ ok: true, expires_at: expiresAt });
  }));

  r.post("/homes/:homeCode/doors/:deviceId/use-code", wrap(async (req, res) => {
    const homeCode = req.params.homeCode;
    const deviceId = req.params.deviceId;
    const schema = z.object({ code: z.string().min(4) });
    const { code } = schema.parse(req.body);

    const h = await queryOne(db, "SELECT id FROM homes WHERE home_code=?", [homeCode]);
    if (!h) return res.status(404).json({ ok: false, error: "home_not_found" });
    const homeId = h.id;

    const codes = await queryAll(db,
      "SELECT * FROM one_time_codes WHERE home_id=? AND used_at IS NULL AND expires_at > datetime('now') ORDER BY id DESC LIMIT 30",
      [homeId]
    );

    let matched = null;
    for (const row of codes) {
      if (row.scope_device_id && row.scope_device_id !== deviceId) continue;
      if (await bcrypt.compare(code, row.code_hash)) {
        matched = row;
        break;
      }
    }
    if (!matched) return res.status(401).json({ ok: false, error: "invalid_code" });

    const upd = await exec(db,
      "UPDATE one_time_codes SET used_at=datetime('now') WHERE id=? AND used_at IS NULL",
      [matched.id]
    );
    if (upd.changes === 0) return res.status(409).json({ ok: false, error: "already_used" });

    mqttClient.publish(
      `home/${homeCode}/device/${deviceId}/cmd`,
      JSON.stringify({ cmd: "UNLOCK_DOOR", value: 1 }),
      { qos: 1 }
    );

    await exec(db, "INSERT INTO events(home_id, device_id, type, payload) VALUES(?,?,?,?)",
      [homeId, deviceId, "guest_code_used", JSON.stringify({ deviceId })]
    );
    saveDb();

    res.json({ ok: true });
  }));

  r.get("/homes/:homeId/events", requireAuth, wrap(async (req, res) => {
    const homeId = Number(req.params.homeId);
    const events = await queryAll(db,
      `SELECT e.id, e.device_id, e.type, e.payload, e.created_at,
              d.name AS device_name, d.category AS device_category
       FROM events e
       LEFT JOIN devices d ON d.home_id=e.home_id AND d.device_id=e.device_id
       WHERE e.home_id=?
       ORDER BY e.id DESC
       LIMIT 50`,
      [homeId]
    );
    // Parse payload JSON strings back to objects
    for (const e of events) {
      try { e.payload = JSON.parse(e.payload); } catch {}
    }
    res.json({ ok: true, events });
  }));

  // ==================== Profile ====================

  /// الحصول على الملف الشخصي
  r.get("/auth/profile", requireAuth, wrap(async (req, res) => {
    const u = await queryOne(db,
      "SELECT id, email, phone, created_at FROM users WHERE id=?",
      [req.userId]
    );
    if (!u) return res.status(404).json({ ok: false, error: "user_not_found" });

    // Get user's home & role info
    const membership = await queryOne(db,
      "SELECT h.id AS home_id, h.home_code, h.name AS home_name, hm.role FROM home_members hm JOIN homes h ON h.id = hm.home_id WHERE hm.user_id=? AND hm.is_active=1 LIMIT 1",
      [req.userId]
    );

    res.json({
      ok: true,
      user: {
        id: u.id,
        email: u.email,
        phone: u.phone,
        created_at: u.created_at,
        home_id: membership?.home_id || null,
        home_code: membership?.home_code || null,
        home_name: membership?.home_name || null,
        role: membership?.role || null,
      }
    });
  }));

  /// تحديث الملف الشخصي
  r.put("/auth/profile", requireAuth, wrap(async (req, res) => {
    const schema = z.object({
      email: z.string().email().optional(),
      phone: z.string().optional(),
      full_name: z.string().optional(),
      family_role: z.string().optional(),
      profile_image_url: z.string().optional(),
    });
    const b = schema.parse(req.body);

    if (b.email) {
      await exec(db, "UPDATE users SET email=? WHERE id=?", [b.email, req.userId]);
    }
    if (b.phone) {
      await exec(db, "UPDATE users SET phone=? WHERE id=?", [b.phone, req.userId]);
    }
    if (b.full_name) {
      await exec(db, "UPDATE users SET full_name=? WHERE id=?", [b.full_name, req.userId]);
    }
    if (b.family_role) {
      await exec(db, "UPDATE users SET family_role=? WHERE id=?", [b.family_role, req.userId]);
    }
    if (b.profile_image_url !== undefined) {
      await exec(db, "UPDATE users SET profile_image_url=? WHERE id=?", [b.profile_image_url, req.userId]);
    }
    saveDb();

    const u = await queryOne(db, "SELECT id, email, phone, full_name, family_role, profile_image_url, created_at FROM users WHERE id=?", [req.userId]);
    res.json({ ok: true, user: u });
  }));

  /// تغيير كلمة المرور
  r.post("/auth/change-password", requireAuth, wrap(async (req, res) => {
    const schema = z.object({
      old_password: z.string(),
      new_password: z.string().min(6),
    });
    const b = schema.parse(req.body);

    const u = await queryOne(db, "SELECT password_hash FROM users WHERE id=?", [req.userId]);
    if (!u) return res.status(404).json({ ok: false, error: "user_not_found" });

    const valid = await verifyPassword(b.old_password, u.password_hash);
    if (!valid) return res.status(401).json({ ok: false, error: "wrong_password" });

    const newHash = await hashPassword(b.new_password);
    await exec(db, "UPDATE users SET password_hash=? WHERE id=?", [newHash, req.userId]);
    saveDb();

    res.json({ ok: true });
  }));

  // ==================== Members ====================

  /// قائمة أعضاء المنزل مع الحالة
  r.get("/homes/:homeId/members", requireAuth, wrap(async (req, res) => {
    const homeId = Number(req.params.homeId);

    const members = await queryAll(db,
      `SELECT u.id, u.email, u.phone, hm.role, hm.is_active
       FROM home_members hm
       JOIN users u ON u.id = hm.user_id
       WHERE hm.home_id=?
       ORDER BY hm.role ASC`,
      [homeId]
    );

    // Sort by role priority (owner > admin > resident > guest)
    const rolePriority = { owner: 1, admin: 2, resident: 3, guest: 4 };
    members.sort((a, b) => {
      const priorityA = rolePriority[a.role] || 999;
      const priorityB = rolePriority[b.role] || 999;
      return priorityA - priorityB;
    });

    res.json({ ok: true, members, total: members.length });
  }));

  // ==================== Image Upload ====================

  const imageStore = {}; // في الذاكرة: { imageId: base64 }

  /// رفع صورة واحدة (صورة البروفايل)
  r.post("/upload/image", requireAuth, upload.single("file"), wrap(async (req, res) => {
    if (!req.file) {
      return res.status(400).json({ ok: false, error: "no_file" });
    }

    const imageId = Date.now() + Math.random().toString(36).substr(2, 9);
    const base64 = req.file.buffer.toString("base64");
    imageStore[imageId] = {
      buffer: base64,
      mimetype: req.file.mimetype,
      originalName: req.file.originalname,
    };

    const imageUrl = `/upload/image/${imageId}`;
    res.json({ ok: true, url: imageUrl, image_id: imageId });
  }));

  /// رفع صور الوجه (3 صور)
  r.post("/upload/faces", requireAuth, upload.array("faces", 3), wrap(async (req, res) => {
    if (!req.files || req.files.length < 3) {
      return res.status(400).json({ ok: false, error: "need_3_face_images" });
    }

    const faceUrls = [];
    for (const file of req.files) {
      const imageId = Date.now() + Math.random().toString(36).substr(2, 9);
      const base64 = file.buffer.toString("base64");
      imageStore[imageId] = {
        buffer: base64,
        mimetype: file.mimetype,
        originalName: file.originalname,
      };
      faceUrls.push(`/upload/image/${imageId}`);
    }

    res.json({ ok: true, face_urls: faceUrls });
  }));

  /// استرجاع الصورة من الذاكرة
  r.get("/upload/image/:imageId", wrap(async (req, res) => {
    const imageId = req.params.imageId;
    const image = imageStore[imageId];
    if (!image) {
      return res.status(404).json({ ok: false, error: "image_not_found" });
    }

    const buffer = Buffer.from(image.buffer, "base64");
    res.set("Content-Type", image.mimetype);
    res.send(buffer);
  }));

  // ==================== Admin API ====================

  // House code generator: DZ-XXXX-XXXX
  function generateHouseCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789';
    let part1 = '', part2 = '';
    for (let i = 0; i < 4; i++) {
      part1 += chars[Math.floor(Math.random() * chars.length)];
      part2 += chars[Math.floor(Math.random() * chars.length)];
    }
    return `DZ-${part1}-${part2}`;
  }

  async function generateUniqueHouseCode(db) {
    let code;
    let existing;
    do {
      code = generateHouseCode();
      existing = await queryOne(db, "SELECT id FROM homes WHERE home_code=?", [code]);
    } while (existing);
    return code;
  }

  const ADMIN_JWT_SECRET = process.env.ADMIN_JWT_SECRET || process.env.JWT_SECRET || "dev_admin_secret_change_me";

  function signAdminToken(username) {
    return jwt.sign({ type: "admin", username }, ADMIN_JWT_SECRET, { expiresIn: "24h" });
  }

  function verifyAdminToken(token) {
    try {
      const payload = jwt.verify(token, ADMIN_JWT_SECRET);
      return payload?.type === "admin";
    } catch {
      return false;
    }
  }

  function requireAdminAuth(req, res, next) {
    const auth = req.headers['authorization'];
    if (!auth || !auth.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, error: 'unauthorized', message: 'غير مصرّح' });
    }
    const token = auth.replace('Bearer ', '');
    if (!verifyAdminToken(token)) {
      return res.status(401).json({ success: false, error: 'unauthorized', message: 'غير مصرّح' });
    }
    next();
  }

  // Admin Login
  const adminLoginHandler = wrap(async (req, res) => {
    const { username, password } = req.body || {};
    const cfg = await queryOne(db, "SELECT * FROM admin_config WHERE username=? LIMIT 1", [username]);
    if (!cfg || cfg.password !== password) {
      return res.status(401).json({ success: false, message: 'اسم المستخدم أو كلمة المرور غير صحيحة' });
    }
    const token = signAdminToken(cfg.username);
    res.json({ success: true, token, admin: cfg.name });
  });

  r.post("/admin/login", adminLoginHandler);
  // Backward compatibility for older web clients
  r.post("/login", adminLoginHandler);

  // Admin Stats
  r.get("/admin/stats", requireAdminAuth, wrap(async (req, res) => {
    const [houses, activeHouses, orders, pendingOrders, revenue, clients] = await Promise.all([
      queryOne(db, "SELECT COUNT(*) AS c FROM homes"),
      queryOne(db, "SELECT COUNT(*) AS c FROM homes WHERE activated=1"),
      queryOne(db, "SELECT COUNT(*) AS c FROM orders"),
      queryOne(db, "SELECT COUNT(*) AS c FROM orders WHERE status='pending'"),
      queryOne(db, "SELECT COALESCE(SUM(amount),0) AS total FROM sales"),
      queryOne(db, "SELECT COUNT(*) AS c FROM clients"),
    ]);
    res.json({
      totalHouses: houses.c, activeHouses: activeHouses.c,
      totalOrders: orders.c, pendingOrders: pendingOrders.c,
      totalRevenue: revenue.total, totalClients: clients.c
    });
  }));

  // Admin Orders
  r.get("/admin/orders", requireAdminAuth, wrap(async (req, res) => {
    const rows = await queryAll(db,
      `SELECT o.*, c.name AS client_name_resolved, h.home_code AS house_code
       FROM orders o
       LEFT JOIN clients c ON c.id = o.client_id
       LEFT JOIN homes h ON h.id = o.home_id
       ORDER BY o.id DESC`);
    const orders = rows.map(o => ({
      ...o,
      client_name: o.client_name_resolved || o.client_name || '-',
      house_code: o.house_code || '-'
    }));
    res.json({ orders });
  }));

  r.post("/admin/orders", requireAdminAuth, wrap(async (req, res) => {
    const b = req.body || {};
    const result = await exec(db,
      "INSERT INTO orders(client_id,client_name,phone,address,package_type) VALUES(?,?,?,?,?) RETURNING id",
      [b.client_id || null, b.client_name || '', b.phone || '', b.address || '', b.package_type || 'basic']);
    const order = await queryOne(db, "SELECT * FROM orders WHERE id=?", [result.lastId]);
    res.json({ success: true, order });
  }));

  r.put("/admin/orders/:id", requireAdminAuth, wrap(async (req, res) => {
    const id = Number(req.params.id);
    const b = req.body || {};
    if (b.status) await exec(db, "UPDATE orders SET status=? WHERE id=?", [b.status, id]);
    res.json({ success: true });
  }));

  // Admin Houses
  r.get("/admin/houses", requireAdminAuth, wrap(async (req, res) => {
    const rows = await queryAll(db,
      `SELECT h.*, c.name AS client_name
       FROM homes h LEFT JOIN clients c ON c.id = h.client_id
       ORDER BY h.id DESC`);
    res.json({
      houses: rows.map(h => ({
        ...h,
        code: h.home_code,
        client_name: h.client_name || '-'
      }))
    });
  }));

  r.post("/admin/houses", requireAdminAuth, wrap(async (req, res) => {
    const b = req.body || {};
    const code = await generateUniqueHouseCode(db);
    const result = await exec(db,
      "INSERT INTO homes(home_code,name,client_id,wilaya,city,address,package_type,activated) VALUES(?,?,?,?,?,?,?,0) RETURNING id",
      [code, b.name || code, b.client_id ? Number(b.client_id) : null,
       b.wilaya || '', b.city || '', b.address || '', b.package_type || 'basic']);
    const house = await queryOne(db, "SELECT * FROM homes WHERE id=?", [result.lastId]);
    res.json({ success: true, code, house: { ...house, code: house.home_code } });
  }));

  r.get("/admin/houses/:id", requireAdminAuth, wrap(async (req, res) => {
    const id = Number(req.params.id);
    const h = await queryOne(db,
      `SELECT h.*, c.name AS client_name, c.phone AS client_phone
       FROM homes h LEFT JOIN clients c ON c.id = h.client_id WHERE h.id=?`, [id]);
    if (!h) return res.status(404).json({ success: false, message: 'المنزل غير موجود' });
    const sales_list = await queryAll(db, "SELECT * FROM sales WHERE home_id=?", [id]);
    const support_tickets = await queryAll(db, "SELECT * FROM support_tickets WHERE home_id=?", [id]);
    res.json({ house: { ...h, code: h.home_code, sales: sales_list, support_tickets } });
  }));

  r.put("/admin/houses/:id/activate", requireAdminAuth, wrap(async (req, res) => {
    const id = Number(req.params.id);
    await exec(db, "UPDATE homes SET activated=1, activated_at=NOW() WHERE id=?", [id]);
    res.json({ success: true });
  }));

  // Admin Clients
  r.get("/admin/clients", requireAdminAuth, wrap(async (req, res) => {
    const rows = await queryAll(db, "SELECT * FROM clients ORDER BY id DESC");
    const clients = await Promise.all(rows.map(async c => {
      const cnt = await queryOne(db, "SELECT COUNT(*) AS c FROM homes WHERE client_id=?", [c.id]);
      return { ...c, house_count: cnt.c };
    }));
    res.json({ clients });
  }));

  r.post("/admin/clients", requireAdminAuth, wrap(async (req, res) => {
    const b = req.body || {};
    if (!b.name) return res.status(400).json({ success: false, message: 'الاسم مطلوب' });
    const result = await exec(db,
      "INSERT INTO clients(name,phone,email,address) VALUES(?,?,?,?) RETURNING id",
      [b.name, b.phone || '', b.email || '', b.address || '']);
    const client = await queryOne(db, "SELECT * FROM clients WHERE id=?", [result.lastId]);
    res.json({ success: true, client });
  }));

  r.delete("/admin/clients/:id", requireAdminAuth, wrap(async (req, res) => {
    const id = Number(req.params.id);
    await exec(db, "DELETE FROM clients WHERE id=?", [id]);
    res.json({ success: true });
  }));

  // Admin Sales
  r.get("/admin/sales", requireAdminAuth, wrap(async (req, res) => {
    const rows = await queryAll(db,
      `SELECT s.*, h.home_code AS house_code, h.package_type, c.name AS client_name
       FROM sales s
       LEFT JOIN homes h ON h.id = s.home_id
       LEFT JOIN clients c ON c.id = h.client_id
       ORDER BY s.id DESC`);
    res.json({ sales: rows.map(s => ({ ...s, house_code: s.house_code || '-', client_name: s.client_name || '-' })) });
  }));

  r.post("/admin/sales", requireAdminAuth, wrap(async (req, res) => {
    const b = req.body || {};
    const result = await exec(db,
      "INSERT INTO sales(home_id,amount,notes) VALUES(?,?,?) RETURNING id",
      [b.home_id ? Number(b.home_id) : null, parseInt(b.amount) || 0, b.notes || '']);
    const sale = await queryOne(db, "SELECT * FROM sales WHERE id=?", [result.lastId]);
    res.json({ success: true, sale });
  }));

  // Admin Support
  r.get("/admin/support", requireAdminAuth, wrap(async (req, res) => {
    const rows = await queryAll(db,
      `SELECT t.*, h.home_code AS house_code, c.name AS client_name
       FROM support_tickets t
       LEFT JOIN homes h ON h.id = t.home_id
       LEFT JOIN clients c ON c.id = h.client_id
       ORDER BY t.id DESC`);
    res.json({ tickets: rows.map(t => ({ ...t, house_code: t.house_code || '-', client_name: t.client_name || '-' })) });
  }));

  r.put("/admin/support/:id", requireAdminAuth, wrap(async (req, res) => {
    const id = Number(req.params.id);
    const b = req.body || {};
    await exec(db, "UPDATE support_tickets SET status=? WHERE id=?", [b.status || 'resolved', id]);
    res.json({ success: true });
  }));

  // Admin Installations
  r.get("/admin/installations", requireAdminAuth, wrap(async (req, res) => {
    const rows = await queryAll(db,
      `SELECT i.*, h.home_code AS house_code, h.address, c.name AS client_name
       FROM installations i
       LEFT JOIN homes h ON h.id = i.home_id
       LEFT JOIN clients c ON c.id = h.client_id
       ORDER BY i.id DESC`);
    res.json({ installations: rows.map(i => ({ ...i, house_code: i.house_code || '-', client_name: i.client_name || '-', address: i.address || '-' })) });
  }));

  r.put("/admin/installations/:id", requireAdminAuth, wrap(async (req, res) => {
    const id = Number(req.params.id);
    const b = req.body || {};
    await exec(db, "UPDATE installations SET status=? WHERE id=?", [b.status || 'completed', id]);
    res.json({ success: true });
  }));

  // Admin Settings
  r.put("/admin/settings", requireAdminAuth, wrap(async (req, res) => {
    const b = req.body || {};
    if (b.name) await exec(db, "UPDATE admin_config SET name=? WHERE username='admin'", [b.name]);
    if (b.newPassword && b.oldPassword) {
      const cfg = await queryOne(db, "SELECT password FROM admin_config WHERE username='admin'");
      if (!cfg || cfg.password !== b.oldPassword) {
        return res.json({ success: false, message: 'كلمة المرور الحالية غير صحيحة' });
      }
      await exec(db, "UPDATE admin_config SET password=? WHERE username='admin'", [b.newPassword]);
    }
    res.json({ success: true });
  }));

  // Public: Verify Home Code
  r.post("/public/verify-home-code", wrap(async (req, res) => {
    const codeRaw = (req.body?.home_code || req.body?.homeCode || '').toString();
    const homeCode = codeRaw.trim().toUpperCase();
    if (!homeCode) {
      return res.status(400).json({ success: false, error: 'validation_error' });
    }

    const h = await queryOne(db, "SELECT id, home_code, activated, package_type FROM homes WHERE home_code=?", [homeCode]);
    if (!h) return res.status(404).json({ success: false, error: 'home_not_found' });
    if (h.activated !== 1) return res.status(403).json({ success: false, error: 'home_not_activated' });

    res.json({
      success: true,
      home: {
        id: h.id,
        code: h.home_code,
        activated: h.activated === 1,
        package_type: h.package_type || 'basic'
      }
    });
  }));

  // Public: Contact Form / Order Submission
  r.post("/public/orders", wrap(async (req, res) => {
    const b = req.body || {};
    const clientName = (b.name || '').trim();
    const contactMethod = (b.contactMethod || '').trim();
    const contact = (b.contact || '').trim();
    if (!clientName || !contactMethod || !contact) {
      return res.status(400).json({ success: false, message: 'البيانات الأساسية ناقصة' });
    }
    const phone = contactMethod !== 'email' ? contact : '';
    const email = contactMethod === 'email' ? contact : '';

    let client = phone
      ? await queryOne(db, "SELECT * FROM clients WHERE phone=? LIMIT 1", [phone])
      : await queryOne(db, "SELECT * FROM clients WHERE email=? LIMIT 1", [email]);

    if (!client) {
      const r2 = await exec(db,
        "INSERT INTO clients(name,phone,email) VALUES(?,?,?) RETURNING id",
        [clientName, phone, email]);
      client = await queryOne(db, "SELECT * FROM clients WHERE id=?", [r2.lastId]);
    }

    const result = await exec(db,
      `INSERT INTO orders(client_id,client_name,phone,contact_method,contact,home_type,doors,windows,cameras,notes,source)
       VALUES(?,?,?,?,?,?,?,?,?,?,'website-contact') RETURNING id`,
      [client.id, clientName, phone, contactMethod, contact,
       (b.homeType || '').trim(),
       parseInt(b.doors) || 0, parseInt(b.windows) || 0, parseInt(b.cameras) || 0,
       (b.notes || '').trim()]);

    res.json({ success: true, orderId: result.lastId });
  }));

  return r;
};
