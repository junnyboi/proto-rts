#!/usr/bin/env python3
"""Local release server with validated precompressed content negotiation."""
from __future__ import annotations

import argparse
import functools
import mimetypes
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/javascript", ".js")
mimetypes.add_type("application/octet-stream", ".pck")


def encoding_quality(header: str) -> dict[str, float]:
    result = {}
    for item in header.lower().split(","):
        parts = item.strip().split(";")
        if not parts[0]:
            continue
        quality = 1.0
        for part in parts[1:]:
            if part.strip().startswith("q="):
                try:
                    quality = float(part.strip()[2:])
                    if not 0 <= quality <= 1:
                        quality = 0.0
                except ValueError:
                    quality = 0.0
        result[parts[0]] = quality
    return result


class ReleaseHandler(SimpleHTTPRequestHandler):
    def send_head(self):
        identity = Path(self.translate_path(self.path))
        if identity.is_dir():
            identity /= "index.html"
        if not identity.is_file():
            self.send_error(404)
            return None
        qualities = encoding_quality(self.headers.get("Accept-Encoding", ""))
        wildcard = qualities.get("*", 0.0)
        candidates = []
        for priority, encoding, extension in ((2, "br", ".br"), (1, "gzip", ".gz")):
            candidate = identity.with_name(identity.name + extension)
            quality = qualities.get(encoding, wildcard)
            if quality > 0 and candidate.is_file():
                candidates.append((quality, priority, encoding, candidate))
        identity_quality = qualities.get("identity", 0.0 if qualities.get("*") == 0 else 1.0)
        if identity_quality > 0:
            candidates.append((identity_quality, 0, "identity", identity))
        if not candidates:
            self.send_error(406, "No acceptable representation")
            return None
        _, _, encoding, chosen = max(candidates)
        stream = chosen.open("rb")
        self.send_response(200)
        self.send_header("Content-Type", self.guess_type(str(identity)))
        self.send_header("Content-Length", str(chosen.stat().st_size))
        self.send_header("Vary", "Accept-Encoding")
        # Export filenames are stable across releases: do not cache old PCK/WASM indefinitely.
        self.send_header("Cache-Control", "no-cache")
        self.send_header("X-Content-Type-Options", "nosniff")
        if encoding != "identity":
            self.send_header("Content-Encoding", encoding)
        self.end_headers()
        return stream


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--port", type=int, default=8060)
    parser.add_argument("--host", default="127.0.0.1")
    args = parser.parse_args()
    if not (args.directory / "index.html").is_file():
        parser.error("directory must contain index.html")
    handler = functools.partial(ReleaseHandler, directory=str(args.directory.resolve()))
    server = ThreadingHTTPServer((args.host, args.port), handler)
    print(f"Serving {args.directory} at http://{args.host}:{server.server_port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
