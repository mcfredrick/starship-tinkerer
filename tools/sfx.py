"""Synthesize the game's sound effects as small WAV files.

Run: uv run --with numpy tools/sfx.py
Writes godot_web_game/assets/sfx/<name>.wav (mono, 22.05 kHz, 16-bit).
"""

import wave
from pathlib import Path

import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "godot_web_game" / "assets" / "sfx"
rng = np.random.default_rng(3)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(n, attack=0.005, release=0.2):
    """Linear attack then exponential release, as a fraction of the sound's length."""
    x = np.arange(n) / RATE
    a = np.clip(x / attack, 0, 1)
    return a * np.exp(-x / max(release, 1e-4))


def tone(freq, seconds, release=0.2, harmonics=(1.0, 0.3, 0.1)):
    x = t(seconds)
    s = sum(h * np.sin(2 * np.pi * freq * (i + 1) * x) for i, h in enumerate(harmonics))
    return s * env(len(x), release=release)


def noise(seconds):
    return rng.uniform(-1, 1, int(RATE * seconds))


def lowpass(x, alpha):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def delay(x, seconds):
    pad = np.zeros(int(RATE * seconds))
    return np.concatenate([pad, x])


def save(name, x, gain=0.7):
    x = x / max(np.max(np.abs(x)), 1e-6) * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # A soft wooden pluck for buttons.
    save("click", mix(tone(660, 0.12, release=0.03, harmonics=(1.0, 0.2)), lowpass(noise(0.02), 0.3) * 0.2), 0.4)
    # Scanner proximity ping.
    save("ping", tone(1320, 0.25, release=0.08, harmonics=(1.0, 0.1)), 0.35)
    # Fault found: two rising notes.
    save("found", mix(tone(784, 0.4, 0.15), delay(tone(1175, 0.5, 0.2), 0.09)), 0.55)
    # Success: a little arpeggio.
    save("success", mix(*[delay(tone(f, 0.6, 0.25), i * 0.08) for i, f in enumerate((523, 659, 784, 1047))]), 0.6)
    # Welding sizzle loop: filtered crackle with pops.
    sizzle = lowpass(noise(1.0), 0.5) * 0.6 + (rng.uniform(0, 1, RATE) > 0.995) * rng.uniform(-1, 1, RATE)
    save("weld", sizzle, 0.35)
    # Dial tick.
    save("tick", lowpass(noise(0.015), 0.6) * env(int(RATE * 0.015), release=0.004), 0.3)
    # Tea pour: falling filtered noise with a gurgle.
    x = t(1.4)
    pour = lowpass(noise(1.4), 0.12) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * x)) * np.clip(1.4 - x, 0, 1)
    save("pour", pour, 0.45)
    # Coins: bright jingly pings.
    save("coins", mix(*[delay(tone(f, 0.3, 0.08, (1.0, 0.5, 0.3)), d) for f, d in
                        ((2093, 0), (2637, 0.05), (2349, 0.11), (3136, 0.16))]), 0.45)
    # Gentle error bonk.
    save("bonk", tone(196, 0.25, release=0.08, harmonics=(1.0, 0.5)), 0.45)
    # Engine hum loop: a buzzy fundamental with a slow wobble, seamless over one second.
    x = t(1.0)
    hum = (np.sin(2 * np.pi * 110 * x) + 0.5 * np.sin(2 * np.pi * 220 * x + 0.4)
           + 0.25 * np.sign(np.sin(2 * np.pi * 55 * x)) + 0.15 * lowpass(noise(1.0), 0.2))
    hum *= 0.85 + 0.15 * np.sin(2 * np.pi * 4 * x)
    save("engine", hum, 0.35)
    # Boost whoosh.
    x = t(0.7)
    whoosh = lowpass(noise(0.7), 0.25) * np.sin(np.pi * x / 0.7)
    save("whoosh", whoosh, 0.5)
    # Wall bump.
    save("bump", mix(lowpass(noise(0.18), 0.15) * env(int(RATE * 0.18), release=0.05), tone(90, 0.18, 0.06)), 0.55)
    # Countdown beeps.
    save("beep", tone(880, 0.2, 0.12, (1.0, 0.1)), 0.4)
    save("go", tone(1320, 0.45, 0.25, (1.0, 0.2)), 0.45)
    # Pressure-washer jet loop: bright hiss (noise minus its low end) with a slight flutter.
    hiss = noise(1.0)
    x = t(1.0)
    save("spray", (hiss - lowpass(hiss, 0.08)) * (0.85 + 0.15 * np.sin(2 * np.pi * 23 * x)), 0.3)
    # Sprocket's purr: a low rumble pulsing about 25 times a second, swelling on each breath.
    x = t(1.4)
    rumble = lowpass(noise(1.4), 0.04) * (0.6 + 0.4 * np.sin(2 * np.pi * 25 * x)) * (0.5 + 0.5 * np.sin(np.pi * x / 0.7) ** 2)
    save("purr", rumble * env(len(x), attack=0.1, release=0.2), 0.55)
    # A short "mrrp": a chirp that rises and falls.
    x = t(0.28)
    f = 520 + 380 * np.sin(np.pi * x / 0.28)
    chirp = np.sin(2 * np.pi * np.cumsum(f) / RATE) * env(len(x), attack=0.03, release=0.3)
    save("mrrp", chirp + 0.3 * np.sin(2 * np.pi * 2 * np.cumsum(f) / RATE) * env(len(x), attack=0.03, release=0.3), 0.35)
    # Foghorn: a low, wobbly two-tone honk.
    x = t(0.7)
    horn = tone(140, 0.7, 0.2, (1.0, 0.7, 0.5, 0.3)) * (1 + 0.15 * np.sin(2 * np.pi * 7 * x))
    save("honk", horn + 0.6 * tone(175, 0.7, 0.2, (1.0, 0.5, 0.3)), 0.5)


if __name__ == "__main__":
    main()
