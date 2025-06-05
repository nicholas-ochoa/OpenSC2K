#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

godot --headless --path "$repo_dir/game" --editor --quit
godot --headless --path "$repo_dir/game" --quit-after 2

if [ -f "$repo_dir/game/tests/test_runner.gd" ]; then
	godot --headless --path "$repo_dir/game" --script res://tests/test_runner.gd -- "$repo_dir/references"
fi

git -C "$repo_dir" diff --check
