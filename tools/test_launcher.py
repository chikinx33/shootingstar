"""Exercise loopback serving and duplicate-launch reuse without opening a browser."""
import json
from pathlib import Path
import socket
import subprocess
import sys
import time
import urllib.request

root = Path(__file__).resolve().parents[1]
with socket.socket() as sock:
    sock.bind(('127.0.0.1', 0))
    port = sock.getsockname()[1]
command = [sys.executable, str(root / 'tools' / 'play_web.py'), '--no-browser', '--port', str(port)]
server = subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
try:
    payload = None
    for _ in range(50):
        try:
            with urllib.request.urlopen(f'http://127.0.0.1:{port}/version.json', timeout=.2) as response:
                payload = json.load(response)
            break
        except OSError:
            time.sleep(.1)
    assert payload and payload['app_name'] == 'shootingstar'
    duplicate = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=10)
    assert duplicate.returncode == 0, duplicate.stderr
    assert 'already running' in duplicate.stdout
    print('PASS loopback launcher serves the web build and reuses an existing game server')
finally:
    server.terminate()
    server.wait(timeout=5)
