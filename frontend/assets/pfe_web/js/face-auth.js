// HomiX Face Auth Web Helper
// Requires backend endpoints:
// - GET /api/auth/face/challenge
// - POST /api/auth/face/register
// - POST /api/homes/:homeCode/doors/:deviceId/unlock-with-face

async function requestFaceChallenge(userToken) {
  const res = await fetch('/api/auth/face/challenge', {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${userToken}`,
    },
  });
  const data = await res.json();
  if (!res.ok || !data.ok) throw new Error(data.error || 'challenge_failed');
  return data;
}

async function captureFramesFromCamera({ frameCount = 10, intervalMs = 500 } = {}) {
  const stream = await navigator.mediaDevices.getUserMedia({
    video: {
      facingMode: 'user',
      width: { ideal: 640 },
      height: { ideal: 480 },
    },
    audio: false,
  });

  const video = document.createElement('video');
  video.autoplay = true;
  video.playsInline = true;
  video.srcObject = stream;
  await video.play();

  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d');
  canvas.width = video.videoWidth || 640;
  canvas.height = video.videoHeight || 480;

  const frames = [];
  for (let i = 0; i < frameCount; i += 1) {
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
    frames.push(canvas.toDataURL('image/jpeg', 0.82));
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }

  stream.getTracks().forEach((t) => t.stop());
  return frames;
}

async function registerFaceWithLiveness(userToken) {
  const challenge = await requestFaceChallenge(userToken);
  const frames = await captureFramesFromCamera({ frameCount: 10, intervalMs: 500 });

  const res = await fetch('/api/auth/face/register', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${userToken}`,
    },
    body: JSON.stringify({
      frames,
      challenge_token: challenge.challenge_token,
    }),
  });

  const data = await res.json();
  if (!res.ok || !data.ok) throw new Error(data.error || 'face_register_failed');
  return data;
}

async function unlockDoorWithFace({ deviceToken, homeCode, doorDeviceId }) {
  const frames = await captureFramesFromCamera({ frameCount: 1, intervalMs: 1 });
  const image = frames[0];

  const res = await fetch(`/api/homes/${encodeURIComponent(String(homeCode).toUpperCase())}/doors/${encodeURIComponent(doorDeviceId)}/unlock-with-face`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${deviceToken}`,
    },
    body: JSON.stringify({ image }),
  });

  const data = await res.json();
  if (!res.ok || !data.ok) throw new Error(data.error || 'unlock_failed');
  return data;
}

window.HomiXFaceAuth = {
  requestFaceChallenge,
  captureFramesFromCamera,
  registerFaceWithLiveness,
  unlockDoorWithFace,
};
