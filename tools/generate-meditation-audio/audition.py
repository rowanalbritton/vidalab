#!/usr/bin/env python3
"""Auditions Kokoro voices for calm, clear, natural-sounding guides.

Renders one passage per candidate and scores it three ways, since the
choice can't rest on one listener:
  clarity   word error rate from a speech-to-text round trip (faster-whisper)
  natural   DNSMOS signal and overall scores (Microsoft, 1 to 5)
  calm      pitch movement in semitones and speaking rate in words a second

    python audition.py            # writes docs/voice-test/audition/ and report.md
"""
import json
import re
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf

import generate

PASSAGE = (
    "Let yourself settle into whatever position feels okay today. "
    "Notice where your body meets the surface under you, the weight of your shoulders, your hands resting. "
    "There's nothing to fix. Let the next breath out be gentle, slow, and a little longer than the last."
)

SINGLE = ["bf_emma", "bf_isabella", "bf_alice", "bm_george", "bm_fable", "bm_lewis",
          "ff_siwis", "if_sara", "im_nicola", "ef_dora", "hf_alpha", "hf_beta", "hm_omega", "hm_psi"]
BLENDS = [("bf_emma", "af_nicole", 0.7), ("bf_isabella", "af_heart", 0.7), ("bm_george", "am_michael", 0.7),
          ("bm_fable", "bm_george", 0.6), ("ff_siwis", "bf_emma", 0.7), ("if_sara", "bf_isabella", 0.6),
          ("im_nicola", "bm_george", 0.6), ("hf_beta", "bf_emma", 0.6), ("hm_omega", "bm_lewis", 0.6),
          ]

OUT = generate.ROOT / "docs" / "voice-test" / "audition"
DNSMOS = generate.KOKORO_DIR / "dnsmos_sig_bak_ovr.onnx"


def words(text):
    return re.findall(r"[a-z']+", text.lower())


def wer(reference, hypothesis):
    r, h = words(reference), words(hypothesis)
    d = np.zeros((len(r) + 1, len(h) + 1), dtype=int)
    d[:, 0], d[0, :] = range(len(r) + 1), range(len(h) + 1)
    for i in range(1, len(r) + 1):
        for j in range(1, len(h) + 1):
            d[i, j] = min(d[i - 1, j] + 1, d[i, j - 1] + 1, d[i - 1, j - 1] + (r[i - 1] != h[j - 1]))
    return d[len(r), len(h)] / max(1, len(r))


def resample16k(path):
    tmp = tempfile.mktemp(suffix=".wav")
    subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEF32@16000", str(path), tmp], check=True)
    audio, _ = sf.read(tmp, dtype="float32")
    Path(tmp).unlink()
    return audio


def dnsmos(session, audio):
    need = 144160  # 9.01 s at 16 kHz
    if len(audio) < need:
        audio = np.pad(audio, (0, need - len(audio)))
    chunks = [audio[i:i + need] for i in range(0, len(audio) - need + 1, 16000)] or [audio[:need]]
    raw = np.array([session.run(None, {"input_1": c[None, :].astype(np.float32)})[0][0] for c in chunks]).mean(0)
    sig = np.poly1d([-0.08397278, 1.22083953, 0.0052439])(raw[0])
    ovr = np.poly1d([-0.06766283, 1.11546468, 0.04602535])(raw[2])
    return float(sig), float(ovr)


def pitch_stats(audio, rate):
    """Median pitch in Hz and its spread in semitones, over voiced frames."""
    frame, hop = int(rate * 0.04), int(rate * 0.01)
    lo, hi = int(rate / 400), int(rate / 60)
    f0 = []
    for start in range(0, len(audio) - frame, hop):
        x = audio[start:start + frame]
        if np.sqrt(np.mean(x ** 2)) < 0.02:
            continue
        x = x - x.mean()
        ac = np.correlate(x, x, "full")[frame - 1:]
        if ac[0] <= 0:
            continue
        lag = lo + int(np.argmax(ac[lo:hi]))
        if ac[lag] / ac[0] > 0.45:
            f0.append(rate / lag)
    if len(f0) < 10:
        return 0.0, 0.0
    f0 = np.array(f0)
    semis = 12 * np.log2(f0 / np.median(f0))
    semis = semis[np.abs(semis) < 12]  # drop octave errors
    return float(np.median(f0)), float(np.std(semis))


def main():
    import onnxruntime
    from faster_whisper import WhisperModel

    engine = generate.kokoro()
    voices = np.load(generate.KOKORO_DIR / "voices-v1.0.bin")
    asr = WhisperModel("base.en", device="cpu", compute_type="int8")
    mos = onnxruntime.InferenceSession(str(DNSMOS))
    OUT.mkdir(parents=True, exist_ok=True)

    candidates = [(v, v, None) for v in SINGLE] + [(f"{a}+{b}", a, (b, w)) for a, b, w in BLENDS]
    results = []
    for label, base, blend in candidates:
        style = voices[base] if blend is None else voices[base] * blend[1] + voices[blend[0]] * (1 - blend[1])
        guide = {"voice": style, "speed": 0.88, "lang": "en-gb"}
        target = OUT / f"{label.replace('+', '_')}.m4a"
        if target.exists():
            # Rendered on an earlier run; reuse it rather than render again.
            tmp = tempfile.mktemp(suffix=".wav")
            subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEF32@24000", str(target), tmp], check=True)
            audio, rate = sf.read(tmp, dtype="float32")
            Path(tmp).unlink()
        else:
            audio, rate = generate.speak(engine, guide, PASSAGE)
            generate.to_m4a(audio, rate, target)

        segments, _ = asr.transcribe(str(target), language="en", beam_size=5)
        heard = " ".join(s.text for s in segments)
        sig, ovr = dnsmos(mos, resample16k(target))
        voiced = np.nonzero(np.abs(audio) > 0.01)[0]
        seconds = (voiced[-1] - voiced[0]) / rate if voiced.size else 1
        median_f0, spread = pitch_stats(audio, rate)
        row = {"voice": label, "wer": round(wer(PASSAGE, heard), 3), "sig": round(sig, 2), "ovr": round(ovr, 2),
               "f0": round(median_f0), "pitch_spread": round(spread, 2),
               "wps": round(len(words(PASSAGE)) / seconds, 2), "heard": heard.strip()}
        results.append(row)
        (OUT / "results.json").write_text(json.dumps(results, indent=2))
        print(flush=True, end="")
        print(f"{label:24} wer {row['wer']:.2f}  sig {sig:.2f}  ovr {ovr:.2f}  f0 {median_f0:4.0f}  spread {spread:4.2f}  wps {row['wps']:.2f}", flush=True)

    (OUT / "results.json").write_text(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
