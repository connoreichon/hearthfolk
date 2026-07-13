"""Genera todos los WAV del juego por sintesis (solo numpy, sin scipy).

Uso:  python tools/gen_audio.py
Salida: assets/audio/generated/*.wav  (44100 Hz, 16 bit, mono)
"""

from __future__ import annotations

import os
import struct
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "generated")
RNG = np.random.default_rng(20260713)


def write_wav(name: str, data: np.ndarray, gain: float = 0.9) -> None:
    data = np.asarray(data, dtype=np.float64)
    peak = np.max(np.abs(data)) or 1.0
    pcm = np.int16(np.clip(data / peak * gain, -1.0, 1.0) * 32767)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())
    print(f"  {name}.wav  ({len(data) / SR:.2f} s)")


def t(dur: float) -> np.ndarray:
    return np.arange(int(SR * dur)) / SR


def env_perc(n: int, attack: float = 0.005, decay: float = 0.15) -> np.ndarray:
    """Envolvente percusiva ataque/caida exponencial."""
    a = int(SR * attack)
    e = np.ones(n)
    e[:a] = np.linspace(0.0, 1.0, a)
    e[a:] = np.exp(-np.arange(n - a) / (SR * decay))
    return e


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """Paso bajo de un polo (IIR a mano, sin scipy)."""
    dt = 1.0 / SR
    rc = 1.0 / (2.0 * np.pi * cutoff)
    alpha = dt / (rc + dt)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def bandpass(x: np.ndarray, low: float, high: float) -> np.ndarray:
    return highpass(lowpass(x, high), low)


def pink_noise(n: int) -> np.ndarray:
    """Ruido rosa por el metodo Voss-McCartney simplificado."""
    rows = 12
    total = np.zeros(n)
    for r in range(rows):
        step = 2**r
        values = RNG.standard_normal(n // step + 2)
        total += np.repeat(values, step)[:n]
    return total / rows


def brown_noise(n: int) -> np.ndarray:
    x = np.cumsum(RNG.standard_normal(n))
    return x / (np.max(np.abs(x)) or 1.0)


def ambience_forest() -> np.ndarray:
    n = SR * 8
    base = pink_noise(n) * 0.5
    base = lowpass(base, 900.0)
    lfo = 0.7 + 0.3 * np.sin(2 * np.pi * 0.13 * np.arange(n) / SR)
    layer = lowpass(RNG.standard_normal(n), 400.0) * 0.25
    lfo2 = 0.6 + 0.4 * np.sin(2 * np.pi * 0.07 * np.arange(n) / SR + 1.7)
    return base * lfo + layer * lfo2


def wind_soft() -> np.ndarray:
    n = SR * 8
    noise = RNG.standard_normal(n)
    banded = bandpass(noise, 300.0, 1200.0)
    lfo = 0.45 + 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.09 * np.arange(n) / SR))
    return banded * lfo


def bird(variant: int) -> np.ndarray:
    rng = np.random.default_rng(100 + variant)
    chirps = []
    for _ in range(rng.integers(2, 5)):
        dur = rng.uniform(0.06, 0.16)
        tt = t(dur)
        f0 = rng.uniform(2200.0, 4200.0)
        f1 = f0 * rng.uniform(0.75, 1.35)
        freq = np.linspace(f0, f1, len(tt))
        chirp = np.sin(2 * np.pi * np.cumsum(freq) / SR) * env_perc(len(tt), 0.008, dur * 0.5)
        chirps.append(chirp)
        chirps.append(np.zeros(int(SR * rng.uniform(0.04, 0.18))))
    return np.concatenate(chirps)


def insects_night() -> np.ndarray:
    n = SR * 6
    carrier = np.sin(2 * np.pi * 4300.0 * np.arange(n) / SR)
    am = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 11.0 * np.arange(n) / SR))
    slow = 0.4 + 0.6 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.21 * np.arange(n) / SR))
    hiss = highpass(RNG.standard_normal(n), 5000.0) * 0.05
    return carrier * am * slow * 0.3 + hiss


def chop() -> np.ndarray:
    n = int(SR * 0.28)
    click = RNG.standard_normal(n) * env_perc(n, 0.001, 0.03)
    body_t = t(0.28)
    body = np.sin(2 * np.pi * 190.0 * body_t) * np.exp(-body_t * 22.0)
    body += np.sin(2 * np.pi * 95.0 * body_t) * np.exp(-body_t * 16.0) * 0.7
    return lowpass(click, 3200.0) * 0.6 + body


def tree_fall() -> np.ndarray:
    n = int(SR * 1.6)
    sweep = RNG.standard_normal(n)
    cracks = np.zeros(n)
    for pos in RNG.uniform(0.05, 0.7, 9):
        i = int(pos * n)
        ln = int(SR * 0.02)
        if i + ln < n:
            cracks[i : i + ln] += RNG.standard_normal(ln) * np.linspace(1, 0, ln) * 2.0
    body = lowpass(sweep, 500.0) * np.linspace(0.2, 1.0, n) ** 2
    thump_t = t(0.5)
    thump = np.sin(2 * np.pi * 60.0 * thump_t) * np.exp(-thump_t * 9.0)
    out = body * 0.6 + lowpass(cracks, 2500.0)
    out[-len(thump) :] += thump * 1.6
    return out


def pickup_wood() -> np.ndarray:
    n = int(SR * 0.16)
    knock_t = t(0.16)
    knock = np.sin(2 * np.pi * 240.0 * knock_t) * np.exp(-knock_t * 34.0)
    knock += np.sin(2 * np.pi * 470.0 * knock_t) * np.exp(-knock_t * 44.0) * 0.5
    return knock


def footstep(variant: int) -> np.ndarray:
    rng = np.random.default_rng(300 + variant)
    n = int(SR * 0.12)
    noise = rng.standard_normal(n) * env_perc(n, 0.002, 0.045)
    pitch = rng.uniform(0.85, 1.2)
    return lowpass(noise, 480.0 * pitch)


def hammer() -> np.ndarray:
    n = int(SR * 0.3)
    hit = RNG.standard_normal(int(SR * 0.02)) * 1.6
    ring_t = t(0.3)
    ring = np.sin(2 * np.pi * 620.0 * ring_t) * np.exp(-ring_t * 26.0) * 0.4
    ring += np.sin(2 * np.pi * 180.0 * ring_t) * np.exp(-ring_t * 18.0)
    out = ring
    out[: len(hit)] += lowpass(hit, 4000.0)
    return out


def fire_loop() -> np.ndarray:
    n = SR * 6
    base = brown_noise(n)
    crackles = np.zeros(n)
    for pos in RNG.uniform(0.0, 0.98, 46):
        i = int(pos * n)
        ln = int(SR * RNG.uniform(0.004, 0.02))
        if i + ln < n:
            crackles[i : i + ln] += RNG.standard_normal(ln) * np.linspace(1, 0, ln) * 1.6
    return lowpass(base, 700.0) * 0.7 + highpass(crackles, 1200.0) * 0.5


def ui_click() -> np.ndarray:
    tt = t(0.03)
    return np.sin(2 * np.pi * 1200.0 * tt) * env_perc(len(tt), 0.002, 0.012)


def ui_confirm() -> np.ndarray:
    a_t = t(0.09)
    b_t = t(0.14)
    a = np.sin(2 * np.pi * 660.0 * a_t) * env_perc(len(a_t), 0.004, 0.05)
    b = np.sin(2 * np.pi * 880.0 * b_t) * env_perc(len(b_t), 0.004, 0.08)
    return np.concatenate([a, b])


def ui_error() -> np.ndarray:
    a_t = t(0.1)
    b_t = t(0.16)
    a = np.sin(2 * np.pi * 520.0 * a_t) * env_perc(len(a_t), 0.004, 0.06)
    b = np.sin(2 * np.pi * 340.0 * b_t) * env_perc(len(b_t), 0.004, 0.1)
    return np.concatenate([a, b])


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    print("Generando audio en", os.path.abspath(OUT))
    write_wav("ambience_forest", ambience_forest(), 0.5)
    write_wav("wind_soft", wind_soft(), 0.35)
    for i in range(4):
        write_wav(f"bird_{i}", bird(i), 0.5)
    write_wav("insects_night", insects_night(), 0.4)
    write_wav("chop", chop(), 0.85)
    write_wav("tree_fall", tree_fall(), 0.9)
    write_wav("pickup_wood", pickup_wood(), 0.8)
    for i in range(4):
        write_wav(f"footstep_{i}", footstep(i), 0.5)
    write_wav("hammer", hammer(), 0.85)
    write_wav("fire_loop", fire_loop(), 0.6)
    write_wav("ui_click", ui_click(), 0.7)
    write_wav("ui_confirm", ui_confirm(), 0.7)
    write_wav("ui_error", ui_error(), 0.7)
    print("Hecho.")


if __name__ == "__main__":
    main()
