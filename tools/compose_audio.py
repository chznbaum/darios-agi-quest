#!/usr/bin/env python3
"""Rebuild the game's original pre-rendered soundtrack. Python standard library only."""
from __future__ import annotations

import array
import functools
import math
from pathlib import Path
import random
import struct
import wave

RATE = 22050
TAU = math.tau
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
TABLE_SIZE = 4096


def table(partials):
    scale = sum(abs(value) for value in partials)
    return tuple(sum(value * math.sin(TAU * (i / TABLE_SIZE) * (n + 1))
                     for n, value in enumerate(partials)) / scale
                 for i in range(TABLE_SIZE))


TABLES = {
    "flute": table([1, 0.12, 0.17, 0.025, 0.035]),
    "pluck": table([1, 0.4, 0.19, 0.065, 0.032]),
    "bell": table([1, 0.16, 0.36, 0.02, 0.05]),
    "bass": table([1, 0.22, 0.10, 0.035]),
    "pad": table([1, 0.08, 0.09]),
    "brass": table([1, 0.36, 0.17, 0.08, 0.035, 0.015]),
}


@functools.lru_cache(maxsize=2048)
def tone(midi, duration, instrument):
    """Band-limited harmonic instruments with independent attack and release."""
    frequency = 440 * 2 ** ((midi - 69) / 12)
    release = {"flute": 0.085, "pluck": 0.11, "bell": 0.24,
               "bass": 0.075, "pad": 0.20, "brass": 0.065}[instrument]
    attack = {"flute": 0.018, "pluck": 0.003, "bell": 0.004,
              "bass": 0.005, "pad": 0.11, "brass": 0.009}[instrument]
    length = int((duration + release) * RATE)
    samples = array.array("f", [0.0]) * length
    wavetable = TABLES[instrument]
    vibrato = instrument in ("flute", "pad")
    phase = 0.0
    step = frequency * TABLE_SIZE / RATE
    for i in range(length):
        t = i / RATE
        envelope = min(1.0, t / attack)
        if instrument in ("pluck", "bell"):
            envelope *= math.exp(-t * (5.5 if instrument == "pluck" else 3.1))
        elif instrument in ("bass", "brass"):
            envelope *= 0.66 + 0.34 * math.exp(-t * 12)
        if t > duration:
            envelope *= max(0, (duration + release - t) / release) ** 2
        phase += step * (1.0 + (0.0025 * math.sin(TAU * 5.2 * t) if vibrato else 0))
        samples[i] = wavetable[int(phase) % TABLE_SIZE] * envelope
    return samples


@functools.lru_cache(maxsize=32)
def drum(kind, variant=0):
    rng = random.Random(19041 + variant)
    duration = {"kick": 0.19, "snare": 0.13, "hat": 0.055, "brush": 0.075}[kind]
    samples = array.array("f", [0.0]) * int(duration * RATE)
    last = 0.0
    phase = 0.0
    for i in range(len(samples)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        if kind == "kick":
            phase += TAU * (48 + 82 * math.exp(-t * 45)) / RATE
            value = math.sin(phase) * math.exp(-t * 23)
        elif kind == "snare":
            value = (0.58 * noise + 0.30 * math.sin(TAU * 175 * t)) * math.exp(-t * 29)
        else:
            highpass = noise - last
            last = noise
            value = highpass * 0.5 * math.exp(-t * (83 if kind == "hat" else 52))
        samples[i] = value * min(1.0, t / 0.002) * min(1.0, (duration - t) / 0.008)
    return samples


class Mix:
    def __init__(self, seconds, loop=False):
        self.length = round(seconds * RATE)
        self.left = array.array("f", [0.0]) * self.length
        self.right = array.array("f", [0.0]) * self.length
        self.loop = loop

    def add(self, samples, seconds, gain, pan=0.0):
        start = round(seconds * RATE)
        left_gain = math.sqrt((1 - pan) / 2) * gain
        right_gain = math.sqrt((1 + pan) / 2) * gain
        for i, sample in enumerate(samples):
            position = start + i
            if self.loop:
                position %= self.length
            elif position >= self.length:
                break
            self.left[position] += sample * left_gain
            self.right[position] += sample * right_gain

    def note(self, midi, beat, duration, gain, instrument, pan, beat_seconds):
        self.add(tone(midi, round(duration * beat_seconds, 6), instrument),
                 beat * beat_seconds, gain, pan)

    def ambience(self, beat_seconds):
        # A quiet stereo echo with circular indexing preserves the loop's reverb tail.
        left = self.left[:]
        right = self.right[:]
        for delay, gain in [(0.375 * beat_seconds, 0.13), (0.75 * beat_seconds, 0.075), (0.071, 0.055)]:
            offset = round(delay * RATE)
            for i in range(self.length):
                j = i - offset
                if self.loop or j >= 0:
                    self.left[i] += right[j] * gain
                    self.right[i] += left[j] * gain

    def write(self, name, peak=0.78):
        maximum = max(max(map(abs, self.left)), max(map(abs, self.right)), 0.001)
        gain = peak / maximum
        pcm = array.array("h")
        for left, right in zip(self.left, self.right):
            pcm.append(round(max(-1, min(1, left * gain)) * 32767))
            pcm.append(round(max(-1, min(1, right * gain)) * 32767))
        import sys
        if sys.byteorder != "little":
            pcm.byteswap()
        OUT.mkdir(parents=True, exist_ok=True)
        with wave.open(str(OUT / f"{name}.wav"), "wb") as output:
            output.setnchannels(2)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(pcm.tobytes())


# Original eight-eighth-note bar phrases, (onset, pitch, duration); MIDI 62 = D4.
MELODY = [
    [(0, 74, 1), (1, 78, 1), (2, 81, 2), (4, 83, 1), (5, 81, 1), (6, 78, 1.5)],
    [(0, 79, 1), (1, 78, 1), (2, 76, 1), (3, 74, 1), (4, 71, 2), (7, 74, 0.7)],
    [(0, 78, 2), (2, 81, 1), (3, 83, 1), (4, 85, 1.5), (6, 83, 1.5)],
    [(0, 81, 1), (1, 78, 1), (2, 76, 2), (5, 73, 1), (6, 76, 1.5)],
    [(0, 74, 1), (1, 78, 1), (2, 81, 2), (4, 86, 1), (5, 85, 1), (6, 83, 1.5)],
    [(0, 83, 1), (1, 81, 1), (2, 79, 1), (3, 78, 1), (4, 76, 2), (6, 79, 1.5)],
    [(0, 78, 1), (1, 79, 1), (2, 81, 1.5), (4, 79, 1), (5, 78, 1), (6, 76, 1)],
    [(0, 73, 1), (1, 76, 1), (2, 81, 2), (4, 78, 1), (5, 76, 1), (6, 73, 1.5)],
    [(0, 83, 2), (2, 81, 1), (3, 78, 1), (4, 78, 1), (5, 76, 1), (6, 74, 1.5)],
    [(0, 79, 2), (2, 78, 1), (3, 74, 1), (4, 71, 1), (5, 74, 1), (6, 79, 1.5)],
    [(0, 81, 1), (1, 83, 1), (2, 86, 2), (4, 85, 1), (5, 83, 1), (6, 81, 1.5)],
    [(0, 80, 1), (1, 81, 1), (2, 85, 2), (4, 83, 1), (5, 81, 1), (6, 76, 1.5)],
    [(0, 79, 1), (1, 81, 1), (2, 83, 2), (4, 86, 2), (6, 83, 1.5)],
    [(0, 81, 1), (1, 79, 1), (2, 78, 1), (3, 76, 1), (4, 74, 2), (6, 71, 1.5)],
    [(0, 76, 1), (1, 78, 1), (2, 81, 2), (4, 83, 1), (5, 81, 1), (6, 78, 1.5)],
    [(0, 76, 2), (2, 73, 1), (3, 76, 1), (4, 81, 2), (6, 73, 1), (7, 76, 0.7)],
]
CHORDS = [
    (50, [62, 66, 69]), (43, [62, 67, 71]), (47, [62, 66, 71]), (45, [61, 64, 69]),
    (50, [62, 66, 69]), (40, [64, 67, 71]), (43, [62, 67, 71]), (45, [61, 64, 69]),
    (47, [62, 66, 71]), (43, [62, 67, 71]), (50, [62, 66, 69]), (45, [61, 64, 69]),
    (43, [62, 67, 71]), (40, [64, 67, 71]), (45, [62, 64, 69]), (45, [61, 64, 69]),
]


def compose_field(name, bpm, title=False):
    beat_seconds = 60 / bpm
    mix = Mix(64 * beat_seconds, loop=True)
    for bar, (root, chord) in enumerate(CHORDS):
        start = bar * 4
        for onset, pitch, duration in MELODY[bar]:
            if title and onset in (1, 3, 5, 7):
                continue
            mix.note(pitch, start + onset / 2, duration / 2 * (1.22 if title else 0.86),
                     0.27 if title else 0.30, "flute", -0.13, beat_seconds)
            if bar >= 8 and onset in (0, 4):
                mix.note(pitch - 12, start + onset / 2, duration / 2 * 0.8,
                         0.045, "bell", 0.30, beat_seconds)
        for eighth in range(8):
            pitch = chord[[0, 2, 1, 2, 0, 1, 2, 1][eighth]] + (12 if title else 0)
            mix.note(pitch, start + eighth / 2, 0.27, 0.11 if title else 0.085,
                     "bell" if title else "pluck", 0.38 if eighth % 2 else -0.32, beat_seconds)
        for pulse, pitch in [(0, root), (1.5, root + 12), (2, root + 7), (3.5, root + 12)]:
            mix.note(pitch, start + pulse, 0.41 if pulse % 1 else 0.72,
                     0.22 if title else 0.27, "bass", 0.0, beat_seconds)
        for note in chord:
            if title:
                mix.note(note, start, 3.65, 0.028, "pad", -0.20, beat_seconds)
            else:
                for pulse in (0.5, 1.5, 2.5, 3.5):
                    mix.note(note, start + pulse, 0.14, 0.065, "pluck", -0.30, beat_seconds)
        for pulse in range(4):
            if pulse % 2 == 0:
                mix.add(drum("kick"), (start + pulse) * beat_seconds, 0.19 if title else 0.27)
            else:
                mix.add(drum("brush" if title else "snare", bar % 2),
                        (start + pulse) * beat_seconds, 0.065 if title else 0.12, 0.18)
        for eighth in range(8):
            mix.add(drum("hat", eighth % 2), (start + eighth / 2) * beat_seconds,
                    (0.018 if title else 0.035) * (1 if eighth % 2 else 0.75), 0.32)
    mix.ambience(beat_seconds)
    mix.write(name)


def compose_boss():
    beat_seconds = 60 / 136
    mix = Mix(64 * beat_seconds, loop=True)
    chords = [(38, [62, 65, 69]), (46, [62, 65, 70]), (43, [62, 67, 70]), (45, [61, 64, 69])]
    phrases = [
        [74, 77, 81, 77, 74, 72, 69, 72],
        [74, 77, 82, 81, 77, 74, 77, 81],
        [79, 77, 74, 70, 74, 77, 79, 82],
        [81, 79, 76, 73, 76, 81, 73, 76],
    ]
    for bar in range(16):
        root, chord = chords[bar % 4]
        start = bar * 4
        for eighth in range(8):
            mix.note(root + (12 if eighth % 4 in (1, 3) else 0), start + eighth / 2,
                     0.33, 0.28, "bass", 0, beat_seconds)
            mix.note(chord[eighth % 3] + 12, start + eighth / 2,
                     0.17, 0.075, "pluck", -0.35, beat_seconds)
            if bar % 8 < 4:
                pitch = phrases[bar % 4][eighth]
                duration = 0.33
            else:
                pitch = phrases[bar % 4][7 - eighth] + (12 if eighth == 0 else 0)
                duration = 0.42
            mix.note(pitch, start + eighth / 2, duration, 0.22,
                     "brass", 0.10, beat_seconds)
            mix.add(drum("hat", eighth % 2), (start + eighth / 2) * beat_seconds,
                    0.042 if eighth % 2 else 0.027, 0.35)
        for pulse in (0, 1.5, 2, 3.5):
            mix.add(drum("kick"), (start + pulse) * beat_seconds, 0.30)
        for pulse in (1, 3):
            mix.add(drum("snare", bar % 2), (start + pulse) * beat_seconds, 0.15, -0.15)
        if bar % 4 == 3:
            for sixteenth in (6.5, 7, 7.5):
                mix.add(drum("snare", 1), (start + sixteenth / 2) * beat_seconds, 0.07, -0.15)
        for note in chord:
            mix.note(note, start, 3.8, 0.037, "pad", 0.35, beat_seconds)
    mix.ambience(beat_seconds)
    mix.write("boss")


def glide(start_frequency, end_frequency, duration, kind="flute"):
    samples = array.array("f", [0.0]) * round(duration * RATE)
    wavetable = TABLES[kind]
    phase = 0.0
    for i in range(len(samples)):
        t = i / len(samples)
        frequency = start_frequency * (end_frequency / start_frequency) ** t
        phase += frequency * TABLE_SIZE / RATE
        envelope = min(1, t / 0.045) * (1 - t) ** 0.8
        samples[i] = wavetable[int(phase) % TABLE_SIZE] * envelope
    return samples


def effects():
    mix = Mix(0.25)
    mix.add(glide(310, 890, 0.21), 0, 0.8)
    mix.write("jump", 0.66)
    mix = Mix(0.40)
    mix.add(tone(88, 0.07, "bell"), 0, 0.55, -0.12)
    mix.add(tone(95, 0.07, "bell"), 0.075, 0.7, 0.12)
    mix.write("token", 0.62)
    mix = Mix(0.25)
    mix.add(glide(270, 78, 0.16, "bass"), 0, 0.9)
    mix.add(drum("snare"), 0.005, 0.21)
    mix.write("stomp", 0.70)
    mix = Mix(0.46)
    mix.add(glide(420, 110, 0.32, "brass"), 0, 0.7, -0.1)
    mix.add(glide(445, 103, 0.32, "brass"), 0.018, 0.35, 0.1)
    mix.write("hurt", 0.66)
    mix = Mix(1.15)
    for i, note in enumerate([62, 66, 69, 74, 78, 81, 86]):
        mix.add(tone(note, 0.13, "bell"), i * 0.105, 0.7, (i % 2 - 0.5) * 0.4)
    mix.write("powerup", 0.69)
    mix = Mix(1.0)
    for i, chord in enumerate([[62, 66, 69], [67, 71, 74], [69, 74, 78]]):
        for note in chord:
            mix.add(tone(note, 0.16, "bell"), i * 0.20, 0.38)
    mix.write("checkpoint", 0.64)
    mix = Mix(0.25)
    mix.add(tone(81, 0.035, "pluck"), 0, 0.45, -0.1)
    mix.add(tone(86, 0.055, "pluck"), 0.06, 0.65, 0.1)
    mix.write("select", 0.58)
    mix = Mix(1.3)
    for i, note in enumerate([74, 71, 67, 62, 59]):
        mix.add(tone(note, 0.15, "flute"), i * 0.17, 0.6)
    mix.write("death", 0.64)
    mix = Mix(0.72)
    for i, note in enumerate([86, 90, 93, 98]):
        mix.add(tone(note, 0.09, "bell"), i * 0.075, 0.6, (i % 2 - 0.5) * 0.6)
    mix.write("shield", 0.63)
    mix = Mix(0.75)
    for i, note in enumerate([62, 65, 69]):
        mix.add(tone(note, 0.12, "brass"), i * 0.20, 0.65)
    mix.write("boss_warn", 0.65)
    mix = Mix(0.48)
    mix.add(glide(170, 38, 0.29, "bass"), 0, 0.75)
    mix.add(drum("snare"), 0, 0.23)
    mix.add(drum("kick"), 0.03, 0.7)
    mix.write("boss_land", 0.74)
    mix = Mix(0.38)
    mix.add(glide(750, 165, 0.24, "brass"), 0, 0.7)
    mix.add(drum("snare"), 0.018, 0.19)
    mix.write("boss_hit", 0.70)
    mix = Mix(1.50)
    mix.add(glide(620, 58, 0.6, "brass"), 0, 0.65)
    for i, note in enumerate([74, 78, 81, 86]):
        mix.add(tone(note, 0.18, "bell"), 0.50 + i * 0.12, 0.40)
    mix.write("boss_defeat", 0.73)
    mix = Mix(5.4)
    beat_seconds = 60 / 126
    melody = [(0, 74, 0.25), (0.3, 74, 0.25), (0.6, 74, 0.25), (1, 81, 1),
              (2.1, 78, 0.7), (3, 79, 0.35), (3.5, 81, 0.35), (4, 86, 3)]
    for beat, note, duration in melody:
        mix.note(note, beat, duration, 0.3, "brass", 0, beat_seconds)
    for start, chord in [(0, [50, 62, 66, 69]), (2, [43, 62, 67, 71]),
                         (3, [45, 61, 64, 69]), (4, [38, 62, 66, 69, 74])]:
        for note in chord:
            mix.note(note, start, 2.8 if start == 4 else 0.7, 0.15, "bell", 0, beat_seconds)
        mix.add(drum("snare"), start * beat_seconds, 0.08)
    mix.ambience(beat_seconds)
    mix.write("victory")


def verify():
    print("Asset          Duration   Peak     RMS     End/start step")
    for path in sorted(OUT.glob("*.wav")):
        with wave.open(str(path), "rb") as source:
            channels, width, rate, frames, _, _ = source.getparams()
            assert channels == 2 and width == 2 and rate == RATE
            pcm = struct.unpack(f"<{frames * channels}h", source.readframes(frames))
        peak = max(map(abs, pcm)) / 32768
        rms = math.sqrt(sum((value / 32768) ** 2 for value in pcm) / len(pcm))
        step = max(abs(pcm[0] - pcm[-2]), abs(pcm[1] - pcm[-1])) / 32768
        assert 0.05 < peak < 0.85, (path.name, peak)
        assert 0.015 < rms < 0.35, (path.name, rms)
        if path.stem in ("title", "meadow", "boss"):
            assert step < 0.05, (path.name, "loop discontinuity", step)
        print(f"{path.name:14} {frames / rate:7.3f}s  {peak:6.3f}  {rms:6.3f}   {step:7.4f}")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="Inspect existing WAV files without rebuilding.")
    args = parser.parse_args()
    if not args.verify:
        compose_field("title", 100, title=True)
        compose_field("meadow", 116)
        compose_boss()
        effects()
    verify()
