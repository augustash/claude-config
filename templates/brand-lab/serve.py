"""A brand lab's local server (skills/brand-lab): serves the folder, and saves the lab's slider settings to settings.json
so they survive refreshes and browser storage resets, the fleur's dragged curves to eagle/fleur.json, the fonts he's marked to fonts.json, his finalist picks to votes.json, and his dragged letter spacing to spacing.json. Run: python3 serve.py [port]"""
import http.server, json, os, sys

ROOT = os.path.dirname(os.path.abspath(__file__))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=ROOT, **k)

    def do_POST(self):
        path = self.path.split('?')[0]
        if path not in ('/settings.json', '/eagle/fleur.json', '/fonts.json', '/votes.json', '/spacing.json'):
            return self.send_error(404)
        n = int(self.headers.get('Content-Length') or 0)
        if n > 20000:
            return self.send_error(413)
        try:
            data = json.loads(self.rfile.read(n))
            assert isinstance(data, dict)
        except Exception:
            return self.send_error(400)
        with open(os.path.join(ROOT, path.lstrip('/')), 'w') as f:
            json.dump(data, f, indent=1, sort_keys=True)
        self.send_response(204)
        self.end_headers()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, *a):
        pass


port = int(sys.argv[1]) if len(sys.argv) > 1 else 8766
http.server.ThreadingHTTPServer(('127.0.0.1', port), Handler).serve_forever()
