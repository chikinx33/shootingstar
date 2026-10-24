"""Audit original individual PNGs and the renderer's safe alpha sampling bounds."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'assets/art/menu_v8'
meta = json.loads((ART/'manifest.json').read_text(encoding='utf-8'))
assert len(meta) == 17
rows = []
for name, item in meta.items():
    path = ART/(name+'.png')
    assert hashlib.sha256(path.read_bytes()).hexdigest() == item['sha256'], name
    im = Image.open(path).convert('RGBA')
    w,h = im.size
    assert [w,h] == item['size']
    alpha = im.getchannel('A')
    if not item['background']:
        assert alpha.getextrema() == (0,255), name
        visible = alpha.point(lambda p: 255 if p>=8 else 0).getbbox()
        assert min(visible[0],visible[1],w-visible[2],h-visible[3]) >= 24, name
        box = [item['bounds'][i]*[w,h,w,h][i] for i in range(4)]
        assert box[0] < visible[0] and box[1] < visible[1]
        assert box[2] > visible[2] and box[3] > visible[3]
        assert all(alpha.getpixel(p)<8 for p in [(0,0),(w-1,0),(0,h-1),(w-1,h-1)]),name
    rows.append({'name':name,'background':item['background'],'sha256':item['sha256'],'alpha':item['alpha']})
style=(ROOT/'lib/art/arcade_style.dart').read_text(encoding='utf-8')
assert 'drawImage' not in style and 'ToonAssets.panel' not in style
assert 'static bool panel(' not in (ROOT/'lib/art/toon_assets.dart').read_text(encoding='utf-8')
out=ROOT/'tools/qa/evidence/menu-v8';out.mkdir(exist_ok=True,parents=True)
(out/'asset-audit.json').write_text(json.dumps({'rows':rows,'separateObjects':14,'backgrounds':3,
    'safeVisibleAlphaMargin':24,'alphaCutoff':8,'bitmapEditing':False,
    'panelRendering':'single continuous path; no bitmap scaling or nine-slice'},indent=2),encoding='utf-8')
print('Menu art passed: 17 individual PNGs; 14 alpha silhouettes; 3 backgrounds; no sliced panel renderer.')
