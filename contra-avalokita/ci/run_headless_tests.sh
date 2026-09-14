#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$SCRIPT_DIR/headless_tests.txt"
GODOT_BIN="${GODOT_BIN:-godot}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v "$GODOT_BIN" >/dev/null 2>&1 || fail "Godot executable '$GODOT_BIN' was not found on PATH."
[[ -f "$PROJECT_DIR/project.godot" ]] || fail "project.godot not found at $PROJECT_DIR"
[[ -f "$MANIFEST" ]] || fail "Headless test manifest not found at $MANIFEST"

echo "Godot runtime: $($GODOT_BIN --version)"
echo "Project: $PROJECT_DIR"

echo "::group::Import project resources"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --import
echo "::endgroup::"

echo "::group::Project startup check"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --editor --quit
echo "::endgroup::"

ran=0
while IFS= read -r test_path || [[ -n "$test_path" ]]; do
  test_path="${test_path%$'\r'}"
  [[ -z "$test_path" || "$test_path" == \#* ]] && continue

  ran=$((ran + 1))
  echo "::group::Headless test $ran: $test_path"
  "$GODOT_BIN" --headless --path "$PROJECT_DIR" --script "$test_path"
  echo "::endgroup::"
done < "$MANIFEST"

(( ran > 0 )) || fail "Headless test manifest contains no runnable tests."

echo "Headless CI suite passed: $ran tests."
