"""Encode game audio to Ogg Vorbis (high quality, exact sample length).

The game ships only .ogg; WAV masters stay out of the bundle. Music loops keep
their exact frame count, so the composed seam is preserved.

Needs soundfile (installed at D:/Programs/pylib):
  PYTHONPATH=D:/Programs/pylib python tools/wav_to_ogg.py   (assets/audio/*.wav)
"""
import pathlib

import soundfile as sf

ROOT = pathlib.Path(__file__).resolve().parents[1]
AUDIO = ROOT / 'assets/audio'
# libsndfile's Vorbis level: 0 = best quality. .3 is transparent for the
# music loops and cuts them to about an eighth. Short effects are tiny either
# way, so they use the best level: their peaks stay within the mix budget
# that AudioDirector.effectGain normalizes against.
MUSIC_LEVEL = .3
EFFECT_LEVEL = 0
MUSIC_SECONDS = 5
# libsndfile overflows the stack when one write holds a whole music loop.
CHUNK = 4096


def encode(wav: pathlib.Path, ogg: pathlib.Path) -> None:
    data, rate = sf.read(wav, dtype='float32')
    channels = data.shape[1] if data.ndim > 1 else 1
    level = MUSIC_LEVEL if len(data) > MUSIC_SECONDS * rate else EFFECT_LEVEL
    with sf.SoundFile(ogg, 'w', rate, channels, format='OGG',
                      subtype='VORBIS', compression_level=level) as out:
        for start in range(0, len(data), CHUNK):
            out.write(data[start:start + CHUNK])


def main() -> None:
    before = after = 0
    for wav in sorted(AUDIO.glob('*.wav')):
        ogg = wav.with_suffix('.ogg')
        encode(wav, ogg)
        before += wav.stat().st_size
        after += ogg.stat().st_size
        wav.unlink()
    print(f'{before // 1024}K -> {after // 1024}K')


if __name__ == '__main__':
    main()
