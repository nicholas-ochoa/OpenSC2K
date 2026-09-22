class_name ScurkContextPreview
extends Control

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const MAP_SIZE := 16
const TARGET_TILE := Tiles.LARGE_APARTMENT_BUILDING_3X3_1
const FRAME_SIZE := Vector2i(512, 384)
const FRAME_CENTER := Vector2i(256, 208)

var snapshot: ImageTexture
var snapshot_city: CityState
var artwork: Texture2D
var target_site := Rect2i()
var footprint := 1
var view_size := CityIsometricRenderer.VIEW_LARGE
var configuration: CityViewConfiguration
var origin_x := 0
var show_roads := true:
	set(value):
		if show_roads != value:
			show_roads = value
			_rebuild()
var show_neighbors := true:
	set(value):
		if show_neighbors != value:
			show_neighbors = value
			_rebuild()

var _palette: Sc2Palette
var _sprites: Sc2SpriteArchive
var _artwork_entry: Sc2SpriteArchive.SpriteEntry


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func configure(pixels: PackedInt32Array, width: int, height: int, tile_size: int,
	palette: Sc2Palette, sprites: Sc2SpriteArchive, view := CityIsometricRenderer.VIEW_LARGE) -> void:
	_palette = palette
	_sprites = sprites
	footprint = clampi(tile_size, 1, 4)
	view_size = clampi(view, CityIsometricRenderer.VIEW_SMALL, CityIsometricRenderer.VIEW_LARGE)
	var config := CityIsometricRenderer.view_configuration(view_size)
	_artwork_entry = Sc2SpriteArchive.entry_from_indices(config.sprite_base + TARGET_TILE, width, height, pixels)
	artwork = indexed_texture(pixels, width, height, palette)
	_rebuild()


static func indexed_texture(pixels: PackedInt32Array, width: int, height: int, palette: Sc2Palette) -> ImageTexture:
	if width <= 0 or height <= 0 or pixels.size() != width * height or palette == null or not palette.is_valid():
		return null
	for index in pixels:
		if index < -1 or index > 255:
			return null
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var index := pixels[y * width + x]
			image.set_pixel(x, y, palette.color(index) if index >= 0 else Color.TRANSPARENT)
	return ImageTexture.create_from_image(image)


func _rebuild() -> void:
	if _artwork_entry == null or _palette == null or not _palette.is_valid() or _sprites == null or not _sprites.is_valid():
		snapshot = null
		queue_redraw()
		return
	var overrides := Sc2SpriteArchive.new()
	overrides.entries.append(_artwork_entry)
	overrides.entries_by_id[_artwork_entry.sprite_id] = _artwork_entry
	var sprites := Sc2SpriteArchive.combine([_sprites, overrides])
	snapshot_city = _create_city()
	var output := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	output.fill(Color("18242c"))
	var config := CityIsometricRenderer.view_configuration(view_size)
	var site_depth := target_site.position.x + target_site.position.y + footprint
	configuration = config.with_top_margin(FRAME_CENTER.y - site_depth * config.half_height)
	origin_x = FRAME_CENTER.x - (target_site.position.x - target_site.position.y + 1) * config.half_width
	var terrain := sprites.find_sprite(CityIsometricRenderer.terrain_sprite_id(TerrainTileIds.FLAT, false, config.sprite_base))
	if terrain != null:
		var ground := terrain.create_image(_palette)
		if ground.ok:
			for x in MAP_SIZE:
				for y in MAP_SIZE:
					var point := Vector2i(origin_x + (x - y) * config.half_width,
						configuration.top_margin + (x + y) * config.half_height + config.tile_height - ground.image.get_height())
					output.blend_rect(ground.image, Rect2i(Vector2i.ZERO, ground.image.get_size()), point)
	var cache: Dictionary = {}
	for diagonal in MAP_SIZE * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y
			if x >= MAP_SIZE or y >= MAP_SIZE:
				continue
			CityIsometricRenderer.draw_tile(output, snapshot_city, _palette, sprites, cache,
				configuration, origin_x, x, y, 0, false, false)
	snapshot = ImageTexture.create_from_image(output)
	queue_redraw()


func _create_city() -> CityState:
	var city := CityState.from_document(EmptyCityTemplate.create(MAP_SIZE))
	for x in MAP_SIZE:
		for y in MAP_SIZE:
			city.set_tile_flag(x, y, Sc2TileFlags.POWERED, true)
	if show_roads:
		for axis in [4, 11]:
			NetworkCommand.apply(city, 6, 0, Vector2i(axis, 0), Vector2i(axis, MAP_SIZE - 1), -1, 0, true)
			NetworkCommand.apply(city, 6, 0, Vector2i(0, axis), Vector2i(MAP_SIZE - 1, axis), -1, 0, true)
	if show_neighbors:
		_add_neighbors(city)
	var inset := (4 - footprint) / 2
	target_site = Rect2i(Vector2i(6 + inset, 6 + inset), Vector2i.ONE * footprint)
	_stamp(city, target_site, TARGET_TILE)
	return city


func _add_neighbors(city: CityState) -> void:
	for site in [
		[Rect2i(0, 0, 2, 2), Tiles.NICE_APARTMENTS_2X2_1],
		[Rect2i(2, 1, 2, 2), Tiles.APARTMENTS_2X2_1],
		[Rect2i(6, 0, 2, 2), Tiles.OFFICE_BUILDING_2X2_1],
		[Rect2i(9, 0, 2, 2), Tiles.SHOPPING_CENTER_2X2],
		[Rect2i(12, 1, 2, 2), Tiles.WAREHOUSE_2X2],
		[Rect2i(1, 6, 2, 2), Tiles.CHEAP_APARTMENTS_2X2],
		[Rect2i(1, 9, 2, 2), Tiles.GROCERY_STORE_2X2],
		[Rect2i(12, 8, 2, 2), Tiles.OFFICE_RETAIL_2X2],
		[Rect2i(1, 12, 2, 2), Tiles.SHOPPING_CENTER_2X2],
	]:
		_stamp(city, site[0], site[1])
	for x in [0, 1, 2, 3, 5, 6, 7, 8, 9, 10, 12, 13, 14]:
		_stamp(city, Rect2i(x, 3, 1, 1), Tiles.MIDDLE_CLASS_HOMES_1X1_1 + x % 4)
		_stamp(city, Rect2i(x, 12, 1, 1), Tiles.LUXURY_HOMES_1X1_1 + x % 4)
	for point in [Vector2i(3, 5), Vector2i(3, 7), Vector2i(3, 9), Vector2i(12, 5), Vector2i(12, 6), Vector2i(5, 6), Vector2i(5, 8)]:
		_stamp(city, Rect2i(point, Vector2i.ONE), Tiles.GAS_STATION_1X1_1 + (point.x + point.y) % 8)
	for point in [Vector2i(6, 5), Vector2i(8, 5), Vector2i(10, 6), Vector2i(10, 8), Vector2i(6, 10), Vector2i(8, 10), Vector2i(14, 10)]:
		_stamp(city, Rect2i(point, Vector2i.ONE), Tiles.SMALL_PARK)
	for x in MAP_SIZE:
		for y in MAP_SIZE:
			if city.building_id(x, y) == Tiles.EMPTY and (x < 4 or x > 11 or y < 4 or y > 11) and (x * 3 + y) % 5 == 0:
				_stamp(city, Rect2i(x, y, 1, 1), Tiles.TREES_1 + (x + y) % 7)


func _stamp(city: CityState, site: Rect2i, tile: int) -> void:
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			if city.building_id(x, y) != Tiles.EMPTY:
				return
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			city.set_building_id(x, y, tile)
			city.set_zone_id(x, y, 0)
	BuildingSites.set_corners(city.zones, site, site.size.x, 0, city.map_size)
	city.document.find_chunk("XZON").set_decoded_payload(city.zones)


func _draw() -> void:
	if snapshot == null:
		return
	var scale := minf(size.x / FRAME_SIZE.x, size.y / FRAME_SIZE.y)
	if scale >= 1.0:
		scale = floorf(scale)
	var extent := Vector2(FRAME_SIZE) * scale
	draw_texture_rect(snapshot, Rect2(((size - extent) * 0.5).floor(), extent), false)
