#!/usr/bin/env python3
"""Read a Godot 4.7 PCK directory, verify bytes, and enforce release budgets."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import struct
from collections import defaultdict
from pathlib import Path
from prepare_web_delivery import ARTIFACT_SUFFIXES

ROOT = Path(__file__).resolve().parents[1]


def read_pack(path: Path) -> list[dict]:
    data = path.read_bytes()
    if len(data) < 112:
        raise ValueError("Truncated PCK header")
    magic, version, major, minor, patch, flags, base, directory = struct.unpack_from("<6I2Q", data)
    if magic != 0x43504447 or version != 4 or flags & ~2:
        raise ValueError(f"Unsupported/encrypted PCK: {magic:x}, v{version}, flags={flags}")
    cursor = directory

    def take(length: int) -> bytes:
        nonlocal cursor
        if length < 0 or cursor + length > len(data):
            raise ValueError("Truncated PCK directory")
        result = data[cursor:cursor + length]
        cursor += length
        return result

    count, = struct.unpack("<I", take(4))
    entries = []
    names = set()
    for _ in range(count):
        length, = struct.unpack("<I", take(4))
        name = take(length).rstrip(b"\0").decode("utf-8")
        offset, size = struct.unpack("<QQ", take(16))
        digest = take(16)
        entry_flags, = struct.unpack("<I", take(4))
        if entry_flags or name in names or ".." in Path(name).parts:
            raise ValueError(f"Unsupported or duplicate PCK entry: {name}")
        names.add(name)
        start = base + offset
        if start < base or start + size > directory:
            raise ValueError(f"Out-of-bounds PCK entry: {name}")
        payload = data[start:start + size]
        if hashlib.md5(payload).digest() != digest:
            raise ValueError(f"PCK integrity failure: {name}")
        category = {".fontdata": "fonts", ".ctex": "textures", ".oggvorbisstr": "audio",
                    ".gdc": "scripts"}.get(Path(name).suffix, "other")
        entries.append({"path": name, "bytes": size, "category": category,
                        "sha256": hashlib.sha256(payload).hexdigest()})
    return entries


def audit(directory: Path, budgets: dict | None = None) -> dict:
    files = sorted(p for p in directory.iterdir() if p.is_file() and p.suffix in ARTIFACT_SUFFIXES)
    for name in ("index.html", "index.js", "index.wasm", "index.pck", "index.audio.worklet.js", "index.audio.position.worklet.js"):
        if not any(p.name == name and p.stat().st_size for p in files):
            raise ValueError(f"Missing non-empty release artifact: {name}")
    html = (directory / "index.html").read_text()
    if 'src="index.js"' not in html:
        raise ValueError("HTML loader does not reference index.js")
    marker = "const GODOT_CONFIG = "
    if marker not in html:
        raise ValueError("Missing Godot loader configuration")
    loader_config, _ = json.JSONDecoder().raw_decode(html.split(marker, 1)[1])
    if loader_config.get("executable") != "index":
        raise ValueError("Unexpected loader executable")
    for name in ("index.pck", "index.wasm"):
        if loader_config.get("fileSizes", {}).get(name) != (directory / name).stat().st_size:
            raise ValueError(f"Loader declares stale file size: {name}")
    packs = [p for p in files if p.suffix == ".pck"]
    if len(packs) != 1:
        raise ValueError("Expected exactly one PCK")
    entries = read_pack(packs[0])
    inventory = []
    for path in files:
        data = path.read_bytes()
        gz = gzip.compress(data, compresslevel=9, mtime=0)
        item = {"path": path.name, "bytes": len(data), "gzip_bytes": len(gz),
                "sha256": hashlib.sha256(data).hexdigest()}
        sidecar = path.with_name(path.name + ".br")
        if sidecar.is_file():
            import brotli
            compressed = sidecar.read_bytes()
            if brotli.decompress(compressed) != data:
                raise ValueError(f"Invalid Brotli sidecar: {sidecar}")
            item["brotli_bytes"] = len(compressed)
        gzip_sidecar = path.with_name(path.name + ".gz")
        if gzip_sidecar.is_file() and gzip.decompress(gzip_sidecar.read_bytes()) != data:
            raise ValueError(f"Invalid gzip sidecar: {gzip_sidecar}")
        inventory.append(item)
    categories = defaultdict(int)
    for entry in entries:
        categories[entry["category"]] += entry["bytes"]
    report = {"schema": 1, "raw_bytes": sum(p["bytes"] for p in inventory),
              "gzip_bytes": sum(p["gzip_bytes"] for p in inventory),
              "pck_bytes": packs[0].stat().st_size, "pck_categories": dict(categories),
              "files": inventory, "pck_entries": entries}
    if all("brotli_bytes" in item for item in inventory):
        report["brotli_bytes"] = sum(p["brotli_bytes"] for p in inventory)
    if budgets:
        for metric in ("raw_bytes", "gzip_bytes", "pck_bytes"):
            if report[metric] > budgets[metric]:
                raise ValueError(f"Budget exceeded: {metric}={report[metric]} > {budgets[metric]}")
        names = [e["path"] for e in entries]
        for fragment in budgets["forbidden_pck_fragments"]:
            if any(fragment in name for name in names):
                raise ValueError(f"Forbidden exported resource: {fragment}")
        for fragment in budgets["required_pck_fragments"]:
            if not any(fragment in name for name in names):
                raise ValueError(f"Missing exported resource: {fragment}")
        cjk = sum(e["bytes"] for e in entries if e["category"] == "fonts" and "NotoSansCJKsc-UI" in e["path"])
        if not 0 < cjk <= budgets["cjk_font_bytes"]:
            raise ValueError(f"CJK font budget exceeded/missing: {cjk}")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--budgets", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = audit(args.directory, json.loads(args.budgets.read_text()) if args.budgets else None)
    encoded = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded)
    print(json.dumps({k: v for k, v in report.items() if k not in ("files", "pck_entries")}, indent=2))


if __name__ == "__main__":
    main()
