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
RUNTIME_PATH = Path("assets/runtime/fonts/NotoSansCJKsc-UI.otf")


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _coverage(root: Path) -> tuple[list[int], list[str]]:
    # Include all production text, not only CJK literals: placeholders and
    # symbols can also be rendered by the fallback font. Dynamic callsigns use
    # the complete source face rather than this UI-only validation corpus.
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
    if fontTools.__version__ != FONTTOOLS_VERSION:
        raise RuntimeError(
            f"FontTools {FONTTOOLS_VERSION} is required; install tools/requirements-assets.txt"
        )
    source = root / SOURCE_PATH
    source_bytes = source.read_bytes()
    codepoints, coverage_inputs = _coverage(root)
    original = TTFont(BytesIO(source_bytes), recalcTimestamp=False)
    font_bytes = source_bytes
    expected_cmap = original.getBestCmap()
    verified_glyph_count = len(original.getGlyphOrder())
    if _sha256(font_bytes) != "2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b":
        raise ValueError("Expected the complete pinned Noto Sans CJK SC font; subsets are forbidden")
    report = {
        "schema_version": 1,
        "generator": "byte-identical complete source copy",
        "subset": False,
        "fonttools_version": FONTTOOLS_VERSION,
        "source": str(SOURCE_PATH),
        "source_sha256": _sha256(source_bytes),
        "source_size_bytes": len(source_bytes),
        "source_glyph_count": len(original.getGlyphOrder()),
        "runtime": str(RUNTIME_PATH),
        "runtime_sha256": _sha256(font_bytes),
        "runtime_size_bytes": len(font_bytes),
        "runtime_glyph_count": verified_glyph_count,
        "coverage_inputs": coverage_inputs,
        "requested_codepoints": [f"U+{value:04X}" for value in codepoints],
        "covered_codepoint_count": len(expected_cmap),
        "source_unsupported_codepoints": [f"U+{value:04X}" for value in codepoints if value not in original.getBestCmap()],
        "glyph_outline_and_metrics_verified": True,
        "layout_features": "all",
        "layout_scripts": "all",
        "hinting_preserved": True,
        "license": "assets/fonts/NotoSansCJK-COPYRIGHT.txt",
    }
    report_bytes = (json.dumps(report, indent=2, sort_keys=True) + "\n").encode("utf-8")
    directory = root / RUNTIME_PATH.parent
    outputs = {
        directory / RUNTIME_PATH.name: font_bytes,
        directory / "font-report.json": report_bytes,
    }
    outputs[directory / "SHA256SUMS"] = "".join(
        f"{_sha256(data)}  {path.relative_to(root)}\n" for path, data in outputs.items()
    ).encode("utf-8")
    for path, data in outputs.items():
        if check:
            if not path.is_file() or path.read_bytes() != data:
                raise ValueError(f"Stale font derivative: {path.relative_to(root)}; run --fonts-only")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            if not path.is_file() or path.read_bytes() != data:
                path.write_bytes(data)
    if source.read_bytes() != source_bytes:
        raise ValueError("Original font changed during generation")
    print(
        f"{'Verified' if check else 'Generated'} complete CJK font: {len(font_bytes)} bytes; "
        f"{len(expected_cmap)} Unicode codepoints; {verified_glyph_count} identical glyph outlines/metrics"
    )
