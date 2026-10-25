"""Offline release inventory. Never builds, purchases, requests ads or reads keys."""
import argparse
import json
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
CASES = {
    'billing_android': {'purchase', 'cancel', 'failure', 'pending', 'restore', 'duplicate', 'refund'},
    'ads_android': {'consent', 'loaded', 'completed', 'closed', 'failed', 'no_fill', 'duplicate_ssv'},
    'device_soak': {'touch', 'resume', 'background', 'frame_time', 'thermal', 'audio'},
    'user_playtest': {'first_sortie', 'combat_rules', 'failure_reason', 'repeat_play'},
}


def public_https(value):
    if not isinstance(value, str):
        return False
    try:
        url = urlsplit(value)
        host = url.hostname or ''
        return (url.scheme == 'https' and '.' in host and not url.username
                and not url.password and not any(c.isspace() for c in value)
                and host not in {'example.com', 'example.org', 'example.net'}
                and not host.startswith(('127.', '0.', '192.168.', '10.'))
                and not host.endswith(('.example', '.invalid', '.localhost', '.test')))
    except ValueError:
        return False


def inspect(root=ROOT, config=None):
    config = config if config is not None else json.loads(
        (root / 'release/google_play.json').read_text(encoding='utf-8'))
    if not isinstance(config, dict):
        raise ValueError('Configuration must be an object')
    checks = []
    def check(name, ok, detail):
        checks.append({'check': name, 'passed': bool(ok), 'detail': detail})
    text = lambda v: isinstance(v, str) and bool(v.strip())
    pubspec = (root / 'pubspec.yaml').read_text(encoding='utf-8')
    version = re.search(r'^version:\s*([^+\s]+)', pubspec, re.M)[1]
    gradle = (root / 'android/app/build.gradle.kts').read_text(encoding='utf-8')
    package = re.search(r'applicationId\s*=\s*"([^"]+)"', gradle)[1]
    check('platform', config.get('schema') == 1 and config.get('platform') == 'android_google_play'
          and config.get('platform_confirmed') is True, 'Android Google Play 사용자 확정')
    check('package', config.get('package_confirmed_in_console') is True
          and config.get('package_id') == package, '현재 패키지와 Play Console 등록 일치 확인')
    check('native_build', config.get('native_build_authorized') is True,
          '기존 APK 빌드 금지 유지; 명시적 변경 전 네이티브 빌드 없음')
    signing = re.sub(r'//[^\n]*', '', gradle)
    check('release_signing', bool(re.search(r'signingConfig\s*=\s*signingConfigs\.(?:getByName|findByName)\("(?:release|upload)"\)', signing)),
          '현재 출시 서명 미구성; 실제 업로드 인증서 일치는 별도 검토')
    products = config.get('products')
    products_ok = isinstance(products, list) and len(products) > 0
    if products_ok:
        ids = [p.get('product_id') for p in products if isinstance(p, dict)]
        products_ok = (len(ids) == len(products) and all(text(v) and not v.startswith('android.test.') for v in ids)
                       and len(set(ids)) == len(ids) and all(p.get('console_verified') is True for p in products))
    check('products', products_ok, '실제 등록 상품 ID와 Console 확인; 제안/테스트 ID는 미완료')
    check('billing_sdk', bool(re.search(r'^  in_app_purchase:', pubspec, re.M)), '실제 Flutter Play 결제 연결 필요')
    ads = config.get('ads')
    ads_ok = (isinstance(ads, dict) and ads.get('provider') == 'admob'
              and ads.get('console_verified') is True
              and all(text(ads.get(k)) and '3940256099942544' not in ads[k]
                      for k in ('app_id', 'rewarded_unit_id'))
              and bool(re.fullmatch(r'ca-app-pub-\d{16}~\d{10}', ads['app_id']))
              and bool(re.fullmatch(r'ca-app-pub-\d{16}/\d{10}', ads['rewarded_unit_id']))
              and ads['app_id'].split('~')[0] == ads['rewarded_unit_id'].split('/')[0])
    check('ads_config', ads_ok, '제공자·실제 앱/광고 단위 ID 확정; Google 샘플 ID는 출시 설정 불가')
    check('ads_sdk', bool(re.search(r'^  google_mobile_ads:', pubspec, re.M)), '현재 사전 검사 지원 후보는 AdMob; 다른 제공자 선택 시 기준 갱신')
    check('publisher', text(config.get('publisher_name')), '실제 게시자/개인정보 처리 주체')
    check('support', text(config.get('support_email')) and bool(re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', config.get('support_email', '') or '')), '작동하는 고객지원 연락처 확인 필요')
    for name in ('privacy_url', 'deletion_url'):
        check(name, public_https(config.get(name)), '실제 HTTPS 주소 필요; 이 검사는 외부 URL을 요청하지 않음')
    verification = config.get('verification')
    verification = verification if isinstance(verification, dict) else {}
    for kind, required in CASES.items():
        ok = False
        ref = verification.get(kind)
        if text(ref):
            try:
                path = (root / ref).resolve()
                if path.is_relative_to(root.resolve()):
                    evidence = json.loads(path.read_text(encoding='utf-8'))
                    if not isinstance(evidence, dict):
                        raise ValueError('Evidence must be an object')
                    results = evidence.get('results')
                    ok = (evidence.get('platform') == 'android_google_play'
                          and evidence.get('package_id') == package
                          and evidence.get('version') == version
                          and evidence.get('kind') == kind
                          and text(evidence.get('tested_at'))
                          and text(evidence.get('environment'))
                          and isinstance(results, dict)
                          and all(results.get(case) == 'passed' for case in required))
            except (OSError, ValueError, TypeError):
                pass
        check(kind, ok, '현재 버전의 실제 검증 기록 필요: ' + ', '.join(sorted(required)))
    return {'version': 'v' + version, 'platform': 'android_google_play',
            'status': 'review_required' if all(c['passed'] for c in checks) else 'blocked',
            'checks': checks,
            'note': '모든 항목이 갖춰져도 증거/URL/정책의 수동 검토가 필요하며, 이 도구는 스토어 출시를 승인하지 않습니다.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()
    try:
        report = inspect()
    except (OSError, ValueError, TypeError, KeyError, IndexError):
        print('Release configuration invalid or unavailable.', file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(report['version'], report['status'])
        for row in report['checks']:
            print(('OK' if row['passed'] else 'BLOCK'), row['check'], row['detail'])
        print(report['note'])
    return 0 if report['status'] == 'review_required' else 2


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    sys.exit(main())
