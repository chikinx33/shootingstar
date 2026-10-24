"""Audit original generated PNG alpha and safe bounds without editing pixels."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'assets/art/refit_v16'
records = json.loads((ART / 'generation.json').read_text(encoding='utf-8'))['records']
refinement = json.loads((ART / 'refinement.json').read_text(encoding='utf-8'))
manifest = {}
for row in records:
    source = refinement['source'] if row['name'] == refinement['name'] else row['source']
    raw = (ART / (row['name'] + '.png')).read_bytes()
    assert raw == Path(source).read_bytes(), row['name']
    im = Image.open(ART / (row['name'] + '.png')).convert('RGBA')
    w, h = im.size
    a = im.getchannel('A')
    bg = row['name'] == 'backdrop'
    b = (0, 0, w, h) if bg else a.point(lambda v: 255 if v >= 8 else 0).getbbox()
    low, high = a.getextrema()
    if bg:
        assert (low, high) == (255, 255)
    else:
        assert low == 0 and high >= 250, row['name']
        assert min(b[0], b[1], w - b[2], h - b[3]) >= 24, row['name']
    safe = b if bg else (b[0]-8, b[1]-8, b[2]+8, b[3]+8)
    manifest[row['name']] = {'background': bg, 'size': [w, h],
        'bounds': [safe[0]/w, safe[1]/h, safe[2]/w, safe[3]/h],
        'visibleBounds': list(b), 'alpha': [low, high],
        'sha256': hashlib.sha256(raw).hexdigest()}
(ART / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(f'Refit art passed: {len(manifest)} original PNGs, real alpha, safe margins, unchanged pixels.')
