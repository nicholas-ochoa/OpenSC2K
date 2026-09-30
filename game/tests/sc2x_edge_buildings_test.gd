extends SceneTree


func _initialize() -> void:
	_check_legacy()
	_check_tools()
	_check_scurk()
	print("PASS: SC2X edge tools, rotation, demolition and save reload")
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


# the native growth rules have their own edge tests. the tools keep the classic margin
func _check_legacy() -> void:
	var city := _city(128, false)
	assert(not BuildingSites.preview_valid(city, 13, 0, Vector2i(1, 1)))
	assert(not BuildingCommand.apply(city, 13, 0, Vector2i(1, 1), SimLfsrRandom.new(1), ZeroRandom.new()).ok)


func _check_tools() -> void:
	# One actual tool for each footprint size, including a powered facility.
	for tool in [Vector2i(14, 0), Vector2i(4, 2), Vector2i(13, 0), Vector2i(3, 2)]:
		var area: int = ToolCatalog.tool(tool.x, tool.y).area
		for origin in _sites(16, area):
			var city := _city(16)
			var selected := origin + (Vector2i.ONE if area > 2 else Vector2i.ZERO)
			assert(BuildingSites.preview_valid(city, tool.x, tool.y, selected))
			var result := BuildingCommand.apply(city, tool.x, tool.y, selected, SimLfsrRandom.new(1), ZeroRandom.new())
			assert(result.ok, result.error)
			_check_footprint(city, Rect2i(origin, Vector2i.ONE * area), _anchors(city))
			_check_rotations(city)
			if origin == Vector2i.ZERO:
				_check_reload(city)
			var demolition := DemolishCommand.apply_path(city, 0, 0, [origin], ZeroRandom.new())
			assert(demolition.ok, demolition.error)
			assert(city.buildings.count(BuildingSites.tile_for_tool(tool.x, tool.y)) == 0)
		for origin in [Vector2i(-1, 5), Vector2i(5, -1), Vector2i(17 - area, 5), Vector2i(5, 17 - area)]:
			var outside: Vector2i = origin + (Vector2i.ONE if area > 2 else Vector2i.ZERO)
			assert(not BuildingSites.preview_valid(_city(16), tool.x, tool.y, outside))


func _check_scurk() -> void:
	for tile in range(BuildingTileIds.DEVELOPED_FIRST, BuildingTileIds.MAX_ID + 1):
		if not ScurkPlaceCommand.is_placeable_tile(tile):
			continue
		var city := _city(16)
		var area := NativeCityTools.building_area(tile)
		var origin := Vector2i.ONE * (16 - area)
		var selected := origin + (Vector2i.ONE if area > 2 else Vector2i.ZERO)
		if tile in [BuildingTileIds.HYDRO_POWER_1, BuildingTileIds.HYDRO_POWER_2]:
			city.set_terrain_id(origin.x, origin.y, TerrainTileIds.SLOPE_TOP_LEFT)
			city.set_tile_flag(origin.x, origin.y, Sc2TileFlags.WATER, true)
		elif tile == BuildingTileIds.MARINA:
			city.set_tile_flag(origin.x, origin.y, Sc2TileFlags.WATER, true)
		var result := ScurkPlaceCommand.apply(city, tile, selected, ZeroRandom.new())
		assert(result.ok, "SCURK edge tile %d: %s" % [tile, result.error])
		_check_footprint(city, Rect2i(origin, Vector2i.ONE * area), _anchors(city))
		_check_rotations(city)
	var legacy := _city(128, false)
	assert(not ScurkPlaceCommand.apply(legacy, BuildingTileIds.LARGE_FACTORY_3X3,
		Vector2i(126, 126), ZeroRandom.new()).ok)


# the map cells whose building sprite the native painter draws
func _anchors(city: CityState) -> Dictionary[int, bool]:
	var tiles: Array[Vector2i] = []

	for x in city.map_size:
		for y in city.map_size:
			if city.building_id(x, y) > BuildingTileIds.EMPTY:
				tiles.append(Vector2i(x, y))

	var context := CityGpuBuildContext.new()
	assert(context.prepare(city, Sc2Palette.index_encoding(), FixtureGraphics.pack().large_sprites,
		CityIsometricRenderer.VIEW_LARGE, CityViewMode.Mode.CITY, true, true, true, 0, false).is_empty())
	var anchors: Dictionary[int, bool] = {}

	for draw in context.tile_draw_list(tiles).draws:
		var y := int(draw.depth_order) % city.map_size
		var x := int(draw.depth_order) / city.map_size - y

		if draw.sprite_id == 1000 + city.building_id(x, y):
			anchors[city.index_of(x, y)] = true

	return anchors


func _check_footprint(city: CityState, site: Rect2i, anchors: Dictionary[int, bool]) -> void:
	var tile := city.building_id(site.position.x, site.position.y)
	var drawn := 0
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			assert(city.building_id(x, y) == tile)
			assert(NativeCityTools.find_building_site(city.buildings, city.zones,
				Vector2i(x, y), tile, site.size.x, city.compass_rotation(), city.map_size) == site)
			if anchors.has(city.index_of(x, y)):
				drawn += 1
				assert(Vector2i(x, y) == Vector2i(site.position.x, site.end.y - 1))
	assert(drawn == 1)


func _check_rotations(city: CityState) -> void:
	var before_buildings := city.buildings.duplicate()
	var before_zones := city.zones.duplicate()
	for ccw in [false, true]:
		for turn in 4:
			assert(CityRotationCommand.apply(city, ccw).ok)
			var anchors := _anchors(city)
			for x in city.map_size:
				for y in city.map_size:
					var tile := city.building_id(x, y)
					if tile < BuildingTileIds.DEVELOPED_FIRST or not anchors.has(city.index_of(x, y)):
						continue
					var area := NativeCityTools.building_area(tile)
					_check_footprint(city, Rect2i(x, y - area + 1, area, area), anchors)
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


## SC2X building footprints can touch every edge without shifting on rotation.

@warning_ignore_start("integer_division")


class ZeroRandom extends SimRandom:
	func next_u15() -> int:
		return 0
