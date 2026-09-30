extends "res://tests/support/core_test_suite.gd"
## Rendering: fire and special overlay checks.

@warning_ignore_start("integer_division")

const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")


# Static tile sprite rules are native painter rules with Rust unit tests.
# These checks cover the fire and special overlays that the moving sprites draw.
func run(reference_root: String, large: Sc2SpriteArchive) -> void:
	var overlay_document := _load_fixture(reference_root.path_join("CITIES/STARTER.SC2"))
	var overlay_city := CityModel.from_document(overlay_document)
	var overlay_point := Vector2i(64, 64)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xff),
		"Fire view fixture installs the fire marker",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x04, false),
		"Fire view fixture uses a land tile",
	)
	_test_disaster_overlays(overlay_city, overlay_point, large)


func _test_disaster_overlays(overlay_city: CityState, overlay_point: Vector2i, large: Sc2SpriteArchive) -> void:
	var fire_visual := IsometricStaticVisuals.fire_overlay_visual(
		overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_LARGE, 3
	)
	_check(
		fire_visual.sprite_id >= 1396 and fire_visual.sprite_id <= 1399,
		"Fire view selects a native large frame from its visual phase",
	)
	var fire_command := IsometricDynamicCommands.special_overlay_draw_command(
		overlay_city,
		large,
		overlay_point,
		fire_visual,
		IsometricRenderer.view_configuration(IsometricRenderer.VIEW_LARGE),
	)
	_check(
		fire_command.static_occlusion,
		"Foreground buildings occlude dynamic fire markers",
	)
	var flipped_fire := IsometricStaticVisuals.fire_overlay_visual(
		overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_LARGE, 4
	)
	_check(
		flipped_fire.sprite_id == 1396 + (int(fire_visual.sprite_id) - 1396 + 1) % 4,
		"Fire advances to the next native frame",
	)
	var fire_frames := {}
	var fire_differences := {}
	var previous_frame := -1

	for fire_x in range(32, 64):
		var original_overlay := overlay_city.text_overlay_id(fire_x, overlay_point.y)
		var original_water := overlay_city.is_water(fire_x, overlay_point.y)
		overlay_city.set_text_overlay_id(fire_x, overlay_point.y, 0xff)
		overlay_city.set_tile_flag(fire_x, overlay_point.y, 0x04, false)
		var visual := IsometricStaticVisuals.fire_overlay_visual(overlay_city, fire_x, overlay_point.y)
		fire_frames[visual.sprite_id] = true
		var repeated := IsometricStaticVisuals.fire_overlay_visual(overlay_city, fire_x, overlay_point.y)
		_check(visual.sprite_id == repeated.sprite_id and visual.flip == repeated.flip and visual.overlay == repeated.overlay,
			"Fire animation is stable for the same tile and display time")
		overlay_city.set_text_overlay_id(fire_x, overlay_point.y, original_overlay)
		overlay_city.set_tile_flag(fire_x, overlay_point.y, 0x04, original_water)

		if previous_frame >= 0:
			fire_differences[(int(visual.sprite_id) - previous_frame + 4) % 4] = true

		previous_frame = int(visual.sprite_id)

	_check(fire_frames.size() == 4 and fire_differences.size() == 4,
		"Adjacent fires use varied phases instead of a constant wave step")
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x04, true),
		"Fire view fixture changes to a water tile",
	)
	_check(
		IsometricStaticVisuals.fire_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		) == null,
		"Fire does not draw on a saved water tile",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xfb),
		"Special-overlay fixture installs marker 0xfb",
	)
	_check(
		IsometricStaticVisuals.special_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).sprite_id == 1496,
		"Special marker 0xfb uses its recovered large sprite on water",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xfc),
		"Special-overlay fixture installs marker 0xfc",
	)
	_check(
		IsometricStaticVisuals.special_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y,
			IsometricRenderer.VIEW_MEDIUM
		).sprite_id == 992,
		"Special marker 0xfc uses its native medium sprite on water",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xfd),
		"Special-overlay fixture installs marker 0xfd",
	)
	_check(
		IsometricStaticVisuals.special_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		) == null,
		"Special marker 0xfd does not draw on a saved water tile",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x04, false),
		"Special-overlay fixture changes back to dry land",
	)
	var launch_effect := IsometricStaticVisuals.special_overlay_visual(
		overlay_city, overlay_point.x, overlay_point.y,
		IsometricRenderer.VIEW_LARGE, 1
	)
	_check(
		launch_effect.sprite_id == 1494 and launch_effect.overlay == 0xfd,
		"Special marker 0xfd selects one of the recovered two-frame effects",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xfe),
		"Special-overlay fixture installs marker 0xfe",
	)
	_check(
		IsometricStaticVisuals.special_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y,
			IsometricRenderer.VIEW_SMALL, 0
		).sprite_id == 493,
		"Special marker 0xfe uses its native small effect frame",
	)
