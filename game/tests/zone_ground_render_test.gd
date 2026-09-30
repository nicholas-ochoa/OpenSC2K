extends SceneTree
## The original draws the zone in place of flat ground. Rubble, radioactive
## waste, trees, parks, and power lines stand on the zone. Roads and other
## networks hide it, and sloped ground keeps its terrain tile.

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")


func _initialize() -> void:
	var palette := Sc2Palette.index_encoding()
	var sprites := FixtureGraphics.pack().large_sprites
	var city := CityState.from_document(Sc2File.load_path("res://tests/fixtures/cities/generated-128.SC2"))
	assert(city.is_valid() and sprites.is_valid())

	var zones := PackedByteArray()
	zones.resize(city.map_size * city.map_size)
	assert(city.replace_zones(zones))

	var point := Vector2i(20, 20)
	var configuration := CityIsometricRenderer.view_configuration(CityIsometricRenderer.VIEW_LARGE)
	var origin := configuration.side_margin + city.map_size * configuration.half_width
	var zone := 1
	var zone_sprite := configuration.sprite_base + 290 + zone
	assert(city.set_zone_id(point.x, point.y, zone))
	assert(city.tile_is_visible(point.x, point.y))

	var shown := [Tiles.EMPTY, Tiles.RUBBLE_1, Tiles.RADIOACTIVE_WASTE, Tiles.TREES_1, Tiles.TREES_7,
		Tiles.SMALL_PARK, Tiles.POWER_LINE_STRAIGHT_1, Tiles.POWER_LINE_CROSSROADS]
	var hidden := [Tiles.ROAD_STRAIGHT_1, Tiles.RAIL_STRAIGHT_1]
	var cases := []

	for building: int in shown:
		cases.append([TerrainTileIds.FLAT, building, true])

	for building: int in hidden:
		cases.append([TerrainTileIds.FLAT, building, false])

	cases.append([TerrainTileIds.RAISED_EXCEPT_BOTTOM, Tiles.EMPTY, false])
	cases.append([TerrainTileIds.RAISED_EXCEPT_BOTTOM, Tiles.TREES_1, false])

	for entry: Array in cases:
		var terrain: int = entry[0]
		var building: int = entry[1]
		var expected: bool = entry[2]
		var label := "terrain 0x%02x building 0x%02x" % [terrain, building]
		assert(city.set_terrain_id(point.x, point.y, terrain) and city.set_building_id(point.x, point.y, building))
		var terrain_sprite := IsometricGeometry.terrain_sprite_id(terrain, city.is_water(point.x, point.y), configuration.sprite_base)

		var drawn := NativeTileDraws.sprite_ids(city, sprites, CityIsometricRenderer.VIEW_LARGE, point.x, point.y)
		assert(drawn.has(zone_sprite) == expected, "Tile painter zone for %s" % label)
		assert(drawn.has(terrain_sprite) != expected, "Tile painter terrain for %s" % label)

		var occluders := 0

		for command in CityIsometricRenderer.static_occlusion_commands(city, sprites, CityIsometricRenderer.VIEW_LARGE):
			if command.sprite_id == zone_sprite:
				occluders += 1

		assert((occluders == 1) == expected, "Foreground zone for %s" % label)

	_check_hidden_buildings(city, palette, sprites, configuration, origin, point)
	print("PASS: zones and hidden-building lots replace the ground as in the original")
	quit()


## The original draws a lot in place of a hidden building, and the zone in place
## of a zoned building when zones are hidden. Terrain does not matter here.
func _check_hidden_buildings(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		configuration: CityViewConfiguration, origin: int, point: Vector2i) -> void:
	var developed := Tiles.DEVELOPED_FIRST
	var buildings_off := { "buildings": false }
	var zones_off := { "zones": false }
	var both_off := { "buildings": false, "zones": false }
	var cases := [
		[TerrainTileIds.FLAT, developed, 1, buildings_off, 300],
		[TerrainTileIds.FLAT, developed, 4, buildings_off, 301],
		[TerrainTileIds.FLAT, developed, 6, buildings_off, 302],
		[TerrainTileIds.FLAT, developed, 0, buildings_off, 303],
		[TerrainTileIds.FLAT, developed, 9, buildings_off, 304],
		[TerrainTileIds.SURFACE_WATER_FIRST, developed, 2, buildings_off, 300],
		[TerrainTileIds.FLAT, developed, 3, zones_off, 293],
		[TerrainTileIds.FLAT, developed, 3, both_off, 293],
		[TerrainTileIds.FLAT, developed, 0, zones_off, -1],
		[TerrainTileIds.FLAT, Tiles.EMPTY, 1, zones_off, 291],
	]

	for entry: Array in cases:
		var terrain: int = entry[0]
		var building: int = entry[1]
		var zone: int = entry[2]
		var visibility: Dictionary = entry[3]
		var expected: int = entry[4]
		var label := "zone %d building 0x%02x with %s" % [zone, building, visibility]
		assert(city.set_terrain_id(point.x, point.y, terrain) and city.set_building_id(point.x, point.y, building))
		assert(city.set_zone_id(point.x, point.y, zone) and city.set_building_corners(point.x, point.y, Sc2ZoneLayout.CORNERS_MASK))
		var shown := CityViewFilter.surface_copy(city, visibility)
		var sprite := configuration.sprite_base + (expected if expected >= 0 else building)
		assert(NativeTileDraws.sprite_ids(shown, sprites, CityIsometricRenderer.VIEW_LARGE, point.x, point.y).has(sprite),
			"Tile painter for %s" % label)


	# a lot and a zone on the same tile must not share a reused GPU tile
	assert(city.set_terrain_id(point.x, point.y, TerrainTileIds.FLAT) and city.set_building_id(point.x, point.y, developed))
	assert(city.set_zone_id(point.x, point.y, 3))
	var bounds := Rect2i(configuration.side_margin + city.map_size * configuration.half_width - 96,
		configuration.top_margin + 40 * configuration.half_height - 160, 192, 224)
	var context := CityGpuBuildContext.new()

	for revision in 4:
		var shown := CityViewFilter.surface_copy(city, [buildings_off, zones_off][revision % 2])
		var expected := CityRegionRenderer.render(shown, palette, sprites, bounds).image
		expected.convert(Image.FORMAT_LA8)
		var region := CityGpuRegionRenderer.render(shown, palette, sprites, bounds, CityIsometricRenderer.VIEW_LARGE,
			CityViewMode.Mode.CITY, true, true, context, revision + 1, -1)
		assert(region.ok and region.paint(bounds).get_data() == expected.get_data(), "Warm GPU lot and zone differ")
