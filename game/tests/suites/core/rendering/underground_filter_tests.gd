extends "res://tests/support/core_test_suite.gd"

## Rendering: underground filter checks.

@warning_ignore_start("integer_division")

const Palette = preload("res://src/assets/sc2_palette.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const UndergroundView = preload("res://src/view/city_underground_view.gd")
const ViewFilter = preload("res://src/view/city_view_filter.gd")


func run(starter: CityState, large: Sc2SpriteArchive, small_medium: Sc2SpriteArchive) -> void:
	var underground_city := CityModel.from_document(starter.document.duplicate_document())
	_check(
		UndergroundView.terrain_wireframe_offset(0x00) == 0x131
		and UndergroundView.terrain_wireframe_offset(0x0e) == 0x13e
		and UndergroundView.terrain_wireframe_offset(0x10) == 0x131
		and UndergroundView.terrain_wireframe_offset(0x2e) == 0x13e
		and UndergroundView.terrain_wireframe_offset(0x45) == 0x131,
		"Underground terrain uses the recovered wireframe lookup table",
	)

	for fixture in [
		[Vector2i(20, 20), 0x01, 1319],
		[Vector2i(21, 20), 0x0f, 1333],
		[Vector2i(22, 20), 0x10, 1334],
		[Vector2i(23, 20), 0x1e, 1348],
		[Vector2i(24, 20), 0x1f, 1349],
		[Vector2i(25, 20), 0x20, 1350],
		[Vector2i(26, 20), 0x22, 1352],
		[Vector2i(27, 20), 0x23, 1353],
	]:
		var point: Vector2i = fixture[0]
		_check(
			underground_city.set_underground_id(point.x, point.y, fixture[1]),
			"Underground view fixture stores tile 0x%02X" % fixture[1],
		)
		_check(
			UndergroundView.tile_sprite_ids(underground_city, point.x, point.y)[0]
			== fixture[2],
			"Underground tile 0x%02X selects native sprite %d" % [fixture[1], fixture[2]],
		)

	var wet_pipe := Vector2i(22, 20)
	_check(
		underground_city.set_tile_flag(wet_pipe.x, wet_pipe.y, 0x20, true)
		and underground_city.set_tile_flag(wet_pipe.x, wet_pipe.y, 0x10, true),
		"Underground fixture marks a pipe as active and watered",
	)
	_check(
		UndergroundView.tile_sprite_ids(underground_city, wet_pipe.x, wet_pipe.y)[0]
		== 1450,
		"Watered pipe selects the recovered blue native sprite",
	)
	var piped_subway := Vector2i(20, 20)
	_check(
		underground_city.set_tile_flag(piped_subway.x, piped_subway.y, 0x20, true),
		"Underground fixture marks the subway tile as piped",
	)
	_check(
		UndergroundView.tile_sprite_ids(
			underground_city, piped_subway.x, piped_subway.y
		) == PackedInt32Array([1319, 1351]),
		"A piped subway adds the recovered underground service overlay",
	)
	_check(
		UndergroundView.tile_sprite_ids(
			underground_city, wet_pipe.x, wet_pipe.y,
			IsometricRenderer.VIEW_LARGE, true, true, false
		) == PackedInt32Array([1305]),
		"Hidden water mains leave the terrain wireframe visible",
	)
	_check(
		UndergroundView.tile_sprite_ids(
			underground_city, 24, 20, IsometricRenderer.VIEW_LARGE, true, true, false
		) == PackedInt32Array([1319]),
		"Hidden water mains replace the first pipe-subway crossover with subway LR",
	)
	_check(
		UndergroundView.tile_sprite_ids(
			underground_city, 25, 20, IsometricRenderer.VIEW_LARGE, true, true, false
		) == PackedInt32Array([1320]),
		"Hidden water mains replace the second pipe-subway crossover with subway TB",
	)
	_check(
		UndergroundView.tile_sprite_ids(
			underground_city, piped_subway.x, piped_subway.y,
			IsometricRenderer.VIEW_LARGE, false
		) == PackedInt32Array([1319]),
		"Hidden pipes keep a subway and remove its pipe overlay",
	)
	_check(
		underground_city.set_building_id(20, 20, Tiles.LLAMA_DOME),
		"Underground fixture adds a surface building",
	)
	_check(
		UndergroundView.tile_sprite_ids(underground_city, 20, 20)
		== PackedInt32Array([1319, 1351]),
		"Surface buildings do not change underground drawing",
	)
	var underground_errors := UndergroundView.validate_assets(
		underground_city, large, IsometricRenderer.VIEW_LARGE
	)
	_check(
		underground_errors.is_empty(),
		"Underground view has every required large sprite: %s" % underground_errors,
	)
	var underground_image := UndergroundView.create_image(
		underground_city,
		Palette.index_encoding(),
		small_medium,
		IsometricRenderer.VIEW_SMALL,
		true,
	)
	_check(underground_image.ok, "Underground view renders: %s" % underground_image.error)

	if underground_image.ok:
		_check(
			underground_image.image.get_pixel(0, 0).to_rgba32()
			== Color8(255, 255, 255, 255).to_rgba32(),
			"Underground view uses the recovered white background",
		)
		_check(
			underground_image.image.get_format() == Image.FORMAT_L8,
			"Opaque indexed underground rendering uses one byte per pixel",
		)

	var filtered_source := CityModel.from_document(starter.document.duplicate_document())
	_check(filtered_source.set_building_id(10, 10, Tiles.SMALL_OFFICE_BUILDING_1X1), "View filter adds a building")
	_check(filtered_source.set_building_id(11, 10, Tiles.RAIL_SLOPE_1), "View filter adds a network")
	_check(filtered_source.set_building_id(12, 10, Tiles.TREES_1), "View filter adds a tree")
	_check(filtered_source.set_zone_id(13, 10, 2), "View filter adds a zone")
	_check(filtered_source.set_terrain_id(14, 10, 0x10), "View filter adds water terrain")
	_check(filtered_source.set_tile_flag(14, 10, 0x04, true), "View filter marks water")
	_check(filtered_source.set_terrain_id(15, 10, 0x2d), "View filter adds shoreline terrain")
	_check(filtered_source.set_tile_flag(15, 10, 0x04, true), "View filter marks shoreline water")
	_check(filtered_source.set_land_altitude(15, 10, 2), "View filter sets shoreline land altitude")
	_check(filtered_source.set_water_altitude(15, 10, 7), "View filter sets shoreline water altitude")
	_check(filtered_source.set_building_id(15, 10, Tiles.MARINA), "View filter adds a partial-water structure")
	var filtered := ViewFilter.surface_copy(filtered_source, {
		"buildings": false,
		"networks": false,
		"water": false,
		"trees": false,
		"zones": false,
	})
	_check(
		filtered.building_id(10, 10) == 0
		and filtered.building_id(11, 10) == 0
		and filtered.building_id(12, 10) == 0
		and filtered.zone_id(13, 10) == 0
		and filtered.terrain_id(14, 10) == 0
		and filtered.terrain_id(15, 10) == 0x0d
		and not filtered.is_water(14, 10),
		"Surface visibility filters each requested display layer",
	)
	_check(
		filtered.land_altitude(15, 10) == 2
		and filtered.object_altitude(15, 10) == 7,
		"Hidden shoreline water draws dry slope terrain but keeps structure altitude",
	)
	_check(
		filtered_source.building_id(10, 10) == 0x80
		and filtered_source.building_id(11, 10) == 0x2e
		and filtered_source.building_id(12, 10) == 0x06
		and filtered_source.zone_id(13, 10) == 2
		and filtered_source.terrain_id(14, 10) == 0x10
		and filtered_source.is_water(14, 10),
		"Surface visibility filtering does not change saved city state",
	)
