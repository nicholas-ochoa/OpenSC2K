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
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/gpu_atlas_growth_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/native_graphics_settings_test.gd
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

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/expanded_limits_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/map_edge_limits_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/onramp_orientation_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/native_data_maps_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/data_map_regression_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/native_data_maps_ui_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/isometric_data_view_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/large_render_patch_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/large_city_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/edit_dirty_indices_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/file_dialog_history_test.gd -- write
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/file_dialog_history_test.gd -- read
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/large_city_simulation_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/large_city_simulation_test.gd -- --native
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/large_city_ui_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tools/build_large_city_fixtures.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/city_region_renderer_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/city_region_cache_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/city_region_occlusion_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/frame_simulation_test.gd

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
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/newspaper_web_view_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/newspaper_layout_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/editor_stream_slopes_test.gd

# Recording decode tests need the optional FLAC converter.
if command -v "${OPENSC2K_FFMPEG:-ffmpeg}" >/dev/null 2>&1; then
	run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/recorded_soundtrack_test.gd
else
	printf '%s\n' 'SKIP: recorded soundtrack decode checks require FFmpeg'
fi

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/soundtrack_settings_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/city_gpu_geometry_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/city_gpu_cache_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/city_foreground_cache_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/renderer_settings_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/camera_query_settings_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/closer_zoom_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/query_details_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/media_controls_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/network_preview_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/bridge_continuation_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/slope_hit_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/city_render_retention_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/static_overlay_signature_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/city_sign_foreground_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/city_dynamic_command_cache_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/city_foreground_palette_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/masked_flag_signature_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/city_worker_sign_foreground_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/city_gpu_prefetch_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/media_pack_test.gd
run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/toolbar_audio_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/pack_settings_test.gd

run_godot godot --audio-driver Dummy --headless --path "$repo_dir/game" --script res://tests/scurk_png_import_test.gd
