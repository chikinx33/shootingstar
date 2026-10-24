"""Reject stale web builds before publishing to the shared test server."""
from pathlib import Path
import json
import re
import subprocess
import sys
import shutil

from web_build_state import RECEIPT, reusable

ROOT = Path(__file__).resolve().parents[1]
subprocess.run([sys.executable, str(ROOT / 'tools/sync_version.py'), '--check'], check=True)
name, build = re.search(r'^version: (\d+\.\d+\.\d+)\+(\d+)\s*$',
    (ROOT / 'pubspec.yaml').read_text(encoding='utf-8'), re.M).groups()
web = ROOT / 'build/web'
metadata = json.loads((web / 'version.json').read_text(encoding='utf-8'))
assert metadata['version'] == name and metadata['build_number'] == build, 'Stale web version.json; rebuild first'
label = f'v{name}'
assert label in (web / 'index.html').read_text(encoding='utf-8'), 'Stale loading-screen version'
js = web / 'main.dart.js'
assert label.encode() in js.read_bytes(), 'Compiled game footer version does not match pubspec'
if (ROOT / RECEIPT).is_file():
    flutter = shutil.which('flutter')
    sdk = Path(flutter).resolve().parents[1] / 'bin/cache/flutter.version.json' if flutter else None
    assert reusable(ROOT, sdk), 'Build inputs or outputs changed; run tools/quick_web.py first'
else:
    inputs = [p for folder in ('lib', 'web', 'assets')
              for p in (ROOT / folder).rglob('*') if p.is_file()]
    inputs += [ROOT / name for name in ('pubspec.yaml', 'pubspec.lock')]
    newer = [str(p.relative_to(ROOT)) for p in inputs if p.stat().st_mtime > js.stat().st_mtime]
    assert not newer, 'Source/assets changed after web compilation: ' + ', '.join(newer)
print(f'Web release ready: {label}')
