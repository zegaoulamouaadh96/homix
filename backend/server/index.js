const express = require("express");
const cors = require("cors");
const path = require("path");
const http = require("http");
const { openDb, initDb, saveDb, queryOne, exec } = require("./db");
const { startMqttBroker, startMqttWsBroker, connectMqttClient } = require("./mqtt");
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

function listenWithFallback(serverFactory, startPort, host = "0.0.0.0", maxAttempts = 5) {
  return new Promise((resolve, reject) => {
    let attempts = 0;

    const tryPort = (port) => {
      const server = serverFactory();
      server.listen(port, host, () => resolve({ server, port }));
      server.once("error", (err) => {
        server.close(() => {
          if (err?.code === "EADDRINUSE" && attempts < maxAttempts) {
            attempts += 1;
            const nextPort = port + 1;
            console.warn(`HTTP port ${port} already in use. Trying ${nextPort}...`);
            return tryPort(nextPort);
          }
          return reject(err);
        });
      });
    };

    tryPort(startPort);
  });
}

async function main() {
  const app = express();
  app.use(cors());
  app.use(express.json({ limit: process.env.JSON_BODY_LIMIT || "20mb" }));

  let realMqttClient = null;
  const mqttClient = {
    publish: (...args) => {
      if (realMqttClient?.connected) {
        return realMqttClient.publish(...args);
      }
      console.warn("MQTT client not connected yet; publish dropped");
    },
  };

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
  const listener = await listenWithFallback(() => http.createServer(app), port, "0.0.0.0", 10);
  startMqttWsBroker(listener.server, "/mqtt");

  const enableTcpMqtt = process.env.MQTT_ENABLE_TCP === "true";
  const mqttPort = Number(process.env.MQTT_PORT || 1883);
  if (enableTcpMqtt) {
    try {
      await startMqttBroker(mqttPort);
    } catch (err) {
      if (err?.code === "EADDRINUSE") {
        console.warn(`MQTT broker port ${mqttPort} already in use. Reusing existing broker.`);
      } else {
        throw err;
      }
    }
  }

  const mqttUrl = process.env.MQTT_URL || `ws://127.0.0.1:${listener.port}/mqtt`;

  // Connect internal MQTT client
  realMqttClient = connectMqttClient({
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

  console.log(`API on http://0.0.0.0:${listener.port}`);
  console.log(`MQTT over WS on ws://0.0.0.0:${listener.port}/mqtt`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
