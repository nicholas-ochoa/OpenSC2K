#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
validation_log=$(mktemp /tmp/city-godot-validation-XXXXXX)
trap 'rm -f "$validation_log"' EXIT HUP INT TERM

run_godot() {
	if "$@" >"$validation_log" 2>&1; then
		validation_status=0
	else
		validation_status=$?
	fi
	cat "$validation_log"
	if [ "$validation_status" -ne 0 ]; then
		exit "$validation_status"
	fi
	if grep -E 'SCRIPT ERROR:|^ERROR:' "$validation_log" >/dev/null; then
		exit 1
	fi
}

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --editor --quit
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --quit-after 2

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/indexed_png_test.gd

if [ -f "$repo_dir/game/tests/test_runner.gd" ]; then
	run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/test_runner.gd -- "$repo_dir/references"
fi

if [ -f "$repo_dir/game/tests/runtime_ui_smoke.gd" ]; then
	run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/runtime_ui_smoke.gd -- "$repo_dir/references"
fi

git -C "$repo_dir" diff --check
