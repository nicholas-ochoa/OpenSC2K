extends "res://tests/support/core_test_suite.gd"

## Tools: terrain checks.

@warning_ignore_start("integer_division")

const Random = preload("res://src/simulation/random/sim_random.gd")
const Demolish = preload("res://src/tools/city/demolish_command.gd")
const TerrainTools = preload("res://src/tools/landscape/terrain_command.gd")


func test_terrain_command(reference_root: String) -> void:
	_check(TerrainTools.supports_tool(0, 1), "Terrain command supports Level Terrain")
	_check(TerrainTools.supports_tool(0, 2), "Terrain command supports Raise Terrain")
	_check(TerrainTools.supports_tool(0, 3), "Terrain command supports Lower Terrain")
	_check(not TerrainTools.supports_tool(0, 0), "Terrain command rejects Demolish")
	var executable_shapes := _load_pe_rva_bytes(
		reference_root.path_join("SIMCITY.EXE"), 0x000e7958, TerrainTools.TERRAIN_SHAPES.size()
	)
	var shape_table_matches := executable_shapes.size() == TerrainTools.TERRAIN_SHAPES.size()

	if shape_table_matches:
		for shape_index in executable_shapes.size():
			if executable_shapes[shape_index] != TerrainTools.TERRAIN_SHAPES[shape_index]:
				shape_table_matches = false
				break

	_check(
		shape_table_matches,
		"Terrain shape table matches the reachable supplied executable bytes",
	)
	var ordered_heights := PackedInt32Array()
	ordered_heights.resize(CityState.TILE_COUNT)
	var ordered_zones := _filled_bytes(CityState.TILE_COUNT, 0)
	var ordered_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)
	var ordered_start := Vector2i(20, 20)
	var ordered_west := Vector2i(19, 20)
	var ordered_north := Vector2i(20, 19)
	ordered_heights[ordered_start.x * CityState.MAP_SIZE + ordered_start.y] = 1
	var ordered_raise := TerrainEditHeights.plan_raise(
		ordered_heights, ordered_zones, ordered_buildings, ordered_start, 25
	)
	_check(
		ordered_raise.valid
		and ordered_raise.heights[ordered_west.x * CityState.MAP_SIZE + ordered_west.y] == 1
		and ordered_raise.heights[ordered_north.x * CityState.MAP_SIZE + ordered_north.y] == 0
		and ordered_raise.heights[ordered_start.x * CityState.MAP_SIZE + ordered_start.y] == 1,
		"Partial Raise Terrain funds apply in executable west-north-east-south order",
	)
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(size, 0)),
			"Terrain fixture clears %s" % chunk_id,
		)

	_check(document.set_misc_i32(0x14, 200), "Terrain fixture sets funds")
	_check(document.set_misc_u32(0x0e40, 0), "Terrain fixture sets sea level")
	_check(document.set_misc_u32(0x01f0, 16384), "Terrain fixture counts clear tiles")
	var city := CityModel.from_document(document)
	var raised := TerrainTools.apply_path(city, 0, 2, Vector2i(20, 20), [Vector2i(20, 20)])
	_check(raised.ok and city.land_altitude(20, 20) == 1, "Raise Terrain increases the selected altitude")
	_check(raised.cost == 25 and city.funds() == 175, "Raise Terrain charges each raised dependency")
	_check(city.terrain_id(20, 19) == 4 and city.terrain_id(21, 20) == 1, "Raise Terrain uses the recovered terrain shape table")
	_check(TerrainTools.undo(city, raised).ok, "Raise Terrain can be undone")
	_check(city.land_altitude(20, 20) == 0 and city.funds() == 200, "Raise undo restores altitude and funds")

	_check(city.set_land_altitude(20, 20, 1), "Lower Terrain fixture raises the selected tile")
	var lowered := TerrainTools.apply_path(city, 0, 3, Vector2i(20, 20), [Vector2i(20, 20)])
	_check(lowered.ok and city.land_altitude(20, 20) == 0, "Lower Terrain decreases the selected altitude")
	_check(lowered.cost == 25 and city.funds() == 175, "Lower Terrain charges the selected height change")
	_check(TerrainTools.undo(city, lowered).ok, "Lower Terrain can be undone")

	_check(city.set_land_altitude(30, 30, 5), "Level Terrain fixture sets the source height")
	_check(city.set_land_altitude(31, 30, 3), "Level Terrain fixture sets a lower path height")
	_check(city.set_land_altitude(31, 29, 3), "Level Terrain fixture sets the north dependency height")
	_check(city.set_land_altitude(32, 30, 3), "Level Terrain fixture sets the east dependency height")
	_check(city.set_land_altitude(31, 31, 3), "Level Terrain fixture sets the south dependency height")
	var leveled := TerrainTools.apply_path(
		city, 0, 1, Vector2i(30, 30), [Vector2i(30, 30), Vector2i(31, 30)]
	)
	_check(leveled.ok and leveled.target_altitude == 5, "Level Terrain captures the drag-start altitude")
	_check(city.land_altitude(31, 30) == 4, "Level Terrain moves a path tile one level toward its target")
	_check(TerrainTools.undo(city, leveled).ok, "Level Terrain can be undone")
	_check(city.set_land_altitude(50, 50, 1), "Lower propagation fixture sets the selected height")
	_check(city.set_land_altitude(51, 50, 3), "Lower propagation fixture sets a high neighbor")
	var propagated := TerrainTools.apply_path(city, 0, 3, Vector2i(50, 50), [Vector2i(50, 50)])
	_check(propagated.ok and city.land_altitude(50, 50) == 0, "Lower Terrain applies its selected change before propagation")
	_check(city.land_altitude(51, 50) == 2 and propagated.cost == 50, "Lower Terrain lowers a neighbor more than one level higher")
	_check(TerrainTools.undo(city, propagated).ok, "Propagated Lower Terrain can be undone")
	_check(city.set_building_id(40, 40, Tiles.ROAD_STRAIGHT_1), "Terrain conflict fixture places a road")
	_check(city.set_underground_id(40, 40, UnderTiles.SUBWAY_LR), "Terrain conflict fixture places a subway")
	_check(document.set_misc_u32(0x01f0, 16383), "Terrain conflict fixture reduces the clear count")
	_check(document.set_misc_u32(0x01f0 + 0x1d * 4, 1), "Terrain conflict fixture counts its road")
	_check(document.set_misc_u32(0x0fe8, 1), "Terrain conflict fixture counts its subway")
	var conflict_without_random := TerrainTools.apply_path(
		city, 0, 2, Vector2i(40, 40), [Vector2i(40, 40)]
	)
	_check(
		not conflict_without_random.ok and not conflict_without_random.error.is_empty(),
		"Terrain conflict demolition requires explicit process random state",
	)
	_check(
		city.building_id(40, 40) == 0x1d and city.underground_id(40, 40) == 0x01,
		"A rejected terrain conflict does not change either network",
	)
	var terrain_random := Random.new(0x1234)
	var terrain_seed := terrain_random.state
	var conflict := TerrainTools.apply_path(
		city, 0, 2, Vector2i(40, 40), [Vector2i(40, 40)], terrain_random
	)
	_check(conflict.ok and city.land_altitude(40, 40) == 1, "Raise Terrain changes a network tile")
	_check(
		city.building_id(40, 40) == 0 and city.underground_id(40, 40) == 0,
		"Terrain retile removes surface and underground networks",
	)
	_check(
		document.misc_u32(0x01f0) == 16384
		and document.misc_u32(0x01f0 + 0x1d * 4) == 0
		and document.misc_u32(0x0fe8) == 0,
		"Terrain conflict demolition updates surface and subway counts",
	)
	_check(
		conflict.random_used and terrain_random.state != terrain_seed
		and not conflict.effect_events.is_empty() and conflict.sound_events == [504],
		"Terrain conflict demolition keeps its dust, sound, and random use",
	)
	_check(TerrainTools.undo(city, conflict, terrain_random).ok, "Network terrain demolition can be undone")
	_check(
		city.building_id(40, 40) == 0x1d and city.underground_id(40, 40) == 0x01
		and city.land_altitude(40, 40) == 0 and terrain_random.state == terrain_seed,
		"Terrain undo restores both networks, altitude, and random state",
	)

	_check(city.set_building_id(40, 40, Tiles.RADIOACTIVE_WASTE), "Terrain radioactivity fixture replaces the road")
	_check(city.set_underground_id(40, 40, UnderTiles.EMPTY), "Terrain radioactivity fixture removes its subway")
	var radioactivity_raise := TerrainTools.apply_path(
		city, 0, 2, Vector2i(40, 40), [Vector2i(40, 40)]
	)
	_check(
		radioactivity_raise.ok
		and city.building_id(40, 40) == 5
		and not radioactivity_raise.random_used,
		"Terrain retile preserves XBLD 0x05 radioactivity without random use",
	)
	_check(
		TerrainTools.undo(city, radioactivity_raise).ok,
		"Radioactivity terrain change can be undone",
	)

	for x in range(60, 62):
		for y in range(60, 62):
			_check(city.set_building_id(x, y, Tiles.CHEAP_APARTMENTS_2X2), "Terrain structure fixture fills its site")

	_check(city.set_building_corners(60, 60, 0x10), "Terrain structure fixture sets bottom-left")
	_check(city.set_building_corners(61, 60, 0x20), "Terrain structure fixture sets bottom-right")
	_check(city.set_building_corners(61, 61, 0x40), "Terrain structure fixture sets top-left")
	_check(city.set_building_corners(60, 61, 0x80), "Terrain structure fixture sets top-right")
	_check(city.set_text_overlay_id(60, 60, 61), "Terrain structure fixture assigns a microsim label")
	var structure_random := Random.new(0x5678)
	var structure_raise := TerrainTools.apply_path(
		city, 0, 2, Vector2i(60, 60), [Vector2i(60, 60)], structure_random
	)
	_check(structure_raise.ok, "Raise Terrain demolishes a complete multi-tile structure")
	_check(
		city.building_id(60, 60) == 0 and city.building_id(61, 60) == 0
		and city.building_id(60, 61) == 0 and city.building_id(61, 61) == 0,
		"Terrain demolition clears the complete two-by-two footprint",
	)
	_check(
		city.text_overlay_id(60, 60) == 0 and structure_raise.changed_ids.has("XTXT"),
		"Terrain demolition releases the structure overlay",
	)
	_check(
		TerrainTools.undo(city, structure_raise, structure_random).ok,
		"Multi-tile terrain demolition can be undone",
	)
	_check(
		city.building_id(60, 60) == 0x8c and city.building_id(61, 61) == 0x8c
		and city.text_overlay_id(60, 60) == 61,
		"Terrain undo restores the complete structure and overlay",
	)

	var basin_altitude := _filled_bytes(CityState.TILE_COUNT * 2, 0)
	var basin_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)
	var basin_terrain := _filled_bytes(CityState.TILE_COUNT, 0)
	var basin_zones := _filled_bytes(CityState.TILE_COUNT, 0)
	var basin_flags := _filled_bytes(CityState.TILE_COUNT, 0)
	var basin_misc := document.find_chunk("MISC").decoded_payload.duplicate()
	var basin_point := Vector2i(70, 70)
	var basin_index := basin_point.x * CityState.MAP_SIZE + basin_point.y
	basin_zones[basin_index] = 6

	for offset in TerrainTools.CARDINAL_OFFSETS:
		var neighbor: Vector2i = basin_point + offset
		TerrainEditHeights.set_land_altitude(
			basin_altitude,
			neighbor.x * CityState.MAP_SIZE + neighbor.y,
			1,
		)

	TerrainRetile.retile_region(
		basin_altitude,
		basin_buildings,
		basin_terrain,
		basin_zones,
		basin_flags,
		basin_misc,
		PackedInt32Array([basin_index]),
		2,
	)
	_check(
		TerrainEditHeights.land_altitude(basin_altitude, basin_index) == 1,
		"Terrain sentinel 0x32 raises a surrounded basin by one level",
	)
	_check(
		basin_terrain[basin_index] == 0x10
		and (basin_flags[basin_index] & TerrainTools.FLAG_WATER) != 0,
		"A raised basin below sea level uses the executable's deep-water terrain",
	)
	_check(
		basin_zones[basin_index] == 0,
		"The raised-basin terrain shape clears the zone nibble",
	)
