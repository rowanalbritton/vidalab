#!/usr/bin/env python3
"""Renders VIDA LAB's guided meditations with Kokoro-82M, run locally.

    python generate.py samples            # one short line per guide, to docs/voice-test/
    python generate.py sessions           # every session for every guide, to out/
    python generate.py sessions --guide faye --session arrive
    python generate.py upload             # out/ to the Supabase bucket, plus manifest.json

Model files are not in the repo. Point KOKORO_DIR at a folder holding
kokoro-v1.0.onnx and voices-v1.0.bin (default ~/kokoro-vida). Upload reads
SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and SUPABASE_AUDIO_BUCKET from the
repo's gitignored .env and never prints them.
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "ios-vida-signals" / "VIDALAB" / "Content" / "Meditations"
OUT = Path(__file__).resolve().parent / "out"
SAMPLES = ROOT / "docs" / "voice-test"
KOKORO_DIR = Path(os.environ.get("KOKORO_DIR", Path.home() / "kokoro-vida"))

SAMPLE_TEXT = (
    "Welcome. For the next few minutes, there's nothing to get right. "
    "Let your shoulders soften, and let the next breath out be a little slower than the one before."
)
LEAD_IN = 2.0      # seconds of quiet before the first words
FADE = 0.02        # seconds, to keep joins click-free
TARGET_RMS = 0.09  # a calm, even speaking level


def load_guides():
    return json.loads((CONTENT / "guides.json").read_text())


def load_sessions():
    return [json.loads(p.read_text()) for p in sorted(CONTENT.glob("*.json")) if p.name != "guides.json"]


def kokoro():
    from kokoro_onnx import Kokoro
    model, voices = KOKORO_DIR / "kokoro-v1.0.onnx", KOKORO_DIR / "voices-v1.0.bin"
    if not model.exists() or not voices.exists():
        sys.exit(f"Missing model files in {KOKORO_DIR}")
    engine = Kokoro(str(model), str(voices))
    # kokoro-onnx sends speed as an int32 for newer exports, but the v1.0
    # model expects a float, and an int would also round 0.9 down to 0.
    run = engine.sess.run
    speed_type = {i.name: i.type for i in engine.sess.get_inputs()}.get("speed")

    def run_with_float_speed(outputs, inputs, *rest):
        if speed_type == "tensor(float)" and "speed" in inputs:
            inputs = {**inputs, "speed": np.array([engine.vida_speed], dtype=np.float32)}
        return run(outputs, inputs, *rest)

    engine.vida_speed = 1.0
    engine.sess.run = run_with_float_speed
    return engine


def speak(engine, guide, text):
    engine.vida_speed = guide.get("speed", 0.9)
    audio, rate = engine.create(text, voice=guide["voice"], speed=guide.get("speed", 0.9), lang=guide.get("lang", "en-us"))
    audio = np.asarray(audio, dtype=np.float32)
    # Every guide at the same loudness, measured over the voiced parts only,
    # so switching guides never means reaching for the volume.
    voiced = audio[np.abs(audio) > 0.01]
    if voiced.size:
        audio *= TARGET_RMS / float(np.sqrt(np.mean(voiced ** 2)))
        peak = float(np.abs(audio).max())
        if peak > 0.9:
            audio *= 0.9 / peak
    n = min(len(audio) // 2, int(rate * FADE))
    if n:
        ramp = np.linspace(0, 1, n, dtype=np.float32)
        audio[:n] *= ramp
        audio[-n:] *= ramp[::-1]
    return audio, rate


def to_m4a(audio, rate, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as wav:
        sf.write(wav.name, audio, rate)
        # afconvert ships with macOS: AAC, mono, 64 kbps is plenty for a voice.
        subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "64000", wav.name, str(target)], check=True)
        os.unlink(wav.name)


def render_samples(args):
    engine = kokoro()
    SAMPLES.mkdir(parents=True, exist_ok=True)
    for guide in load_guides():
        audio, rate = speak(engine, guide, SAMPLE_TEXT)
        target = SAMPLES / f"{guide['id']}-{guide['voice']}.m4a"
        to_m4a(audio, rate, target)
        print(f"{guide['name']:8} {guide['voice']:11} {len(audio) / rate:5.1f}s  {target.relative_to(ROOT)}")


def render_sessions(args):
    engine = kokoro()
    guides = [g for g in load_guides() if not args.guide or g["id"] == args.guide]
    sessions = [s for s in load_sessions() if not args.session or s["id"] == args.session]
    for guide in guides:
        for session in sessions:
            pieces, cues, cursor, rate = [], [], LEAD_IN, 24000
            pieces.append(np.zeros(int(rate * LEAD_IN), dtype=np.float32))
            for segment in session["segments"]:
                audio, rate = speak(engine, guide, segment["text"])
                start = cursor
                cursor += len(audio) / rate
                cues.append({"start": round(start, 2), "end": round(cursor, 2)})
                pieces.append(audio)
                pause = float(segment.get("pause", 0))
                pieces.append(np.zeros(int(rate * pause), dtype=np.float32))
                cursor += pause
            pieces.append(np.zeros(int(rate * 3), dtype=np.float32))  # room for the closing bell
            audio = np.concatenate(pieces)
            base = OUT / guide["id"] / session["id"]
            to_m4a(audio, rate, base.with_suffix(".m4a"))
            base.with_suffix(".json").write_text(json.dumps({
                "guide": guide["id"], "session": session["id"],
                "duration": round(len(audio) / rate, 2), "cues": cues,
            }, indent=2))
            print(f"{guide['name']:8} {session['title']:22} {len(audio) / rate / 60:4.1f} min")


def read_env():
    values = {}
    env = ROOT / ".env"
    for line in env.read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def request(method, url, key, body=None, content_type="application/json", upsert=False):
    headers = {"Authorization": f"Bearer {key}", "apikey": key, "Content-Type": content_type}
    if upsert:
        headers["x-upsert"] = "true"
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code


def upload(args):
    env = read_env()
    base, key = env.get("SUPABASE_URL", "").rstrip("/"), env.get("SUPABASE_SERVICE_ROLE_KEY", "")
    bucket = env.get("SUPABASE_AUDIO_BUCKET") or "meditation-audio"
    if not base or not key:
        sys.exit("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in .env")
    # Public read: the audio is the same for everyone and holds nothing personal.
    status = request("POST", f"{base}/storage/v1/bucket", key,
                     json.dumps({"id": bucket, "name": bucket, "public": True}).encode())
    print(f"bucket {bucket}: {'created' if status == 200 else 'exists' if status in (400, 409) else status}")

    manifest = {"version": 1, "guides": {}}
    for m4a in sorted(OUT.glob("*/*.m4a")):
        path = f"{m4a.parent.name}/{m4a.name}"
        cues = json.loads(m4a.with_suffix(".json").read_text())
        manifest["guides"].setdefault(m4a.parent.name, {})[m4a.stem] = {"path": path, "duration": cues["duration"], "cues": cues["cues"]}
        status = request("POST", f"{base}/storage/v1/object/{bucket}/{path}", key, m4a.read_bytes(), "audio/mp4", upsert=True)
        print(f"{path}: {status}")
        if status != 200:
            sys.exit("Upload failed; stopping.")
    status = request("POST", f"{base}/storage/v1/object/{bucket}/manifest.json", key,
                     json.dumps(manifest).encode(), "application/json", upsert=True)
    print(f"manifest.json: {status}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("samples")
    sessions = sub.add_parser("sessions")
    sessions.add_argument("--guide")
    sessions.add_argument("--session")
    sub.add_parser("upload")
    args = parser.parse_args()
    {"samples": render_samples, "sessions": render_sessions, "upload": upload}[args.command](args)


if __name__ == "__main__":
    main()
