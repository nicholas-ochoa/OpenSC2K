extends "res://tests/city_gpu_geometry_test.gd"
## Compare edge building pixels in the region painter and native GPU renderer.

@warning_ignore_start("integer_division")


static func edge_city() -> CityState:
	var city := CityState.from_document(EmptyCityTemplate.create(32))
	city.document.set_misc_i32(Sc2MiscLayout.FUNDS, 1000000)
	for x in city.map_size:
		for y in city.map_size:
			city.set_land_altitude(x, y, 4)
	var origins := [Vector2i.ZERO, Vector2i(29, 0), Vector2i(0, 29),
		Vector2i(29, 29), Vector2i(0, 12), Vector2i(29, 12)]
	# a grown 3x3 building at each edge, with the corner flags of view 0
	var corners := {Vector2i(0, 0): 0x10, Vector2i(2, 0): 0x20, Vector2i(2, 2): 0x40, Vector2i(0, 2): 0x80}
	for i in origins.size():
		var origin: Vector2i = origins[i]
		for x in range(origin.x, origin.x + 3):
			for y in range(origin.y, origin.y + 3):
				assert(city.set_building_id(x, y, BuildingTileIds.INDUSTRIAL_3X3_FIRST + i))
				assert(city.set_tile_flag(x, y, Sc2TileFlags.STRUCTURE_MASK, true))
				assert(city.set_building_corners(x, y, int(corners.get(Vector2i(x, y) - origin, 0))))
	for item in [[13, 0, Vector2i(13, 1)], [3, 2, Vector2i(13, 29)],
		[14, 1, Vector2i(1, 23)], [14, 0, Vector2i(31, 22)], [4, 2, Vector2i(22, 0)]]:
		var result := BuildingCommand.apply(city, item[0], item[1], item[2], SimLfsrRandom.new(1), SimRandom.new(1))
		assert(result.ok, result.error)
	assert(ScurkPlaceCommand.apply(city, BuildingTileIds.LAUNCH_ARCOLOGY, Vector2i(23, 29), SimRandom.new(1)).ok)
	return city


func _run() -> void:
	var city := edge_city()
	var pack := FixtureGraphics.pack()
	for turn in 4:
		for view in 3:
			var sprites := pack.large_sprites if view == 2 else pack.small_medium_sprites
			var config := CityIsometricRenderer.view_configuration(view)
			# Include the complete small map, tall artwork, and exposed edge walls.
			var bounds := Rect2i(config.side_margin, config.top_margin - 256 / config.divisor,
				32 * config.tile_width + config.tile_width, 32 * config.tile_height + 320 / config.divisor)
			await _compare(city, Sc2Palette.index_encoding(), sprites, bounds, view,
				CityViewMode.Mode.CITY, CityGpuBuildContext.new())
		assert(CityRotationCommand.apply(city, false).ok)
	print("PASS: SC2X edge buildings match CPU and GPU pixels at all artwork sizes and rotations")
	quit()
