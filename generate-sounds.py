#!/usr/bin/env python3
"""Generate the ambient horror audio for Omarchy Backrooms.

Pure stdlib (wave + math + random) so it runs anywhere. Synthesizes droning
fluorescent hums, sub-bass booms, breathy whispers, violin-ish jumpscare
stings, footsteps and a heartbeat - everything the game needs, no assets.

Usage: python3 generate-sounds.py [outdir]
"""

import math
import os
import random
import struct
import sys
import wave

RATE = 44100
random.seed(666)


def write_wav(path, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    norm = min(1.0, 0.92 / peak)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * norm)) * 32767))
            for s in samples))


def seconds(n):
    return int(RATE * n)


def env_exp(i, n, attack=0.005, decay=6.0):
    t = i / RATE
    ta = attack * RATE
    a = min(1.0, i / ta) if ta > 0 else 1.0
    return a * math.exp(-decay * t)


def lowpass(samples, cutoff):
    rc = 1.0 / (2 * math.pi * cutoff)
    dt = 1.0 / RATE
    alpha = dt / (rc + dt)
    out = []
    prev = 0.0
    for s in samples:
        prev += alpha * (s - prev)
        out.append(prev)
    return out


def highpass(samples, cutoff):
    lp = lowpass(samples, cutoff)
    return [s - l for s, l in zip(samples, lp)]


def bandpass(samples, lo, hi):
    hp = highpass(samples, lo)
    return lowpass(hp, hi)


def noise(n):
    return [random.uniform(-1, 1) for _ in range(n)]


def sine_sweep(f0, f1, dur, volume=1.0, curve=1.0):
    out = []
    phase = 0.0
    for i in range(seconds(dur)):
        t = i / seconds(dur)
        f = f0 + (f1 - f0) * (t ** curve)
        phase += f / RATE
        out.append(volume * math.sin(2 * math.pi * phase))
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def gain(samples, g):
    return [s * g for s in samples]


def delay_pad(samples, sec):
    return [0.0] * seconds(sec) + list(samples)


def loopify(samples, fade_sec=1.5):
    n = len(samples)
    f = seconds(fade_sec)
    out = list(samples)
    for i in range(f):
        a = i / f
        out[i] = out[i] * a + samples[n - f + i] * (1 - a)
    return out[: n - f]


def gen_drone():
    dur = 24.0
    n = seconds(dur)

    def voice(freq, detune, amp, lfo_p, lfo_amt):
        out = []
        ph = 0.0
        for i in range(n):
            t = i / RATE
            lfo = 1.0 - lfo_amt * (0.5 + 0.5 * math.sin(2 * math.pi * t / lfo_p + freq))
            f = freq * (1 + detune)
            ph += f / RATE
            saw = 2.0 * (ph % 1.0) - 1.0
            s = 0.55 * math.sin(2 * math.pi * ph) + 0.45 * saw
            out.append(amp * s * lfo)
        return out

    tracks = [
        voice(55.0, 0.000, 0.30, 13.0, 0.5),
        voice(55.0, 0.004, 0.22, 17.0, 0.6),
        voice(65.41, 0.002, 0.20, 11.0, 0.55),
        voice(82.41, -0.003, 0.16, 19.0, 0.6),
        voice(98.0, 0.001, 0.10, 23.0, 0.7),
    ]
    wind = gain(lowpass(noise(n), 240), 0.05)
    drone = mix(*(tracks + [wind]))
    return loopify(drone, 2.0)


def gen_buzz():
    dur = 3.0
    n = seconds(dur)
    out = []
    ph = 0.0
    ampw = 1.0
    for i in range(n):
        t = i / RATE
        ph += 120.0 / RATE
        ampw += random.uniform(-0.04, 0.04)
        ampw = max(0.75, min(1.15, ampw))
        s = (math.sin(2 * math.pi * ph)
             + 0.42 * math.sin(2 * math.pi * 2 * ph)
             + 0.25 * math.sin(2 * math.pi * 3 * ph)
             + 0.14 * math.sin(2 * math.pi * 5 * ph))
        hiss = random.uniform(-1, 1) * 0.06
        out.append((s * 0.8 + hiss) * ampw * 0.5)
    return loopify(out, 0.4)


def gen_footstep(variant):
    dur = 0.16 + variant * 0.012
    n = seconds(dur)
    raw = noise(n)
    brown = []
    acc = 0.0
    for s in raw:
        acc = (acc + 0.12 * s) * 0.96
        brown.append(acc * 3.2)
    cut = 420 - variant * 40
    body = lowpass(brown, cut)
    thump = sine_sweep(95 - variant * 6, 38, dur, 0.7, 0.5)
    out = mix(gain(body, 0.85), thump)
    return [s * env_exp(i, n, 0.002, 16 + variant * 2) for i, s in enumerate(out)]


def gen_sting():
    dur = 1.5
    n = seconds(dur)
    parts = []
    for k in range(6):
        f0 = 1350 + k * 190 + random.uniform(-40, 40)
        parts.append(sine_sweep(f0, 260 - k * 18, dur, 0.16, 0.65))
    shriek = bandpass(noise(n), 700, 3200)
    parts.append(gain(shriek, 0.5))
    boom = sine_sweep(160, 30, dur, 0.9, 0.35)
    parts.append(boom)
    out = mix(*parts)
    shaped = []
    for i, s in enumerate(out):
        t = i / RATE
        atk = min(1.0, t / 0.012)
        dec = math.exp(-2.6 * max(0.0, t - 0.12))
        shaped.append(s * atk * dec)
    return shaped


def gen_thud():
    dur = 1.8
    n = seconds(dur)
    boom = sine_sweep(58, 24, dur, 1.0, 0.6)
    rumble = gain(lowpass(noise(n), 130), 0.5)
    out = mix(boom, rumble)
    return [s * env_exp(i, n, 0.01, 2.4) for i, s in enumerate(out)]


def gen_whisper():
    dur = 2.8
    n = seconds(dur)
    src = noise(n)
    out = []
    for chunk_start in range(0, n, seconds(0.28)):
        chunk = src[chunk_start:chunk_start + seconds(0.28)]
        if not chunk:
            break
        lo = 500 + random.uniform(-200, 700)
        hi = lo + 900 + random.uniform(0, 900)
        bp = bandpass(chunk, lo, hi)
        gap = random.random()
        vol = 0.0 if gap < 0.30 else random.uniform(0.35, 1.0)
        ramp_n = min(len(bp), seconds(0.09))
        for i, s in enumerate(bp):
            e = min(1.0, i / ramp_n) if ramp_n else 1.0
            out.append(s * vol * e)
    return lowpass(out[:n], 3800)


def gen_heartbeat():
    dur = 1.05
    out = [0.0] * seconds(dur)

    def pulse(t0, f, amp):
        ln = seconds(0.16)
        for i in range(ln):
            idx = seconds(t0) + i
            if idx < len(out):
                tt = i / RATE
                out[idx] += amp * math.sin(2 * math.pi * f * tt) * math.exp(-26 * tt)

    pulse(0.0, 52, 1.0)
    pulse(0.34, 48, 0.72)
    return out


def gen_switch():
    dur = 0.30
    n = seconds(dur)
    click = [0.0] * n
    for i in range(seconds(0.004)):
        click[i] = random.uniform(-1, 1) * (1 - i / seconds(0.004))
    ring = []
    for i in range(n):
        t = i / RATE
        ring.append(math.sin(2 * math.pi * 2800 * t) * math.exp(-38 * t) * 0.5)
    return mix(click, ring)


def gen_death():
    dur = 2.8
    fall = sine_sweep(210, 27, dur, 0.9, 0.75)
    rumble = gain(lowpass(noise(seconds(dur)), 110), 0.55)
    swell = []
    n = seconds(dur)
    for i in range(n):
        t = i / RATE
        swell.append(math.sin(2 * math.pi * 43 * t) * min(1.0, t / 1.4))
    out = mix(fall, rumble, gain(swell, 0.5))
    cut = seconds(2.45)
    return [out[i] * (1.0 if i < cut else math.exp(-30 * (i - cut) / RATE))
            for i in range(n)]


def gen_enter():
    dur = 1.6
    n = seconds(dur)
    riser = bandpass(noise(n), 180, 1000)
    out = []
    for i in range(n):
        t = i / RATE
        rise = t / dur
        sub = math.sin(2 * math.pi * 38 * t) * rise * 0.7
        out.append(riser[i] * rise * 1.4 + sub)
    return out


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "sounds")
    os.makedirs(outdir, exist_ok=True)

    print("drone.wav")
    write_wav(os.path.join(outdir, "drone.wav"), gen_drone())
    print("buzz.wav")
    write_wav(os.path.join(outdir, "buzz.wav"), gen_buzz())
    for v in range(4):
        name = "footstep%d.wav" % (v + 1)
        print(name)
        write_wav(os.path.join(outdir, name), gen_footstep(v))
    print("sting.wav")
    write_wav(os.path.join(outdir, "sting.wav"), gen_sting())
    print("thud.wav")
    write_wav(os.path.join(outdir, "thud.wav"), gen_thud())
    print("whisper.wav")
    write_wav(os.path.join(outdir, "whisper.wav"), gen_whisper())
    print("heartbeat.wav")
    write_wav(os.path.join(outdir, "heartbeat.wav"), gen_heartbeat())
    print("switch.wav")
    write_wav(os.path.join(outdir, "switch.wav"), gen_switch())
    print("death.wav")
    write_wav(os.path.join(outdir, "death.wav"), gen_death())
    print("enter.wav")
    write_wav(os.path.join(outdir, "enter.wav"), gen_enter())
    print("done ->", outdir)


if __name__ == "__main__":
    main()
