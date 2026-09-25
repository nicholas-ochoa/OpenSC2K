extends "res://tests/support/core_test_suite.gd"

## Rendering: map geometry checks.

@warning_ignore_start("integer_division")

const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const MapInteractionTests = preload("res://tests/suites/core/rendering/map_interaction_tests.gd")


func run(reference_root: String, starter: CityState, large: Sc2SpriteArchive) -> void:
	var surface_city := CityModel.from_document(starter.document.duplicate_document())
	var surface_point := Vector2i(64, 64)
	_check(
		surface_city.set_terrain_id(surface_point.x, surface_point.y, 0x09),
		"Selection surface fixture installs a one-corner slope",
	)
	var flat_polygon := IsometricRenderer.tile_polygon(
		surface_city, surface_point.x, surface_point.y
	)
	var slope_polygon := IsometricRenderer.terrain_surface_polygon(
		surface_city, surface_point.x, surface_point.y
	)
	_check(
		slope_polygon[0] == flat_polygon[0] + Vector2(0, -12)
		and slope_polygon[1] == flat_polygon[1]
		and slope_polygon[2] == flat_polygon[2]
		and slope_polygon[3] == flat_polygon[3],
		"Selection surface follows the raised corner of a terrain slope",
	)
	_check(
		surface_city.set_terrain_id(surface_point.x, surface_point.y, 0x0d),
		"Selection surface fixture installs a raised flat shape",
	)
	var raised_polygon := IsometricRenderer.terrain_surface_polygon(
		surface_city, surface_point.x, surface_point.y
	)
	var raised_surface_matches := true

	for corner in 4:
		if raised_polygon[corner] != flat_polygon[corner] + Vector2(0, -12):
			raised_surface_matches = false
			break

	_check(
		raised_surface_matches,
		"Selection surface follows all corners of a raised flat terrain shape",
	)
	var generated_city := CityModel.from_document(
		_load_fixture(GeneratedCityFixture.path(128))
	)
	var generated_city_dynamic := IsometricRenderer.dynamic_draw_commands(
		generated_city, large, IsometricRenderer.VIEW_LARGE, 0
	)
	var generated_city_dynamic_moving: Array[CityDynamicCommand] = []

	for command in generated_city_dynamic:
		if command.overlay < 0:
			generated_city_dynamic_moving.append(command)

	_check(
		_dynamic_command_values(generated_city_dynamic_moving) == _dynamic_command_values(IsometricDynamicCommands.moving_thing_draw_commands(
			generated_city, large, IsometricRenderer.VIEW_LARGE, 0
		)),
		"Indexed dynamic lookup preserves generated city moving-object draw order",
	)

	for expected in [
		Vector2i(0, 0), Vector2i(18, 44), Vector2i(47, 93),
		Vector2i(64, 64), Vector2i(96, 31), Vector2i(127, 127),
	]:
		var polygon := IsometricRenderer.tile_polygon(generated_city, expected.x, expected.y)

		for offset in [Vector2.ZERO, Vector2(5, 2), Vector2(-5, -2)]:
			var screen_point: Vector2 = (
				(polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.25 + offset
			)
			_check(
				IsometricRenderer.screen_to_tile(generated_city, screen_point)
				== _brute_force_screen_to_tile(generated_city, screen_point),
				"Fast isometric lookup matches the full generated city scan at %s" % screen_point,
			)
	MapInteractionTests.new(context).run(starter, surface_city, surface_point, raised_polygon)


func _dynamic_command_values(commands: Array[CityDynamicCommand]) -> Array:
	var values: Array = []

	for command in commands:
		values.append([command.sprite_id, command.flip, command.position,
			command.shadow, command.depth_order, command.record, command.overlay,
			command.static_occlusion, command.train, command.same_tile_foreground_indices])

	return values


func _brute_force_screen_to_tile(city: CityState, point: Vector2) -> Vector2i:
	var result := Vector2i(-1, -1)

	for diagonal in CityModel.MAP_SIZE * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y

			if x >= CityModel.MAP_SIZE or y >= CityModel.MAP_SIZE:
				continue

			if Geometry2D.is_point_in_polygon(
				point, IsometricRenderer.terrain_surface_polygon(city, x, y)
			):
				result = Vector2i(x, y)

	return result
