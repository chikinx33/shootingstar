"""Fast web test: reuse/build once, one smoke check, optional deployment."""
import argparse
from contextlib import contextmanager
from datetime import datetime
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from threading import Thread
import time
import urllib.request
import urllib.error

from web_build_state import record, reusable

ROOT = Path(__file__).resolve().parents[1]


def prior_access_evidence(root):
    """Reuse an already observed Access block from this project's reports."""
    for path in sorted((root / '.local/quick-web').glob('*/report.json'), reverse=True):
        try:
            prior = json.loads(path.read_text(encoding='utf-8'))
        except (OSError, ValueError):
            continue
        if prior.get('status') == 'passed' and prior.get('publicStaticCheck', '').startswith('Access login required'):
            return path
    return None


@contextmanager
def preview():
    class Server(ThreadingHTTPServer):
        request_queue_size = 128
        daemon_threads = True
    class Handler(SimpleHTTPRequestHandler):
        def log_message(self, *_args):
            pass
    with Server(('127.0.0.1', 0), partial(Handler, directory=str(ROOT / 'build/web'))) as server:
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            yield f'http://127.0.0.1:{server.server_port}'
        finally:
            server.shutdown()
            thread.join()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version')
    parser.add_argument('--deploy', action='store_true')
    parser.add_argument('--verify-only', metavar='WORKER_ID', help='Resume verification after upload without building/testing/uploading again')
    parser.add_argument('--build-only', action='store_true')
    parser.add_argument('--checks-only', action='store_true', help='Source checks and explicitly selected tests only; no web build, browser, or deployment')
    parser.add_argument('--test-name', help='Run only tests matching this plain-name substring; requires --test')
    parser.add_argument('--analyze', action='store_true', help='Analyze lib once with Dart; no stalled Flutter analyzer retries')
    parser.add_argument('--access-blocked-report', type=Path, help='Reuse an already recorded Access block; still verify the active Worker and API')
    parser.add_argument('--test', action='append', default=[], help='Only the related Flutter test file; repeat as needed')
    args = parser.parse_args()
    if args.checks_only and (args.deploy or args.build_only or args.verify_only):
        parser.error('--checks-only cannot be combined with build/deploy/verify modes')
    if args.test_name and not args.test:
        parser.error('--test-name requires at least one --test file')
    if args.deploy and args.build_only:
        parser.error('--deploy cannot skip the smoke check')
    if args.access_blocked_report and not (args.deploy or args.verify_only):
        parser.error('--access-blocked-report requires deployment verification')
    if (args.deploy or args.verify_only) and not args.access_blocked_report:
        args.access_blocked_report = prior_access_evidence(ROOT)
    if args.access_blocked_report:
        prior = json.loads(args.access_blocked_report.read_text(encoding='utf-8'))
        if not prior.get('publicStaticCheck', '').startswith('Access login required'):
            parser.error('The supplied report does not record an Access block')
    if args.verify_only and (args.deploy or args.build_only or args.version or args.analyze or args.test):
        parser.error('--verify-only cannot be combined with build/deploy options')
    env = {**os.environ, 'PUB_CACHE': str(ROOT / '.pub-cache')}
    needs_flutter = not args.checks_only or bool(args.test) or args.analyze
    flutter = shutil.which('flutter') if needs_flutter else None
    if needs_flutter and not flutter:
        raise RuntimeError('Flutter is not on PATH')
    sdk = Path(flutter).resolve().parents[1] / 'bin/cache/flutter.version.json' if flutter else None
    run_dir = ROOT / '.local/quick-web' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    run_dir.mkdir(parents=True)
    report = {'startedAt': datetime.now().astimezone().isoformat(), 'steps': [], 'status': 'running',
              'mode': 'checks-only' if args.checks_only else 'verify-only' if args.verify_only else 'web',
              'requestedTests': args.test, 'testName': args.test_name,
              'buildSkipped': bool(args.checks_only or args.verify_only),
              'browserSkipped': bool(args.checks_only or args.build_only or args.verify_only)}
    started = time.perf_counter()

    def run(name, command, timeout, cwd=ROOT):
        log = run_dir / (name + '.log')
        stamp = time.perf_counter()
        print(f'{name}...', flush=True)
        # Only repository-owned commands/validated version numbers are passed.
        cmd = subprocess.list2cmdline(command) if os.name == 'nt' and command[0].endswith(('.bat', '.cmd')) else command
        if isinstance(cmd, str) and any(re.search(r'[\r\n&|<>^%!]', item) for item in command):
            raise ValueError('Shell metacharacters are not allowed in batch command arguments')
        with log.open('w', encoding='utf-8') as output:
            process = subprocess.Popen(cmd, cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT,
                                       stdin=subprocess.DEVNULL, shell=isinstance(cmd, str))
            try:
                code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                if os.name == 'nt':
                    subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], capture_output=True)
                else:
                    process.kill()
                process.wait()
                raise RuntimeError(f'{name} exceeded {timeout}s; stopped this command. See {log}')
        seconds = round(time.perf_counter() - stamp, 2)
        report['steps'].append({'name': name, 'seconds': seconds, 'exitCode': code, 'log': str(log)})
        print(f'{name}: {seconds}s', flush=True)
        if code:
            raise RuntimeError(log.read_text(encoding='utf-8', errors='replace')[-2200:])
        return log.read_text(encoding='utf-8', errors='replace')

    try:
        if not args.verify_only:
            run('version', [sys.executable, 'tools/sync_version.py'] + (['--version', args.version] if args.version else []), 10)
        version = re.search(r'^version: (.+)$', (ROOT / 'pubspec.yaml').read_text(encoding='utf-8'), re.M)[1].strip()
        report['version'] = version
        report['displayVersion'] = 'v' + version.split('+')[0]
        env['QA_VERSION'] = version.split('+')[0]
        evidence = ROOT / 'tools/qa/evidence/quick-web' / version.replace('+', '-')
        env['QA_EVIDENCE_DIR'] = str(evidence)
        if not args.verify_only:
            run('ui-contract', [sys.executable, 'tools/qa/check_ui_contract.py'], 15)
        if args.analyze:
            run('dart-analyze', [shutil.which('dart'), 'analyze', 'lib'], 45)
        if args.test:
            command = [flutter, '--no-version-check', 'test', '--no-pub', *args.test]
            if args.test_name:
                command += ['--plain-name', args.test_name]
            run('related-tests', command, 120)
        if not args.verify_only and not args.checks_only:
            stamp = time.perf_counter()
            reuse = reusable(ROOT, sdk)
            report['reuseCheckSeconds'] = round(time.perf_counter() - stamp, 2)
            report['buildReused'] = reuse
            if reuse:
                print('build: unchanged inputs and outputs; reusing existing release', flush=True)
            else:
                run('build', [flutter, '--no-version-check', 'build', 'web', '--release', '--no-pub',
                    '--no-web-resources-cdn', '--no-wasm-dry-run', '-O2', '--target', 'lib/main.dart'], 180)
                record(ROOT, sdk)
        if not args.build_only and not args.verify_only and not args.checks_only:
            with preview() as url:
                env['QA_URL'] = url
                run('smoke', [shutil.which('node'), 'tools/qa/quick-smoke.cjs'], 45)
        if args.deploy or args.verify_only:
            if args.deploy:
                text = run('deploy', [shutil.which('npm'), 'run', 'deploy', '--', '--tag', 'v' + version.replace('+', '-'),
                    '--message', 'Quick web test ' + report['displayVersion']], 120, ROOT / 'server')
                worker = re.search(r'Current Version ID:\s*([a-f0-9-]+)', text)[1]
            else:
                worker = args.verify_only
            report['workerVersionId'] = worker
            deployments = json.loads(run('active-deployment', [shutil.which('npx'), '--no-install',
                'wrangler', 'deployments', 'list', '--json'], 30, ROOT / 'server'))
            latest = max(deployments, key=lambda d: d['created_on'])
            assert latest['versions'] == [{'version_id': worker, 'percentage': 100}], 'New version is not active at 100%'
            report['activeTrafficPercentage'] = 100
            base = 'https://shootingstar-online.chikinx1.workers.dev'
            def fetch(route):
                # A plain URL returned an older response immediately after rollout.
                req = urllib.request.Request(base + route + '?verify=' + str(time.time_ns()),
                    headers={'User-Agent': 'Mozilla/5.0', 'Cache-Control': 'no-cache'})
                with urllib.request.urlopen(req, timeout=10) as response:
                    return response.headers.get('Content-Type', ''), response.read()
            stamp = time.perf_counter()
            report['healthVersionAttempts'] = []
            for attempt in range(3):
                _, body = fetch('/api/health')
                health = json.loads(body)
                report['healthVersionAttempts'].append(health.get('version'))
                if health.get('version') == version.split('+')[0]:
                    break
                if attempt < 2:
                    time.sleep(1)
            assert health.get('ok') and health.get('version') == version.split('+')[0] and health.get('storage') == 'D1', health
            report['health'] = health
            if args.access_blocked_report:
                report['publicStaticCheck'] = 'Access login required; reused prior evidence without another request'
                report['accessEvidenceReport'] = str(args.access_blocked_report.resolve())
            else:
                try:
                    typ, body = fetch('/version.json')
                except urllib.error.HTTPError as error:
                    if error.code not in (401, 403):
                        raise
                    typ, body = 'auth-required', b''
                if typ == 'auth-required' or ('text/html' in typ and b'Cloudflare Access' in body[:1000]):
                    report['publicStaticCheck'] = 'Access login required; no repeated static or browser retries'
                else:
                    meta = json.loads(body)
                    assert meta['version'] + '+' + meta['build_number'] == version
                    _, body = fetch('/main.dart.js')
                    assert body == (ROOT / 'build/web/main.dart.js').read_bytes(), 'Public JavaScript does not match'
                    report['publicStaticCheck'] = 'Version and JavaScript match'
            report['publicCheckSeconds'] = round(time.perf_counter() - stamp, 2)
        elif not args.checks_only:
            run('build-guard', [sys.executable, 'tools/verify_web_release.py'], 15)
        if args.checks_only:
            print('checks-only: source/selected checks passed; build and browser were not run', flush=True)
        report['status'] = 'passed'
    finally:
        if report['status'] == 'running':
            report['status'] = 'failed'
        report['totalSeconds'] = round(time.perf_counter() - started, 2)
        payload = json.dumps(report, ensure_ascii=False, indent=2)
        (run_dir / 'report.json').write_text(payload, encoding='utf-8')
        (ROOT / '.local/quick-web/last-run.json').write_text(payload, encoding='utf-8')
        print(f"{report['status']}: {report['totalSeconds']}s; {run_dir / 'report.json'}", flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
