extends SceneTree

@warning_ignore_start("integer_division")


func _initialize() -> void:
	_check_stamp_pixels()
	_check_road_pixels()
	_check_local_invalidation()
	_check_surface_budget()
	_check_network_search()
	_check_geometry_changes()
	_check_path_segments()
	print("PASS: exact city-life artwork/emission pixels, road coordinates, local occlusion invalidation and bounded light reuse")
	quit()


func _check_path_segments() -> void:
	var city := load("res://tests/city_life_test.gd").fixture() as CityState
	var tile := Vector2i(64, 64)
	for id in [BuildingTileIds.ROAD_CROSSROADS, BuildingTileIds.HIGHWAY_CURVE_1,
			BuildingTileIds.HIGHWAY_ONRAMP_1, BuildingTileIds.HIGHWAY_ROAD_CROSSING_1, BuildingTileIds.HIGHWAY_BRIDGE]:
		city.set_building_id(tile.x, tile.y, id)
		for shape in [0, 1, 6]:
			city.set_terrain_id(tile.x, tile.y, shape)
			for flipped in [false, true]:
				city.set_tile_flag(tile.x, tile.y, Sc2TileFlags.FLIPPED, flipped)
				for enter in 4:
					for exit in 4:
						for walking in [false, true]:
							var segment := CityLifePaths.Segment.new(city, tile, enter, exit, walking)
							for progress in [-0.1, 0.0, 0.1, 0.499, 0.5, 0.7, 1.0, 1.1]:
								assert(segment.point(progress) == CityLifePaths.point(city, tile, enter, exit, progress, walking),
									"Cached lane geometry must preserve exact positions, bends, grades and endpoint clamping")


func _check_geometry_changes() -> void:
	var city := load("res://tests/city_life_test.gd").fixture() as CityState
	var lights := CityLifeLights.new()
	lights.sync_geometry(city)
	assert(lights.geometry_reset)
	var tile := Vector2i(64, 64)
	var before := lights.surface(city, tile, 0, 2)
	city.set_building_id(10, 10, 112)
	lights.sync_geometry(city)
	assert(not lights.geometry_reset and lights.surface(city, tile, 0, 2).texture == before.texture,
		"Distant development must not rebuild unchanged road receivers")
	city.set_tile_flag(64, 64, Sc2TileFlags.POWERED, true)
	city.set_zone_id(64, 64, 2)
	assert(lights.sync_geometry(city).is_empty(), "Power and zoning colors do not alter road geometry")
	for change in ["slope", "height", "building", "flip", "corner"]:
		match change:
			"slope":
				city.set_terrain_id(64, 64, 6)
			"height":
				city.set_land_altitude(64, 64, 3)
			"building":
				city.set_building_id(64, 64, BuildingTileIds.HIGHWAY_CURVE_1)
			"flip":
				city.set_tile_flag(64, 64, Sc2TileFlags.FLIPPED, true)
			"corner":
				city.set_building_corners(64, 64, 0x80)
		assert(lights.sync_geometry(city).has(tile), "Changed geometry not detected: " + change)
		var cached := lights.surface(city, tile, 0, 2)
		var fresh := CityLifeLights.new().surface(city, tile, 0, 2)
		assert(cached.image.get_data() == fresh.image.get_data(), "Local geometry update left stale road pixels: " + change)
	# An initially closed next tile becomes part of an existing headlight receiver.
	city.set_land_altitude(64, 64, 0)
	city.set_terrain_id(64, 64, 0)
	city.set_building_id(64, 64, BuildingTileIds.ROAD_STRAIGHT_1)
	city.set_building_id(64, 65, 0)
	lights.sync_geometry(city)
	before = lights.surface(city, tile, 0, 2)
	city.set_building_id(64, 65, BuildingTileIds.ROAD_STRAIGHT_1)
	lights.sync_geometry(city)
	var reopened := lights.surface(city, tile, 0, 2)
	assert(reopened.texture != before.texture)
	assert(reopened.image.get_data() == CityLifeLights.new().surface(city, tile, 0, 2).image.get_data())
	assert(NativeCityChanges.changed_cells(PackedByteArray([1, 2, 3, 4]), PackedByteArray([1, 8, 3, 9]), 2, 255) == PackedInt32Array([0, 1]))


func _check_stamp_pixels() -> void:
	var sprites := CityLifeSprites.new()
	var lights := CityLifeLights.new()
	var mask := Image.create(11, 9, false, Image.FORMAT_RGBA8)
	for y in mask.get_height():
		for x in mask.get_width():
			mask.set_pixel(x, y, Color(0.2, 0.4, 0.6, 0.1 if (x + y) % 3 == 0 else 0.0))
	var occluders: Array = [{"origin": Vector2i(-4, -2), "image": mask}, {"origin": Vector2i(3, 2), "image": mask}]
	var merged := CityLifeCanvas.merged_occluders(occluders)
	for y in range(-5, 15):
		for x in range(-8, 20):
			assert(CityLifeCanvas.hidden_at(Vector2i(x, y), occluders) == CityLifeCanvas.hidden_at(Vector2i(x, y), merged))
	for opacity in [0.0, 0.31, 1.0]:
		for offset in [Vector2i(-5, -4), Vector2i.ZERO, Vector2i(4, 5)]:
			var expected := Image.create(16, 12, false, Image.FORMAT_RGBA8)
			var actual := expected.duplicate() as Image
			var expected_lamps := expected.duplicate() as Image
			var actual_lamps := expected.duplicate() as Image
			for kind in 4:
				for direction in 4:
					var sprite := sprites.sprite(kind == 3, kind * 3, direction, direction % 2, mini(kind, 2))
					var lamps := lights.lamp_mask(sprite, kind, direction) if kind < 3 else null
					var origin := Vector2i(kind - 3, direction - 2)
					_reference_stamp(expected, offset, sprite, origin, occluders, opacity, expected_lamps, lamps)
					CityLifeCanvas.stamp(actual, offset, sprite, origin, merged, opacity, actual_lamps, lamps)
					assert(actual.get_data() == expected.get_data(), "Batch blits changed overlap, clipping or fade pixels")
					assert(actual_lamps.get_data() == expected_lamps.get_data(), "A later figure failed to replace the old lamp pixels")


func _reference_stamp(destination: Image, offset: Vector2i, sprite: Image, origin: Vector2i,
		occluders: Array, opacity: float, emission: Image, lamps: Image) -> void:
	# Original per-pixel replacement rule, including transparent lamp erasure.
	for y in sprite.get_height():
		for x in sprite.get_width():
			var color := sprite.get_pixel(x, y)
			var point := origin + Vector2i(x, y)
			var local := point - offset
			if color.a == 0.0 or not Rect2i(Vector2i.ZERO, destination.get_size()).has_point(local):
				continue
			if CityLifeCanvas.hidden_at(point, occluders):
				continue
			color.a *= opacity
			destination.set_pixelv(local, color)
			var lamp := lamps.get_pixel(x, y) if lamps != null else Color.TRANSPARENT
			lamp.a *= opacity
			emission.set_pixelv(local, lamp)


func _check_road_pixels() -> void:
	var city := load("res://tests/city_life_test.gd").fixture() as CityState
	var mask := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	mask.fill_rect(Rect2i(20, 0, 13, 64), Color.WHITE)
	var occluders: Array = [{"origin": Vector2i(2080, 1512), "image": mask}]
	for slope in [0, 1, 6]:
		city.set_terrain_id(64, 64, slope)
		var lights := CityLifeLights.new()
		for direction in 4:
			var tile := Vector2i(64, 64)
			var enter := (direction + 2) % 4
			var surface := lights.surface(city, tile, enter, direction,
				func(_tile: Vector2i, _enter: int) -> Array: return occluders)
			var expected := Image.create(96, 96, false, Image.FORMAT_RGBAF)
			var bounds := Rect2i(surface.origin, expected.get_size())
			for step in 3:
				for road: Dictionary in lights._road_patches(city, tile, enter):
					for y in road.image.get_height():
						for x in road.image.get_width():
							var color: Color = road.image.get_pixel(x, y)
							var point: Vector2i = road.origin + Vector2i(x, y)
							if color.a > 0.0 and bounds.has_point(point) and not CityLifeCanvas.hidden_at(point, occluders):
								expected.set_pixelv(point - bounds.position, color)
				if not CityLifePaths.connected(city, tile, direction):
					break
				tile += CityLifePaths.DIRECTIONS[direction]
				enter = (direction + 2) % 4
			assert(surface.image.get_data() == expected.get_data(), "Road blits changed numeric world coordinates or occlusion")


func _check_local_invalidation() -> void:
	var app := CityApplication.new()
	var canvas := CityLifeCanvas.new()
	app.city_life.canvas = canvas
	var near := Vector3i(1, 2, 0)
	var far := Vector3i(3, 4, 1)
	var near_surface := Vector4i(1, 2, 0, 1)
	var far_surface := Vector4i(3, 4, 1, 2)
	canvas._occluder_bounds.assign({near: Rect2i(0, 0, 64, 48), far: Rect2i(500, 500, 64, 48)})
	canvas._occluders.assign({near: [], far: []})
	canvas._light_occluders.assign({near: [], far: []})
	canvas.lights.visible_roads.assign({near: [], far: []})
	canvas.lights.surfaces.assign({near_surface: {"occlusion_keys": [far, near]}, far_surface: {"occlusion_keys": [far]}})
	var changed: Array[Rect2i] = [Rect2i(32, 16, 8, 8)]
	app.map_render._invalidate_region_foregrounds(changed, [])
	assert(canvas._occluders.size() == 2, "A palette-only publication invalidated silhouettes")
	app.map_render._invalidate_region_foregrounds(changed, changed)
	assert(not canvas._occluders.has(near) and canvas._occluders.has(far))
	assert(not canvas._light_occluders.has(near) and canvas._light_occluders.has(far))
	assert(not canvas.lights.visible_roads.has(near) and canvas.lights.visible_roads.has(far))
	assert(not canvas.lights.surfaces.has(near_surface) and canvas.lights.surfaces.has(far_surface),
		"A surface must depend on every queried road tile, including the tiles ahead")
	var regions := CityRegionCache.new()
	regions.region_edge = 256
	regions.divisor = 1
	regions.visible.assign([Vector2i.ZERO, Vector2i(1, 1)])
	regions.visible_keys.assign({Vector2i.ZERO: true, Vector2i(1, 1): true})
	canvas._sync_visible_regions(regions)
	regions.visible.assign([Vector2i.ZERO])
	regions.visible_keys.erase(Vector2i(1, 1))
	canvas._sync_visible_regions(regions)
	assert(canvas._occluders.is_empty() and canvas.lights.surfaces.is_empty(),
		"Regions that leave the viewport must release cached silhouettes and dependent lights")
	canvas.free()
	app.free()


func _check_surface_budget() -> void:
	var city := load("res://tests/city_life_test.gd").fixture() as CityState
	var lights := CityLifeLights.new()
	for i in CityLifeLights.SURFACE_LIMIT:
		lights.surfaces[Vector4i(i, 0, 0, 0)] = {"retained": i}
	var oldest := lights.surface(city, Vector2i.ZERO, 0, 0)
	lights.surface(city, Vector2i(64, 64), 0, 2)
	assert(lights.surfaces.size() == CityLifeLights.SURFACE_LIMIT)
	assert(lights.surfaces[Vector4i.ZERO] == oldest and not lights.surfaces.has(Vector4i(1, 0, 0, 0)),
		"The cache must retain recently used light surfaces when it reaches its budget")


func _check_network_search() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	for id in 256:
		city.set_building_id(id / 16, id % 16, id)
	for area in [Rect2i(0, 0, 128, 128), Rect2i(3, 2, 7, 11), Rect2i(0, 15, 16, 1)]:
		var expected: Array[Vector2i] = []
		for x in range(area.position.x, area.end.x):
			for y in range(area.position.y, area.end.y):
				if CityLifePaths.ports(city, Vector2i(x, y)) != 0:
					expected.append(Vector2i(x, y))
		var actual: Array[Vector2i] = []
		for index in CityLifePaths.candidate_indices(city, area.position, area.end - Vector2i.ONE):
			var tile := Vector2i(index / city.map_size, index % city.map_size)
			if CityLifePaths.ports(city, tile) != 0:
				actual.append(tile)
		assert(actual == expected, "Packed search must preserve every network id and original spawn order")
	assert(CityLifePaths.candidate_indices(city, Vector2i(129, 0), Vector2i(127, 127)).is_empty())
	var app := CityApplication.new()
	city.set_building_id(0, 0, BuildingTileIds.BUS_DEPOT)
	city.set_building_id(127, 127, BuildingTileIds.BUS_DEPOT)
	city.set_building_id(127, 126, BuildingTileIds.ROAD_STRAIGHT_1)
	var expected_bus := {}
	for x in city.map_size:
		for y in city.map_size:
			if city.building_id(x, y) != BuildingTileIds.BUS_DEPOT:
				continue
			for dx in range(-CityLifeController.BUS_RADIUS, CityLifeController.BUS_RADIUS + 1):
				for dy in range(-CityLifeController.BUS_RADIUS, CityLifeController.BUS_RADIUS + 1):
					var tile := Vector2i(x + dx, y + dy)
					if dx * dx + dy * dy <= CityLifeController.BUS_RADIUS * CityLifeController.BUS_RADIUS and CityLifePaths.ports(city, tile) != 0:
						expected_bus[tile] = true
	app.city_life._refresh_bus_area(city)
	assert(app.city_life._bus_tiles == expected_bus, "Packed depot search changed decorative bus coverage at map edges")
	city.set_building_id(127, 127, 0)
	app.city_life._refresh_bus_area(city)
	assert(not app.city_life._bus_tiles.has(Vector2i(127, 126)), "A removed depot retained its coverage")
	app.free()
