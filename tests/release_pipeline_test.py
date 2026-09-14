#!/usr/bin/env python3
"""Exercise release integrity, HTTP negotiation, and isolated package membership."""
import functools
import gzip
import json
import struct
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from audit_export import audit, read_pack
from package_template import members, package, verify_package
from prepare_web_delivery import prepare
from serve_web import ReleaseHandler, ThreadingHTTPServer
from verify_web_delivery import verify


class QuietHandler(ReleaseHandler):
    def log_message(self, *_args):
        pass


class ReleaseTests(unittest.TestCase):
    def test_missing_main_loader_is_not_hidden_by_worklets(self):
        with tempfile.TemporaryDirectory() as location:
            directory = Path(location)
            for name in ("index.html", "index.wasm", "index.pck", "index.audio.worklet.js"):
                (directory / name).write_bytes(b"not empty")
            with self.assertRaisesRegex(ValueError, "index.js"):
                audit(directory)

    def test_http_negotiation_hashes_and_stale_sidecars(self):
        with tempfile.TemporaryDirectory() as location:
            directory = Path(location)
            (directory / "index.html").write_text("<html>existing game</html>")
            (directory / "index.wasm").write_bytes(b"\0asm" + bytes(range(256)) * 40)
            (directory / "index.wasm.br").write_bytes(b"stale prior build")
            manifest = prepare(directory)
            self.assertFalse((directory / "index.wasm.br").exists())
            first = (directory / "index.wasm.gz").read_bytes()
            prepare(directory)
            self.assertEqual(first, (directory / "index.wasm.gz").read_bytes())
            server = ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(QuietHandler, directory=location))
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            url = f"http://127.0.0.1:{server.server_port}"
            try:
                report = verify(url, manifest, ("identity", "gzip"))
                self.assertLess(report["response_body_bytes"]["gzip"], report["response_body_bytes"]["identity"])
                for header, expected in (("gzip;q=0", None), ("gzip;q=0.2, identity;q=0.1", "gzip"), ("br, gzip", "gzip")):
                    with urlopen(Request(url + "/index.wasm", headers={"Accept-Encoding": header})) as response:
                        self.assertEqual(response.headers.get("Content-Encoding"), expected)
                with self.assertRaises(HTTPError) as error:
                    urlopen(Request(url + "/index.wasm", headers={"Accept-Encoding": "*;q=0"}))
                self.assertEqual(error.exception.code, 406)
                (directory / "index.wasm.gz").write_bytes(gzip.compress(b"wrong bytes"))
                with self.assertRaisesRegex(ValueError, "differs from release"):
                    verify(url, manifest, ("gzip",))
            finally:
                server.shutdown()
                server.server_close()
                thread.join()

    def test_pack_reader_rejects_truncated_and_unsupported_packs(self):
        with tempfile.TemporaryDirectory() as location:
            path = Path(location) / "bad.pck"
            path.write_bytes(b"GDPC")
            with self.assertRaisesRegex(ValueError, "Truncated"):
                read_pack(path)
            data = bytearray(112)
            struct.pack_into("<6I2Q", data, 0, 0x43504447, 4, 4, 7, 2, 2, 112, 10000)
            path.write_bytes(data)
            with self.assertRaisesRegex(ValueError, "Truncated"):
                read_pack(path)
            struct.pack_into("<I", data, 4, 99)
            path.write_bytes(data)
            with self.assertRaisesRegex(ValueError, "Unsupported"):
                read_pack(path)

    def test_editable_package_is_complete_and_integrity_checked(self):
        selected = {p.relative_to(ROOT).as_posix() for p in members(ROOT, "editable")}
        self.assertIn("assets/runtime/fonts/NotoSansCJKsc-UI.otf", selected)
        self.assertIn("assets.lock.json", selected)
        self.assertIn("assets/fonts/ManusCC0-Regular.ttf.import", selected)
        self.assertFalse(any(p.startswith((".venv/", ".godot/", ".git/", "build/", "captures/", "assets/source/")) for p in selected))
        self.assertNotIn("assets/fonts/NotoSansCJKsc-Regular.otf", selected)
        self.assertIn("assets/source/.gdignore", {p.relative_to(ROOT).as_posix() for p in members(ROOT, "authoring")})
        with tempfile.TemporaryDirectory() as location:
            destination = Path(location) / "editable"
            manifest = package(ROOT, "editable", destination, directory=True)
            self.assertEqual(len(manifest["files"]), len(selected))
            extra = destination / "unexpected-secret.txt"
            extra.write_text("unlisted")
            with self.assertRaisesRegex(ValueError, "unlisted"):
                verify_package(destination, directory=True)
            extra.unlink()
            (destination / "localization/en-US.json").write_text("corruption")
            with self.assertRaisesRegex(ValueError, "integrity failure"):
                verify_package(destination, directory=True)


if __name__ == "__main__":
    unittest.main()
