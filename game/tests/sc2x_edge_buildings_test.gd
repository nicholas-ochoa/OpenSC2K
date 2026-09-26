extends SceneTree
## SC2X building footprints can touch every edge without shifting on rotation.

@warning_ignore_start("integer_division")

class ZeroRandom extends SimRandom:
	func next_u15() -> int:
		return 0


func _initialize() -> void:
	for edge in [16, 128, 256]:
		_check_growth(edge)
	_check_legacy()
	_check_tools()
	_check_special()
	_check_scurk()
	print("PASS: SC2X edge growth, tools, lifecycle, rotation, demolition and save reload")
	quit()


func _city(edge: int, extended := true) -> CityState:
	var document := EmptyCityTemplate.create(edge)
	if extended and edge == 128:
		assert(document.enable_full_resolution_maps())
	document.set_misc_i32(Sc2MiscLayout.FUNDS, 1000000)
	return CityState.from_document(document)


func _sites(edge: int, area: int) -> Array[Vector2i]:
	var far := edge - area
	return [Vector2i(0, 5), Vector2i(5, 0), Vector2i(far, 5), Vector2i(5, far),
		Vector2i.ZERO, Vector2i(far, 0), Vector2i(0, far), Vector2i(far, far)]


func _scan(city: CityState) -> GrowthScan.TileScan:
	return GrowthScan.TileScan.new(city, GrowthState.payloads(city), ZeroRandom.new(),
		SimLfsrRandom.new(1), GameLcgRandom.new(1), null)


func _commit_scan(city: CityState, scan: GrowthScan.TileScan) -> void:
	for id: String in scan.city_payloads:
		assert(city.document.find_chunk(id).set_decoded_payload(scan.city_payloads[id]))
	city.resync_mirrors(CityState.MIRRORED_CHUNKS)


func _check_growth(edge: int) -> void:
	var city := _city(edge)
	for density in [2, 4]:
		var area: int = density / 2 + 1
		for origin in _sites(edge, area):
			var anchor := origin + Vector2i(0, area - 1)
			var scan := _scan(city)
			scan.buildings.fill(0)
			scan.zones.fill(6)
			assert(scan.allow_edge_buildings)
			scan._try_advance_density(origin if density == 2 else anchor, 6, 6,
				1 if density == 2 else 3, 1000)
			assert(scan.advanced_construction == (1 if density == 2 else 0))
			# 3x3 promotion still requires a real road at an in-map corner.
			if density == 4:
				for delta in [Vector2i(-1, 1), Vector2i(-1, -3), Vector2i(3, -3), Vector2i(3, 1)]:
					var road: Vector2i = anchor + delta
					if city.index_of(road.x, road.y) >= 0:
						scan.buildings[city.index_of(road.x, road.y)] = BuildingTileIds.ROAD_CROSSROADS
						break
				scan._try_advance_density(anchor, 6, 6, 3, 1000)
				assert(scan.advanced_construction == 1)
			assert(scan._try_complete_construction(anchor, 6, density))
			var developed := scan.buildings.duplicate()
			assert(scan._count_population_or_abandon(anchor, 6, density, 1000))
			assert(scan.buildings != developed)
			scan._try_recover_abandoned(anchor, 6, density, 1000)
			assert(scan.buildings == developed)
			_commit_scan(city, scan)
			_check_footprint(city, Rect2i(origin, Vector2i.ONE * area))
		# Explicitly reject footprints one tile beyond each edge without writes.
		for origin in [Vector2i(-1, 5), Vector2i(5, -1), Vector2i(edge - area + 1, 5), Vector2i(5, edge - area + 1)]:
			var scan := _scan(city)
			var before := scan.buildings.duplicate()
			assert(not GrowthDevelopment.place_zone(scan.buildings, scan.zones, scan.flags,
				scan.misc, scan.land_value, origin + Vector2i(0, area - 1), density,
				2, scan.random, 0, edge, true))
			assert(scan.buildings == before)

	# Use a small map for full rotations and demolition; size-dependent bounds
	# are checked above without repeating the same rotation rules on huge grids.
	if edge == 16:
		_check_rotations(city)
		_check_reload(city)


func _check_legacy() -> void:
	var city := _city(128, false)
	var scan := _scan(city)
	assert(not scan.allow_edge_buildings)
	for anchor in [Vector2i(0, 8), Vector2i(125, 8), Vector2i(8, 127)]:
		assert(not GrowthDevelopment.place_zone(scan.buildings, scan.zones, scan.flags,
			scan.misc, scan.land_value, anchor, 4, 2,
			scan.random, 0, 128, scan.allow_edge_buildings))
	assert(not BuildingSites.preview_valid(city, 13, 0, Vector2i(1, 1)))
	assert(not BuildingEdit.apply(city, 13, 0, Vector2i(1, 1), SimLfsrRandom.new(1), ZeroRandom.new()).ok)


func _check_tools() -> void:
	# One actual tool for each footprint size, including a powered facility.
	for tool in [Vector2i(14, 0), Vector2i(4, 2), Vector2i(13, 0), Vector2i(3, 2)]:
		var area: int = ToolCatalog.tool(tool.x, tool.y).area
		for origin in _sites(16, area):
			var city := _city(16)
			var selected := origin + (Vector2i.ONE if area > 2 else Vector2i.ZERO)
			assert(BuildingSites.preview_valid(city, tool.x, tool.y, selected))
			var result := BuildingEdit.apply(city, tool.x, tool.y, selected, SimLfsrRandom.new(1), ZeroRandom.new())
			assert(result.ok, result.error)
			_check_footprint(city, Rect2i(origin, Vector2i.ONE * area))
			_check_rotations(city)
			var demolition := DemolishCommand.apply_path(city, 0, 0, [origin], ZeroRandom.new())
			assert(demolition.ok, demolition.error)
			assert(city.buildings.count(BuildingSites.tile_for_tool(tool.x, tool.y)) == 0)
		for origin in [Vector2i(-1, 5), Vector2i(5, -1), Vector2i(17 - area, 5), Vector2i(5, 17 - area)]:
			assert(not BuildingSites._footprint_is_in_bounds(Rect2i(origin, Vector2i.ONE * area), area, 16, true))


func _check_special() -> void:
	for origin in _sites(16, 2):
		var city := _city(16)
		var scan := _scan(city)
		var anchor := origin + Vector2i(0, 1)
		assert(GrowthDevelopment._place_church(scan.buildings, scan.zones, scan.flags,
			scan.misc, anchor, 0, 16, scan.allow_edge_buildings))
		_commit_scan(city, scan)
		_check_footprint(city, Rect2i(origin, Vector2i(2, 2)))
		_check_rotations(city)
	for origin in [Vector2i.ZERO, Vector2i(14, 0), Vector2i(0, 14), Vector2i(14, 14)]:
		for zone in [7, 8, 9]:
			var city := _city(16)
			var scan := _scan(city)
			scan.zones.fill(zone)
			scan.flags.fill(Sc2TileFlags.POWERED)
			var result := SpecialZoneSelection.grow_special_zone(scan.buildings, scan.zones,
				scan.underground, scan.flags, scan.terrain, scan.altitudes, scan.misc,
				origin, BuildingTileIds.HANGAR_2 if zone == 8 else BuildingTileIds.CARGO_YARD,
				zone, 0, 16, scan.allow_edge_buildings)
			assert(result.ok and result.changed_tiles == 4)
			_commit_scan(city, scan)
			_check_footprint(city, Rect2i(origin, Vector2i(2, 2)))
			_check_rotations(city)


func _check_scurk() -> void:
	for tile in range(BuildingTileIds.DEVELOPED_FIRST, BuildingTileIds.MAX_ID + 1):
		if not ScurkPlaceCommand.is_placeable_tile(tile):
			continue
		var city := _city(16)
		var area := DemolishStructures.structure_area(tile)
		var origin := Vector2i.ONE * (16 - area)
		var selected := origin + (Vector2i.ONE if area > 2 else Vector2i.ZERO)
		if tile in [BuildingTileIds.HYDRO_POWER_1, BuildingTileIds.HYDRO_POWER_2]:
			city.set_terrain_id(origin.x, origin.y, TerrainTileIds.SLOPE_TOP_LEFT)
			city.set_tile_flag(origin.x, origin.y, Sc2TileFlags.WATER, true)
		elif tile == BuildingTileIds.MARINA:
			city.set_tile_flag(origin.x, origin.y, Sc2TileFlags.WATER, true)
		var result := ScurkPlaceCommand.apply(city, tile, selected, ZeroRandom.new())
		assert(result.ok, "SCURK edge tile %d: %s" % [tile, result.error])
		_check_footprint(city, Rect2i(origin, Vector2i.ONE * area))
		_check_rotations(city)
	var legacy := _city(128, false)
	assert(not ScurkPlaceCommand.apply(legacy, BuildingTileIds.LARGE_FACTORY_3X3,
		Vector2i(126, 126), ZeroRandom.new()).ok)


func _check_footprint(city: CityState, site: Rect2i) -> void:
	var tile := city.building_id(site.position.x, site.position.y)
	var drawn := 0
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			assert(city.building_id(x, y) == tile)
			assert(DemolishEffectsSites._find_building_site(city.buildings, city.zones,
				Vector2i(x, y), tile, site.size.x, city.compass_rotation(), city.map_size) == site)
			if IsometricStaticVisuals._should_draw_building(city, x, y, tile):
				drawn += 1
				assert(Vector2i(x, y) == Vector2i(site.position.x, site.end.y - 1))
	assert(drawn == 1)


func _check_rotations(city: CityState) -> void:
	var before_buildings := city.buildings.duplicate()
	var before_zones := city.zones.duplicate()
	for ccw in [false, true]:
		for turn in 4:
			assert(CityRotationCommand.apply(city, ccw).ok)
			for x in city.map_size:
				for y in city.map_size:
					var tile := city.building_id(x, y)
					if tile < BuildingTileIds.DEVELOPED_FIRST or not IsometricStaticVisuals._should_draw_building(city, x, y, tile):
						continue
					var area := DemolishStructures.structure_area(tile)
					_check_footprint(city, Rect2i(x, y - area + 1, area, area))
		assert(city.buildings == before_buildings and city.zones == before_zones)


func _check_reload(city: CityState) -> void:
	var encoded := city.document.serialize()
	assert(encoded.ok, encoded.error)
	var loaded := Sc2File.new()
	assert(loaded.parse(encoded.data))
	assert(loaded.is_extended())
	var restored := CityState.from_document(loaded)
	assert(restored.buildings == city.buildings and restored.zones == city.zones)
	_check_rotations(restored)
