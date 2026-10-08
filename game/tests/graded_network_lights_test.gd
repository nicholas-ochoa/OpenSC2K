extends SceneTree
## Match graded transport lighting to the independent terrain corner geometry.
const State = preload("res://tests/support/document_state.gd")

func _initialize() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(128))
	var tile := Vector2i(64, 64)
	city.set_land_altitude(64, 64, 3)
	for highway in [false, true]:
		for rotation in 4:
			city.set_building_id(64, 64, (BuildingTileIds.HIGHWAY_SLOPE_1 if highway else BuildingTileIds.ROAD_SLOPE_1) + rotation)
			city.set_terrain_id(64, 64, rotation + 1)
			var before := State.capture(city.document)
			var high: int = [3, 0, 1, 2][rotation]
			var low := (high + 2) % 4
			assert(CityLifePaths.ports(city, tile) == ((1 << high) | (1 << low)), "Slope display lanes cross the road instead of following it")
			var raised := 1.0 if highway else 0.0
			assert(CityLifePaths.edge_height(city, tile, high) == 4 + raised)
			assert(CityLifePaths.edge_height(city, tile, low) == 3 + raised)
			_check_surface(city, tile, high, raised)
			_check_lamp(city, tile, high, raised)
			assert(State.capture(city.document) == before, "Slope display queries changed the city")
			for walking in [false, true]:
				if highway and walking:
					continue
				for direction in [high, low]:
					var next: Vector2i = tile + CityLifePaths.DIRECTIONS[direction]
					city.set_building_id(next.x, next.y, (BuildingTileIds.HIGHWAY_STRAIGHT_1 if highway else BuildingTileIds.ROAD_STRAIGHT_1) + direction % 2)
					city.set_land_altitude(next.x, next.y, 4 if direction == high else 3)
					city.set_terrain_id(next.x, next.y, 0)
					assert(CityLifePaths.connected(city, tile, direction, walking), "Slope fails to meet its flat continuation")
					var a := CityLifePaths.point(city, tile, (direction + 2) % 4, direction, 1, walking)
					var b := CityLifePaths.point(city, next, (direction + 2) % 4, direction, 0, walking)
					assert(a.is_equal_approx(b), "Light/vehicle geometry jumps at slope boundary")
	_check_ramps_and_bridges(city, tile)
	print("PASS: all road/highway grades match terrain, graded receiver pixels and lamp feet, flat joins, ramps and level bridge decks")
	quit()


func _check_surface(city: CityState, tile: Vector2i, high: int, raised: float) -> void:
	var lights := CityLifeLights.new()
	var seen := 0
	for patch: Dictionary in lights._road_patches(city, tile, high):
		for y in patch.image.get_height():
			for x in patch.image.get_width():
				var pixel: Color = patch.image.get_pixel(x, y)
				if pixel.a == 0:
					continue
				seen += 1
				var local := Vector2(pixel.r, pixel.g) - Vector2(tile)
				# A legal planar slope rises one level toward its high edge.
				var height := 3.5 + raised + local.dot(Vector2(CityLifePaths.DIRECTIONS[high]))
				var expected := Vector2(48 + city.map_size * 16, 520 + 128 * 8) \
					+ Vector2((local.x - local.y) * 16, (local.x + local.y) * 8 - height * 12)
				var actual := Vector2(patch.origin) + Vector2(x + 0.5, y + 0.5)
				assert(expected.distance_to(actual) < 0.001, "Light receiver is flat or misaligned with sloping asphalt")
	assert(seen > 8, "Slope has no light receiver")


func _check_lamp(city: CityState, tile: Vector2i, high: int, raised: float) -> void:
	var layout := CityNightFixtures.street_layout(city, tile, 2)
	assert(not layout.is_empty())
	for fixture in layout:
		var offset: Vector2 = fixture.offset
		assert(absf(offset.dot(Vector2(CityLifePaths.DIRECTIONS[high]))) < 0.001, "Pole lies along the lane instead of beside it")
		var height := 3.5 + raised + offset.dot(Vector2(CityLifePaths.DIRECTIONS[high]))
		var expected := Vector2(48 + city.map_size * 16, 520 + 128 * 8) \
			+ Vector2((offset.x - offset.y) * 16, (offset.x + offset.y) * 8 - height * 12)
		assert(CityNightFixtures._foot(city, tile, offset, fixture.enter) == Vector2i(expected.round()), "Pole foot floats above its graded road")


func _check_ramps_and_bridges(city: CityState, tile: Vector2i) -> void:
	city.set_terrain_id(64, 64, 0)
	for flipped in [false, true]:
		city.set_tile_flag(64, 64, Sc2TileFlags.FLIPPED, flipped)
		for rotation in 4:
			city.set_building_id(64, 64, BuildingTileIds.HIGHWAY_ONRAMP_1 + rotation)
			var high := CityLifePaths.ramp_highway_direction(city, tile)
			var low := CityLifePaths.ramp_road_direction(city, tile)
			assert(CityLifePaths.edge_height(city, tile, high) == 4)
			assert(CityLifePaths.edge_height(city, tile, low) == 3)
			assert(CityLifePaths.ports(city, tile) == ((1 << high) | (1 << low)))
		for id in [BuildingTileIds.SUSPENSION_BRIDGE_1, BuildingTileIds.HIGHWAY_BRIDGE, BuildingTileIds.REINFORCED_HIGHWAY_BRIDGE]:
			city.set_building_id(64, 64, id)
			city.set_terrain_id(64, 64, 2)
			var level := CityLifePaths.edge_height(city, tile, 0)
			for direction in 4:
				assert(CityLifePaths.edge_height(city, tile, direction) == level, "Bridge deck incorrectly follows the ground slope")
			city.set_terrain_id(64, 64, 0)
