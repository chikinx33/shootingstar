"""Local Flutter preview with a queue sized for concurrent mobile QA browsers."""
import argparse,functools
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path

class PreviewServer(ThreadingHTTPServer):
    request_queue_size=128

class Handler(SimpleHTTPRequestHandler):
    protocol_version='HTTP/1.1'
    def end_headers(self):
        self.send_header('Cache-Control','no-cache')
        super().end_headers()

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,required=True)
    parser.add_argument('--directory',required=True);args=parser.parse_args()
    root=Path(args.directory).resolve();workspace=Path(__file__).resolve().parents[2]
    assert root.is_relative_to(workspace/'.local') and root.is_dir()
    with PreviewServer(('127.0.0.1',args.port),functools.partial(Handler,directory=str(root))) as server:
        print(f'Preview {args.port}: {root}',flush=True);server.serve_forever()
