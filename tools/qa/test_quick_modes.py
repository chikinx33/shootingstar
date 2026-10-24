"""Bounded runner checks: source-only has no Flutter/build/browser dependency."""
import contextlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import quick_web

class QuickModesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.write('pubspec.yaml', 'version: 1.0.0+1\n')
        self.write('tools/sync_version.py', 'print("fixture version checked")\n')
        self.write('tools/qa/check_ui_contract.py', 'print("fixture contract checked")\n')

    def write(self, name, value):
        p = self.root / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(value, encoding='utf-8')
        return p

    def invoke(self, args, flutter=None):
        with patch.object(quick_web, 'ROOT', self.root), \
             patch.object(sys, 'argv', ['quick_web.py', *args]), \
             patch.object(quick_web.shutil, 'which', return_value=flutter), \
             patch.object(quick_web, 'preview') as preview, \
             patch.object(quick_web, 'reusable') as reuse, \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(quick_web.main(), 0)
            preview.assert_not_called()
            reuse.assert_not_called()
        return json.loads((self.root / '.local/quick-web/last-run.json').read_text(encoding='utf-8'))

    def test_source_only_works_without_sdk_or_build(self):
        report = self.invoke(['--checks-only'])
        self.assertEqual(report['status'], 'passed')
        self.assertEqual(report['mode'], 'checks-only')
        self.assertTrue(report['buildSkipped'])
        self.assertTrue(report['browserSkipped'])
        self.assertEqual([s['name'] for s in report['steps']], ['version','ui-contract'])
        self.assertFalse((self.root / 'build').exists())

    @unittest.skipUnless(os.name == 'nt', 'Windows launcher integration')
    def test_only_requested_file_and_plain_name_reach_flutter(self):
        flutter = self.write('flutter.bat', '@echo off\necho %*\nexit /b 0\n')
        report = self.invoke(['--checks-only','--test','test/one.dart','--test-name','small phone'], str(flutter))
        text = Path(report['steps'][-1]['log']).read_text(encoding='utf-8')
        self.assertIn('test/one.dart --plain-name "small phone"', text)
        self.assertEqual(report['testName'], 'small phone')
        self.assertEqual(report['requestedTests'], ['test/one.dart'])
        self.assertEqual(len(report['steps']), 3)

    def test_invalid_modes_fail_before_any_execution(self):
        for args in [['--checks-only','--deploy'],['--checks-only','--build-only'],
                     ['--checks-only','--verify-only','x'],['--test-name','case']]:
            with self.subTest(args=args), patch.object(sys,'argv',['quick_web.py',*args]), \
                 patch.object(quick_web.subprocess,'Popen') as run, \
                 contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    quick_web.main()
                self.assertEqual(error.exception.code, 2)
                run.assert_not_called()

    def test_access_evidence_skips_bad_failed_and_nonblocked_reports(self):
        expected = self.write('.local/quick-web/001/report.json', json.dumps({'status':'passed','publicStaticCheck':'Access login required; recorded'}))
        self.write('.local/quick-web/002/report.json', json.dumps({'status':'failed','publicStaticCheck':'Access login required'}))
        self.write('.local/quick-web/003/report.json', '{broken')
        self.write('.local/quick-web/004/report.json', json.dumps({'status':'passed'}))
        self.assertEqual(quick_web.prior_access_evidence(self.root), expected)

    def test_no_access_evidence_does_not_claim_a_block(self):
        self.assertIsNone(quick_web.prior_access_evidence(self.root))

if __name__ == '__main__':
    unittest.main()
