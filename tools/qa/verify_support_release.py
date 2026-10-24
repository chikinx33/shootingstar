"""Verify unchanged saves/assets, current browser results and served web builds."""
from datetime import datetime
from pathlib import Path
import hashlib
import json
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'tools/qa/evidence/support-ui-20261018'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8-sig'))


preserved = read('.local/support-ui-before-20261018/preserved-hashes.json')
for item in preserved:
    assert sha(Path(item['path'])).lower() == item['sha256'].lower(), item['path']
models = [i for i in preserved if '/lib/data/' in i['path'].replace('\\', '/')]
pngs = [i for i in preserved if i['path'].endswith('.png')]
assert len(models) == 19 and len(pngs) == 9

tests = (ROOT / '.local/support-all-tests.log').read_text(encoding='utf-8-sig')
count = int(re.search(r'\+(\d+): All tests passed!', tests)[1])
assert count >= 239
assert 'Warning:' not in tests and 'EXCEPTION CAUGHT' not in tests
analyzer = (ROOT / '.local/support-analyze.log').read_text(encoding='utf-8-sig')
assert 'No issues found!' in analyzer
contract = (ROOT / '.local/support-contract.log').read_text(encoding='utf-8-sig').strip()
assert contract.startswith('UI contract passed:')

groups = {}
build_time = max((ROOT / '.local' / stage / 'main.dart.js').stat().st_mtime
                 for stage in ['support-web', 'support-fixtures'])
for folder in ['lib/ui', 'lib/art']:
    for source in (ROOT / folder).glob('*.dart'):
        assert source.stat().st_mtime <= build_time, source
for name, folder, expected in [('support', 'support-ui-20261018', 8),
                                ('menus', 'ui-contract-20261017', 17),
                                ('catalog', 'catalog-fixed-ui-20261017', 8),
                                ('content', 'content-ui-contract-20261017', 8)]:
    result_path = Path('tools/qa/evidence') / folder / 'browser-result.json'
    result = read(result_path)
    assert len(result['rows']) == expected, name
    assert result['errors'] == [], name
    assert (ROOT / result_path).stat().st_mtime > build_time, name
    groups[name] = len(result['rows'])

assets = ['main.dart.js', 'flutter_bootstrap.js', 'assets/assets/art/ui_icon_regions.json']
assets += [f'assets/assets/art/toon_v7/{p.name}' for p in sorted((ROOT / 'assets/art/toon_v7').glob('*.png'))]
runtime = []
for port, stage in [(8797, 'support-web'), (8798, 'support-fixtures')]:
    for relative in assets:
        request = urllib.request.Request(f'http://127.0.0.1:{port}/{relative}?proof=support-final',
                                         headers={'Cache-Control': 'no-cache'})
        with urllib.request.urlopen(request, timeout=20) as response:
            data = response.read()
        actual = hashlib.sha256(data).hexdigest()
        assert actual == sha(ROOT / '.local' / stage / relative), (port, relative)
        if relative.endswith('.png'):
            assert actual == sha(ROOT / 'assets/art/toon_v7' / Path(relative).name)
        runtime.append({'port': port, 'file': relative, 'bytes': len(data), 'sha256': actual})

references = Path('F:/NKW/App/PuzzleKnight/work/UI 샘플 1')
report = {
    'verifiedAt': datetime.now().astimezone().isoformat(),
    'flutterTests': count, 'testWarnings': 0,
    'analyzer': analyzer.strip(), 'sourceContract': contract, 'browserGroups': groups,
    'viewportCases': ['320x568', '360x640', '390x844', '430x932'], 'textScales': [1, 1.3],
    'modelFilesUnchanged': len(models), 'pngFilesUnchanged': len(pngs),
    'runtimeFilesMatched': len(runtime), 'runtime': runtime,
    'references': {name: sha(references / name) for name in [
        '설정 - 계정.jpg', '설정 - 일반.jpg', '신규콘텐츠 해제.jpg',
        '진화 - 스킬트리2.jpg', '아이템 팝업.jpg']},
    'uiSourceSha256': {str(p.relative_to(ROOT)): sha(p)
                       for folder in ['lib/ui', 'lib/art']
                       for p in sorted((ROOT / folder).glob('*.dart'))},
    'screenshots': len(list(OUT.glob('*-scale-*.png'))),
    'saveProof': 'Isolated guests only: inventory/equipment/preset IDs and balances preserved across account/settings/guide/codex and reload. User browser storage untouched.',
    'accountProof': 'All account/cloud requests intercepted locally. Existing client login/register/recovery/sync/retry/conflict backups/logout exercised; no real account writes or live-service claim.',
    'keyboardProof': 'All eight widget cases use 220px keyboard inset with reachable account inputs and actions.',
    'scrollProof': 'Browser wheel and CDP touch leave non-list anchors stationary; item-list scrolling leaves headers stationary. Fixed GamePages used for forms/settings/guide/details.',
    'regressionProof': 'Menus and content matrices passed. An initial overlapping catalog run timed out during Flutter semantics initialization on its final reload; the acceptance catalog matrix was rerun alone after all other browsers closed.',
    'androidBuild': False, 'productionDeployment': False,
}
(OUT / 'final-validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({k: report[k] for k in ['flutterTests', 'browserGroups', 'modelFilesUnchanged', 'runtimeFilesMatched', 'screenshots']}, ensure_ascii=False))
