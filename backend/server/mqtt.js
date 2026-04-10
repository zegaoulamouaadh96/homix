const Aedes = require("aedes");
const net = require("net");
const mqtt = require("mqtt");
const websocketStream = require("websocket-stream");

function startMqttBroker(port = 1883) {
  return new Promise((resolve, reject) => {
    const aedes = Aedes();
    const server = net.createServer(aedes.handle);

    server.listen(port, "0.0.0.0", () => {
      console.log(`MQTT broker running on port ${port}`);
      resolve({ aedes, server });
    });

    server.on("error", reject);

    aedes.on("client", (client) => {
      console.log(`MQTT client connected: ${client.id}`);
    });
  });
}

function startMqttWsBroker(httpServer, path = "/mqtt") {
  const aedes = Aedes();
  const wsServer = websocketStream.createServer({ server: httpServer, path }, aedes.handle);

  aedes.on("client", (client) => {
    console.log(`MQTT (WS) client connected: ${client?.id || "unknown"}`);
  });

  aedes.on("clientDisconnect", (client) => {
    console.log(`MQTT (WS) client disconnected: ${client?.id || "unknown"}`);
  });

  wsServer.on("error", (err) => {
    console.error("MQTT WS broker error:", err.message);
  });

  console.log(`MQTT broker over WebSocket enabled on ${path}`);
  return { aedes, wsServer };
}

function connectMqttClient({ mqttUrl, onTelemetry, onEvent, onAck }) {
  const clientId = `backend_${process.pid}_${Date.now()}`;
  const client = mqtt.connect(mqttUrl, {
    clientId,
    clean: true,
    reconnectPeriod: 2000,
    connectTimeout: 10000,
    keepalive: 30,
    resubscribe: true,
  });

  client.on("connect", () => {
    console.log("MQTT client connected:", mqttUrl, `(${clientId})`);
    client.subscribe("home/+/device/+/telemetry", { qos: 1 });
    client.subscribe("home/+/device/+/event", { qos: 1 });
    client.subscribe("home/+/device/+/ack", { qos: 1 });
  });

  client.on("reconnect", () => {
    console.warn("MQTT client reconnecting...");
  });

  client.on("offline", () => {
    console.warn("MQTT client offline");
  });

  client.on("close", () => {
    console.warn("MQTT client connection closed");
  });

  client.on("error", (err) => {
    console.error("MQTT client error:", err.message);
  });

  client.on("message", async (topic, message) => {
    const parts = topic.split("/");
    const homeCode = parts[1];
    const deviceId = parts[3];
    const kind = parts[4];

    let payload;
    try {
      payload = JSON.parse(message.toString());
    } catch {
      return console.error("Bad JSON:", topic);
    }

    if (kind === "telemetry") return onTelemetry({ homeCode, deviceId, payload });
    if (kind === "event") return onEvent({ homeCode, deviceId, payload });
    if (kind === "ack") return onAck({ homeCode, deviceId, payload });
  });

  return client;
}

module.exports = { startMqttBroker, startMqttWsBroker, connectMqttClient };
