"""Check local web delivery and attach reproducible evidence to the UI report."""
from datetime import datetime
from pathlib import Path
import hashlib
import json
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'tools/qa/evidence/command-ui-20261017'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8-sig'))


models = read('.local/command-ui-before-20261017/model-hashes.json')
for item in models:
    assert sha(Path(item['path'])).lower() == item['sha256'].lower(), item['path']
pngs = read('.local/command-ui-before-20261017/png-hashes.json')
for item in pngs:
    assert sha(ROOT / 'assets/art/toon_v7' / item['file']) == item['sha256']

tests = (ROOT / '.local/command-all-tests.log').read_text(encoding='utf-8-sig')
assert 'All tests passed!' in tests
count = int(re.search(r'\+(\d+): All tests passed!', tests)[1])
assert count >= 231
assert 'Warning:' not in tests and 'EXCEPTION CAUGHT' not in tests
analyzer = (ROOT / '.local/command-analyze.log').read_text(encoding='utf-8-sig')
assert 'No issues found!' in analyzer
contract = (ROOT / '.local/command-contract.log').read_text(encoding='utf-8-sig').strip()
assert contract.startswith('UI contract passed:')

groups = {}
regression_sources = read('.local/command-regression-source-hashes.json')
for relative, expected in regression_sources.items():
    assert sha(ROOT / relative) == expected, relative
for name, folder, expected in [('command', 'command-ui-20261017', 8),
                                ('menus', 'ui-contract-20261017', 17),
                                ('catalog', 'catalog-fixed-ui-20261017', 8)]:
    result_path = Path('tools/qa/evidence') / folder / 'browser-result.json'
    result = read(result_path)
    assert len(result['rows']) == expected, name
    assert result['errors'] == [], name
    groups[name] = len(result['rows'])
labels_path = OUT / 'final-labels-browser-result.json'
labels = json.loads(labels_path.read_text(encoding='utf-8'))
assert len(labels['rows']) == 8 and labels['errors'] == []
assert len({(r['width'], r['scale']) for r in labels['rows']}) == 8
assert labels_path.stat().st_mtime > (ROOT / '.local/command-web/main.dart.js').stat().st_mtime
groups['finalPresetAndVisual'] = len(labels['rows'])

assets = ['main.dart.js', 'flutter_bootstrap.js', 'assets/assets/art/ui_icon_regions.json']
assets += [f'assets/assets/art/toon_v7/{p.name}' for p in sorted((ROOT / 'assets/art/toon_v7').glob('*.png'))]
runtime = []
for port, stage in [(8797, 'command-web'), (8798, 'command-fixtures')]:
    for relative in assets:
        local = ROOT / '.local' / stage / relative
        request = urllib.request.Request(f'http://127.0.0.1:{port}/{relative}?proof=command-final',
                                         headers={'Cache-Control': 'no-cache'})
        with urllib.request.urlopen(request, timeout=20) as response:
            data = response.read()
        actual = hashlib.sha256(data).hexdigest()
        assert actual == sha(local), (port, relative)
        if relative.endswith('.png'):
            assert actual == sha(ROOT / 'assets/art/toon_v7' / Path(relative).name)
        runtime.append({'port': port, 'file': relative, 'bytes': len(data), 'sha256': actual})

references = Path('F:/NKW/App/PuzzleKnight/work/UI 샘플 1')
report = {
    'verifiedAt': datetime.now().astimezone().isoformat(),
    'flutterTests': count, 'testWarnings': 0,
    'analyzer': analyzer.strip(), 'sourceContract': contract, 'browserGroups': groups,
    'viewportCases': ['320x568', '360x640', '390x844', '430x932'], 'textScales': [1, 1.3],
    'modelFilesUnchanged': len(models), 'pngFilesUnchanged': len(pngs), 'runtimeFilesMatched': len(runtime),
    'references': {name: sha(references / name) for name in [
        '진화 - 스킬트리1.jpg', '챕터 - 맵 선택1.jpg', '아이템 팝업.jpg', '추가 메뉴.jpg']},
    'uiSourceSha256': {str(p.relative_to(ROOT)): sha(p) for p in sorted((ROOT / 'lib/ui').glob('*.dart'))},
    'runtime': runtime, 'screenshots': len(list(OUT.glob('*-scale-*.png'))),
    'saveProof': 'Isolated guest real UI actions, reload, identical inventory IDs/equipped items/preset names and research/chapter state. User browser storage untouched.',
    'guildProof': 'Existing account/guild client with intercepted local API responses; no real guild writes or live service acceptance claim.',
    'regressionProof': 'Full command/menu/catalog matrices passed before the final three preset display labels. Every UI source except hangar_presets.dart is SHA-identical to that validated revision. A final sequential eight-case matrix rechecks preset save/overwrite cancellation/apply/reload and guild guest/research/chapter visuals against the rebuilt labels. Concurrent browser initialization timed out; final sequential cases are the acceptance result.',
    'keyboardProof': 'Widget tests apply 220px keyboard inset to preset naming and guild forms at all eight cases.',
    'androidBuild': False, 'productionDeployment': False,
}
(OUT / 'final-validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({k: report[k] for k in ['flutterTests', 'browserGroups', 'modelFilesUnchanged', 'runtimeFilesMatched', 'screenshots']}, ensure_ascii=False))
