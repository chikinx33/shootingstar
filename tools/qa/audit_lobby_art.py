"""Record original PNGs, real alpha bounds and safe sampling without editing pixels."""
from pathlib import Path
import hashlib,json
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'assets/art/lobby_v9'
records=json.loads((ART/'generation.json').read_text(encoding='utf-8'))['records']
manifest={}
for row in records:
    p=ART/(row['name']+'.png')
    raw=p.read_bytes()
    assert raw==Path(row['source']).read_bytes(),row['name']
    im=Image.open(p).convert('RGBA');w,h=im.size
    a=im.getchannel('A');background=row['name']=='backdrop'
    b=(0,0,w,h) if background else a.point(lambda p:255 if p>=8 else 0).getbbox()
    margin=min(b[0],b[1],w-b[2],h-b[3])
    if not background:
        assert a.getextrema()==(0,255),row['name']
        assert margin>=24,(row['name'],margin)
    else: assert a.getextrema()==(255,255)
    safe=b if background else (b[0]-12,b[1]-12,b[2]+12,b[3]+12)
    manifest[row['name']]={'background':background,'size':[w,h],
      'bounds':[safe[0]/w,safe[1]/h,safe[2]/w,safe[3]/h],
      'visibleBounds':list(b),'safeMargin':margin,'alpha':list(a.getextrema()),
      'sha256':hashlib.sha256(raw).hexdigest()}
(ART/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(f'Lobby art: {len(manifest)} original independent PNGs; real transparency and safe bounds passed.')
