const WebSocket = require('ws');
const { verifyImageAgainstEncoding } = require('./face-engine');

// تخزين اتصالات الكاميرا النشطة
const activeStreams = new Map();

// تخزين آخر إشعار لكل منزل لتجنب التكرار
const lastAlerts = new Map();
const ALERT_COOLDOWN_MS = 30000; // 30 ثانية بين الإشعارات

/**
 * بدء خادم WebSocket لبث الكاميرا والتعرف على الوجوه
 */
function startCameraStreamServer(httpServer, path = '/camera-stream') {
  const wss = new WebSocket.Server({ server: httpServer, path });

  wss.on('connection', (ws, req) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const homeId = url.searchParams.get('homeId');
    const deviceId = url.searchParams.get('deviceId');

    if (!homeId || !deviceId) {
      ws.close(4000, 'Missing homeId or deviceId');
      return;
    }

    const streamKey = `${homeId}:${deviceId}`;
    console.log(`[Camera Stream] Client connected: ${streamKey}`);

    // إضافة العميل إلى قائمة الانتظار للبث
    if (!activeStreams.has(streamKey)) {
      activeStreams.set(streamKey, {
        clients: new Set(),
        lastFrame: null,
        isProcessing: false
      });
    }
    activeStreams.get(streamKey).clients.add(ws);

    // إرسال آخر إطار إذا كان متاحاً
    const stream = activeStreams.get(streamKey);
    if (stream.lastFrame) {
      ws.send(JSON.stringify({ type: 'frame', data: stream.lastFrame }));
    }

    ws.on('message', async (message) => {
      try {
        const data = JSON.parse(message);
        
        if (data.type === 'frame') {
          // معالجة إطار الفيديو للتعرف على الوجوه
          stream.lastFrame = data.data;
          
          // بث الإطار لجميع العملاء المتصلين
          broadcastToStream(streamKey, {
            type: 'frame',
            data: data.data
          });

          // التعرف على الوجوه (كل 5 إطارات لتقليل الحمل)
          if (!stream.isProcessing && data.frameIndex % 5 === 0) {
            stream.isProcessing = true;
            await processFrameForFaces(homeId, deviceId, data.data);
            stream.isProcessing = false;
          }
        }
      } catch (err) {
        console.error('[Camera Stream] Error processing message:', err.message);
      }
    });

    ws.on('close', () => {
      console.log(`[Camera Stream] Client disconnected: ${streamKey}`);
      const stream = activeStreams.get(streamKey);
      if (stream) {
        stream.clients.delete(ws);
        // حذف البث إذا لم يكن هناك عملاء
        if (stream.clients.size === 0) {
          activeStreams.delete(streamKey);
        }
      }
    });

    ws.on('error', (err) => {
      console.error('[Camera Stream] WebSocket error:', err.message);
    });
  });

  console.log(`Camera Stream WebSocket server on ${path}`);
  return wss;
}

/**
 * بث رسالة لجميع العملاء المتصلين ببث معين
 */
function broadcastToStream(streamKey, message) {
  const stream = activeStreams.get(streamKey);
  if (!stream) return;

  const messageStr = JSON.stringify(message);
  stream.clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(messageStr);
    }
  });
}

/**
 * معالجة إطار للتعرف على الوجوه واكتشاف الأشخاص الغرباء
 */
async function processFrameForFaces(homeId, deviceId, imageBase64, db) {
  try {
    // هذا الجزء يتطلب الوصول إلى قاعدة البيانات لجلب encodings
    // سيتم تنفيذه من خلال routes.js
    return { detected: false, strangers: [] };
  } catch (err) {
    console.error('[Camera Stream] Error processing frame:', err.message);
    return { detected: false, strangers: [] };
  }
}

/**
 * التحقق من اكتشاف شخص غريب وإرسال إشعار
 */
async function checkForStrangers(homeId, deviceId, detectedFaces, db, mqttClient, registeredEncodings) {
  try {
    const streamKey = `${homeId}:${deviceId}`;
    const now = Date.now();
    const lastAlert = lastAlerts.get(streamKey) || 0;

    // التحقق من فترة التبريد
    if (now - lastAlert < ALERT_COOLDOWN_MS) {
      return { detected: false, count: 0, cooldown: true };
    }

    // التحقق من كل وجه مكتشف
    const strangers = [];
    for (const face of detectedFaces) {
      let isKnown = false;
      
      for (const encoding of registeredEncodings) {
        const result = await verifyImageAgainstEncoding(face.image, encoding);
        if (result.success && result.matched) {
          isKnown = true;
          break;
        }
      }

      if (!isKnown) {
        strangers.push(face);
      }
    }

    // إذا تم اكتشاف أشخاص غرباء
    if (strangers.length > 0) {
      lastAlerts.set(streamKey, now);

      // إرسال إشعار عبر MQTT
      if (mqttClient && mqttClient.publish) {
        mqttClient.publish(
          `home/${homeId}/device/${deviceId}/alert`,
          JSON.stringify({
            type: 'stranger_detected',
            count: strangers.length,
            timestamp: new Date().toISOString(),
            device_id: deviceId
          }),
          { qos: 1 }
        );
      }

      // تسجيل الحدث في قاعدة البيانات
      await db.query(
        `INSERT INTO events(home_id, device_id, type, payload) 
         VALUES($1, $2, $3, $4)`,
        [
          homeId,
          deviceId,
          'stranger_detected',
          JSON.stringify({
            count: strangers.length,
            timestamp: new Date().toISOString()
          })
        ]
      );

      return { detected: true, count: strangers.length };
    }

    return { detected: false, count: 0 };
  } catch (err) {
    console.error('[Camera Stream] Error checking for strangers:', err.message);
    return { detected: false, count: 0 };
  }
}

/**
 * الحصول على حالة البث النشط
 */
function getActiveStreams() {
  const streams = [];
  activeStreams.forEach((value, key) => {
    streams.push({
      streamKey: key,
      clientCount: value.clients.size,
      hasFrame: !!value.lastFrame
    });
  });
  return streams;
}

module.exports = {
  startCameraStreamServer,
  broadcastToStream,
  processFrameForFaces,
  checkForStrangers,
  getActiveStreams
};
