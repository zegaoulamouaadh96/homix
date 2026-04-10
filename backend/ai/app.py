import base64
import os
import time
import sys
from typing import Any, Dict, List, Optional, Tuple

import cv2
import numpy as np
from flask import Flask, jsonify, request

# Fallback to bundled InsightFace source in this repo.
local_insightface_pkg = os.path.join(os.path.dirname(__file__), "insightface", "python-package")
if local_insightface_pkg not in sys.path:
    sys.path.insert(0, local_insightface_pkg)

def _apply_default_cache_paths() -> None:
    if os.getenv("INSIGHTFACE_HOME"):
        return

    if os.name == "nt":
        cache_root = r"D:\homix-cache"
        os.environ["INSIGHTFACE_HOME"] = os.path.join(cache_root, ".insightface")
        os.environ["HOME"] = cache_root
        os.environ["USERPROFILE"] = cache_root
    else:
        cache_root = "/opt/homix-cache"
        os.environ["INSIGHTFACE_HOME"] = os.path.join(cache_root, ".insightface")

    os.makedirs(os.environ["INSIGHTFACE_HOME"], exist_ok=True)


def _patch_insightface_optional_imports() -> None:
    target = os.path.join(local_insightface_pkg, "insightface", "app", "__init__.py")
    if not os.path.exists(target):
        return

    try:
        with open(target, "r", encoding="utf-8") as f:
            content = f.read()

        marker = "from .mask_renderer import *"
        if marker not in content:
            return

        if "optional compiled face3d extension" in content:
            return

        patched = content.replace(
            marker,
            "try:\n\tfrom .mask_renderer import *\nexcept Exception:\n\t# mask_renderer depends on optional compiled face3d extension.\n\tpass",
        )

        with open(target, "w", encoding="utf-8") as f:
            f.write(patched)
    except Exception:
        # Best-effort patching only.
        pass


_apply_default_cache_paths()
_patch_insightface_optional_imports()

from insightface.app.face_analysis import FaceAnalysis


app = Flask(__name__)

FACE_CTX = int(os.getenv("FACE_CTX", "-1"))
FACE_DET_SIZE = int(os.getenv("FACE_DET_SIZE", "640"))

metrics: Dict[str, Any] = {
    "requests": 0,
    "register_requests": 0,
    "verify_requests": 0,
    "success": 0,
    "fail": 0,
    "last_error": None,
    "avg_latency_ms": 0.0,
}


def _update_latency(started_at: float) -> None:
    elapsed_ms = (time.time() - started_at) * 1000.0
    n = max(metrics["requests"], 1)
    prev = float(metrics["avg_latency_ms"])
    metrics["avg_latency_ms"] = float(((prev * (n - 1)) + elapsed_ms) / n)


def _error(error: str, reason: Optional[str] = None, code: int = 400):
    metrics["fail"] += 1
    metrics["last_error"] = reason or error
    return jsonify({"ok": False, "error": error, "reason": reason}), code


def _strip_data_url(value: str) -> str:
    if "," in value and value.startswith("data:"):
        return value.split(",", 1)[1]
    return value


def _decode_image(image_b64: str) -> Optional[np.ndarray]:
    try:
        payload = _strip_data_url(image_b64)
        raw = base64.b64decode(payload)
        arr = np.frombuffer(raw, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        return img
    except Exception:
        return None


def _pick_best_face(faces: List[Any]) -> Optional[Any]:
    if not faces:
        return None
    return max(faces, key=lambda f: float(getattr(f, "det_score", 0.0)))


def _normalize(vec: np.ndarray) -> np.ndarray:
    norm = float(np.linalg.norm(vec))
    if norm <= 1e-8:
        return vec
    return vec / norm


def _face_pose_features(face: Any) -> Tuple[float, float]:
    bbox = np.array(getattr(face, "bbox", [0, 0, 1, 1]), dtype=np.float32)
    kps = np.array(getattr(face, "kps", []), dtype=np.float32)
    if kps.shape[0] < 5:
        return 0.0, 0.0

    left_eye = kps[0]
    right_eye = kps[1]
    nose = kps[2]
    mouth_left = kps[3]
    mouth_right = kps[4]

    w = max(float(bbox[2] - bbox[0]), 1.0)
    eye_dist = max(float(np.linalg.norm(left_eye - right_eye)), 1.0)

    center_x = float((bbox[0] + bbox[2]) / 2.0)
    yaw = float((nose[0] - center_x) / w)
    mouth_width = float(np.linalg.norm(mouth_left - mouth_right))
    smile_ratio = mouth_width / eye_dist
    return yaw, smile_ratio


def _challenge_passed(challenge_type: str, yaws: List[float], smiles: List[float], motion_score: float) -> Tuple[bool, Optional[str]]:
    if not challenge_type:
        return True, None

    c = challenge_type.strip().lower()
    if c == "turn_left":
        ok = min(yaws) < -0.05 if yaws else False
        return ok, None if ok else "turn_left_not_detected"

    if c == "turn_right":
        ok = max(yaws) > 0.05 if yaws else False
        return ok, None if ok else "turn_right_not_detected"

    if c == "smile":
        if not smiles:
            return False, "smile_not_detected"
        baseline = float(np.median(smiles))
        peak = float(np.max(smiles))
        ok = (peak - baseline) > 0.08 or peak > 1.85
        return ok, None if ok else "smile_not_detected"

    if c == "blink":
        # 5-point landmarks do not provide eyelid detail; use temporal motion as fallback.
        ok = motion_score >= 0.02
        return ok, None if ok else "blink_not_detected"

    return True, None


print("[face-ai] Initializing InsightFace...")
face_app = FaceAnalysis(name=os.getenv("FACE_MODEL_NAME", "buffalo_l"))
face_app.prepare(ctx_id=FACE_CTX, det_size=(FACE_DET_SIZE, FACE_DET_SIZE))
print("[face-ai] InsightFace ready")


@app.get("/health")
def health():
    return jsonify({"ok": True, "service": "insightface", "ctx": FACE_CTX})


@app.get("/metrics")
def get_metrics():
    return jsonify({"ok": True, "metrics": metrics})


@app.post("/face/register")
def face_register():
    started = time.time()
    metrics["requests"] += 1
    metrics["register_requests"] += 1

    body = request.get_json(silent=True) or {}
    frames = body.get("frames") or []
    challenge_type = str(body.get("challenge_type") or "")
    min_frames = int(body.get("min_frames") or 6)
    max_frames = int(body.get("max_frames") or 14)

    if not isinstance(frames, list) or len(frames) < 1:
        _update_latency(started)
        return _error("invalid_frames", "frames must be a non-empty array")

    frames = frames[: max(1, max_frames)]

    embeddings: List[np.ndarray] = []
    det_scores: List[float] = []
    yaws: List[float] = []
    smiles: List[float] = []

    for item in frames:
        if not isinstance(item, str):
            continue
        img = _decode_image(item)
        if img is None:
            continue

        faces = face_app.get(img)
        best = _pick_best_face(faces)
        if best is None:
            continue

        emb = np.array(getattr(best, "normed_embedding", []), dtype=np.float32)
        if emb.size < 64:
            continue

        emb = _normalize(emb)
        embeddings.append(emb)
        det_scores.append(float(getattr(best, "det_score", 0.0)))

        yaw, smile_ratio = _face_pose_features(best)
        yaws.append(yaw)
        smiles.append(smile_ratio)

    if len(embeddings) < min_frames:
        _update_latency(started)
        return _error("no_face_detected", f"detected only {len(embeddings)} frames")

    mean_emb = _normalize(np.mean(np.vstack(embeddings), axis=0).astype(np.float32))

    if len(embeddings) > 1:
        pairwise_motion = []
        for i in range(1, len(embeddings)):
            sim = float(np.dot(embeddings[i - 1], embeddings[i]))
            pairwise_motion.append(max(0.0, 1.0 - sim))
        emb_motion = float(np.mean(pairwise_motion))
    else:
        emb_motion = 0.0

    yaw_motion = float(np.std(yaws)) if yaws else 0.0
    motion_score = float(min(1.0, (emb_motion * 5.0) + (yaw_motion * 8.0)))

    challenge_ok, challenge_reason = _challenge_passed(challenge_type, yaws, smiles, motion_score)

    quality_score = float(np.clip(np.mean(det_scores) if det_scores else 0.0, 0.0, 1.0))
    liveness_score = float(np.clip((motion_score * 0.8) + (quality_score * 0.2), 0.0, 1.0))
    spoof_score = float(np.clip((quality_score * 0.7) + (liveness_score * 0.3), 0.0, 1.0))

    metrics["success"] += 1
    _update_latency(started)

    return jsonify(
        {
            "ok": True,
            "engine": "insightface",
            "embedding": mean_emb.tolist(),
            "confidence": quality_score,
            "accepted": bool(challenge_ok),
            "challenge_passed": bool(challenge_ok),
            "challenge_reason": challenge_reason,
            "frames_processed": len(embeddings),
            "unique_embeddings": len(embeddings),
            "liveness_score": liveness_score,
            "spoof_score": spoof_score,
            "quality_score": quality_score,
        }
    )


@app.post("/face/verify")
def face_verify():
    started = time.time()
    metrics["requests"] += 1
    metrics["verify_requests"] += 1

    body = request.get_json(silent=True) or {}
    image_b64 = body.get("image")
    encoding = body.get("encoding")
    threshold = float(body.get("distance_threshold") or 0.42)

    if not isinstance(image_b64, str) or len(image_b64) < 20:
        _update_latency(started)
        return _error("invalid_image", "image is required")

    if not isinstance(encoding, list) or len(encoding) < 64:
        _update_latency(started)
        return _error("invalid_encoding", "stored encoding must be an array")

    img = _decode_image(image_b64)
    if img is None:
        _update_latency(started)
        return _error("invalid_image", "failed to decode image")

    faces = face_app.get(img)
    best = _pick_best_face(faces)
    if best is None:
        _update_latency(started)
        return _error("no_face_detected", "no face in image", code=422)

    probe = np.array(getattr(best, "normed_embedding", []), dtype=np.float32)
    ref = np.array(encoding, dtype=np.float32)
    if probe.size < 64 or ref.size < 64 or probe.size != ref.size:
        _update_latency(started)
        return _error("embedding_size_mismatch", "probe and stored embeddings differ", code=422)

    probe = _normalize(probe)
    ref = _normalize(ref)

    cosine_sim = float(np.dot(probe, ref))
    distance = float(max(0.0, 1.0 - cosine_sim))
    matched = bool(distance <= threshold)
    confidence = float(np.clip(1.0 - distance, 0.0, 1.0))

    quality_score = float(np.clip(float(getattr(best, "det_score", 0.0)), 0.0, 1.0))
    spoof_score = float(np.clip((quality_score * 0.8) + (confidence * 0.2), 0.0, 1.0))

    metrics["success"] += 1
    _update_latency(started)

    return jsonify(
        {
            "ok": True,
            "engine": "insightface",
            "matched": matched,
            "distance": distance,
            "threshold": threshold,
            "confidence": confidence,
            "quality_score": quality_score,
            "spoof_score": spoof_score,
        }
    )


if __name__ == "__main__":
    host = os.getenv("FACE_HOST", "0.0.0.0")
    port = int(os.getenv("FACE_PORT", "5000"))
    app.run(host=host, port=port)
