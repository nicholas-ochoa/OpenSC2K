extends SceneTree

const Preview = preload("res://src/view/scurk_context_preview.gd")
const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sprites := Sc2SpriteArchive.combine([
		Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT"),
		Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/SMALLMED.DAT"),
	])
	assert(sprites.is_valid())
	var palette := Sc2Palette.index_encoding()
	var preview := Preview.new()
	root.add_child(preview)
	var before := sprites.find_sprite(1000 + Preview.TARGET_TILE)
	var artwork := PackedInt32Array()
	artwork.resize(32 * 32)
	artwork.fill(-1)
	preview.configure(artwork, 32, 32, 1, palette, sprites)
	assert(preview.snapshot != null and preview.snapshot_city.is_valid())
	assert(sprites.find_sprite(1000 + Preview.TARGET_TILE) == before)
	var city := preview.snapshot_city
	assert(city.building_id(6, 4) == Tiles.ROAD_STRAIGHT_2)
	assert(city.building_id(4, 6) == Tiles.ROAD_STRAIGHT_1)
	assert(city.building_id(4, 4) == Tiles.ROAD_CROSSROADS)
	assert(city.building_id(11, 11) == Tiles.ROAD_CROSSROADS)
	var kinds: Dictionary[int, bool] = {}
	for x in Preview.MAP_SIZE:
		for y in Preview.MAP_SIZE:
			var tile := city.building_id(x, y)
			if tile >= Tiles.DEVELOPED_FIRST and tile != Preview.TARGET_TILE:
				kinds[tile] = true
	assert(kinds.size() >= 12)
	_check_sites(city)
	for view in [CityIsometricRenderer.VIEW_LARGE, CityIsometricRenderer.VIEW_MEDIUM, CityIsometricRenderer.VIEW_SMALL]:
		var config := CityIsometricRenderer.view_configuration(view)
		artwork.resize(config.tile_width * config.tile_width)
		artwork.fill(-1)
		preview.configure(artwork, config.tile_width, config.tile_width, 1, palette, sprites, view)
		assert(preview.view_size == view and preview.configuration.divisor == config.divisor)
		assert(preview.artwork.get_size() == Vector2(config.tile_width, config.tile_width))
		var site := preview.target_site
		var center := Vector2i(preview.origin_x + (site.position.x - site.position.y + 1) * config.half_width,
			preview.configuration.top_margin + (site.position.x + site.position.y + site.size.x) * config.half_height)
		assert(center == Preview.FRAME_CENTER)
		preview.show_neighbors = true
		_check_building_roof(preview, sprites, palette, Tiles.OFFICE_BUILDING_2X2_1, Vector2i(6, 1))
		preview.show_neighbors = false
		preview.show_roads = true
		_check_sprite_pixels(preview, sprites, palette, config.sprite_base + Tiles.ROAD_STRAIGHT_2, Vector2i(6, 4))
		_check_sprite_pixels(preview, sprites, palette, config.sprite_base + Tiles.ROAD_STRAIGHT_1, Vector2i(4, 6))
		_check_sprite_pixels(preview, sprites, palette, config.sprite_base + Tiles.ROAD_CROSSROADS, Vector2i(4, 4))
		preview.show_roads = false
		var terrain_id := CityIsometricRenderer.terrain_sprite_id(TerrainTileIds.FLAT, false, config.sprite_base)
		_check_sprite_pixels(preview, sprites, palette, terrain_id, Vector2i(6, 4))
		_check_sprite_pixels(preview, sprites, palette, terrain_id, preview.target_site.position)
		assert(preview.snapshot_city.building_id(6, 4) == Tiles.EMPTY)
	for area in [2, 3, 4]:
		artwork.resize(area * 32 * 32)
		artwork.fill(-1)
		artwork[0] = 42
		preview.configure(artwork, area * 32, 32, area, palette, sprites)
		assert(preview.target_site.size == Vector2i.ONE * area)
		var count := 0
		var anchors := 0
		for x in Preview.MAP_SIZE:
			for y in Preview.MAP_SIZE:
				if preview.snapshot_city.building_id(x, y) == Preview.TARGET_TILE:
					count += 1
					if (preview.snapshot_city.building_corners(x, y) & 0x80) != 0:
						anchors += 1
		assert(count == area * area and anchors == 1)
	preview.show_neighbors = true
	_check_sites(preview.snapshot_city)
	preview.free()
	print("SCURK context preview checks passed")
	quit()


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
			if tile < Tiles.DEVELOPED_FIRST or tile == Preview.TARGET_TILE or (city.building_corners(x, y) & 0x80) == 0:
				continue
			var site := DemolishEffectsSites._find_building_site(city.buildings, city.zones, Vector2i(x, y),
				tile, DemolishEffectsSites._building_area(tile), 0, city.map_size)
			assert(site != Rect2i())
			for sx in range(site.position.x, site.end.x):
				for sy in range(site.position.y, site.end.y):
					assert(city.building_id(sx, sy) == tile)


func _check_building_roof(preview: ScurkContextPreview, sprites: Sc2SpriteArchive, palette: Sc2Palette, tile: int, anchor: Vector2i) -> void:
	var config := preview.configuration
	var entry := sprites.find_sprite(config.sprite_base + tile)
	var source := entry.create_image(palette).image
	var output := preview.snapshot.get_image()
	var baseline := CityIsometricRenderer.building_baseline_offset(tile, TerrainTileIds.FLAT, entry.width, preview.view_size)
	var offset := Vector2i(preview.origin_x + (anchor.x - anchor.y) * config.half_width,
		config.top_margin + (anchor.x + anchor.y) * config.half_height + baseline + config.tile_height - source.get_height())
	for y in source.get_height():
		var checked := 0
		for x in source.get_width():
			var color := source.get_pixel(x, y)
			if color.a > 0.0:
				assert(output.get_pixelv(offset + Vector2i(x, y)).is_equal_approx(color), "Neighbor roof pixels at view %d" % preview.view_size)
				checked += 1
		if checked > 0:
			return
	assert(false)
