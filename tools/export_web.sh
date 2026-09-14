#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_EXECUTABLE="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PYTHON_EXECUTABLE="${PYTHON_BIN:-python3}"
OUTPUT="${1:-${ROOT}/build/release/$(date -u +%Y%m%dT%H%M%SZ)}"
if [[ "$("$GODOT_EXECUTABLE" --version)" != 4.7.2* ]]; then
  echo "Godot 4.7.2 and matching Web templates are required." >&2
  exit 1
fi
if [[ -e "$OUTPUT" ]]; then
  echo "Choose a new output directory; release artifacts are not overwritten: $OUTPUT" >&2
  exit 1
fi
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"
IMPORT_LOG="$(mktemp)"
trap 'rm -f "$IMPORT_LOG"' EXIT
"$GODOT_EXECUTABLE" --headless --audio-driver Dummy --editor --path "$ROOT" --import 2>&1 | tee "$IMPORT_LOG"
if grep -Eq 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load' "$IMPORT_LOG"; then exit 1; fi
"$GODOT_EXECUTABLE" --headless --audio-driver Dummy --path "$ROOT" --export-release Web "$OUTPUT/index.html" 2>&1 | tee "$IMPORT_LOG"
if grep -Eq 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load' "$IMPORT_LOG"; then exit 1; fi
COMPRESSION_ARGS=()
if [[ "${BROTLI:-0}" == 1 ]]; then COMPRESSION_ARGS+=(--brotli); fi
"$PYTHON_EXECUTABLE" "$ROOT/tools/prepare_web_delivery.py" "$OUTPUT" "${COMPRESSION_ARGS[@]}"
"$PYTHON_EXECUTABLE" "$ROOT/tools/audit_export.py" "$OUTPUT" --budgets "$ROOT/config/size-budgets.json" --output "$OUTPUT/export-audit.json"
printf 'PASS release export: %s\n' "$OUTPUT"
