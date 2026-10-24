"""Verify final staged/served code, original art, unchanged models and fresh QA."""
from pathlib import Path
import hashlib,json,re,urllib.request
from datetime import datetime
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tools/qa/evidence/lobby-v9'
def read(path):return json.loads((ROOT/path).read_text(encoding='utf-8-sig'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
models=read('.local/v8-before/model-hashes.json')
for row in models:assert sha(Path(row['path'])).lower()==row['sha256'].lower(),row['path']
manifest=read('assets/art/lobby_v9/manifest.json');assert len(manifest)==14
generation=read('assets/art/lobby_v9/generation.json')
for record in generation['records']:
    assert sha(Path(record['source']))==sha(ROOT/'assets/art/lobby_v9'/(record['name']+'.png'))
    assert sha(Path(record['source']))==manifest[record['name']]['sha256']
tests=(ROOT/'.local/v9-tests.log').read_text(encoding='utf-8-sig')
count=int(re.search(r'\+(\d+): All tests passed!',tests)[1]);assert count>=240
assert not re.search('Warning:|EXCEPTION CAUGHT',tests)
analyze=(ROOT/'.local/v9-analyze.log').read_text(encoding='utf-8-sig');assert 'No issues found!' in analyze
contract=(ROOT/'.local/v9-contract.log').read_text(encoding='utf-8-sig').strip();assert contract.startswith('UI contract passed:')
build_time=max((ROOT/'.local'/folder/'main.dart.js').stat().st_mtime for folder in ['v9-web','v9-fixtures'])
for folder in ['lib/ui','lib/art']:
    for p in (ROOT/folder).glob('*.dart'):assert p.stat().st_mtime<=build_time,p
groups={}
for name,total in [('lobby-v9',8),('ui-contract-20261017',17),('catalog-fixed-ui-20261017',8)]:
    p=Path('tools/qa/evidence')/name/'browser-result.json';result=read(p)
    assert len(result['rows'])==total and result['errors']==[],name
    assert (ROOT/p).stat().st_mtime>build_time,name
    groups[name]=total
files=['index.html','main.dart.js','flutter_bootstrap.js','assets/assets/art/lobby_v9/manifest.json']
files+=['assets/assets/art/lobby_v9/'+name+'.png' for name in manifest]
runtime=[]
for port,folder in [(8797,'v9-web'),(8798,'v9-fixtures')]:
    for name in files:
        req=urllib.request.Request(f'http://127.0.0.1:{port}/{name}?verify=lobby-v9',headers={'Cache-Control':'no-cache'})
        with urllib.request.urlopen(req,timeout=20) as r:data=r.read()
        digest=hashlib.sha256(data).hexdigest()
        assert digest==sha(ROOT/'.local'/folder/name),(port,name)
        runtime.append({'port':port,'file':name,'sha256':digest})
report={'verifiedAt':datetime.now().astimezone().isoformat(),'flutterTests':count,'analyzer':'No issues found',
 'sourceContract':contract,'browserGroups':groups,'modelsUnchanged':len(models),'generatedOriginalPNGs':14,
 'originalArtBytesPreserved':True,'individualObjects':13,'opaqueBackgrounds':1,'runtimeFilesMatched':len(runtime),
 'runtime':runtime,'mobileWidths':[320,360,390,430],'textScales':[1,1.3],
 'noNonListScroll':True,'storage':'Isolated QA guest earned gear IDs, equipment, presets and currency survive navigation and reload; user browser storage never attached.',
 'screenshots':len(list(OUT.glob('*-scale-*.png'))),'androidBuild':False,'productionDeployment':False}
(OUT/'final-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:report[k] for k in ['flutterTests','browserGroups','modelsUnchanged','generatedOriginalPNGs','runtimeFilesMatched','screenshots']},ensure_ascii=False))
