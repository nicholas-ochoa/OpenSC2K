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
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/graphics_pack_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/independent_startup_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/asset_source_original_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/windows_bitmap_rle8_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/pe_named_bitmap_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/pe_icon_cursor_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tools/audit_reference_overlays.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tools/audit_reference_ui_strips.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tools/audit_reference_neighbors.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/scurk_graphics_pack_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tools/audit_reference_scurk_controls.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tools/audit_reference_scurk_workspace.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tools/audit_reference_check_controls.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tools/audit_reference_advisor_portraits.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tools/audit_reference_terrain_media_ui.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tools/audit_reference_notices.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tools/audit_reference_city_presentation.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/desktop_runtime_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tools/audit_reference_desktop.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tools/audit_reference_scurk_presentation.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tools/audit_reference_scurk_drawing.gd

if [ -f "$repo_dir/game/tests/test_runner.gd" ]; then
	run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/test_runner.gd -- "$repo_dir/references"
fi

if [ -f "$repo_dir/game/tests/runtime_ui_smoke.gd" ]; then
	run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/runtime_ui_smoke.gd -- "$repo_dir/references"
fi

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/toolbar_interaction_test.gd

python3 "$repo_dir/tools/test_graphics_tools.py"

git -C "$repo_dir" diff --check

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/usability_polish_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/terrain_workflow_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/landscape_editor_tools_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/presentation_refinements_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/live_terrain_stretch_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/placement_error_tooltip_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/ship_map_exit_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/menu_music_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/stream_waterfall_render_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/newspaper_layout_test.gd
