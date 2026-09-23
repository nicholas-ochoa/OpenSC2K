class_name ScurkContextPreview
extends Control

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const ContextScene = preload("res://src/tools/scurk/scurk_context_scene.gd")
const MAP_SIZE := ContextScene.MAP_SIZE
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
var scene := ContextScene.new()
var tile_id := Tiles.LARGE_APARTMENT_BUILDING_3X3_1
var show_networks := true:
	set(value):
		if show_networks != value:
			show_networks = value
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
	palette: Sc2Palette, sprites: Sc2SpriteArchive, view := CityIsometricRenderer.VIEW_LARGE, selected_tile := Tiles.LARGE_APARTMENT_BUILDING_3X3_1) -> void:
	tile_id = selected_tile
	_palette = palette
	_sprites = sprites
	footprint = clampi(tile_size, 1, 4)
	view_size = clampi(view, CityIsometricRenderer.VIEW_SMALL, CityIsometricRenderer.VIEW_LARGE)
	var config := CityIsometricRenderer.view_configuration(view_size)
	_artwork_entry = Sc2SpriteArchive.entry_from_indices(config.sprite_base + tile_id, width, height, pixels)
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
	scene.build(tile_id, footprint, show_networks, show_neighbors)
	snapshot_city = scene.city
	target_site = scene.target_sites[0]
	var output := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	output.fill(Color.WHITE if scene.kind == ContextScene.Kind.UNDERGROUND else Color("18242c"))
	var config := CityIsometricRenderer.view_configuration(view_size)
	var site_depth := target_site.position.x + target_site.position.y + footprint
	configuration = config.with_top_margin(FRAME_CENTER.y - site_depth * config.half_height)
	origin_x = FRAME_CENTER.x - (target_site.position.x - target_site.position.y + 1) * config.half_width
	var terrain := sprites.find_sprite(CityIsometricRenderer.terrain_sprite_id(TerrainTileIds.FLAT, false, config.sprite_base))
	var underground_ground := sprites.find_sprite(config.sprite_base + CityUndergroundView.TERRAIN_WIREFRAME_FIRST)
	if terrain != null and scene.kind != ContextScene.Kind.UNDERGROUND:
		var ground := terrain.create_image(_palette)
		if ground.ok:
			for x in MAP_SIZE:
				for y in MAP_SIZE:
					var point := Vector2i(origin_x + (x - y) * config.half_width,
						configuration.top_margin + (x + y) * config.half_height + config.tile_height - ground.image.get_height())
					output.blend_rect(ground.image, Rect2i(Vector2i.ZERO, ground.image.get_size()), point)
	var artwork_image := artwork.get_image()
	var cache: Dictionary = {}
	for diagonal in MAP_SIZE * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y
			if x >= MAP_SIZE or y >= MAP_SIZE:
				continue
			var support_target := tile_id > Tiles.MAX_ID and scene.target_sites.has(Rect2i(x, y, 1, 1))
			if scene.kind == ContextScene.Kind.UNDERGROUND:
				if not support_target:
					CityUndergroundView.draw_tile(output, snapshot_city, _palette, sprites, cache,
						configuration, origin_x, x, y, true, true)
			elif not support_target or scene.kind != ContextScene.Kind.TERRAIN:
				CityIsometricRenderer.draw_tile(output, snapshot_city, _palette, sprites, cache,
					configuration, origin_x, x, y, 0, false, false)
			if support_target:
				var anchor_height := underground_ground.height if scene.kind == ContextScene.Kind.UNDERGROUND and underground_ground != null else artwork_image.get_height()
				var point := Vector2i(origin_x + (x - y) * config.half_width,
					configuration.top_margin + (x + y) * config.half_height + config.tile_height - anchor_height)
				output.blend_rect(artwork_image, Rect2i(Vector2i.ZERO, artwork_image.get_size()), point)
	snapshot = ImageTexture.create_from_image(output)
	queue_redraw()


func _draw() -> void:
	if snapshot == null:
		return
	var scale := minf(size.x / FRAME_SIZE.x, size.y / FRAME_SIZE.y)
	if scale >= 1.0:
		scale = floorf(scale)
	var extent := Vector2(FRAME_SIZE) * scale
	draw_texture_rect(snapshot, Rect2(((size - extent) * 0.5).floor(), extent), false)
