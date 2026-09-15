"""Deterministic CJK font derivatives, invoked by process_assets.py only."""

from __future__ import annotations

import hashlib
from io import BytesIO
import json
from pathlib import Path

import fontTools
from fontTools.ttLib import TTFont


FONTTOOLS_VERSION = "4.60.2"
SOURCE_PATH = Path("assets/fonts/NotoSansCJKsc-Regular.otf")
RUNTIME_PATH = Path("assets/runtime/fonts/ManusGameSC-Common.woff2")


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _coverage(root: Path) -> tuple[list[int], list[str]]:
    # Include all production text, not only CJK literals: placeholders and
    # symbols can also be rendered by the fallback font. Player names use the
    # shared common-Chinese repertoire rather than a per-game UI-only subset.
    codepoints = set(range(32, 127))
    codepoints.update(range(0x2000, 0x2070))
    codepoints.update(range(0x3000, 0x3040))
    # The text shaper can insert a dotted circle for an isolated combining mark,
    # even when that character never occurs literally in the input string.
    codepoints.add(0x25CC)
    inputs: list[Path] = []
    for path in sorted((root / "localization").glob("*.json")):
        entries = json.loads(path.read_text(encoding="utf-8"))["entries"]
        codepoints.update(ord(char) for text in entries.values() for char in text)
        inputs.append(path)
    for directory in ("scripts", "config", "resources", "scenes"):
        for path in sorted((root / directory).rglob("*")):
            if path.suffix in {".gd", ".tres", ".tscn"}:
                codepoints.update(map(ord, path.read_text(encoding="utf-8")))
                inputs.append(path)
    return sorted(codepoints), sorted(str(path.relative_to(root)) for path in inputs)


def process_fonts(root: Path, *, check: bool = False) -> None:
    from sync_cjk_font import verify
    verify()
    source = root / RUNTIME_PATH
    font_bytes = source.read_bytes()
    font = TTFont(BytesIO(font_bytes), recalcTimestamp=False)
    expected_cmap = font.getBestCmap()
    repertoire = set(json.loads(source.with_name("cjk-codepoints.json").read_text()))
    if set(expected_cmap) != repertoire or len(font_bytes) > 1_000_000:
        raise ValueError("Bounded CJK repertoire or size differs")
    codepoints, coverage_inputs = _coverage(root)
    report = {
        "schema_version": 2, "generator": "Pinned common-Simplified-Chinese WOFF2",
        "subset": True, "maximum_font_bytes": 1_000_000,
        "source": str(SOURCE_PATH),
        "source_sha256": "2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b",
        "runtime": str(RUNTIME_PATH), "runtime_sha256": _sha256(font_bytes),
        "runtime_size_bytes": len(font_bytes), "runtime_glyph_count": len(font.getGlyphOrder()),
        "coverage_inputs": coverage_inputs,
        "requested_codepoints": [f"U+{value:04X}" for value in codepoints],
        "covered_codepoint_count": len(expected_cmap),
        "source_unsupported_codepoints": [f"U+{value:04X}" for value in codepoints if value not in expected_cmap],
        "repertoire": "6500 TGH first/second-level common/general characters plus 47 UI/name/symbol characters",
        "license": "assets/runtime/fonts/NotoSansCJK-COPYRIGHT.txt",
    }
    directory = source.parent
    report_bytes = (json.dumps(report, indent=2, sort_keys=True) + "\n").encode()
    outputs = {directory / "font-report.json": report_bytes}
    outputs[directory / "SHA256SUMS"] = (
        f"{_sha256(font_bytes)}  {RUNTIME_PATH}\n"
        f"{_sha256(report_bytes)}  {RUNTIME_PATH.parent / 'font-report.json'}\n"
    ).encode()
    for path, data in outputs.items():
        if check:
            if not path.is_file() or path.read_bytes() != data:
                raise ValueError(f"Stale font report: {path.relative_to(root)}; run --fonts-only")
        elif not path.exists() or path.read_bytes() != data: path.write_bytes(data)
    print(f"{'Verified' if check else 'Recorded'} bounded CJK font: {len(font_bytes)} bytes; {len(expected_cmap)} codepoints")
