const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const crypto = require("crypto");

const JWT_SECRET = process.env.JWT_SECRET || "dev";

function signToken(userId) {
  return jwt.sign({ sub: userId }, JWT_SECRET, { expiresIn: "7d" });
}

function requireAuth(req, res, next) {
  const h = req.headers.authorization || "";
  const token = h.startsWith("Bearer ") ? h.slice(7) : null;
  if (!token) return res.status(401).json({ ok: false, error: "missing_token" });

  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.userId = payload.sub;
    next();
  } catch {
    return res.status(401).json({ ok: false, error: "invalid_token" });
  }
}

function sha256(s) {
  return crypto.createHash("sha256").update(s).digest("hex");
}

async function hashPassword(p) {
  return bcrypt.hash(p, 12);
}

async function verifyPassword(p, hash) {
  return bcrypt.compare(p, hash);
}

module.exports = { signToken, requireAuth, sha256, hashPassword, verifyPassword };
