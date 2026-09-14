#!/usr/bin/env python3
"""Generate lossless HTTP compression sidecars; never rewrite identity artifacts."""
import argparse
import gzip
import hashlib
import json
import subprocess
from pathlib import Path

ARTIFACT_SUFFIXES = {".html", ".js", ".wasm", ".pck", ".png", ".svg"}


def delivery_manifest(directory: Path) -> dict:
    """Describe existing identity/sidecar bytes, verifying all encodings first."""
    files = sorted(p for p in directory.iterdir() if p.is_file() and p.suffix in ARTIFACT_SUFFIXES)
    manifest = {"schema": 1, "files": []}
    root = Path(__file__).resolve().parents[1]
    try:
        manifest["source_revision"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
        manifest["source_dirty"] = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=root, text=True).strip())
    except (OSError, subprocess.CalledProcessError):
        manifest["source_revision"] = "unavailable"
    for path in files:
        data = path.read_bytes()
        item = {"path": path.name, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}
        for encoding, extension in (("gzip", ".gz"), ("brotli", ".br")):
            sidecar = path.with_name(path.name + extension)
            if not sidecar.is_file():
                continue
            encoded = sidecar.read_bytes()
            if encoding == "gzip":
                decoded = gzip.decompress(encoded)
            else:
                import brotli
                decoded = brotli.decompress(encoded)
            if decoded != data:
                raise ValueError(f"Stale compression sidecar: {sidecar}")
            item[encoding + "_bytes"] = len(encoded)
            item[encoding + "_sha256"] = hashlib.sha256(encoded).hexdigest()
        manifest["files"].append(item)
    return manifest


def prepare(directory: Path, with_brotli: bool = False) -> dict:
    if with_brotli:
        import brotli
    files = sorted(p for p in directory.iterdir() if p.is_file() and p.suffix in ARTIFACT_SUFFIXES)
    for path in files:
        data = path.read_bytes()
        encoded = gzip.compress(data, compresslevel=9, mtime=0)
        path.with_name(path.name + ".gz").write_bytes(encoded)
        if with_brotli:
            encoded = brotli.compress(data, quality=11)
            path.with_name(path.name + ".br").write_bytes(encoded)
        else:
            # A prior build's compressed bytes must never shadow the new artifact.
            path.with_name(path.name + ".br").unlink(missing_ok=True)
    manifest = delivery_manifest(directory)
    (directory / "delivery-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--brotli", action="store_true", help="Requires tools/requirements-release.txt")
    args = parser.parse_args()
    manifest = prepare(args.directory, args.brotli)
    print(f"Prepared {len(manifest['files'])} files with gzip" + (" and Brotli" if args.brotli else ""))
