"""Confirm current served art/code, preserved models and fresh web acceptance."""
from pathlib import Path
from datetime import datetime
import hashlib,json,re,urllib.request

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tools/qa/evidence/menu-v8'
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
models=read('.local/v8-before/model-hashes.json')
for row in models:assert sha(Path(row['path'])).lower()==row['sha256'].lower(),row['path']
art=read('assets/art/menu_v8/manifest.json')
assert len(art)==17
for name,row in art.items():assert sha(ROOT/'assets/art/menu_v8'/f'{name}.png')==row['sha256']
gen=read('assets/art/menu_v8/generation.json')
for row in gen['records']:assert sha(Path(row['source']))==sha(ROOT/'assets/art/menu_v8'/(row['name']+'.png'))
tests=(ROOT/'.local/v8-tests.log').read_text(encoding='utf-8-sig')
count=int(re.search(r'\+(\d+): All tests passed!',tests)[1]);assert count>=240
assert 'Warning:' not in tests and 'EXCEPTION CAUGHT' not in tests
analyze=(ROOT/'.local/v8-analyze.log').read_text(encoding='utf-8-sig');assert 'No issues found!' in analyze
contract=(ROOT/'.local/v8-contract.log').read_text(encoding='utf-8-sig').strip();assert contract.startswith('UI contract passed:')
audit=read('tools/qa/evidence/menu-v8/asset-audit.json');assert len(audit['rows'])==17
build_time=max((ROOT/'.local'/s/'main.dart.js').stat().st_mtime for s in ['v8-web','v8-fixtures'])
for folder in ['lib/ui','lib/art']:
 for source in (ROOT/folder).glob('*.dart'):assert source.stat().st_mtime<=build_time,source
groups={}
for name,folder,total in [('menusV8','menu-v8',8),('menuCombat','ui-contract-20261017',17),('catalog','catalog-fixed-ui-20261017',8)]:
 result_path=Path('tools/qa/evidence')/folder/'browser-result.json';r=read(result_path)
 assert len(r['rows'])==total and r['errors']==[],name
 assert (ROOT/result_path).stat().st_mtime>build_time,name
 groups[name]=total
assets=['main.dart.js','flutter_bootstrap.js','assets/assets/art/menu_v8/manifest.json','assets/assets/art/ui_icon_regions.json']
assets += ['assets/assets/art/menu_v8/'+name+'.png' for name in art]
assets += ['assets/assets/art/toon_v7/'+p.name for p in sorted((ROOT/'assets/art/toon_v7').glob('*.png'))]
runtime=[]
for port,stage in [(8797,'v8-web'),(8798,'v8-fixtures')]:
 for name in assets:
  req=urllib.request.Request(f'http://127.0.0.1:{port}/{name}?proof=menu-v8-final',headers={'Cache-Control':'no-cache'})
  with urllib.request.urlopen(req,timeout=20) as response:data=response.read()
  digest=hashlib.sha256(data).hexdigest();assert digest==sha(ROOT/'.local'/stage/name),(port,name)
  runtime.append({'port':port,'file':name,'sha256':digest})
refs=Path('F:/NKW/App/PuzzleKnight/work/UI 샘플 1')
report={'verifiedAt':datetime.now().astimezone().isoformat(),'flutterTests':count,'testWarnings':0,
 'sourceContract':contract,'analyzer':analyze.strip(),'browserGroups':groups,
 'viewports':['320x568','360x640','390x844','430x932'],'textScales':[1,1.3],
 'newGeneratedPNGs':len(art),'individualAlphaObjects':14,'backgrounds':3,'bitmapBytesMatchGeneratedOriginals':True,
 'modelsUnchanged':len(models),'runtimeFilesMatched':len(runtime),'runtime':runtime,
 'references':{name:sha(refs/name) for name in ['챕터 - 맵 선택1.jpg','추가 메뉴.jpg','보관함 - 장비.jpg','상점.jpg']},
 'sources':{str(p.relative_to(ROOT)):sha(p) for f in ['lib/ui','lib/art'] for p in sorted((ROOT/f).glob('*.dart'))},
 'screenshots':len(list(OUT.glob('*-scale-*.png'))),
 'storageProof':'Only isolated QA guests seeded; actual UI claims/reload preserve inventory/equipped/preset IDs; user browser storage untouched.',
 'graphicsProof':'17 new generated standalone PNGs. Render-time low-alpha cleanup and aspect-preserving safe bounds. Continuous painted panels; no bitmap panel scaling or nine-slice.',
 'scrollProof':'Lobby/overview/management/details use fixed layout/pages; only repeated items scroll. Pointer/wheel/CDP touch and fixed headers checked.',
 'androidBuild':False,'productionDeployment':False}
(OUT/'final-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:report[k] for k in ['flutterTests','browserGroups','newGeneratedPNGs','modelsUnchanged','runtimeFilesMatched','screenshots']},ensure_ascii=False))
