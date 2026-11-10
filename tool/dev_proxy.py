#!/usr/bin/env python3
"""Serve the Flutter web build and the local API from one origin.

The customer API has no CORS on purpose (its clients are native apps), so the
web preview of the app must be served from the same origin as the API:

    python3 tool/dev_proxy.py --root build/web --api http://127.0.0.1:8000 --port 8080

`/api/` and `/media/` are forwarded to the backend unchanged (all headers,
including X-GD-* and Idempotency-Key); everything else is a static file, with
`index.html` for unknown paths (client-side routes). Local development only.
"""

import argparse
import http.server
import os
import socketserver
import urllib.error
import urllib.request

HOP_BY_HOP = {"connection", "keep-alive", "proxy-authenticate", "proxy-authorization", "te", "trailers",
              "transfer-encoding", "upgrade", "host", "content-length", "accept-encoding"}


def make_handler(root: str, api: str):
    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=root, **kwargs)

        def log_message(self, fmt, *args):  # quieter log
            pass

        def _proxy(self):
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length) if length else None
            req = urllib.request.Request(api + self.path, data=body, method=self.command)
            for key, value in self.headers.items():
                if key.lower() not in HOP_BY_HOP:
                    req.add_header(key, value)
            req.add_header("Host", "localhost")
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            try:
                resp = opener.open(req, timeout=60)
                status, headers, data = resp.status, resp.headers, resp.read()
            except urllib.error.HTTPError as err:
                status, headers, data = err.code, err.headers, err.read()
            self.send_response(status)
            for key, value in headers.items():
                if key.lower() not in HOP_BY_HOP:
                    self.send_header(key, value)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def _is_api(self):
            return self.path.startswith("/api/") or self.path.startswith("/media/")

        def do_GET(self):
            if self._is_api():
                return self._proxy()
            path = self.translate_path(self.path.split("?")[0])
            if not os.path.exists(path) or (os.path.isdir(path) and not os.path.exists(os.path.join(path, "index.html"))):
                self.path = "/index.html"
            return super().do_GET()

        def do_POST(self):
            return self._proxy()

        do_PUT = do_PATCH = do_DELETE = do_POST

    return Handler


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="build/web")
    parser.add_argument("--api", default="http://127.0.0.1:8000")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()
    socketserver.ThreadingTCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(("127.0.0.1", args.port), make_handler(os.path.abspath(args.root), args.api.rstrip("/"))) as httpd:
        print(f"Serving {args.root} with the API {args.api} on http://localhost:{args.port}")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
