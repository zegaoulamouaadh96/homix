const express = require("express");
const cors = require("cors");
const path = require("path");
const { openDb, initDb, saveDb, queryOne, exec } = require("./db");
const { startMqttBroker, connectMqttClient } = require("./mqtt");
const buildRoutes = require("./routes");
const { ZodError } = require("zod");

function inferCategory(deviceId = "", payload = {}) {
  const id = String(deviceId).toLowerCase();
  const type = String(payload?.type || payload?.sensorType || "").toLowerCase();

  if (id.includes("cam") || id.includes("camera") || type.includes("camera")) return "camera";
  if (id.includes("door") || type.includes("door")) return "door";
  if (id.includes("window") || type.includes("window")) return "window";
  if (id.includes("seismic") || id.includes("vibration") || id.includes("quake") || type.includes("seismic")) return "seismic";
  if (id.includes("motion") || type.includes("motion")) return "motion";
  if (id.includes("smoke") || type.includes("smoke")) return "smoke";
  if (id.includes("flood") || id.includes("water") || type.includes("flood")) return "flood";
  if (id.includes("glass") || type.includes("glass")) return "glass";
  return "custom";
}

function toDeviceName(deviceId = "", category = "custom") {
  const labels = {
    camera: "Camera",
    door: "Door",
    window: "Window",
    seismic: "Seismic Sensor",
    motion: "Motion Sensor",
    smoke: "Smoke Sensor",
    flood: "Flood Sensor",
    glass: "Glass Sensor",
    custom: "Device",
  };
  return `${labels[category] || "Device"} ${deviceId}`.trim();
}

async function main() {
  const app = express();
  app.use(cors());
  app.use(express.json());

  // PostgreSQL
  const db = await openDb();
  await initDb(db);
  console.log("PostgreSQL DB ready");

  async function ensureDeviceExists(homeId, deviceId, payload) {
    const category = inferCategory(deviceId, payload);
    const name = toDeviceName(deviceId, category);
    await exec(
      db,
      "INSERT INTO devices(home_id, device_id, name, category, metadata) VALUES(?,?,?,?,?) ON CONFLICT (home_id, device_id) DO NOTHING",
      [homeId, deviceId, name, category, JSON.stringify({ discovered_by: "mqtt" })]
    );
  }

  // Start embedded MQTT only if no external broker URL is provided
  const mqttPort = Number(process.env.MQTT_PORT || 1883);
  const mqttUrl = process.env.MQTT_URL || `mqtt://localhost:${mqttPort}`;
  if (!process.env.MQTT_URL) {
    await startMqttBroker(mqttPort);
  }

  // Connect internal MQTT client
  const mqttClient = connectMqttClient({
    mqttUrl,
    onTelemetry: async ({ homeCode, deviceId, payload }) => {
      try {
        const h = await queryOne(db, "SELECT id FROM homes WHERE home_code=?", [homeCode]);
        if (!h) return;
        await ensureDeviceExists(h.id, deviceId, payload);
        await exec(db,
          "INSERT INTO device_states(device_key, home_id, device_id, state, updated_at) VALUES(?,?,?,?,datetime('now')) ON CONFLICT (device_key) DO UPDATE SET state=excluded.state, updated_at=datetime('now')",
          [`${h.id}:${deviceId}`, h.id, deviceId, JSON.stringify(payload)]
        );
        saveDb();
      } catch (err) {
        console.error("Failed to store telemetry:", err);
      }
    },
    onEvent: async ({ homeCode, deviceId, payload }) => {
      try {
        const h = await queryOne(db, "SELECT id FROM homes WHERE home_code=?", [homeCode]);
        if (!h) return;
        await ensureDeviceExists(h.id, deviceId, payload);
        const type = payload.type || "unknown";
        await exec(db, "INSERT INTO events(home_id, device_id, type, payload) VALUES(?,?,?,?)",
          [h.id, deviceId, type, JSON.stringify(payload)]
        );
        saveDb();
      } catch (err) {
        console.error("Failed to store event:", err);
      }
    },
    onAck: async ({ homeCode, deviceId, payload }) => {
      try {
        const h = await queryOne(db, "SELECT id FROM homes WHERE home_code=?", [homeCode]);
        if (!h) return;
        await ensureDeviceExists(h.id, deviceId, payload);
        await exec(db, "INSERT INTO events(home_id, device_id, type, payload) VALUES(?,?,?,?)",
          [h.id, deviceId, "ack", JSON.stringify(payload)]
        );
        saveDb();
      } catch (err) {
        console.error("Failed to store ack:", err);
      }
    }
  });

  app.get("/", (req, res) => {
    res.sendFile(path.join(__dirname, "../../web/index.html"));
  });

  app.use(express.static(path.join(__dirname, "../../web")));

  app.get("/health", (req, res) => res.json({ ok: true }));

  app.use("/api", buildRoutes({ db, mqttClient }));

  // Global error handler
  app.use((err, req, res, _next) => {
    if (err instanceof ZodError) {
      return res.status(400).json({ ok: false, error: "validation_error", details: err.errors });
    }
    // Unique constraint violation (PostgreSQL)
    if (err.code === "23505" || /unique constraint/i.test(err.message || "")) {
      return res.status(409).json({ ok: false, error: "duplicate_entry" });
    }
    console.error("Unhandled error:", err);
    res.status(500).json({ ok: false, error: "internal_error" });
  });

  const port = Number(process.env.PORT || 3000);
  app.listen(port, "0.0.0.0", () => console.log(`API on http://0.0.0.0:${port}`));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
