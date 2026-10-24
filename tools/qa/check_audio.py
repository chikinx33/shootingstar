"""Check generated audio masters: finite headroom, seams and mono compatibility.

Reads the WAV masters that tools/compose_audio.py keeps in .local/audio-v12.3/wav.
"""
import json
from pathlib import Path
import wave
import numpy as np

root=Path(__file__).resolve().parents[2]
stats=json.loads((root/'.local/audio-v12.3/assets.json').read_text())
for name,spec in stats.items():
    with wave.open(str(root/f'.local/audio-v12.3/wav/{name}.wav')) as f:
        assert f.getframerate()==24000 and f.getsampwidth()==2,name
        data=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2')/32768
        if f.getnchannels()==2: data=data.reshape(-1,2)
    assert np.isfinite(data).all() and 0 < np.max(abs(data)) < .8,name
    assert abs(np.mean(data)) < .015,(name,'DC offset')
    if 'bpm' in spec:
        # The seam must be within the existing waveform's ordinary steps.
        assert np.max(abs(data[0]-data[-1])) < np.quantile(abs(np.diff(data,axis=0)),.995),name
        mono=data.mean(axis=1)
        assert np.sqrt(np.mean(mono**2)) > .08,(name,'mono cancellation')
    else:
        assert abs(data[0]) < .001 and abs(data[-1]) < .001,(name,'click boundary')
print(f'Audio assets passed: {len(stats)} original clips, headroom/DC, loop seams, mono fold-down')
