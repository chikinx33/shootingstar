"""v12.3 guardian-cat score and feedback library. No samples or paid APIs.

Python + numpy, deterministic synthesis. Cat voices are additive harmonic
sources shaped by moving vowel formants (m-i-a-o), purrs are pulsed low noise,
chicks are short sine chirps. Instruments are music box / pizzicato / kalimba /
soft chip lead / brush kit. Music loops are mixed circularly (note tails, echo
and room reverb cross the loop boundary) so the seam is inaudible.

WAV masters go to .local/audio-v12.3/wav/ (outside the bundle); the game
ships Ogg Vorbis made from them by tools/wav_to_ogg.py.
Run `PYTHONPATH=D:/Programs/pylib python tools/compose_audio.py` then
`PYTHONPATH=D:/Programs/pylib python tools/audio_mix_catalog.py`.
"""
import json
import math
from pathlib import Path
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/audio'
MASTERS = ROOT / '.local/audio-v12.3/wav'
RATE = 24000
NYQ = RATE / 2
rng = np.random.default_rng(12_300)
report = {}


# ---------------------------------------------------------------- basics
def hz(note):
    return 440 * 2 ** ((note - 69) / 12)


NAMES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def midi(name):
    """'C#5' / 'Bb4' -> MIDI number."""
    pitch = NAMES[name[0]]
    rest = name[1:]
    while rest and rest[0] in '#b':
        pitch += 1 if rest[0] == '#' else -1
        rest = rest[1:]
    return pitch + 12 * (int(rest) + 1)


def axis(duration):
    return np.arange(max(1, int(duration * RATE))) / RATE


def curve(points, n):
    xs, ys = zip(*points)
    return np.interp(np.linspace(0, 1, n), xs, ys)


def fade(x, a=.003, r=.012):
    """Zero-start / zero-end envelope that never clicks."""
    n = len(x)
    env = np.ones(n)
    ai, ri = max(1, int(a * RATE)), max(1, int(r * RATE))
    env[:ai] = np.linspace(0, 1, ai) if ai < n else env[:ai]
    env[-ri:] *= np.linspace(1, 0, min(ri, n))
    return x * env


def spectral(x, lo=None, hi=None, order=2, pad=True):
    """Zero-phase Butterworth-shaped filter. Padded for one-shot clips."""
    x = np.asarray(x, dtype=float)
    p = int(.06 * RATE) if pad else 0
    y = np.pad(x, (p, p)) if p else x
    f = np.fft.rfftfreq(len(y), 1 / RATE)
    m = np.ones_like(f)
    if hi:
        m /= np.sqrt(1 + (f / hi) ** (2 * order))
    if lo:
        m /= np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** (2 * order))
    y = np.fft.irfft(np.fft.rfft(y) * m, len(y))
    return y[p:len(y) - p] if p else y


def noise(duration, lo=None, hi=None, order=2):
    return spectral(rng.normal(0, 1, len(axis(duration))), lo, hi, order)


def at(parts, length=None):
    """Mix (offset_seconds, signal, gain) parts into one clip."""
    end = max(int(o * RATE) + len(s) for o, s, _ in parts)
    out = np.zeros(max(end, int((length or 0) * RATE)))
    for o, s, g in parts:
        i = int(o * RATE)
        out[i:i + len(s)] += s * g
    return out


# ---------------------------------------------------------------- voices
# (frequency, bandwidth) of the first three formants per vowel.
VOWELS = {
    'm': ((320, 90), (1250, 260), (2600, 420)),
    'i': ((420, 110), (2350, 300), (3300, 420)),
    'e': ((620, 120), (2050, 300), (2950, 420)),
    'a': ((980, 160), (1620, 280), (2850, 440)),
    'o': ((560, 110), (980, 160), (2650, 380)),
    'u': ((390, 90), (820, 140), (2500, 400)),
}


def cat(duration, pitch, vowels, loud=None, breath=.02, rough=0.0,
        rough_rate=27, vibrato=.012, bright=1.0):
    """Synthetic cat vocalisation: harmonic source + moving vowel formants."""
    t = axis(duration)
    n = len(t)
    f0 = curve(pitch, n)
    f0 = f0 * (1 + vibrato * np.sin(2 * math.pi * 6.3 * t + rng.uniform(0, 6)))
    f0 *= 1 + .004 * spectral(rng.normal(0, 1, n), hi=30, pad=False)
    phase = 2 * math.pi * np.cumsum(f0) / RATE
    us = [u for u, _ in vowels]
    formants = []
    for k in range(3):
        freq = np.interp(np.linspace(0, 1, n), us, [VOWELS[v][k][0] for _, v in vowels])
        band = np.interp(np.linspace(0, 1, n), us, [VOWELS[v][k][1] for _, v in vowels])
        formants.append((freq, band, (1, .95 * bright, .55 * bright)[k]))
    nasal = np.interp(np.linspace(0, 1, n), us, [.35 if v == 'm' else 1 for _, v in vowels])
    out = np.zeros(n)
    for k in range(1, int(11000 / f0.min()) + 1):
        fk = k * f0
        amp = sum(g / (1 + ((fk - f) / b) ** 2) for f, b, g in formants)
        amp = amp * k ** -.2 * np.clip((11200 - fk) / 600, 0, 1)
        out += amp * np.sin(k * phase)
    out *= nasal
    if rough:
        out *= 1 - rough * (.5 + .5 * np.sin(2 * math.pi * rough_rate * t)) ** 2
    out += breath * noise(duration, 1800, 7000) * (.4 + .6 * nasal)
    env = curve(loud or [(0, 0), (.08, 1), (.75, .85), (1, 0)], n)
    return fade(out * env / max(np.max(np.abs(out)), 1e-6), .004, .02)


def mew(base=800, duration=.2, up=1.25):
    return cat(duration, [(0, base), (.35, base * up), (1, base * .82)],
               [(0, 'm'), (.25, 'i'), (.7, 'e'), (1, 'u')])


def nya(base=640, duration=.24):
    return cat(duration, [(0, base * .9), (.3, base * 1.3), (1, base * 1.1)],
               [(0, 'i'), (.25, 'a'), (1, 'a')], [(0, 0), (.05, 1), (.6, .9), (1, 0)],
               bright=1.1)


def meow(base=520, duration=.55, rise=1.4, end=.9):
    return cat(duration, [(0, base), (.3, base * rise), (.65, base * rise * .95), (1, base * end)],
               [(0, 'm'), (.14, 'i'), (.42, 'a'), (.85, 'o'), (1, 'u')])


def trill(base=520, duration=.22):
    return cat(duration, [(0, base), (1, base * 1.35)], [(0, 'm'), (.5, 'e'), (1, 'i')],
               rough=.75, breath=.015)


def grumble(base=260, duration=.34):
    return cat(duration, [(0, base), (.5, base * 1.08), (1, base * .9)],
               [(0, 'm'), (.3, 'o'), (1, 'u')], rough=.7, rough_rate=24, bright=.7)


def yelp(base=900, duration=.16):
    return cat(duration, [(0, base), (.25, base * 1.35), (1, base * .7)],
               [(0, 'i'), (.3, 'a'), (1, 'o')], [(0, 0), (.04, 1), (.5, .8), (1, 0)],
               breath=.04, bright=1.15)


def hiss(duration=.4):
    t = axis(duration)
    return fade(noise(duration, 2800, 9000) * np.minimum(t / .03, 1) * np.exp(-t * 3), .004, .05)


def purr(duration=.6, rate=26):
    t = axis(duration)
    body = noise(duration, 45, 320) * 2.2 + .5 * np.sin(2 * math.pi * 52 * t)
    pulse = (.55 + .45 * np.sin(2 * math.pi * rate * t)) ** 3
    return fade(body * pulse * np.minimum(t / .06, 1), .01, .08)


def chirp(duration, start, end, harmonics=(1, .22, .06)):
    t = axis(duration)
    f = curve([(0, start), (.25, start * 1.04), (1, end)], len(t))
    phase = 2 * math.pi * np.cumsum(f) / RATE
    s = sum(a * np.sin((k + 1) * phase) for k, a in enumerate(harmonics) if f.max() * (k + 1) < NYQ)
    return fade(s * np.minimum(t / .004, 1) * np.exp(-t * 18))


def piyo(scale=1.0):
    return at([(0, chirp(.07, 3900 * scale, 3000 * scale), 1),
               (.085, chirp(.1, 3500 * scale, 2500 * scale), .8)])


# ---------------------------------------------------------------- instruments
def partials(note, duration, ratios, amps, decays, attack=.002):
    t = axis(duration)
    f = hz(note)
    s = sum(a * np.sin(2 * math.pi * f * r * t) * np.exp(-t * d)
            for r, a, d in zip(ratios, amps, decays) if f * r < NYQ - 400)
    return fade(s * np.minimum(t / attack, 1), attack, .03)


def musicbox(note, duration=.9):
    return partials(note, duration, [1, 2, 3.01, 5.43, 8.9],
                    [1, .32, .16, .1, .04], [3.2, 4.5, 7, 11, 18], .0015)


def bell(note, duration=1.2):
    return partials(note, duration, [1, 2.76, 5.4, 8.93, 13.3],
                    [1, .45, .25, .12, .06], [2.4, 3.6, 6, 9, 14])


def kalimba(note, duration=.7):
    return partials(note, duration, [1, 3.05, 6.1], [1, .2, .06], [4.2, 10, 20], .002)


def marimba(note, duration=.5):
    return partials(note, duration, [1, 3.93, 9.8], [1, .22, .05], [6, 15, 30], .0015)


def pluck(note, duration=.5, bright=1.0, damp=3.5):
    """Additive pizzicato: upper partials die faster, exact pitch."""
    t = axis(duration)
    f = hz(note)
    s = np.zeros(len(t))
    for k in range(1, 24):
        if f * k > NYQ - 500:
            break
        s += (k ** -1.15) * np.sin(2 * math.pi * f * k * t + k * .7) * np.exp(-t * (damp + .9 * k ** 1.5 / bright))
    return fade(s * np.minimum(t / .0015, 1), .0015, .025)


def chip(note, duration, duty=.25, sustain=.75, vib=.01, soft=5200):
    """Band-limited pulse lead, gently low-passed (cute rather than harsh)."""
    t = axis(duration)
    f = hz(note) * (1 + vib * np.minimum(t / .18, 1) * np.sin(2 * math.pi * 5.8 * t))
    phase = 2 * math.pi * np.cumsum(f) / RATE
    s = np.zeros(len(t))
    base = hz(note)
    for k in range(1, 40):
        if base * k > NYQ - 600:
            break
        s += math.sin(math.pi * k * duty) / k / (1 + (base * k / soft) ** 2) * np.sin(k * phase)
    env = np.minimum(t / .006, 1) * (sustain + (1 - sustain) * np.exp(-t * 12))
    return fade(s * env, .003, .03)


def bass(note, duration):
    t = axis(duration)
    f = hz(note)
    s = np.sin(2 * math.pi * f * t) + .35 * np.sin(4 * math.pi * f * t) * np.exp(-t * 9)
    s += .12 * np.sin(6 * math.pi * f * t) * np.exp(-t * 14)
    return fade(s * np.minimum(t / .004, 1) * np.exp(-t * 2.2), .004, .03)


def pad(notes, duration):
    t = axis(duration)
    s = np.zeros(len(t))
    for n in notes:
        for d in (-.006, .006):
            f = hz(n) * (1 + d)
            s += np.sin(2 * math.pi * f * t) + .3 * np.sin(4 * math.pi * f * t) + .1 * np.sin(6 * math.pi * f * t)
    env = np.minimum(t / (duration * .3), 1) * np.minimum((duration - t) / (duration * .3), 1)
    return s * env / (2 * len(notes))


def drum(kind):
    if kind == 'kick':
        t = axis(.28)
        phase = 2 * math.pi * np.cumsum(48 + 110 * np.exp(-t / .03)) / RATE
        return fade(np.sin(phase) * np.exp(-t * 13) + .06 * noise(.28, 1000, 5000) * np.exp(-t * 80), .001)
    if kind == 'soft-kick':
        t = axis(.24)
        phase = 2 * math.pi * np.cumsum(55 + 70 * np.exp(-t / .025)) / RATE
        return fade(np.sin(phase) * np.exp(-t * 16), .001)
    if kind == 'brush':
        t = axis(.22)
        return fade(noise(.22, 700, 6500) * np.minimum(t / .006, 1) * np.exp(-t * 16), .002)
    if kind == 'snare':
        t = axis(.2)
        return fade((noise(.2, 900, 8000) * .9 + .5 * np.sin(2 * math.pi * 196 * t)) * np.exp(-t * 22), .001)
    if kind == 'clap':
        t = axis(.2)
        env = sum(np.exp(-np.maximum(t - d, 0) * 90) * (t >= d) for d in (0, .009, .019))
        return fade(noise(.2, 900, 4200) * (env + .6 * np.exp(-t * 18) * (t > .02)), .001)
    if kind == 'hat':
        t = axis(.06)
        return fade(noise(.06, 6500) * np.exp(-t * 70), .001)
    if kind == 'shaker':
        t = axis(.09)
        return fade(noise(.09, 4500, 11000) * np.minimum(t / .018, 1) * np.exp(-t * 40), .002)
    if kind == 'tom':
        t = axis(.3)
        phase = 2 * math.pi * np.cumsum(115 + 80 * np.exp(-t / .04)) / RATE
        return fade(np.sin(phase) * np.exp(-t * 10) + .15 * noise(.3, 200, 2000) * np.exp(-t * 40), .001)
    if kind == 'taiko':
        t = axis(.5)
        phase = 2 * math.pi * np.cumsum(62 + 45 * np.exp(-t / .05)) / RATE
        return fade(np.sin(phase) * np.exp(-t * 7) + .25 * noise(.5, 60, 900) * np.exp(-t * 18), .001)
    if kind == 'crash':
        t = axis(1.4)
        return fade(noise(1.4, 3200) * np.exp(-t * 2.6) * .7, .002, .2)
    if kind == 'block':
        return partials(81, .12, [1, 2.71], [1, .4], [45, 70], .0008)
    raise KeyError(kind)


DRUMS = {}


def kit(kind):
    """Three cached variations per drum so repeated hits do not machine-gun."""
    if kind not in DRUMS:
        DRUMS[kind] = [drum(kind) for _ in range(3)]
    return DRUMS[kind][int(rng.integers(0, 3))]


# ---------------------------------------------------------------- writer
def write(name, data, music=False, **meta):
    data = np.asarray(data, dtype=float)
    data = data - (np.mean(data, axis=0) if not music else 0)
    peak = float(np.max(np.abs(data)))
    data *= (.72 if music else .64) / max(peak, 1e-6)
    if not music:
        # Drop the inaudible room tail (< -42 dB) so alert-voice protection
        # and music ducking follow what is actually heard.
        loud = np.nonzero(np.abs(data) > .008 * .64)[0]
        data = fade(data[:loud[-1] + int(.02 * RATE)], .002, .02)
    pcm = np.round(data * 32767).astype('<i2')
    with wave.open(str(MASTERS / f'{name}.wav'), 'wb') as f:
        f.setnchannels(2 if data.ndim == 2 else 1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm.tobytes())
    report[name] = dict(seconds=len(data) / RATE, peak=float(np.max(np.abs(data))),
                        rms=float(np.sqrt(np.mean(data * data))),
                        seam=float(np.max(np.abs(data[0] - data[-1]))), **meta)


def room(signal, decay=.35, wet=.12, tail=.5):
    """Small non-circular room for one-shots (adds a short cozy tail)."""
    ir_t = axis(tail)
    ir = rng.normal(0, 1, len(ir_t)) * np.exp(-ir_t / decay * 3)
    ir = spectral(ir, 200, 5000, pad=False)
    ir /= np.sqrt(np.sum(ir * ir))
    padded = np.concatenate([signal, np.zeros(len(ir))])
    n = len(padded)
    wet_sig = np.fft.irfft(np.fft.rfft(padded) * np.fft.rfft(ir, n), n)
    return padded + wet * wet_sig


# ---------------------------------------------------------------- score
class Song:
    def __init__(self, bpm, bars, swing=0.0):
        self.beat = 60 / bpm
        self.bars = bars
        self.swing = swing
        self.length = int(round(bars * 4 * self.beat * RATE))
        self.mix = np.zeros((self.length, 2))
        self.send = np.zeros((self.length, 2))

    def place(self, beat):
        frac = beat % 1
        if self.swing and abs(frac - .5) < 1e-6:
            beat += self.swing
        return int(round(beat * self.beat * RATE))

    def add(self, sound, beat, gain, pan=0.0, echo=0.0, verb=.25):
        ids = (np.arange(len(sound)) + self.place(beat)) % self.length
        for ch, scale in enumerate([math.sqrt((1 - pan) / 2), math.sqrt((1 + pan) / 2)]):
            np.add.at(self.mix[:, ch], ids, sound * gain * scale)
            np.add.at(self.send[:, ch], ids, sound * gain * scale * verb)
        if echo:
            d = int(self.beat * .75 * RATE)
            np.add.at(self.mix[:, 0], (ids + d) % self.length, sound * gain * echo * .8)
            np.add.at(self.mix[:, 1], (ids + d + int(.013 * RATE)) % self.length, sound * gain * echo)

    def line(self, start_bar, text, voice, gain, pan=0.0, echo=0.0, verb=.3):
        """'A5:.5 C6:1 r:.5' sequence of notes starting at a bar."""
        beat = start_bar * 4
        for token in text.split():
            name, length = token.split(':')
            length = float(length)
            if name != 'r':
                self.add(voice(midi(name), length * self.beat), beat, gain, pan, echo, verb)
            beat += length

    def finish(self, decay, wet, drive=1.4):
        # Circular stereo room: tails wrap into the loop start.
        t = axis(decay * 2.2)
        out = self.mix.copy()
        for ch in range(2):
            ir = rng.normal(0, 1, len(t)) * np.exp(-t / decay * 3)
            ir = spectral(ir, 180, 6000, pad=False)
            ir /= np.sqrt(np.sum(ir * ir))
            irf = np.zeros(self.length)
            irf[:len(ir)] = ir
            out[:, ch] += wet * np.fft.irfft(np.fft.rfft(self.send[:, ch]) * np.fft.rfft(irf), self.length)
        out /= np.max(np.abs(out))
        return np.tanh(out * drive) / math.tanh(drive)


def lobby():
    """'집사네 거실' — cozy F major, music box + pizzicato + brushes + kittens."""
    s = Song(100, 16, swing=.06)
    chords = [  # one entry per bar: list of (beat_in_bar, MIDI chord tones)
        'F3 A3 C4 E4', 'D3 F3 A3 C4', 'G3 Bb3 D4 F4', 'C3 E3 G3 Bb3',
        'F3 A3 C4 E4', 'D3 F3 A3 C4', 'G3 Bb3 D4 F4|C3 E3 G3 Bb3', 'F3 A3 C4 F4',
        'Bb2 D3 F3 A3', 'A2 C3 E3 G3', 'G2 Bb2 D3 F3', 'C3 E3 G3 Bb3',
        'Bb2 D3 F3 A3', 'A2 C#3 E3 G3', 'D3 F3 A3 C4|G2 B2 D3 F3', 'G2 Bb2 D3 F3|C3 E3 G3 Bb3',
    ]
    for bar, text in enumerate(chords):
        halves = [[midi(n) for n in part.split()] for part in text.split('|')]
        for q in range(8):  # eighth notes
            chord = halves[0] if len(halves) == 1 or q < 4 else halves[1]
            beat = bar * 4 + q * .5
            # Pizzicato arpeggio: root-fifth-tenth-fifth pattern.
            note = chord[[0, 2, 3, 2, 1, 2, 3, 2][q]] + 12
            s.add(pluck(note, .5, .8), beat, .17 if q % 2 else .21, -.35, verb=.35)
            if q % 4 == 0:
                s.add(bass(chord[0] - 12, s.beat * 1.6), beat, .42, 0, verb=.08)
            if q in (3, 7):
                s.add(bass(chord[2] - 12, s.beat * .45), beat + .5, .2, 0, verb=.08)
            if q in (2, 6):  # off-beat kalimba chord stab
                for n in chord[1:]:
                    s.add(kalimba(n + 12, .6), beat, .07, .4, verb=.4)
        for q in range(4):
            beat = bar * 4 + q
            s.add(kit('soft-kick'), beat, .55 if q in (0, 2) else 0, verb=.02)
            if q in (1, 3):
                s.add(kit('brush'), beat, .22, .1, verb=.3)
            for h in (0, .5):
                s.add(kit('shaker'), beat + h, .07 if h else .045, .3, verb=.1)
        if bar % 4 == 3:
            s.add(drum('block'), bar * 4 + 3.5, .12, -.4)
    melody = [
        'A4:.5 C5:.5 F5:1 E5:.5 F5:.5 G5:1',
        'A5:1.5 G5:.5 F5:1 D5:1',
        'Bb4:.5 D5:.5 G5:1 F5:.5 G5:.5 A5:1',
        'G5:1.5 E5:.5 C5:1 r:1',
        'A4:.5 C5:.5 F5:1 E5:.5 F5:.5 A5:1',
        'C6:1.5 A5:.5 F5:1 D5:1',
        'Bb5:1 A5:.5 G5:.5 E5:1 G5:1',
        'F5:2 r:2',
        'D6:1 C6:.5 Bb5:.5 A5:1 F5:1',
        'C6:1 Bb5:.5 A5:.5 G5:1 E5:1',
        'Bb5:1 A5:.5 G5:.5 F5:1 D5:1',
        'E5:.5 F5:.5 G5:1 C6:2',
        'D6:1 C6:.5 Bb5:.5 A5:1 F5:1',
        'C#6:1 E6:.5 C#6:.5 A5:2',
        'D6:1 A5:1 B5:1 G5:1',
        'Bb5:.5 A5:.5 G5:.5 F5:.5 E5:1 r:1',
    ]
    for bar, text in enumerate(melody):
        s.line(bar, text, lambda n, d: musicbox(n, max(d * 1.6, .7)), .3, .15, echo=.16, verb=.45)
        if bar >= 8:  # second half: soft kalimba counter an octave below
            s.line(bar, text, lambda n, d: kalimba(n - 12, max(d, .4)), .08, -.45, verb=.3)
    # Kitten answers at phrase ends (tuned to the chord), plus a purr bed.
    for bar, base in [(3, hz(midi('G5'))), (7, hz(midi('C6'))), (11, hz(midi('G5'))), (15, hz(midi('A5')))]:
        s.add(mew(base, .22, 1.18), bar * 4 + 3, .16, .45 if bar % 8 == 3 else -.45, echo=.25, verb=.5)
    s.add(trill(hz(midi('F5')), .26), 7 * 4 + 2.5, .1, -.3, verb=.5)
    for bar in range(0, 16, 4):
        s.add(purr(s.beat * 4 * 2, 25), bar * 4, .05, 0, verb=0)
    write('lobby-groove', s.finish(.55, .32, 1.25), music=True, bpm=100, bars=16, key='F major', original=True)


def battle():
    """'냥냥 출격' — bright G major chip-pop with nya! vocal chops."""
    s = Song(150, 16)
    roots = ['G2', 'D2', 'E2', 'C2', 'G2', 'D2', 'C2', 'D2', 'E2', 'C2', 'G2', 'D2', 'C2', 'D2', 'B1', 'C2|D2']
    triads = {'G': 'G B D', 'D': 'D F# A', 'E': 'E G B', 'C': 'C E G', 'B': 'B D G'}
    for bar, text in enumerate(roots):
        parts = text.split('|')
        for e in range(8):
            root = midi(parts[0] if len(parts) == 1 or e < 4 else parts[1])
            beat = bar * 4 + e * .5
            s.add(bass(root + (12 if e % 2 else 0), s.beat * .45), beat, .36, 0, verb=.05)
            chord = [midi(n + '4') for n in triads[(parts[0] if len(parts) == 1 or e < 4 else parts[1])[0]].split()]
            if bar >= 4:  # 16th-note pluck arpeggio after the intro
                for sub in (0, .25):
                    n = chord[int((e * 2 + sub * 4) % 3)] + (12 if (e // 2) % 2 else 0)
                    s.add(pluck(n, .22, 1.2, 6), beat + sub, .085, -.4 if sub else .4, verb=.25)
            if e in (1, 5):
                for n in chord:
                    s.add(kalimba(n + 12, .25), beat, .05, .2, verb=.35)
        for q in range(4):
            beat = bar * 4 + q
            s.add(kit('kick'), beat, .62, verb=.02)
            if q in (1, 3):
                s.add(kit('clap'), beat, .3, -.05, verb=.3)
            for h in (0, .25, .5, .75):
                s.add(kit('hat'), beat + h, .1 if h == .5 else .055, .25, verb=.05)
        if bar % 8 == 7:  # paw-tom fill into the next phrase
            for i, (b, p) in enumerate([(3, -.5), (3.25, -.2), (3.5, .2), (3.75, .5)]):
                s.add(kit('tom'), bar * 4 + b, .35 + i * .04, p, verb=.2)
        if bar % 8 == 0:
            s.add(kit('crash'), bar * 4, .22, .3, verb=.4)
    lead = [
        'D5:.5 G5:.5 B5:.5 G5:.5 D6:1 B5:1',
        'A5:.5 F#5:.5 D5:.5 F#5:.5 A5:1 r:.5 A5:.5',
        'B5:.5 G5:.5 E5:.5 G5:.5 B5:.5 C6:.5 B5:1',
        'G5:1 E5:.5 G5:.5 C6:1 r:1',
        'D5:.5 G5:.5 B5:.5 G5:.5 D6:1 E6:1',
        'F#6:.5 E6:.5 D6:.5 A5:.5 F#5:1 A5:1',
        'G5:.5 A5:.5 B5:.5 C6:.5 E6:1 D6:1',
        'D6:1.5 C6:.5 B5:.5 A5:.5 r:1',
        'E6:1 B5:.5 G5:.5 E5:1 G5:1',
        'E6:.5 D6:.5 C6:.5 G5:.5 E5:1 C6:1',
        'D6:.5 B5:.5 G5:.5 B5:.5 D6:.5 G6:.5 F#6:.5 E6:.5',
        'D6:1 A5:1 F#5:1 r:1',
        'C6:.5 E6:.5 G6:1 E6:.5 C6:.5 G5:1',
        'D6:.5 F#6:.5 A6:1 F#6:.5 D6:.5 A5:1',
        'B5:.5 D6:.5 G6:.5 D6:.5 B5:.5 G5:.5 D5:1',
        'E5:.5 G5:.5 C6:1 F#5:.5 A5:.5 D6:1',
    ]
    for bar, text in enumerate(lead):
        s.line(bar, text, lambda n, d: chip(n - 12, d * .92), .2, .1, echo=.14, verb=.25)
        s.line(bar, text, lambda n, d: musicbox(n, max(d * 1.2, .4)), .12, -.15, verb=.35)
    for bar, beat, voice, pan in [(3, 3, nya(hz(midi('G5')), .2), .45), (11, 3, nya(hz(midi('A5')), .2), -.45),
                                  (7, 3, mew(hz(midi('D6')), .2, 1.3), -.3), (15, 3.5, mew(hz(midi('D6')), .18, 1.35), .3)]:
        s.add(voice, bar * 4 + beat, .22, pan, echo=.2, verb=.4)
        s.add(voice, bar * 4 + beat + .5, .16, -pan, verb=.4)
    write('battle-drive', s.finish(.35, .2, 1.5), music=True, bpm=150, bars=16, key='G major', original=True)


def boss():
    """'진공 제국 습격' — D harmonic minor, vacuum drone, taiko + hisses."""
    s = Song(160, 16)
    roots = ['D2', 'D2', 'Bb1', 'A1', 'D2', 'D2', 'G1', 'A1', 'Bb1', 'C2', 'D2', 'A1', 'Bb1', 'G1', 'A1', 'A1']
    quality = {'D': (0, 3, 7), 'Bb': (0, 4, 7), 'A': (0, 4, 7), 'G': (0, 3, 7), 'C': (0, 4, 7)}
    pattern = [0, 0, 12, 0, 7, 0, 10, 12]
    for bar, root_name in enumerate(roots):
        root = midi(root_name)
        tones = quality[root_name.rstrip('0123456789')]
        for e in range(8):
            beat = bar * 4 + e * .5
            s.add(pluck(root + pattern[e] + 12, .3, .9, 7), beat, .3, -.15, verb=.08)
            s.add(bass(root + (0 if e % 2 == 0 else 12), s.beat * .4), beat, .3, 0, verb=.03)
        s.add(pad([root + 24 + t for t in tones], s.beat * 4), bar * 4, .1, 0, verb=.6)
        for q in range(4):
            beat = bar * 4 + q
            if q in (0, 2):
                s.add(kit('taiko'), beat, .62, verb=.15)
            if q == 2:
                s.add(kit('taiko'), beat + .5, .4, .2, verb=.15)
            if q in (1, 3):
                s.add(kit('snare'), beat, .32, -.05, verb=.3)
            for h in (0, .5):
                s.add(kit('hat'), beat + h, .06 if h else .09, .3, verb=.05)
        if bar % 4 == 0:
            s.add(kit('crash'), bar * 4, .2, -.3, verb=.4)
            s.add(bell(root + 36, 1.6), bar * 4, .09, .4, echo=.2, verb=.5)
        if bar % 8 == 7:
            s.add(hiss(.35), bar * 4 + 3.25, .12, .5, verb=.4)
            for i, b in enumerate((3, 3.25, 3.5, 3.75)):
                s.add(kit('tom'), bar * 4 + b, .32 + i * .05, -.5 + i * .33, verb=.2)
    lead = [
        'D5:1 F5:.5 E5:.5 D5:.5 A4:.5 D5:1',
        'F5:1 G5:.5 F5:.5 E5:1 C#5:1',
        'D5:.5 F5:.5 Bb5:1 A5:.5 G5:.5 F5:1',
        'E5:1.5 C#5:.5 A4:2',
        'D5:1 F5:.5 E5:.5 D5:.5 A4:.5 D5:1',
        'A5:1 Bb5:.5 A5:.5 G5:1 F5:1',
        'G5:.5 Bb5:.5 D6:1 C6:.5 Bb5:.5 G5:1',
        'A5:2 C#6:1 E6:1',
        'F6:1 D6:.5 Bb5:.5 F5:1 D6:1',
        'E6:1 C6:.5 G5:.5 E5:1 C6:1',
        'D6:.5 C6:.5 A5:.5 F5:.5 D5:1 F5:1',
        'E5:.5 F5:.5 G5:.5 A5:.5 C#6:2',
        'D6:1 Bb5:1 F5:1 Bb5:1',
        'G5:1 Bb5:1 D6:1 G6:1',
        'F6:.5 E6:.5 D6:.5 C#6:.5 A5:1 E5:1',
        'A5:.5 G5:.5 F5:.5 E5:.5 C#5:.5 E5:.5 A4:1',
    ]
    for bar, text in enumerate(lead):
        s.line(bar, text, lambda n, d: chip(n - 12, d * .9, duty=.4, soft=3800), .2, .12, echo=.12, verb=.3)
        if bar >= 8:
            s.line(bar, text, lambda n, d: musicbox(n, max(d * 1.2, .4)), .1, -.2, verb=.4)
    # The vacuum empire's hum: slow wobbling low drone under the whole loop.
    t = np.arange(s.length) / RATE
    wobble = 1 + .5 * np.sin(2 * math.pi * t / (s.length / RATE) * 8)
    hum = (np.sin(2 * math.pi * 73.4 * t) + .4 * np.sin(2 * math.pi * 146.8 * t)) * (.6 + .4 * wobble)
    hum += 1.4 * spectral(rng.normal(0, 1, s.length), 90, 420, pad=False) * wobble
    s.mix += np.stack([hum, hum], 1) * .05
    s.add(grumble(220, .4), 15 * 4 + 1.5, .18, .3, verb=.4)
    write('boss-theme', s.finish(.4, .22, 1.6), music=True, bpm=160, bars=16, key='D minor', original=True)


# ---------------------------------------------------------------- effects
def sweep_noise(duration, start, end, width=1.6):
    """Whoosh: noise band whose centre sweeps from start to end Hz."""
    t = axis(duration)
    out = np.zeros(len(t))
    steps = 12
    for i in range(steps):
        a, b = i / steps, (i + 1) / steps
        c = start * (end / start) ** ((a + b) / 2)
        seg = noise(duration, c / width, min(c * width, NYQ - 200))
        w = np.clip(1 - np.abs(t / duration - (a + b) / 2) * steps, 0, 1)
        out += seg * w
    return out


def glide(duration, start, end, harmonics=(1, .3, .1), decay=8):
    t = axis(duration)
    f = start * (end / start) ** (t / duration)
    phase = 2 * math.pi * np.cumsum(f) / RATE
    s = sum(a * np.sin((k + 1) * phase) for k, a in enumerate(harmonics))
    return fade(s * np.minimum(t / .003, 1) * np.exp(-t * decay))


def pop(base=1300, duration=.06):
    """Soft paw-tap 'bop'."""
    t = axis(duration)
    f = base * (.65 + .35 * np.exp(-t / .012))
    phase = 2 * math.pi * np.cumsum(f) / RATE
    return fade(np.sin(phase) * np.exp(-t * 55) + .08 * noise(duration, 1500, 6000) * np.exp(-t * 200), .001)


def clink(base=1500, duration=.25):
    return partials(69 + 12 * math.log2(base / 440), duration, [1, 2.7, 5.1, 8.3],
                    [1, .5, .3, .15], [14, 22, 30, 45], .0008)


def boing(duration=.35, base=220):
    t = axis(duration)
    f = base * (1 + .6 * np.exp(-t * 6) * np.sin(2 * math.pi * 14 * t)) * (1 + t * 1.5)
    phase = 2 * math.pi * np.cumsum(f) / RATE
    return fade((np.sin(phase) + .2 * np.sin(2 * phase)) * np.exp(-t * 7))


def thump(duration=.3, top=140, bottom=45):
    t = axis(duration)
    phase = 2 * math.pi * np.cumsum(bottom + (top - bottom) * np.exp(-t / .04)) / RATE
    return fade(np.sin(phase) * np.exp(-t * 9), .001)


def puff(duration=.4, hi=2600):
    t = axis(duration)
    return fade(noise(duration, 120, hi) * np.minimum(t / .006, 1) * np.exp(-t * 7), .002, .04)


def jingle(count=3, start=midi('A6'), spacing=.045):
    return at([(i * spacing + rng.uniform(0, .01), bell(start + [0, 4, 7, 12, 9][i % 5], .4), 1 - i * .12)
               for i in range(count)])


def arpeggio(notes, step, voice=musicbox, length=.6):
    return at([(i * step, voice(n, length), 1) for i, n in enumerate(notes)])


def effects():
    m = midi
    fx = {
        # ---------------- UI
        'click': at([(0, pop(1250, .06), 1), (.004, pop(2500, .03), .25)]),
        'select': at([(0, pop(1500, .05), .7), (.01, trill(700, .12), .55)]),
        'back': at([(0, mew(760, .15, 1.05), .7), (.0, pop(900, .06), .6)]),
        'confirm': at([(0, nya(700, .18), .75), (.05, musicbox(m('C6'), .4), .5), (.12, musicbox(m('G6'), .4), .45)]),
        'error': at([(0, grumble(250, .3), .9), (0, drum('block'), .3), (.12, drum('block'), .25)]),
        'pause': at([(0, musicbox(m('G6'), .4), 1), (.09, musicbox(m('D6'), .45), .9), (.04, purr(.25), .4)]),
        'resume': at([(0, musicbox(m('D6'), .35), .9), (.08, musicbox(m('G6'), .45), 1), (.05, trill(620, .14), .4)]),
        'pick': at([(0, pop(1400, .05), .6), (.02, bell(m('E6'), .45), .7), (.06, bell(m('B6'), .4), .4)]),
        'reroll': at([*[(i * .04, noise(.025, 2000, 7000) * np.exp(-axis(.025) * 90), .7) for i in range(4)],
                      (.16, arpeggio([m('C6'), m('E6'), m('A6')], .04, pluck, .3), .6)]),
        'equip': at([(0, clink(2100, .12), .5), (.03, jingle(4, m('A6'), .04), .65), (.08, trill(640, .14), .35)]),
        'purchase': at([(0, clink(2300, .3), .7), (.07, clink(3000, .3), .6), (.14, nya(760, .2), .55)]),
        'reward': at([(0, arpeggio([m('C6'), m('E6'), m('G6'), m('C7')], .06), .8), (.2, meow(620, .38, 1.3, 1.1), .55),
                      (.24, jingle(3, m('E7'), .05), .25)]),
        'upgrade': at([(0, purr(.5), .35), (0, arpeggio([m('F5'), m('A5'), m('C6'), m('F6')], .055, pluck, .4), .7),
                       (.24, bell(m('A6'), .5), .5), (.28, mew(1000, .16, 1.3), .4)]),
        'launch': at([(0, sweep_noise(.55, 300, 5000) * np.linspace(.3, 1, len(axis(.55))) * np.exp(-axis(.55) * 1.5), .45),
                      (0, meow(560, .5, 1.55, 1.35), .8), (.42, thump(.25, 160, 60), .55), (.45, puff(.25), .25)]),
        'level': at([(0, arpeggio([m('G5'), m('C6'), m('E6'), m('G6'), m('C7')], .045), .75),
                     (.12, mew(1150, .2, 1.3), .55), (.2, jingle(3, m('G7'), .04), .25)]),
        # ---------------- pickups / support
        'pickup': at([(0, glide(.05, 2400, 3600, (1, .15), 40), .8), (0, pop(3000, .02), .25)]),
        'chest': at([(0, thump(.18, 220, 90), .5), (0, puff(.16, 1800), .4), (.08, pop(700, .06), .5),
                     (.12, arpeggio([m('E6'), m('G#6'), m('B6'), m('E7')], .05, bell, .5), .6)]),
        'magnet': at([(0, sweep_noise(.45, 600, 6000) * np.exp(-axis(.45) * 3), .5),
                      (.05, arpeggio([m('C6'), m('D6'), m('E6'), m('G6'), m('A6'), m('C7')], .045, kalimba, .3), .55)]),
        'heal': at([(0, purr(.55, 24), .7), (.05, arpeggio([m('F5'), m('A5'), m('C6')], .09, musicbox, .6), .55),
                    (.25, jingle(2, m('F7'), .07), .2)]),
        'shield': at([(0, boing(.28, 420), .7), (.02, glide(.22, 900, 1800, (1, .2), 10), .35),
                      (.04, jingle(2, m('B6'), .05), .3)]),
        'pet': at([(0, piyo(1.0), .9)]),
        # ---------------- player damage / danger
        'hit': at([(0, thump(.18, 180, 70), .65), (0, puff(.12, 2200), .3), (.01, yelp(950, .16), .9)]),
        'warning': at([(0, chip(m('A5'), .11, .5, .9, 0), .6), (.13, chip(m('E5'), .11, .5, .9, 0), .6),
                       (.26, chip(m('A5'), .11, .5, .9, 0), .6), (0, grumble(300, .36), .45)]),
        'enemy-fire': at([(0, noise(.11, 3200, 9000) * np.minimum(axis(.11) / .005, 1) * np.exp(-axis(.11) * 30), .7),
                          (0, glide(.05, 900, 600, (1, .3), 50), .3)]),
        'enemy-charge': at([(0, glide(.34, 140, 520, (1, .5, .33, .25, .2), 0) * np.linspace(.2, 1, len(axis(.34))), .5),
                            (0, sweep_noise(.34, 400, 2400) * np.linspace(.1, 1, len(axis(.34))), .25)]),
        'boss': at([(0, glide(.75, 65, 110, (1, .6, .4, .3, .2, .15), 1.8), .7), (0, noise(.75, 60, 500) * np.exp(-axis(.75) * 2), .45),
                    (.06, chip(m('D4'), .5, .5, .8, 0, 2400), .3), (.06, chip(m('F4'), .5, .5, .8, 0, 2400), .3),
                    (.35, hiss(.35), .35)]),
        'boss-phase': at([(0, clink(900, .3), .6), (.05, clink(1350, .25), .4), (.08, thump(.2, 160, 70), .5),
                          (.1, glide(.35, 400, 1200, (1, .4, .2), 3), .35)]),
        # ---------------- attacks
        'impact': at([(0, noise(.045, 300, 2400) * np.exp(-axis(.045) * 90), .6), (0, pop(600, .045), .6)]),
        'explosion': at([(0, puff(.3, 2400), .7), (0, thump(.25, 130, 50), .7), (.02, clink(1300, .2), .35),
                         (.05, boing(.2, 330), .2)]),
        'boss-explosion': at([(0, thump(.8, 120, 35), .9), (0, puff(1.0, 1800), .8),
                              *[(.08 + i * .09, clink(900 + 260 * i, .3), .45 - i * .05) for i in range(5)],
                              (.25, boing(.4, 180), .35), (.6, arpeggio([m('C6'), m('E6'), m('G6'), m('C7')], .05, bell, .6), .4),
                              (.7, nya(720, .24), .45)]),
        'bomb': at([(0, thump(.6, 110, 40), 1), (0, puff(.7, 1500), .8), (.04, noise(.5, 40, 300) * np.exp(-axis(.5) * 4), .6),
                    (.15, boing(.35, 160), .25)]),
        'skill-electric': at([(0, noise(.2, 2500, 9000) * (.5 + .5 * np.sign(np.sin(2 * math.pi * 120 * axis(.2)))) * np.exp(-axis(.2) * 14), .7),
                              *[(rng.uniform(0, .15), pop(4000, .012), .3) for _ in range(5)]]),
        'skill-beam': at([(0, glide(.22, 1100, 800, (1, .4, .2, .1), 8), .7), (0, noise(.22, 3000, 8000) * np.exp(-axis(.22) * 18), .15)]),
        'skill-blast': at([(0, puff(.2, 2600), .7), (0, thump(.16, 160, 70), .6), (.01, pop(500, .06), .4)]),
        'skill-drone': at([(0, chirp(.06, 3300, 2600), .7), (0, pop(1800, .04), .4)]),
        'skill-blade': at([(0, sweep_noise(.14, 7000, 1800) * np.exp(-axis(.14) * 14), .8), (.02, pluck(m('E6'), .14, 2, 12), .3)]),
        'skill-field': at([(0, glide(.28, 300, 380, (1, .5, .25), 5), .5), (0, jingle(2, m('D7'), .08), .25)]),
        'missile': at([(0, sweep_noise(.22, 500, 4500) * np.exp(-axis(.22) * 9), .7), (.02, glide(.12, 300, 800, (1, .3), 18), .55),
                       (.03, pop(900, .05), .3)]),
        'laser': at([(0, glide(.36, 2000, 500, (1, .35, .15), 4) * (1 + .3 * np.sin(2 * math.pi * 30 * axis(.36))), .7),
                     (0, noise(.1, 4000, 9000) * np.exp(-axis(.1) * 40), .2)]),
        # ---------------- growth / big moments
        'evolution': at([(0, glide(.5, 400, 1600, (1, .3, .1), 1.5), .35),
                         (0, arpeggio([m('C6'), m('D6'), m('E6'), m('G6'), m('A6'), m('C7'), m('E7')], .05, musicbox, .6), .65),
                         (.35, mew(1100, .25, 1.35), .5), (.4, jingle(4, m('C7'), .05), .3)]),
        'transform': at([(0, sweep_noise(.7, 200, 6000) * np.linspace(.2, 1, len(axis(.7))) * np.exp(-axis(.7) * 1.2), .5),
                         (0, arpeggio([m('C5'), m('G5'), m('C6'), m('E6'), m('G6'), m('C7'), m('E7'), m('G7')], .06, bell, .9), .5),
                         (.5, meow(480, .75, 1.6, 1.3), .9), (.5, thump(.4, 150, 45), .6), (.55, bell(m('C5'), 1.4), .45),
                         (.7, jingle(5, m('G7'), .06), .3)]),
        'synergy': at([(0, arpeggio([m('E6'), m('A6'), m('C#7')], .07, bell, .6), .55),
                       (0, arpeggio([m('A5'), m('E6'), m('A6')], .07, kalimba, .6), .45), (.2, trill(800, .16), .4)]),
        'ultimate': at([(0, sweep_noise(.4, 200, 4000) * np.exp(-axis(.4) * 3), .55), (.02, meow(400, .6, 1.5, 1.0), 1),
                        (.35, thump(.5, 120, 40), .8), (.36, puff(.5, 2000), .5), (.4, bell(m('G5'), 1.0), .35)]),
        'pilot': at([(0, nya(680, .22), .85), (.05, sweep_noise(.3, 800, 5000) * np.exp(-axis(.3) * 6), .4),
                     (.12, arpeggio([m('G6'), m('D7')], .05, bell, .4), .35)]),
        'victory': at([(0, arpeggio([m('C5'), m('E5'), m('G5'), m('C6')], .11, pluck, .5), .5),
                       (0, arpeggio([m('G5'), m('C6'), m('E6'), m('G6')], .11, musicbox, .8), .7),
                       (.5, musicbox(m('A6'), .5), .6), (.62, musicbox(m('G6'), .5), .6), (.74, bell(m('C7'), 1.2), .7),
                       (.78, arpeggio([m('C6'), m('E6'), m('G6')], .0, kalimba, 1.0), .35),
                       (.9, meow(640, .55, 1.35, 1.15), .7), (1.3, purr(.7), .35)]),
        'defeat': at([(0, arpeggio([m('E6'), m('D6'), m('C6'), m('A5')], .2, musicbox, .8), .6),
                      (.85, cat(.7, [(0, 720), (.3, 760), (1, 420)], [(0, 'm'), (.2, 'i'), (.6, 'a'), (1, 'u')],
                                [(0, 0), (.1, .9), (.7, .6), (1, 0)]), .75),
                      (.9, pluck(m('A3'), 1.0, .6), .4)]),
        # ---------------- main weapons (냥냥 연사포 / 정밀 냥냥포 / 꾹꾹 산탄포 + legacy set)
        'weapon-pulse': at([(0, glide(.075, 1500, 700, (1, .25), 30), .9), (0, pop(2400, .02), .2)]),
        'weapon-revolver': at([(0, glide(.09, 2600, 1200, (1, .2, .1), 30), .75), (0, clink(3200, .07), .3)]),
        'weapon-shotgun': at([(0, pop(380, .07), .8), (0, noise(.06, 400, 3000) * np.exp(-axis(.06) * 60), .4),
                              (.045, pop(320, .07), .6)]),
    }
    # Main-weapon shots share one perceived level (the director normalises by
    # RMS under a peak cap), so give each a dense, gently saturated body.
    for name in [k for k in fx if k.startswith('weapon-')]:
        x = fx[name] / np.max(np.abs(fx[name]))
        drive = 1.0
        while np.sqrt(np.mean((np.tanh(drive * x) / math.tanh(drive)) ** 2)) * .64 < .25 and drive < 12:
            drive *= 1.15
        fx[name] = np.tanh(drive * x) / math.tanh(drive)
    fx['shoot'] = fx['weapon-pulse'].copy()
    small_room = {'click', 'select', 'back', 'pickup', 'impact', 'enemy-fire', 'shoot'}
    for name, data in fx.items():
        if not name.startswith('weapon-') and name not in small_room:
            data = room(data, .3, .14, .45)
        write(name, data, original=True)


def main():
    OUT.mkdir(exist_ok=True)
    MASTERS.mkdir(parents=True, exist_ok=True)
    for old in [*OUT.glob('*.ogg'), *OUT.glob('*.wav'), *MASTERS.glob('*.wav')]:
        old.unlink()
    lobby()
    battle()
    boss()
    effects()
    folder = ROOT / '.local/audio-v12.3'
    folder.mkdir(parents=True, exist_ok=True)
    (folder / 'assets.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
    from wav_to_ogg import encode
    for master in sorted(MASTERS.glob('*.wav')):
        encode(master, OUT / f'{master.stem}.ogg')
    print(f'Composed {len(report)} original clips (Ogg in {OUT}, WAV masters in {MASTERS}); '
          f'stats: {folder / "assets.json"}')


if __name__ == '__main__':
    main()
