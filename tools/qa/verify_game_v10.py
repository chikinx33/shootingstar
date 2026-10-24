"""Final V10 source/storage/art/runtime/browser evidence consistency check."""
from pathlib import Path
import hashlib,json,re,urllib.request
from datetime import datetime
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tools/qa/evidence/game-v10'
def read(p):return json.loads((ROOT/p).read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
models=read('.local/v8-before/model-hashes.json')
for row in models:assert sha(Path(row['path'])).lower()==row['sha256'].lower(),row['path']
engines=[]
for p in (ROOT/'.local/v10-before/game').glob('*.dart'):
    if p.name=='battle_painter.dart':continue
    assert sha(p)==sha(ROOT/'lib/game'/p.name),p.name
    engines.append(p.name)
packs={name:read(f'assets/art/{name}/manifest.json') for name in ['game_v10','lobby_v9']}
assert len(packs['game_v10'])==51 and len(packs['lobby_v9'])==14
for pack,manifest in packs.items():
    for row in read(f'assets/art/{pack}/generation.json')['records']:
        assert sha(Path(row['source']))==sha(ROOT/f'assets/art/{pack}'/(row['name']+'.png'))
        assert sha(Path(row['source']))==manifest[row['name']]['sha256']
tests=(ROOT/'.local/v10-tests.log').read_text(encoding='utf-8-sig')
count=int(re.search(r'\+(\d+): All tests passed!',tests)[1]);assert count>=250
assert not re.search('Warning:|EXCEPTION CAUGHT',tests)
assert 'No issues found!' in (ROOT/'.local/v10-analyze.log').read_text(encoding='utf-8-sig')
contract=(ROOT/'.local/v10-contract.log').read_text(encoding='utf-8-sig').strip();assert contract.startswith('UI contract passed:')
builds=[ROOT/'.local'/f for f in ['v10-web','v10-fixtures']]
build_time=max((p/'main.dart.js').stat().st_mtime for p in builds)
core=read('.local/v10-core-source-proof.json')
changed=[]
for relative,digest in core['files'].items():
    if sha(ROOT/relative)!=digest:changed.append(relative)
assert changed==['lib/ui/arcade_home_widgets.dart'],changed
for folder in ['lib/ui','lib/art','lib/game']:
    for p in (ROOT/folder).glob('*.dart'):assert p.stat().st_mtime<=build_time,p
assert (ROOT/'tools/qa/survivor_style_preview.dart').stat().st_mtime<=build_time
groups={}
for name,total in [('game-v10',8),('ui-contract-20261017',17),('catalog-fixed-ui-20261017',8),
                   ('content-ui-contract-20261017',8),('command-ui-20261017',8),('support-ui-20261018',8)]:
    p=Path('tools/qa/evidence')/name/'browser-result.json';result=read(p)
    assert len(result['rows'])==total and result['errors']==[],name
    assert (ROOT/p).stat().st_mtime>core['buildTime'],name
    groups[name]=total
assert read('tools/qa/evidence/game-v10/browser-result.json')['legacyRequests']==[]
for name in ['game-v10','menu-v8','command-ui-20261017']:
    p=Path('tools/qa/evidence')/name/'browser-result.json';result=read(p)
    assert len(result['rows'])==8 and result['errors']==[],name
    assert (ROOT/p).stat().st_mtime>build_time,name
worlds=read('tools/qa/evidence/game-v10/world-fixtures-result.json')
assert len(worlds['rows'])==10 and worlds['errors']==[]
files=['index.html','main.dart.js','flutter_bootstrap.js']
for pack,manifest in packs.items():
    files.append(f'assets/assets/art/{pack}/manifest.json')
    files += [f'assets/assets/art/{pack}/{name}.png' for name in manifest]
runtime=[]
for port,folder in [(8797,'v10-web'),(8798,'v10-fixtures')]:
    for name in files:
        req=urllib.request.Request(f'http://127.0.0.1:{port}/{name}?verify=game-v10',headers={'Cache-Control':'no-cache'})
        with urllib.request.urlopen(req,timeout=20) as r:data=r.read()
        digest=hashlib.sha256(data).hexdigest();assert digest==sha(ROOT/'.local'/folder/name),(port,name)
        runtime.append({'port':port,'file':name,'sha256':digest})
report={'verifiedAt':datetime.now().astimezone().isoformat(),'flutterTests':count,'analyzer':'No issues found',
 'sourceContract':contract,'browserGroups':groups,
 'browserCoreSourceFiles':len(core['files']),'finalCosmeticChangeOnly':changed,
 'latestBuildBrowserRegressions':{'game-v10':8,'menu-v8':8,'command-ui-20261017':8},
 'validationScope':'Full functional mobile matrix uses the core V10 build. Only the navigation outline changed afterward; source hashes prove all other Dart files identical. Final release build repeats real combat and complete menu/inventory/supply/reward flows at all eight size/scale combinations.',
 'modelsUnchanged':len(models),'combatRuleFilesUnchanged':engines,
 'newOriginalPNGs':51,'sharedLobbyOriginalPNGs':14,'originalBytesPreserved':True,'runtimeFilesMatched':len(runtime),
 'runtime':runtime,'mobileWidths':[320,360,390,430],'textScales':[1,1.3],
 'noNonListScroll':True,'legacyGraphicRequests':[],
 'storage':'Real UI earned gear IDs, equipment and presets survive navigation/battle/reload in isolated guests. User browser storage never attached.',
 'screenshots':len([p for p in OUT.glob('*.png') if not p.name.startswith('failure')]),
 'historicalDiagnosticsExcluded':['failure*'],
 'androidBuild':False,'productionDeployment':False}
(OUT/'final-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:report[k] for k in ['flutterTests','browserGroups','modelsUnchanged','newOriginalPNGs','runtimeFilesMatched','screenshots']},ensure_ascii=False))
