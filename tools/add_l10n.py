"""Append Korean→English pairs to lib/l10n/english_catalog.dart (skips keys
that already exist). Input: a UTF-8 JSON object file.

  python tools/add_l10n.py pairs.json
"""
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'lib/l10n/english_catalog.dart'


def main():
    pairs = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
    src = CATALOG.read_text(encoding='utf-8')
    keys = set(json.loads('"' + k + '"') for k in re.findall(r'^\s*"((?:[^"\\]|\\.)*)"\s*:', src, re.M))
    add = {k: v for k, v in pairs.items() if k not in keys}
    lines = ''.join(f'  {json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)},\n'
                    for k, v in add.items())
    idx = src.rstrip().rfind('};')
    CATALOG.write_text(src[:idx] + lines + src[idx:], encoding='utf-8')
    print(f'added {len(add)} of {len(pairs)}')


if __name__ == '__main__':
    main()
