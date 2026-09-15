#!/usr/bin/env python3
"""Build deterministic, verified editable or complete authoring archives."""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def members(root: Path, profile_name: str) -> list[Path]:
    config = json.loads((root / "config/package-profiles.json").read_text())
    profile = config["profiles"][profile_name]
    selected = set()
    for name in profile["include"]:
        location = root / name
        candidates = [location] if location.is_file() else location.rglob("*")
        for path in candidates:
            relative = path.relative_to(root)
            if path.is_symlink():
                raise ValueError(f"Package sources must not be symlinks: {relative}")
            if not path.is_file():
                continue
            if path.suffix == ".import" and relative.as_posix() not in config["authored_imports"]:
                continue
            if any(fnmatch.fnmatch(part, pattern) for part in relative.parts for pattern in config["common_excludes"]):
                continue
            if any(relative.as_posix() == prefix or relative.as_posix().startswith(prefix + "/") for prefix in profile["exclude"]):
                continue
            selected.add(path)
    required = ["project.godot", "scenes/main.tscn", "assets/runtime/fonts/ManusGameSC-Common.woff2",
                "localization/en-US.json", "localization/zh-CN.json"]
    for name in required:
        if root / name not in selected:
            raise ValueError(f"Missing required package resource: {name}")
    if profile_name == "authoring" and root / "assets/source/.gdignore" not in selected:
        raise ValueError("Authoring archive must preserve source .gdignore")
    return sorted(selected)


def package(root: Path, profile_name: str, destination: Path, directory: bool = False) -> dict:
    if destination.exists():
        raise ValueError(f"Refusing to overwrite an existing package: {destination}")
    selected = members(root, profile_name)
    manifest = {"schema": 1, "profile": profile_name,
                "note": "This manifest describes embedded local files. assets.lock.json retains upstream provenance and is not a claim that omitted masters are embedded or remotely verified.",
                "files": []}
    for path in selected:
        data = path.read_bytes()
        manifest["files"].append({"path": path.relative_to(root).as_posix(), "bytes": len(data),
                                  "sha256": hashlib.sha256(data).hexdigest()})
    encoded_manifest = (json.dumps(manifest, indent=2) + "\n").encode()
    destination.parent.mkdir(parents=True, exist_ok=True)
    if directory:
        destination.mkdir()
        for path, item in zip(selected, manifest["files"]):
            target = destination / item["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
        (destination / "package-manifest.json").write_bytes(encoded_manifest)
    else:
        with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for path, item in zip(selected, manifest["files"]):
                info = zipfile.ZipInfo(item["path"], date_time=(1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = (0o100755 if path.stat().st_mode & 0o111 else 0o100644) << 16
                archive.writestr(info, path.read_bytes())
            info = zipfile.ZipInfo("package-manifest.json", date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, encoded_manifest)
    verify_package(destination, directory)
    return manifest


def verify_package(destination: Path, directory: bool = False) -> None:
    archive = None if directory else zipfile.ZipFile(destination)
    try:
        read = (lambda name: (destination / name).read_bytes()) if directory else archive.read
        manifest = json.loads(read("package-manifest.json"))
        declared = [item["path"] for item in manifest["files"]]
        if len(declared) != len(set(declared)):
            raise ValueError("Duplicate package manifest paths")
        for name in declared:
            path = Path(name)
            if path.is_absolute() or ".." in path.parts or "\\" in name:
                raise ValueError(f"Unsafe package manifest path: {name}")
        actual = ([p.relative_to(destination).as_posix() for p in destination.rglob("*") if p.is_file()]
                  if directory else archive.namelist())
        if len(actual) != len(set(actual)) or set(actual) != set(declared) | {"package-manifest.json"}:
            raise ValueError("Package contains missing, duplicate or unlisted files")
        for item in manifest["files"]:
            data = read(item["path"])
            if len(data) != item["bytes"] or hashlib.sha256(data).hexdigest() != item["sha256"]:
                raise ValueError(f"Package integrity failure: {item['path']}")
    finally:
        if archive:
            archive.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--profile", choices=("editable", "authoring"), default="editable")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--directory", action="store_true", help="Assemble a fresh directory for import/boot validation")
    args = parser.parse_args()
    manifest = package(args.root.resolve(), args.profile, args.output.resolve(), args.directory)
    print(json.dumps({"profile": args.profile, "files": len(manifest["files"]),
                      "embedded_bytes": sum(item["bytes"] for item in manifest["files"]),
                      "output": str(args.output)}))
