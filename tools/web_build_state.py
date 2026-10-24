"""Content fingerprints for reusing the standard web build safely."""
import hashlib
import json
from pathlib import Path

RECEIPT = '.local/web-build-receipt.json'


def tree_hash(paths, root):
    digest = hashlib.sha256()
    for path in sorted(paths):
        digest.update(path.relative_to(root).as_posix().encode())
        digest.update(b'\0')
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def input_hash(root, sdk_metadata=None):
    paths = [p for folder in ('lib', 'web', 'assets')
             for p in (root / folder).rglob('*') if p.is_file()]
    paths += [root / name for name in ('pubspec.yaml', 'pubspec.lock',
              '.dart_tool/package_config.json') if (root / name).is_file()]
    digest = tree_hash(paths, root)
    if sdk_metadata and sdk_metadata.is_file():
        digest += hashlib.sha256(sdk_metadata.read_bytes()).hexdigest()
    return digest


def output_hash(root):
    web = root / 'build/web'
    return tree_hash([p for p in web.rglob('*') if p.is_file()], web)


def reusable(root, sdk_metadata=None):
    try:
        receipt = json.loads((root / RECEIPT).read_text(encoding='utf-8'))
        return (root / 'build/web/main.dart.js').is_file() and (
            receipt['inputs'] == input_hash(root, sdk_metadata)
            and receipt['outputs'] == output_hash(root))
    except (OSError, ValueError, KeyError):
        return False


def record(root, sdk_metadata=None):
    receipt = root / RECEIPT
    receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt.write_text(json.dumps({'inputs': input_hash(root, sdk_metadata),
        'outputs': output_hash(root)}, indent=2), encoding='utf-8')
