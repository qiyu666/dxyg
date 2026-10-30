import http.server, socketserver, os, time, json

ROOT = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.join(ROOT, 'shots')
os.makedirs(SHOTS, exist_ok=True)

class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=ROOT, **k)
    def log_message(self, *a):
        pass
    def do_POST(self):
        if self.path.startswith('/shot'):
            n = int(self.headers.get('Content-Length', 0))
            data = self.rfile.read(n)
            name = self.headers.get('X-Name', 'shot')
            fn = os.path.join(SHOTS, f'{name}.png')
            with open(fn, 'wb') as f:
                f.write(data)
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'ok')
        else:
            self.send_response(404); self.end_headers()

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(('127.0.0.1', 8124), H) as httpd:
    print('serving on 8124 with /shot POST')
    httpd.serve_forever()
