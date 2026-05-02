import http.server
import socket
import socketserver
import os

PORT = 5000
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def do_GET(self):
        path = self.path.split("?")[0]
        full_path = os.path.join(WEB_DIR, path.lstrip("/"))
        if not os.path.exists(full_path) or os.path.isdir(full_path):
            self.path = "/index.html"
        super().do_GET()

    def log_message(self, format, *args):
        pass

class ReusePortTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

    def server_bind(self):
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        super().server_bind()

with ReusePortTCPServer(("0.0.0.0", PORT), Handler) as httpd:
    print(f"Serving Mezanya on port {PORT}")
    httpd.serve_forever()
