import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('readiness', ROOT / 'tools/google_play_readiness.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class ReleaseGateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'android/app').mkdir(parents=True)
        (self.root / 'android/app/build.gradle.kts').write_text(
            'applicationId = "com.shootingstar.shootingstar"', encoding='utf-8')
        (self.root / 'pubspec.yaml').write_text('version: 10.0.28+44\n', encoding='utf-8')
        self.config = json.loads((ROOT / 'release/google_play.json').read_text(encoding='utf-8'))
        # start every case from the unconfigured state, whatever the real file holds
        self.config.update(package_id='com.shootingstar.shootingstar', package_confirmed_in_console=False,
                           native_build_authorized=False, support_email=None, publisher_name=None,
                           privacy_url=None, deletion_url=None,
                           ads={**self.config['ads'], 'app_id': None,
                                'rewarded_unit_id': None, 'console_verified': False})

    def row(self, name):
        return next(r for r in gate.inspect(self.root, self.config)['checks'] if r['check'] == name)

    def test_current_unconfigured_state_is_blocked_and_only_platform_is_confirmed(self):
        report = gate.inspect(self.root, self.config)
        self.assertEqual(report['status'], 'blocked')
        self.assertEqual([r['check'] for r in report['checks'] if r['passed']], ['platform'])

    def test_sdk_install_and_manual_flags_cannot_replace_missing_device_evidence(self):
        self.config['native_build_authorized'] = True
        self.config['products'] = [{'product_id': 'supporter', 'console_verified': True}]
        (self.root / 'pubspec.yaml').write_text('version: 10.0.28+44\n  in_app_purchase: any\n  google_mobile_ads: any\n', encoding='utf-8')
        self.assertFalse(self.row('billing_android')['passed'])
        self.assertEqual(gate.inspect(self.root, self.config)['status'], 'blocked')

    def test_package_mismatch_and_google_sample_product_do_not_pass(self):
        self.config.update(package_confirmed_in_console=True, package_id='wrong.package')
        self.config['products'] = [{'product_id': 'android.test.purchased', 'console_verified': True}]
        self.assertFalse(self.row('package')['passed'])
        self.assertFalse(self.row('products')['passed'])

    def test_sample_ad_ids_and_placeholder_urls_do_not_pass(self):
        self.config['ads'] = {'provider': 'admob', 'console_verified': True,
                              'app_id': 'ca-app-pub-3940256099942544~3347511713',
                              'rewarded_unit_id': 'ca-app-pub-3940256099942544/5224354917'}
        self.config['deletion_url'] = 'https://example.com/delete'
        self.assertFalse(self.row('ads_config')['passed'])
        self.assertFalse(self.row('deletion_url')['passed'])

    def test_malformed_stale_and_failed_evidence_is_rejected(self):
        proof = self.root / 'device.json'
        self.config['verification']['billing_android'] = 'device.json'
        for value in [[], {'version': '10.0.27'}, {'results': {'purchase': 'failed'}}]:
            proof.write_text(json.dumps(value), encoding='utf-8')
            self.assertFalse(self.row('billing_android')['passed'])

    def test_complete_structural_evidence_requires_human_review_and_never_says_ready(self):
        self.config.update(package_confirmed_in_console=True, native_build_authorized=True,
            publisher_name='Synthetic QA', support_email='qa@shootingstar.game',
            privacy_url='https://shootingstar.game/privacy', deletion_url='https://shootingstar.game/delete')
        self.config['products'] = [{'product_id': 'supporter', 'console_verified': True}]
        self.config['ads'] = {'provider': 'admob', 'console_verified': True,
            'app_id': 'ca-app-pub-1111111111111111~1111111111',
            'rewarded_unit_id': 'ca-app-pub-1111111111111111/1111111111'}
        (self.root / 'android/app/build.gradle.kts').write_text(
            'applicationId = "com.shootingstar.shootingstar"\nsigningConfig = signingConfigs.getByName("release")', encoding='utf-8')
        (self.root / 'pubspec.yaml').write_text('version: 10.0.28+44\n  in_app_purchase: any\n  google_mobile_ads: any\n', encoding='utf-8')
        for kind, cases in gate.CASES.items():
            ref = kind + '.json'
            (self.root / ref).write_text(json.dumps({'kind': kind, 'platform': 'android_google_play',
                'package_id': self.config['package_id'], 'version': '10.0.28',
                'tested_at': '2026-10-19', 'environment': 'synthetic unit-test fixture only',
                'results': dict.fromkeys(cases, 'passed')}), encoding='utf-8')
            self.config['verification'][kind] = ref
        self.assertEqual(gate.inspect(self.root, self.config)['status'], 'review_required')
        # A future version must obtain matching evidence again.
        (self.root / 'pubspec.yaml').write_text('version: 10.0.29+45\n  in_app_purchase: any\n  google_mobile_ads: any\n', encoding='utf-8')
        self.assertFalse(self.row('billing_android')['passed'])


if __name__ == '__main__':
    unittest.main()
