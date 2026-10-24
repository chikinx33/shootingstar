"""Fast checks for stale-build prevention, without compiling Flutter."""
import sys
from pathlib import Path
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from web_build_state import input_hash, record, reusable


class BuildReuseTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.write('lib/main.dart', 'game')
        self.write('assets/hero.png', 'original image')
        self.write('web/index.html', 'page')
        self.write('pubspec.yaml', 'version: 10.0.0+16')
        self.write('build/web/main.dart.js', 'compiled')

    def write(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding='utf-8')

    def test_image_change_invalidates_even_without_dart_change(self):
        record(self.root)
        self.assertTrue(reusable(self.root))
        self.write('assets/hero.png', 'new image')
        self.assertFalse(reusable(self.root))

    def test_docs_and_server_changes_do_not_recompile_client(self):
        before = input_hash(self.root)
        self.write('docs/notes.md', 'note')
        self.write('server/src/worker.mjs', 'server change')
        self.assertEqual(input_hash(self.root), before)

    def test_replaced_or_missing_output_is_not_reused(self):
        record(self.root)
        self.write('build/web/main.dart.js', 'other entrypoint with same version')
        self.assertFalse(reusable(self.root))
        record(self.root)
        (self.root / 'build/web/main.dart.js').unlink()
        self.assertFalse(reusable(self.root))

    def test_sdk_change_invalidates_build(self):
        self.write('sdk.json', 'SDK A')
        sdk = self.root / 'sdk.json'
        record(self.root, sdk)
        self.assertTrue(reusable(self.root, sdk))
        self.write('sdk.json', 'SDK B')
        self.assertFalse(reusable(self.root, sdk))


if __name__ == '__main__':
    unittest.main()
