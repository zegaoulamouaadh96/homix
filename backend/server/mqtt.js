const Aedes = require("aedes");
const net = require("net");
const mqtt = require("mqtt");

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

function connectMqttClient({ mqttUrl, onTelemetry, onEvent, onAck }) {
  const client = mqtt.connect(mqttUrl);

  client.on("connect", () => {
    console.log("MQTT client connected:", mqttUrl);
    client.subscribe("home/+/device/+/telemetry");
    client.subscribe("home/+/device/+/event");
    client.subscribe("home/+/device/+/ack");
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

module.exports = { startMqttBroker, connectMqttClient };
