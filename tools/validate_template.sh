#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
GODOT_EXECUTABLE=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
SCAFFOLD_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/proto-rts-scaffold.XXXXXX")
trap 'rm -rf "$SCAFFOLD_ROOT"' EXIT INT TERM

python3 -m json.tool "$PROJECT_DIR/template.json" >/dev/null
mkdir -p "$SCAFFOLD_ROOT/project"
rsync -a \
  --exclude '.git/' \
  --exclude '.godot/' \
  --exclude 'assets/source/' \
  --exclude 'build/' \
  --exclude 'captures/' \
  "$PROJECT_DIR/" "$SCAFFOLD_ROOT/project/"

test ! -e "$SCAFFOLD_ROOT/project/assets/source"
"$GODOT_EXECUTABLE" --headless --path "$SCAFFOLD_ROOT/project" --import
"$GODOT_EXECUTABLE" --headless --path "$SCAFFOLD_ROOT/project" --script res://tests/template_boot_test.gd
printf '%s\n' 'PASS validate_template: clean source-free scaffold imports and boots'
