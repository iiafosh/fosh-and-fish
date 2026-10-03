#!/usr/bin/env python3
"""Serve the web export (build/web) locally, e.g. to open it on a phone on
the same Wi-Fi: python tools/serve_web.py  ->  http://<this-pc-ip>:8060"""
import http.server
import os
import socket
import socketserver

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")
PORT = 8060


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      ".wasm": "application/wasm", ".pck": "application/octet-stream",
                      ".js": "text/javascript", ".webmanifest": "application/manifest+json"}

    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def end_headers(self):
        # cross-origin isolation (harmless for the single-threaded build) + no stale caches while testing
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(("0.0.0.0", PORT), Handler) as httpd:
        print("Virtual Fisher web build:")
        print("  this PC : http://localhost:%d" % PORT)
        print("  phone   : http://%s:%d  (same Wi-Fi)" % (lan_ip(), PORT))
        httpd.serve_forever()
