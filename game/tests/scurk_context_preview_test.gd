extends SceneTree

const Preview = preload("res://src/view/scurk_context_preview.gd")
const ContextScene = preload("res://src/tools/scurk/scurk_context_scene.gd")
const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_scenes()
	var sprites := Sc2SpriteArchive.combine([
		Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT"),
		Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/SMALLMED.DAT"),
	])
	assert(sprites.is_valid())
	var palette := Sc2Palette.index_encoding()
	var preview := Preview.new()
	root.add_child(preview)
	var tile := Tiles.APARTMENTS_2X2_1
	var before := sprites.find_sprite(1000 + tile)
	for view in [CityIsometricRenderer.VIEW_LARGE, CityIsometricRenderer.VIEW_MEDIUM, CityIsometricRenderer.VIEW_SMALL]:
		var config := CityIsometricRenderer.view_configuration(view)
		var entry := sprites.find_sprite(config.sprite_base + tile)
		var artwork := entry.decode_indices().pixels
		preview.configure(artwork, entry.width, entry.height, 2, palette, sprites, view, tile)
		assert(preview.snapshot != null and preview.snapshot_city.is_valid())
		assert(preview.view_size == view and preview.configuration.divisor == config.divisor)
		assert(preview.artwork.get_size() == Vector2(entry.width, entry.height))
		var site := preview.target_site
		var center := Vector2i(preview.origin_x + (site.position.x - site.position.y + 1) * config.half_width,
			preview.configuration.top_margin + (site.position.x + site.position.y + site.size.x) * config.half_height)
		assert(center == Preview.FRAME_CENTER)
		_check_sites(preview.snapshot_city)
	assert(sprites.find_sprite(1000 + tile) == before)
	for sample in [[Tiles.ROAD_STRAIGHT_2, Tiles.ROAD_STRAIGHT_2], [CityUndergroundView.SUBWAY_AND_PIPE_FIRST + UndergroundTileIds.PIPE_TB, CityUndergroundView.SUBWAY_AND_PIPE_FIRST + UndergroundTileIds.PIPE_LR]]:
		tile = sample[0]
		var entry := sprites.find_sprite(1000 + tile)
		preview.configure(entry.decode_indices().pixels, entry.width, entry.height, 1, palette, sprites, CityIsometricRenderer.VIEW_LARGE, tile)
		var point := Vector2i(8, 7)
		var sprite_id := 1000 + preview.snapshot_city.building_id(point.x, point.y)
		if preview.scene.kind == ContextScene.Kind.UNDERGROUND:
			sprite_id = CityUndergroundView.tile_sprite_ids(preview.snapshot_city, point.x, point.y)[0]
		_check_sprite_pixels(preview, sprites, palette, sprite_id, point)
	preview.free()
	print("SCURK context preview checks passed")
	quit()


func _test_scenes() -> void:
	var scene := ContextScene.new()
	for tile in [Tiles.MIDDLE_CLASS_HOMES_1X1_1, Tiles.APARTMENTS_2X2_1, Tiles.LARGE_APARTMENT_BUILDING_3X3_1, Tiles.OFFICE_BUILDING_2X2_1, Tiles.FACTORY_3X3, Tiles.COAL_POWER, Tiles.HOSPITAL]:
		var area := DemolishStructures.structure_area(tile)
		scene.build(tile, area, true, true)
		assert(scene.kind == ContextScene.Kind.BUILDING and scene.target_sites.size() == 2)
		assert(scene.target_sites[0].size == Vector2i.ONE * area)
		var city := scene.city
		var neighbors := 0
		for x in ContextScene.MAP_SIZE:
			for y in ContextScene.MAP_SIZE:
				var other := city.building_id(x, y)
				if other >= Tiles.DEVELOPED_FIRST and other != tile:
					neighbors += 1
					assert(ContextScene.family_for_tile(other) == ContextScene.family_for_tile(tile))
					assert(DemolishStructures.structure_area(other) == area)
		assert(neighbors > 0)
		_check_sites(city)
		scene.build(tile, area, false, false)
		assert(scene.target_sites.size() == 1 and scene.city.buildings.count(tile) == area * area)
	for pair in [[Tiles.ROAD_STRAIGHT_1, ContextScene.Kind.ROAD], [Tiles.RAIL_STRAIGHT_1, ContextScene.Kind.RAIL], [Tiles.POWER_LINE_STRAIGHT_1, ContextScene.Kind.POWER], [Tiles.HIGHWAY_STRAIGHT_1, ContextScene.Kind.HIGHWAY]]:
		scene.build(pair[0], 1, true, true)
		assert(scene.kind == pair[1])
		assert(ContextScene.kind_for_tile(scene.city.building_id(8, 7)) == pair[1])
		assert(scene.city.building_id(7, 7) == pair[0] and scene.city.building_id(10, 7) == pair[0])
	for tile in [CityUndergroundView.TERRAIN_WIREFRAME_FIRST, CityUndergroundView.SUBWAY_AND_PIPE_FIRST + UndergroundTileIds.SUBWAY_LR, CityUndergroundView.SUBWAY_AND_PIPE_FIRST + UndergroundTileIds.PIPE_TB, CityUndergroundView.WATERED_TERRAIN]:
		scene.build(tile, 1, true, true)
		assert(scene.kind == ContextScene.Kind.UNDERGROUND)
		assert(scene.city.buildings.count(Tiles.EMPTY) == ContextScene.MAP_SIZE * ContextScene.MAP_SIZE)
		assert(scene.city.underground_id(8, 7) != UndergroundTileIds.EMPTY)
	assert(ContextScene.kind_for_tile(0x167) == ContextScene.Kind.SUPPORT)
	scene.build(0x100, 1, false, true)
	assert(scene.kind == ContextScene.Kind.TERRAIN and scene.target_sites.size() == 2)


func _check_sprite_pixels(preview: ScurkContextPreview, sprites: Sc2SpriteArchive, palette: Sc2Palette, id: int, tile: Vector2i) -> void:
	var source := sprites.find_sprite(id).create_image(palette)
	assert(source.ok)
	var output := preview.snapshot.get_image()
	var config := preview.configuration
	var checked := 0
	var offset := Vector2i(preview.origin_x + (tile.x - tile.y) * config.half_width,
		config.top_margin + (tile.x + tile.y) * config.half_height + config.tile_height - source.image.get_height())
	for x in source.image.get_width():
		for y in source.image.get_height():
			var color := source.image.get_pixel(x, y)
			var ground_y := y - (source.image.get_height() - config.tile_height)
			if color.a > 0.0 and absf(x - config.half_width + 0.5) / config.half_width + absf(ground_y - config.half_height) / config.half_height < 0.8:
				checked += 1
				assert(output.get_pixelv(offset + Vector2i(x, y)).is_equal_approx(color), "Preview sprite pixel %d at %s" % [id, tile])
	assert(checked > 0)


func _check_sites(city: CityState) -> void:
	for x in Preview.MAP_SIZE:
		for y in Preview.MAP_SIZE:
			var tile := city.building_id(x, y)
			if tile < Tiles.DEVELOPED_FIRST or (city.building_corners(x, y) & 0x80) == 0:
				continue
			var site := DemolishEffectsSites._find_building_site(city.buildings, city.zones, Vector2i(x, y),
				tile, DemolishEffectsSites._building_area(tile), 0, city.map_size)
			assert(site != Rect2i())
			for sx in range(site.position.x, site.end.x):
				for sy in range(site.position.y, site.end.y):
					assert(city.building_id(sx, sy) == tile)
