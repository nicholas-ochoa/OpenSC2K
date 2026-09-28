extends SceneTree
## Trees and power lines draw over the zone, so the zone stays visible.
## Other buildings hide the zone.

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

	var shown := [Tiles.EMPTY, Tiles.TREES_1, Tiles.TREES_7, Tiles.POWER_LINE_STRAIGHT_1, Tiles.POWER_LINE_CROSSROADS]
	var hidden := [Tiles.RUBBLE_1, Tiles.SMALL_PARK, Tiles.ROAD_STRAIGHT_1]

	for building: int in shown + hidden:
		var expected := building in shown
		assert(city.set_building_id(point.x, point.y, building))

		var context := CityGpuBuildContext.new()
		var zone_image := CityIsometricRenderer.sprite_image(sprites, palette, context.images, zone_sprite, false)
		var painter := CityGpuDrawList.new()
		CityIsometricRenderer.draw_tile(painter, city, palette, sprites, context.images, configuration, origin,
			point.x, point.y, 0, false, false)
		assert(_draws_image(painter, zone_image) == expected, "Tile painter zone for building 0x%02x" % building)

		var shortcut := CityGpuDrawList.new()

		if context._fast_tile(shortcut, city, palette, sprites, configuration, origin, point.x, point.y):
			assert(_draws_image(shortcut, zone_image) == expected, "GPU shortcut zone for building 0x%02x" % building)

		var occluders := 0

		for command in CityIsometricRenderer.static_occlusion_commands(city, sprites, CityIsometricRenderer.VIEW_LARGE):
			if command.sprite_id == zone_sprite:
				occluders += 1

		assert((occluders == 1) == expected, "Foreground zone for building 0x%02x" % building)

	print("PASS: zones stay visible under trees and power lines")
	quit()


func _draws_image(list: CityGpuDrawList, image: Image) -> bool:
	for draw in list.draws:
		if draw.image == image:
			return true

	return false
