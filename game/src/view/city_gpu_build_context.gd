class_name CityGpuBuildContext
extends RefCounted
# owned by one geometry worker. main-thread uploads use an immutable atlas copy

@warning_ignore_start("integer_division")

class Tile extends RefCounted:
	var draws: Array[CityGpuDrawList.Draw] = []
	var foreground: Array[CityStaticCommand] = []
	var foreground_draws: Array[CityGpuDrawList.Draw] = []


class ImageRole extends RefCounted:
	var sprite_id: int
	var flip: bool

	func _init(id: int, flipped: bool) -> void:
		sprite_id = id
		flip = flipped


const ATLAS_EDGE := 2048
const MAX_ATLAS_EDGE := 8192
var atlas_edge := ATLAS_EDGE
const TILE_CACHE_LIMIT := 16384
var images: Dictionary = {}
# derived train crossing masks for the moving-object depth meshes
var occlusion_masks: Dictionary[String, Image] = {}
var image_roles: Dictionary[int, ImageRole] = {}
var _image_key_count := 0
var tiles: Dictionary[int, Tile] = {}
var bounds_cache: Dictionary = {}
var revision := -1
var rotation := 0
var atlas: Image
var atlas_slots: Dictionary[int, Rect2i] = {}
var atlas_revision := 0
var atlas_x := 0
var atlas_y := 0
var row_height := 0
var error := ""


func set_revision(value: int) -> void:
	if revision != value:
		tiles.clear()
		bounds_cache.clear()
		revision = value


func tile(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		configuration: CityViewConfiguration, x: int, y: int, mode: CityViewMode.Mode, pipes: bool, subways: bool, water_mains := true) -> Tile:
	var key := city.index_of(x, y)

	if tiles.has(key):
		return tiles[key]

	var recorder := CityGpuDrawList.new()
	var origin := configuration.side_margin + city.map_size * configuration.half_width
	var order := (x + y) * city.map_size + y
	var foreground: Array[CityStaticCommand] = []
	var foreground_draws: Array[CityGpuDrawList.Draw] = []

	if mode == CityViewMode.Mode.UNDERGROUND:
		CityUndergroundView.draw_tile(recorder, city, palette, sprites, images, configuration, origin, x, y, pipes, subways, water_mains)
	else:
		if not _fast_tile(recorder, city, palette, sprites, configuration, origin, x, y):
			CityIsometricRenderer.draw_tile(recorder, city, palette, sprites, images, configuration, origin, x, y, 0, false, false)

		_register_image_roles()

		if city.tile_is_visible(x, y):
			var building := city.building_id(x, y)

			for draw in recorder.draws:
				var role: ImageRole = image_roles.get(draw.image.get_instance_id())

				if role == null:
					continue # masked traffic changes color, not foreground geometry

				var command := CityStaticCommand.new()
				command.sprite_id = role.sprite_id
				command.flip = role.flip
				command.position = draw.position
				command.size = draw.source.size
				command.depth_order = order
				command.region_order = (order << 16) | foreground.size()

				if building > 0 and int(role.sprite_id) == configuration.sprite_base + building:
					CityIsometricRenderer.configure_train_foreground(command, building, configuration)

				foreground.append(command)
				foreground_draws.append(draw)

	var result := Tile.new()
	result.draws = recorder.draws
	result.foreground = foreground
	result.foreground_draws = foreground_draws

	if tiles.size() >= TILE_CACHE_LIMIT:
		# fifo bounds geometry memory even during repeated cross-map pans
		var keys := tiles.keys()

		for index in 1024:
			tiles.erase(keys[index])

	tiles[key] = result

	return result


func slot(image: Image) -> Rect2i:
	var key := image.get_instance_id()

	if atlas_slots.has(key):
		return atlas_slots[key]

	var size := image.get_size()

	if size.x + 2 > MAX_ATLAS_EDGE or size.y + 2 > MAX_ATLAS_EDGE:
		error = "Sprite exceeds GPU atlas dimensions"

		return Rect2i()

	while size.x + 2 > atlas_edge or size.y + 2 > atlas_edge:
		_grow_atlas()

	if atlas_x + size.x + 2 > atlas_edge:
		atlas_x = 0
		atlas_y += row_height
		row_height = 0

	while atlas_y + size.y + 2 > atlas_edge and atlas_edge < MAX_ATLAS_EDGE:
		_grow_atlas()

	if atlas_y + size.y + 2 > atlas_edge:
		error = "GPU sprite atlas is full"

		return Rect2i()

	if atlas == null:
		atlas = Image.create(atlas_edge, atlas_edge, false, Image.FORMAT_LA8)
		atlas.fill(Color.TRANSPARENT)

	var rectangle := Rect2i(Vector2i(atlas_x + 1, atlas_y + 1), size)
	var indexed := image.duplicate()
	indexed.convert(Image.FORMAT_LA8)
	atlas.blit_rect(indexed, Rect2i(Vector2i.ZERO, size), rectangle.position)
	atlas_x += size.x + 2
	row_height = maxi(row_height, size.y + 2)
	atlas_slots[key] = rectangle
	atlas_revision += 1

	return rectangle


func _grow_atlas() -> void:
	atlas_edge *= 2

	if atlas != null:
		var expanded := Image.create(atlas_edge, atlas_edge, false, Image.FORMAT_LA8)
		expanded.fill(Color.TRANSPARENT)
		expanded.blit_rect(atlas, Rect2i(Vector2i.ZERO, atlas.get_size()), Vector2i.ZERO)
		atlas = expanded

	atlas_revision += 1


func intersects(city: CityState, sprites: Sc2SpriteArchive, config: CityViewConfiguration,
		x: int, y: int, region: Rect2i, mode: CityViewMode.Mode) -> bool:
	var key := x * city.map_size + y

	if bounds_cache.has(key):
		return true if bounds_cache[key] == null else (bounds_cache[key] as Rect2i).intersects(region)

	if bounds_cache.size() >= TILE_CACHE_LIMIT:
		var keys := bounds_cache.keys()

		for index in 1024:
			bounds_cache.erase(keys[index])

	# cache conservative special cases too; adjacent regions revisit them often
	bounds_cache[key] = null

	if mode != CityViewMode.Mode.CITY or x == city.map_size - 1 or y == city.map_size - 1 or not city.tile_is_visible(x, y):
		return true

	var building := int(city.buildings[key])

	if (building >= 0x61 and building <= 0x6b) or OverlayData.is_thing(city.text_overlay_id(x, y)):
		return true

	if building >= 0x70 and (int(city.zones[key]) & [0x80, 0x10, 0x20, 0x40][rotation]) == 0:
		bounds_cache[key] = Rect2i()

		return false

	var terrain := CityIsometricRenderer.surface_terrain_id(city, x, y)
	var origin := config.side_margin + city.map_size * config.half_width
	var screen_x := origin + (x - y) * config.half_width
	var flat_y := config.top_margin + (x + y) * config.half_height
	var altitude := city.water_altitude(x, y) if terrain >= 0x10 else city.land_altitude(x, y)
	var base_y := flat_y - altitude * config.altitude_step + config.tile_height
	var terrain_entry := sprites.find_sprite(CityIsometricRenderer.terrain_sprite_id(terrain, city.is_water(x, y), config.sprite_base))

	if terrain_entry == null:
		return true

	var bounds := Rect2i(screen_x, base_y - terrain_entry.height, terrain_entry.width, terrain_entry.height)

	if building > 0:
		var entry := sprites.find_sprite(config.sprite_base + building)

		if entry == null:
			return true

		var object_y := flat_y - city.object_altitude(x, y) * config.altitude_step + config.tile_height
		object_y += CityIsometricRenderer.building_baseline_offset(building, terrain, entry.width, config.view_size)
		bounds = bounds.merge(Rect2i(screen_x, object_y - entry.height, entry.width, entry.height))

		if building >= 0x70:
			var marker := sprites.find_sprite(config.sprite_base + CityIsometricRenderer.POWER_MARKER_SPRITE_OFFSET)

			if marker != null:
				bounds = bounds.merge(Rect2i(screen_x + int(entry.width / 2) - int(marker.width / 2), object_y - marker.height, marker.width, marker.height))
	elif city.zone_id(x, y) > 0:
		var zone := sprites.find_sprite(config.sprite_base + 290 + city.zone_id(x, y))

		if zone != null:
			bounds = bounds.merge(Rect2i(screen_x, base_y - zone.height, zone.width, zone.height))

	bounds_cache[key] = bounds

	return bounds.intersects(region)


func _register_image_roles() -> void:
	if _image_key_count == images.size():
		return

	var keys := images.keys()

	for index in range(_image_key_count, keys.size()):
		var key: Variant = keys[index]

		if not key is String:
			continue

		var fields: PackedStringArray = key.split(":")

		if fields.size() != 2 or not fields[0].is_valid_int():
			continue

		image_roles[images[key].get_instance_id()] = ImageRole.new(fields[0].to_int(), fields[1] == "1")

	_image_key_count = images.size()


# a shortcut for common surface tiles. city_gpu_fast_tile_test proves that it
# records the same draws as cityisometricrenderer.draw_tile
func _fast_tile(recorder: CityGpuDrawList, city: CityState, palette: Sc2Palette,
		sprites: Sc2SpriteArchive, config: CityViewConfiguration, origin: int, x: int, y: int) -> bool:
	var key := x * city.map_size + y
	var building := int(city.buildings[key])

	if ((building >= 0x0e and building < 0x70) or x == city.map_size - 1 or y == city.map_size - 1 or not city.tile_is_visible(x, y)
			or OverlayData.is_thing(city.text_overlay_id(x, y))):
		return false

	var flags := int(city.tile_flags[key])
	var terrain := int(city.terrain[key])

	if terrain >= 0x30 and terrain <= 0x45:
		terrain = CityIsometricRenderer.surface_terrain_id(city, x, y)

	var word := int(city.altitude_words[key])
	var altitude := ((word >> 5) & 31) if terrain >= 0x10 else (word & 31)
	var screen_x := origin + (x - y) * config.half_width
	var flat_y := config.top_margin + (x + y) * config.half_height + config.tile_height
	var base_y := flat_y - altitude * config.altitude_step

	if building < 0x70:
		_append_sprite(recorder, sprites, palette, CityIsometricRenderer.terrain_sprite_id(terrain, (flags & 4) != 0, config.sprite_base),
				false, Vector2i(screen_x, base_y))

	if building == 0:
		var zone := int(city.zones[key]) & 15

		if zone > 0:
			_append_sprite(recorder, sprites, palette, config.sprite_base + 290 + zone, false, Vector2i(screen_x, base_y))

		return true

	if building >= 0x70 and (int(city.zones[key]) & [0x80, 0x10, 0x20, 0x40][rotation]) == 0:
		return true

	var flip := (flags & 2) != 0

	if building >= 0x70 and (rotation & 1) != 0:
		flip = not flip

	var sprite_id := config.sprite_base + building
	var image := CityIsometricRenderer.sprite_image(sprites, palette, images, sprite_id, flip)
	var object_altitude := ((word >> 5) & 31) if (flags & 4) != 0 else (word & 31)

	if city.object_altitude_overrides.size() == city.map_size * city.map_size and city.object_altitude_overrides[key] >= 0:
		object_altitude = city.object_altitude_overrides[key]

	var offset := int(image.get_width() / 4) - config.half_height if building >= 0x70 else (-config.altitude_step if terrain == 0x0d else 0)
	var object_y := flat_y - object_altitude * config.altitude_step + offset
	recorder.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(screen_x, object_y - image.get_height()))

	if building >= 0x70 and (flags & 0xc0) == 0x80:
		var marker := CityIsometricRenderer.sprite_image(sprites, palette, images, config.sprite_base + CityIsometricRenderer.POWER_MARKER_SPRITE_OFFSET, false)
		recorder.blend_rect(marker, Rect2i(Vector2i.ZERO, marker.get_size()),
				Vector2i(screen_x + int(image.get_width() / 2) - int(marker.get_width() / 2), object_y - marker.get_height()))

	return true


func _append_sprite(recorder: CityGpuDrawList, sprites: Sc2SpriteArchive,
		palette: Sc2Palette, sprite_id: int, flip: bool, base: Vector2i) -> void:
	var image := CityIsometricRenderer.sprite_image(sprites, palette, images, sprite_id, flip)
	recorder.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), base - Vector2i(0, image.get_height()))
