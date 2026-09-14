#!/usr/bin/env python3
"""Verify negotiated HTTP bodies, hashes, and MIME against a release manifest."""
import argparse
import functools
import gzip
import hashlib
import json
import threading
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen


def verify(base_url: str, manifest: dict, encodings: tuple[str, ...]) -> dict:
    totals = {encoding: 0 for encoding in encodings}
    for item in manifest["files"]:
        for encoding in encodings:
            request = Request(base_url.rstrip("/") + "/" + quote(item["path"]),
                              headers={"Accept-Encoding": encoding})
            with urlopen(request, timeout=30) as response:
                payload = response.read()
                actual_encoding = response.headers.get("Content-Encoding", "identity").lower()
                if actual_encoding != encoding:
                    raise ValueError(f"{item['path']}: requested {encoding}, received {actual_encoding}")
                if "accept-encoding" not in response.headers.get("Vary", "").lower():
                    raise ValueError(f"{item['path']}: missing Vary: Accept-Encoding")
                expected_mime = {".wasm": "application/wasm", ".js": "application/javascript",
                                 ".html": "text/html"}.get(Path(item["path"]).suffix)
                if expected_mime and response.headers.get_content_type() != expected_mime:
                    raise ValueError(f"{item['path']}: wrong Content-Type")
                if int(response.headers.get("Content-Length", len(payload))) != len(payload):
                    raise ValueError(f"{item['path']}: incomplete body")
            totals[encoding] += len(payload)
            if encoding == "gzip":
                payload = gzip.decompress(payload)
            elif encoding == "br":
                import brotli
                payload = brotli.decompress(payload)
            if len(payload) != item["bytes"] or hashlib.sha256(payload).hexdigest() != item["sha256"]:
                raise ValueError(f"{item['path']}: decoded body differs from release artifact")
    return {"files": len(manifest["files"]), "response_body_bytes": totals}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", nargs="?")
    parser.add_argument("--local-directory", type=Path, help="Start an ephemeral loopback server for this directory during verification")
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--encodings", nargs="+", choices=("identity", "gzip", "br"), default=["identity", "gzip"])
    args = parser.parse_args()
    if bool(args.url) == bool(args.local_directory):
        parser.error("provide a URL or --local-directory, exclusively")
    server = None
    thread = None
    if args.local_directory:
        from serve_web import ReleaseHandler, ThreadingHTTPServer
        class QuietHandler(ReleaseHandler):
            def log_message(self, *_args):
                pass
        server = ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(QuietHandler, directory=str(args.local_directory.resolve())))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        args.url = f"http://127.0.0.1:{server.server_port}"
    try:
        print(json.dumps(verify(args.url, json.loads(args.manifest.read_text()), tuple(args.encodings)), indent=2))
    finally:
        if server:
            server.shutdown()
            server.server_close()
            thread.join()
