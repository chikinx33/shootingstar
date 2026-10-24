"""Double-click launcher. Standard library only; always binds to loopback."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import socket
import urllib.error
import urllib.request
import webbrowser
from guild_service import GuildService
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / 'build' / 'web'
# Ship editor (developer mode) reads and writes this project file directly.
SHIP_LAYOUTS = ROOT / 'assets' / 'data' / 'ship_layouts.json'
SHIP_LAYOUTS_ROUTE = '/editor/ship-layouts'
SHIP_LAYOUTS_BACKUP = ROOT / '.local' / 'ship-layouts-backup'

class GameHandler(SimpleHTTPRequestHandler):
    service = None
    online_api = "https://shootingstar-online.chikinx1.workers.dev"

    def _send_json(self, status, payload):
        body = (payload if isinstance(payload, bytes) else json.dumps(payload, ensure_ascii=False).encode('utf-8'))
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers(); self.wfile.write(body)

    def do_GET(self):
        if urlparse(self.path).path == SHIP_LAYOUTS_ROUTE:
            if not SHIP_LAYOUTS.is_file():
                self.send_error(404); return
            self._send_json(200, SHIP_LAYOUTS.read_bytes()); return
        super().do_GET()

    def do_PUT(self):
        if urlparse(self.path).path != SHIP_LAYOUTS_ROUTE:
            self.send_error(404); return
        origin = self.headers.get('Origin')
        if origin and urlparse(origin).netloc != self.headers.get('Host'):
            self.send_error(403); return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if length <= 0 or length > 1_000_000: raise ValueError('layout size')
            data = json.loads(self.rfile.read(length))
            if not isinstance(data, dict) or not isinstance(data.get('ships'), dict) or not isinstance(data.get('revision'), int):
                raise ValueError('layout shape')
            text = json.dumps(data, ensure_ascii=False, indent=2) + '\n'
            if SHIP_LAYOUTS.is_file():
                SHIP_LAYOUTS_BACKUP.mkdir(parents=True, exist_ok=True)
                previous = json.loads(SHIP_LAYOUTS.read_text(encoding='utf-8')).get('revision', 0)
                (SHIP_LAYOUTS_BACKUP / f'ship_layouts.r{previous}.json').write_bytes(SHIP_LAYOUTS.read_bytes())
            temp = SHIP_LAYOUTS.with_suffix('.json.tmp')
            temp.write_text(text, encoding='utf-8')
            temp.replace(SHIP_LAYOUTS)
            self._send_json(200, {'ok': True, 'revision': data['revision']})
        except (ValueError, TypeError, OSError) as error:
            self._send_json(400, {'error': str(error)})

    def do_POST(self):
        if not self.path.startswith('/api/'):
            self.send_error(404); return
        origin = self.headers.get('Origin')
        if origin and urlparse(origin).netloc != self.headers.get('Host'):
            self.send_error(403); return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if length < 0 or length > 450000: raise ValueError('요청이 너무 큽니다.')
            raw = self.rfile.read(length) or b'{}'
            if self.service is None:
                # Same-origin loopback bridge preserves the existing browser save.
                # The upstream is fixed/configured by the launcher, never by an HTTP request.
                headers = {'Content-Type':'application/json', 'X-Client':'web', 'User-Agent':'Shootingstar/4.0'}
                for key in ('Cookie', 'Authorization'):
                    if self.headers.get(key): headers[key] = self.headers[key]
                request = urllib.request.Request(self.online_api + self.path, data=raw, headers=headers, method='POST')
                try:
                    response = urllib.request.urlopen(request, timeout=15)
                except urllib.error.HTTPError as error:
                    response = error
                with response:
                    body = response.read(500000)
                    self.send_response(response.status)
                    if response.headers.get('Set-Cookie'):
                        self.send_header('Set-Cookie', response.headers['Set-Cookie'])
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers(); self.wfile.write(body)
                return
            data = json.loads(raw)
            result = self.service.handle(self.path[5:], data, self.headers.get('Authorization', '').removeprefix('Bearer '))
            body = json.dumps(result, ensure_ascii=False).encode('utf-8')
            self.send_response(200)
        except (OSError, urllib.error.URLError):
            body = json.dumps({'error':'온라인 서버에 연결하지 못했습니다. 기기 진행은 유지됩니다.'}, ensure_ascii=False).encode('utf-8')
            self.send_response(503)
        except (ValueError, TypeError, KeyError, OverflowError) as error:
            body = json.dumps({'error':str(error)}, ensure_ascii=False).encode('utf-8')
            self.send_response(400)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers(); self.wfile.write(body)

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

    def log_message(self, *_args):
        pass

class LocalServer(ThreadingHTTPServer):
    allow_reuse_address = False
    allow_reuse_port = False

    def server_bind(self):
        if hasattr(socket, 'SO_EXCLUSIVEADDRUSE'):
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        super().server_bind()

def main():
    parser = argparse.ArgumentParser(description='Open Shootingstar on this computer only.')
    parser.add_argument('--port', type=int, default=8787)
    parser.add_argument('--no-browser', action='store_true', help='For local verification.')
    parser.add_argument('--guild-db', type=Path, default=ROOT / '.local' / 'guild.sqlite3', help='Guild database path (use a separate file for tests).')
    parser.add_argument('--legacy-guild', action='store_true', help='Historical v3 API only; not compatible with the online v4 client.')
    parser.add_argument('--online-api', default=GameHandler.online_api, help='Online API base; loopback URL permitted for development.')
    args = parser.parse_args()
    upstream = urlparse(args.online_api)
    if upstream.scheme != 'https' and not (upstream.scheme == 'http' and upstream.hostname in ('127.0.0.1','localhost')):
        parser.error('Online API requires HTTPS or loopback for development.')
    GameHandler.service = GuildService(args.guild_db) if args.legacy_guild else None
    GameHandler.online_api = args.online_api.rstrip('/')
    if not 1 <= args.port <= 65526:
        parser.error('port must be between 1 and 65526')
    if not (WEB / 'main.dart.js').is_file():
        print('Web build is missing. Run tools\\run.ps1 build-web first.', flush=True)
        return 1
    handler = partial(GameHandler, directory=str(WEB))
    server = None
    for port in range(args.port, args.port + 10):
        url = f'http://127.0.0.1:{port}'
        try:
            server = LocalServer(('127.0.0.1', port), handler)
            break
        except OSError:
            try:
                with urllib.request.urlopen(url + '/version.json', timeout=1) as response:
                    ours = json.load(response).get('app_name') == 'shootingstar'
                if ours:
                    print(f'Shootingstar is already running: {url}', flush=True)
                    if not args.no_browser:
                        webbrowser.open(url)
                    return 0
            except (OSError, ValueError, urllib.error.URLError):
                pass
    if server is None:
        print('Could not find a free local port. Close an older game window and try again.', flush=True)
        return 1
    print(f'Shootingstar: {url}', flush=True)
    print('Only this computer can connect. Keep this window open while playing.', flush=True)
    print('Close this window or press Ctrl+C to stop.', flush=True)
    if not args.no_browser:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
