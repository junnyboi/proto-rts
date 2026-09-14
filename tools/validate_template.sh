#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
GODOT_EXECUTABLE=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
SCAFFOLD_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/proto-rts-scaffold.XXXXXX")
trap 'rm -rf "$SCAFFOLD_ROOT"' EXIT INT TERM

run_checked() {
  validation_stage=$1
  shift
  validation_log="$SCAFFOLD_ROOT/$validation_stage.log"
  validation_status=0
  "$@" > "$validation_log" 2>&1 || validation_status=$?
  cat "$validation_log"
  if [ "$validation_status" -ne 0 ] || grep -Eq 'ERROR:|SCRIPT ERROR|Parse Error|Compile Error|Failed to load|No loader found' "$validation_log"; then
    printf '%s\n' "FAIL validate_template: $validation_stage" >&2
    return 1
  fi
}

python3 -m json.tool "$PROJECT_DIR/template.json" >/dev/null
python3 "$SCRIPT_DIR/package_template.py" --profile editable --directory --output "$SCAFFOLD_ROOT/project"

test ! -e "$SCAFFOLD_ROOT/project/assets/source"
test ! -e "$SCAFFOLD_ROOT/project/.venv"
test ! -e "$SCAFFOLD_ROOT/project/assets/fonts/NotoSansCJKsc-Regular.otf"

# Godot loads the project font before its first import scan. Prime only this
# disposable scaffold without that eager reference, then restore exact package
# bytes and require a normal import and boot with the authored font enabled.
cp "$SCAFFOLD_ROOT/project/project.godot" "$SCAFFOLD_ROOT/project.godot.original"
python3 - "$SCAFFOLD_ROOT/project/project.godot" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
section = b""
lines = []
for line in path.read_bytes().splitlines(keepends=True):
    stripped = line.strip()
    if stripped.startswith(b"[") and stripped.endswith(b"]"):
        section = stripped
    if section == b"[gui]" and stripped.partition(b"=")[0].strip() == b"theme/custom_font":
        continue
    lines.append(line)
path.write_bytes(b"".join(lines))
PY
run_checked bootstrap "$GODOT_EXECUTABLE" --headless --audio-driver Dummy --editor --path "$SCAFFOLD_ROOT/project" --import
cp "$SCAFFOLD_ROOT/project.godot.original" "$SCAFFOLD_ROOT/project/project.godot"
run_checked import "$GODOT_EXECUTABLE" --headless --audio-driver Dummy --editor --path "$SCAFFOLD_ROOT/project" --import
cp "$SCAFFOLD_ROOT/project.godot.original" "$SCAFFOLD_ROOT/project/project.godot"
cmp -s "$SCAFFOLD_ROOT/project.godot.original" "$SCAFFOLD_ROOT/project/project.godot"
run_checked boot "$GODOT_EXECUTABLE" --headless --audio-driver Dummy --path "$SCAFFOLD_ROOT/project" --script res://tests/template_boot_test.gd
run_checked localization "$GODOT_EXECUTABLE" --headless --audio-driver Dummy --path "$SCAFFOLD_ROOT/project" --script res://tests/localization_test.gd
cmp -s "$SCAFFOLD_ROOT/project.godot.original" "$SCAFFOLD_ROOT/project/project.godot"
printf '%s\n' 'PASS validate_template: clean source-free scaffold imports, boots, and preserves font coverage and project bytes'
