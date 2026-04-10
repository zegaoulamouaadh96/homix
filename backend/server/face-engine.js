const MATCH_DISTANCE_THRESHOLD = Number(process.env.FACE_DISTANCE_THRESHOLD || 0.42);
const FACE_MIN_REGISTER_FRAMES = Number(process.env.FACE_MIN_REGISTER_FRAMES || 6);
const FACE_MAX_REGISTER_FRAMES = Number(process.env.FACE_MAX_REGISTER_FRAMES || 14);
const FACE_PYTHON_URL = process.env.FACE_PYTHON_URL || "http://127.0.0.1:5000";

const FACE_TIMEOUT_MS = Number(process.env.FACE_TIMEOUT_MS || 15000);
const FACE_RETRY_COUNT = Number(process.env.FACE_RETRY_COUNT || 2);
const FACE_RETRY_BACKOFF_MS = Number(process.env.FACE_RETRY_BACKOFF_MS || 250);
const FACE_MAX_IN_FLIGHT = Number(process.env.FACE_MAX_IN_FLIGHT || 3);
const FACE_MAX_QUEUE = Number(process.env.FACE_MAX_QUEUE || 200);

const CHALLENGES = [
  { type: "blink", instruction_ar: "ارمش بعينيك", instruction_en: "Blink your eyes" },
  { type: "turn_left", instruction_ar: "لف راسك لليسار", instruction_en: "Turn your head left" },
  { type: "turn_right", instruction_ar: "لف راسك لليمين", instruction_en: "Turn your head right" },
  { type: "smile", instruction_ar: "ابتسم", instruction_en: "Smile" },
];

const metrics = {
  requests: 0,
  success: 0,
  fail: 0,
  retries: 0,
  queueRejected: 0,
  inFlight: 0,
  queued: 0,
  totalLatencyMs: 0,
};

class Limiter {
  constructor(maxInFlight, maxQueue) {
    this.maxInFlight = maxInFlight;
    this.maxQueue = maxQueue;
    this.inFlight = 0;
    this.queue = [];
  }

  run(task) {
    return new Promise((resolve, reject) => {
      const execute = () => {
        this.inFlight += 1;
        metrics.inFlight = this.inFlight;
        Promise.resolve()
          .then(task)
          .then(resolve)
          .catch(reject)
          .finally(() => {
            this.inFlight -= 1;
            metrics.inFlight = this.inFlight;
            this._drain();
          });
      };

      if (this.inFlight < this.maxInFlight) {
        execute();
        return;
      }

      if (this.queue.length >= this.maxQueue) {
        metrics.queueRejected += 1;
        reject(Object.assign(new Error("face_queue_overloaded"), { code: "FACE_QUEUE_OVERLOADED" }));
        return;
      }

      this.queue.push(execute);
      metrics.queued = this.queue.length;
    });
  }

  _drain() {
    if (!this.queue.length) {
      metrics.queued = 0;
      return;
    }
    if (this.inFlight >= this.maxInFlight) return;
    const next = this.queue.shift();
    metrics.queued = this.queue.length;
    next();
  }
}

const limiter = new Limiter(FACE_MAX_IN_FLIGHT, FACE_MAX_QUEUE);

function randomChallenge() {
  const pick = CHALLENGES[Math.floor(Math.random() * CHALLENGES.length)];
  return { ...pick, duration_seconds: 5 };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function _fetchFace(path, payload, timeoutMs) {
  const started = Date.now();
  const res = await fetch(`${FACE_PYTHON_URL}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(timeoutMs),
  });

  const body = await res.json().catch(() => ({}));
  const latency = Date.now() - started;
  metrics.totalLatencyMs += latency;

  if (!res.ok || body.ok === false) {
    return {
      ok: false,
      error: body.error || "face_service_error",
      reason: body.reason,
      status: res.status,
      details: body,
    };
  }

  return { ok: true, data: body };
}

async function postToFaceService(path, payload, timeoutMs = FACE_TIMEOUT_MS, retries = FACE_RETRY_COUNT) {
  metrics.requests += 1;
  const started = Date.now();

  return limiter.run(async () => {
    let lastError = null;

    for (let attempt = 0; attempt <= retries; attempt += 1) {
      try {
        const result = await _fetchFace(path, payload, timeoutMs);
        if (result.ok) {
          metrics.success += 1;
          return result;
        }

        lastError = result;
        const retriable = result.status >= 500 || result.error === "face_processing_timeout";
        if (!retriable || attempt === retries) {
          metrics.fail += 1;
          return result;
        }
      } catch (err) {
        lastError = { ok: false, error: "face_service_unavailable", reason: err.message };
        if (attempt === retries) {
          metrics.fail += 1;
          return lastError;
        }
      }

      metrics.retries += 1;
      await sleep(FACE_RETRY_BACKOFF_MS * (attempt + 1));
    }

    metrics.fail += 1;
    return lastError || { ok: false, error: "face_service_unknown_error" };
  }).finally(() => {
    const latency = Date.now() - started;
    metrics.totalLatencyMs += latency;
  });
}

async function analyzeFrames(framesBase64, challengeType) {
  try {
    const result = await postToFaceService("/face/register", {
      frames: framesBase64,
      challenge_type: challengeType,
      min_frames: FACE_MIN_REGISTER_FRAMES,
      max_frames: FACE_MAX_REGISTER_FRAMES,
    });

    if (!result.ok) {
      return {
        success: false,
        error: result.error,
        reason: result.reason,
        details: result.details,
      };
    }

    const data = result.data;
    return {
      success: true,
      encoding: data.embedding || data.encoding,
      confidence: Number(data.confidence || data.liveness_score || 0.0),
      challenge_passed: Boolean(data.challenge_passed),
      liveness_score: Number(data.liveness_score || 0),
      spoof_score: Number(data.spoof_score || 0),
      quality_score: Number(data.quality_score || 0),
      accepted: Boolean(data.accepted),
      frames_processed: Number(data.frames_processed || 0),
      unique_embeddings: Number(data.unique_embeddings || 0),
      challenge_reason: data.challenge_reason || null,
      engine: data.engine || "python_face_recognition",
    };
  } catch (err) {
    return {
      success: false,
      error: "face_service_unavailable",
      reason: err.message,
    };
  }
}

async function verifyImageAgainstEncoding(imageBase64, storedEncoding) {
  if (!Array.isArray(storedEncoding) || storedEncoding.length < 64) {
    return { success: false, error: "invalid_stored_encoding" };
  }

  try {
    const result = await postToFaceService("/face/verify", {
      image: imageBase64,
      encoding: storedEncoding,
      distance_threshold: MATCH_DISTANCE_THRESHOLD,
    });

    if (!result.ok) {
      return {
        success: false,
        error: result.error,
        reason: result.reason,
        details: result.details,
      };
    }

    const data = result.data;
    return {
      success: true,
      matched: Boolean(data.matched),
      distance: Number(data.distance || 0),
      confidence: Number(data.confidence || 0),
      threshold: Number(data.threshold || MATCH_DISTANCE_THRESHOLD),
      quality_score: Number(data.quality_score || 0),
      spoof_score: Number(data.spoof_score || 0),
      engine: data.engine || "python_face_recognition",
    };
  } catch {
    return {
      success: false,
      error: "face_service_unavailable",
    };
  }
}

function getFaceEngineMetrics() {
  const req = Math.max(metrics.requests, 1);
  return {
    ...metrics,
    avgLatencyMs: Number((metrics.totalLatencyMs / req).toFixed(2)),
    queueDepth: limiter.queue.length,
  };
}

module.exports = {
  randomChallenge,
  analyzeFrames,
  verifyImageAgainstEncoding,
  MATCH_DISTANCE_THRESHOLD,
  getFaceEngineMetrics,
};
