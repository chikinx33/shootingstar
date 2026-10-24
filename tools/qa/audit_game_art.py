"""Verify every new asset is original, individually padded and genuinely transparent."""
from pathlib import Path
import hashlib,json,sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'assets/art/game_v10'
names=[*[f'enemy-{i}' for i in range(11)],*[f'boss-{i}' for i in range(10)],
 *[f'pet-{i}' for i in range(3)],*[f'gear-{n}' for n in ['gun','sensor','core','hull','belt','engine']],
 'missile','ball','drill','boomerang','mine','fire','ice','lightning','shield','impact','ring','spark',
 'gem','medkit','magnet','rock','crystal','mushroom','menu-purple','pulse','laser']
assert len(names)==51
records=json.loads((ART/'generation.json').read_text(encoding='utf-8'))['records']
if '--partial' not in sys.argv:
    assert set(x['name'] for x in records)==set(names),'missing final generated assets'
manifest={}
for row in records:
    p=ART/(row['name']+'.png');raw=p.read_bytes()
    assert raw==Path(row['source']).read_bytes(),row['name']
    im=Image.open(p).convert('RGBA');w,h=im.size;a=im.getchannel('A')
    background=row['name']=='menu-purple'
    b=(0,0,w,h) if background else a.point(lambda p:255 if p>=8 else 0).getbbox()
    margin=min(b[0],b[1],w-b[2],h-b[3])
    if background:assert a.getextrema()[0]>=250,row['name']
    else:
        assert a.getextrema()[0]==0 and a.getextrema()[1]>=250,row['name']
        assert margin>=24,(row['name'],margin)
    safe=b if background else (b[0]-12,b[1]-12,b[2]+12,b[3]+12)
    manifest[row['name']]={'background':background,'size':[w,h],'visibleBounds':list(b),
      'bounds':[safe[0]/w,safe[1]/h,safe[2]/w,safe[3]/h],'safeMargin':margin,
      'alpha':list(a.getextrema()),'sha256':hashlib.sha256(raw).hexdigest()}
(ART/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(f'Game art: {len(manifest)}/51 original separate PNGs; alpha and padding checked; no bitmap edits.')
