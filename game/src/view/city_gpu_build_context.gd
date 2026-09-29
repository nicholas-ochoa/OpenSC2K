class_name CityGpuBuildContext
extends RefCounted
# owned by one geometry worker. main-thread uploads use an immutable atlas copy

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")
const ATLAS_EDGE := 2048
const MAX_ATLAS_EDGE := 8192
const TILE_CACHE_LIMIT := 16384

# Keep the GDScript implementation as an explicit comparison path.
var use_native := OS.get_environment("OPENSC2K_REGION_BUILDER") != "gdscript"
var native_builder: CityNativeRegionBuilder
var native_cached_tiles := 0

var atlas_edge := ATLAS_EDGE
var images: Dictionary = {}
var image_roles: Dictionary[int, ImageRole] = {}
var _image_key_count := 0
var tiles: Dictionary[int, Tile] = {}
var _tile_order := PackedInt32Array()
var _tile_order_head := 0
# Screen bounds of each tile's static sprites, for region culling. A tile keeps
# its bounds while its packed inputs stay the same, so simulation revisions do
# not discard them. The region renderer reads these arrays inline. A width of
# -1 marks a tile that every region must visit.
var bound_rects := PackedInt32Array()
var bound_inputs := PackedInt64Array()
var bound_extras := PackedInt64Array()
# the revision in which the region renderer last checked each tile's keys
var bound_stamps := PackedInt32Array()
var _maximum_altitude := -1
var revision := -1
var _layout: Array = []
var _sprite_limit := Vector2i.ZERO
var tile_builds := 0
var tile_reuses := 0
var rotation := 0
var atlas: Image
var atlas_slots: Dictionary[int, Rect2i] = {}
var atlas_revision := 0
var atlas_x := 0
var atlas_y := 0
var row_height := 0
var error := ""
var _quad_indices := PackedInt32Array()
# City arrays of the current build. The tile shortcut reads these members in
# place of a property read and an accessor call for each field of each tile.
var _city: CityState
var _edge := 0
var _altitudes := PackedInt32Array()
var _terrains := PackedByteArray()
var _buildings := PackedByteArray()
var _zones := PackedByteArray()
var _flags := PackedByteArray()
var _overlays := PackedByteArray()
var _overlay_high := false
var _grounds := PackedInt32Array()
var _objects := PackedInt32Array()
var _visible_levels := 32
# The painter's sprite images and terrain sprites by integer key, so that the
# shortcut does not format a string key for each sprite. Image keys are
# sprite id * 2 + flip. The images are the same objects as in `images`.
var _sprite_images: Dictionary[int, Image] = {}
var _terrain_sprites := PackedInt32Array()
# archive width and height by sprite offset from the view's sprite base
var _sprite_sizes := PackedInt32Array()
# image keys of the draws that the last shortcut recorded, in draw order
var _fast_keys := PackedInt32Array()


func _init() -> void:
	_tile_order.resize(TILE_CACHE_LIMIT)


func set_revision(value: int, layout: Array = []) -> void:
	if revision != value or _layout != layout:
		# Only the common surface painter has a complete per-tile input key.
		# Other drawings expire lazily. Layout changes still discard all tiles.
		if layout.is_empty() or _layout != layout:
			tiles.clear()
			_tile_order_head = 0
			_sprite_limit = Vector2i.ZERO
			bound_inputs = PackedInt64Array()
			_sprite_images.clear()
			_terrain_sprites = PackedInt32Array()
			_sprite_sizes = PackedInt32Array()

		_maximum_altitude = -1
		revision = value
		_layout = layout


func sprite_limit(sprites: Sc2SpriteArchive, config: CityViewConfiguration) -> Vector2i:
	if _sprite_limit == Vector2i.ZERO:
		# Static tile painters use only the current artwork's 500 sprite IDs.
		# SMALLMED also contains larger artwork, which needlessly widens scans.
		for entry in sprites.entries:
			if entry.sprite_id >= config.sprite_base and entry.sprite_id < config.sprite_base + 500:
				_sprite_limit.x = maxi(_sprite_limit.x, entry.width)
				_sprite_limit.y = maxi(_sprite_limit.y, entry.height)

	return _sprite_limit


# Read the city arrays for later tile builds. Call again after the city changes:
# a write to a shared packed array gives the city a new copy.
func bind_city(city: CityState) -> void:
	var cells := city.map_size * city.map_size
	_city = city
	_edge = city.map_size
	_altitudes = city.altitude_words
	_terrains = city.terrain
	_buildings = city.buildings
	_zones = city.zones
	_flags = city.tile_flags
	_overlays = city.text_overlays
	_overlay_high = OverlayData.count(_overlays) != _overlays.size()
	_grounds = city.ground_overrides if city.ground_overrides.size() == cells else PackedInt32Array()
	_objects = city.object_altitude_overrides if city.object_altitude_overrides.size() == cells else PackedInt32Array()
	_visible_levels = city.visible_altitude_levels


func tile(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		configuration: CityViewConfiguration, x: int, y: int, mode: CityViewMode.Mode, pipes: bool, subways: bool,
		water_mains := true) -> Tile:
	bind_city(city)
	var key := city.index_of(x, y)
	var city_mode := mode == CityViewMode.Mode.CITY

	return build_tile(city, palette, sprites, configuration, x, y, mode, pipes, subways, water_mains,
		bound_input_key(city, key) if city_mode else 0, bound_extra_key(city, key) if city_mode else 0)


# Build or reuse one tile of the bound city. `input` and `extra` are the packed
# culling inputs of the tile, or 0 when the tile must not be reused.
# gdstyle:ignore=quality/max-parameters
func build_tile(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		configuration: CityViewConfiguration, x: int, y: int, mode: CityViewMode.Mode, pipes: bool, subways: bool,
		water_mains: bool, input: int, extra: int) -> Tile:
	var key := x * _edge + y
	var cached: Tile = tiles.get(key)
	var raw_terrain := _terrains[key]
	# Neighboring land heights can turn a shoreline into a waterfall.
	var surface := (CityIsometricRenderer.surface_terrain_id(city, x, y)
		if raw_terrain >= TerrainTileIds.SURFACE_WATER_FIRST and raw_terrain <= TerrainTileIds.CHANNEL_LAST else raw_terrain)

	if cached != null:
		if cached.revision == revision:
			return cached

		# The packed inputs are exact, not a hash. Layout inputs are checked
		# separately; complex network and underground tiles are never reused.
		if cached.reusable and input != 0 and cached.inputs == input and cached.extras == extra and cached.surface == surface:
			cached.revision = revision
			tile_reuses += 1

			return cached

	tile_builds += 1
	var draws: Array[CityGpuDrawList.Draw] = []
	var origin := configuration.side_margin + _edge * configuration.half_width
	var order := (x + y) * _edge + y
	var foreground: Array[CityStaticCommand] = []
	var reusable := false

	if mode == CityViewMode.Mode.UNDERGROUND:
		var recorder := CityGpuDrawList.new()
		CityUndergroundView.draw_tile(recorder, city, palette, sprites, images, configuration, origin, x, y, pipes, subways, water_mains)
		draws = recorder.draws
	else:
		reusable = _record_fast_tile(draws, city, palette, sprites, configuration, origin, x, y)

		if not reusable:
			var recorder := CityGpuDrawList.new()
			CityIsometricRenderer.draw_tile(recorder, city, palette, sprites, images, configuration, origin, x, y, 0, false, false)
			draws = recorder.draws
			_register_image_roles()

		if reusable or city.tile_is_visible(x, y):
			var building := _buildings[key]

			for index in draws.size():
				var draw := draws[index]
				var sprite_id := -1
				var flip := false

				if reusable:
					sprite_id = _fast_keys[index] >> 1
					flip = (_fast_keys[index] & 1) != 0
				else:
					var role: ImageRole = image_roles.get(draw.image.get_instance_id())

					if role == null:
						continue # masked traffic changes color, not foreground geometry

					sprite_id = role.sprite_id
					flip = role.flip

				if not draw.source.has_area():
					continue

				draw.sprite_id = sprite_id
				draw.flip = flip
				draw.size = draw.source.size
				draw.depth_order = order
				draw.region_order = (order << 16) | foreground.size()

				# train masks do not apply to the shortcut's buildings
				if not reusable and building > Tiles.EMPTY and sprite_id == configuration.sprite_base + building:
					CityIsometricRenderer.configure_train_foreground(draw, building, configuration)

				foreground.append(draw)

	var result := Tile.new()
	result.draws = draws
	result.foreground = foreground
	result.revision = revision
	result.reusable = reusable and input != 0
	result.inputs = input
	result.extras = extra
	result.surface = surface
	_pack_quads(result)

	if cached != null:
		# Replacing an expired tile must not add a duplicate FIFO key.
		tiles[key] = result

		return result

	if tiles.size() >= TILE_CACHE_LIMIT:
		# fifo bounds geometry memory even during repeated cross-map pans
		for index in 1024:
			tiles.erase(_tile_order[(_tile_order_head + index) % TILE_CACHE_LIMIT])

		_tile_order_head = (_tile_order_head + 1024) % TILE_CACHE_LIMIT

	_tile_order[(_tile_order_head + tiles.size()) % TILE_CACHE_LIMIT] = key
	tiles[key] = result

	return result


# Record the visible draws of a tile as quads in world pixels and atlas pixels.
# A region that contains the whole tile appends these arrays without a loop.
func _pack_quads(tile: Tile) -> void:
	var drawn: Array[CityGpuDrawList.Draw] = []
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var bounds := Rect2i()

	for draw in tile.draws:
		var size := draw.source.size

		if size.x <= 0 or size.y <= 0:
			continue

		var atlas_slot: Rect2i = atlas_slots.get(draw.image.get_instance_id(), Rect2i())

		if not atlas_slot.has_area():
			atlas_slot = slot(draw.image)

			if not error.is_empty():
				return

		var rectangle := Rect2i(draw.position, size)
		bounds = rectangle if drawn.is_empty() else bounds.merge(rectangle)
		drawn.append(draw)
		var start := Vector2(draw.position)
		var end := start + Vector2(size)
		vertices.append_array([start, Vector2(end.x, start.y), end, Vector2(start.x, end.y)])
		start = Vector2(atlas_slot.position + draw.source.position)
		end = start + Vector2(size)
		uvs.append_array([start, Vector2(end.x, start.y), end, Vector2(start.x, end.y)])

	# most tiles draw no empty sprite, so they can share the draw list
	tile.drawn = tile.draws if drawn.size() == tile.draws.size() else drawn
	tile.vertices = vertices
	tile.uvs = uvs
	tile.bounds = bounds


# Return the triangle indices of `count` quads that use four vertices each
func quad_indices(count: int) -> PackedInt32Array:
	var pattern := _quad_indices
	_quad_indices = PackedInt32Array()

	for quad in range(pattern.size() / 6, count):
		var first := quad * 4
		pattern.append_array([first, first + 1, first + 2, first, first + 2, first + 3])

	_quad_indices = pattern

	return pattern.slice(0, count * 6)


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


# Size the bound arrays for the city. New entries match no packed input.
func prepare_bounds(city: CityState) -> void:
	var cells := city.map_size * city.map_size

	if bound_inputs.size() == cells:
		return

	bound_inputs.resize(cells)
	bound_inputs.fill(0)
	bound_extras.resize(cells)
	bound_extras.fill(0)
	bound_rects.resize(cells * 4)
	bound_stamps.resize(cells)
	bound_stamps.fill(-0x7fffffff)


# The highest land, water, or object altitude in the city. Region spans use it
# in place of the full altitude range.
func maximum_altitude(city: CityState) -> int:
	if _maximum_altitude >= 0:
		return _maximum_altitude

	var words := city.altitude_words
	var highest := 0

	for word in words:
		highest = maxi(highest, maxi(word & Sc2AltitudeLayout.LAND_MASK,
			(word >> Sc2AltitudeLayout.WATER_SHIFT) & Sc2AltitudeLayout.LEVEL_MASK))

	for override in city.object_altitude_overrides:
		highest = maxi(highest, override)

	_maximum_altitude = mini(highest, 31)

	return _maximum_altitude


# Packed culling inputs of one tile. The region renderer computes the same
# values inline. Bit 62 keeps a valid key different from an empty entry.
static func bound_input_key(city: CityState, index: int) -> int:
	return ((int(city.altitude_words[index]) & 0xffff) | (int(city.terrain[index]) << 16) | (int(city.buildings[index]) << 24)
		| (int(city.zones[index]) << 32) | (int(city.tile_flags[index]) << 40) | (1 << 62))


static func bound_extra_key(city: CityState, index: int) -> int:
	var cells := city.map_size * city.map_size
	var overlays := city.text_overlays
	var overlay := (int(overlays[index]) | (int(overlays[cells + index]) << 8 if overlays.size() > cells else 0)
		if overlays.size() >= cells else 0)
	var ground := city.ground_overrides[index] + 1 if city.ground_overrides.size() == cells else 0
	var object := city.object_altitude_overrides[index] + 1 if city.object_altitude_overrides.size() == cells else 0

	return overlay | (ground << 16) | (object << 40) | (1 << 62)


# Return the screen bounds that the static sprites of one tile can touch, or a
# width of -1 when the tile needs the full painter to know its bounds. It reads
# the bound city arrays; the region renderer calls it once per changed tile.
func tile_bounds(city: CityState, sprites: Sc2SpriteArchive, config: CityViewConfiguration,
		x: int, y: int, mode: CityViewMode.Mode) -> Rect2i:
	var everywhere := Rect2i(0, 0, -1, -1)

	if city != _city:
		bind_city(city)

	if mode != CityViewMode.Mode.CITY or x == _edge - 1 or y == _edge - 1:
		return everywhere

	var key := x * _edge + y
	var building := _buildings[key]
	var flags := _flags[key]
	var word := _altitudes[key]
	var water := (flags & Sc2TileFlags.WATER) != 0
	var water_level := (word >> Sc2AltitudeLayout.WATER_SHIFT) & Sc2AltitudeLayout.LEVEL_MASK
	var land_level := word & Sc2AltitudeLayout.LAND_MASK
	var overlay := int(_overlays[key]) | ((int(_overlays[_edge * _edge + key]) << 8) if _overlay_high else 0)

	if ((_visible_levels < 32 and (water_level if water else land_level) >= _visible_levels)
			or (building >= Tiles.HIGHWAY_SLOPE_FIRST and building <= Tiles.REINFORCED_HIGHWAY_BRIDGE)
			or (overlay != 0 and OverlayData.is_thing(overlay))):
		return everywhere

	if building >= Tiles.DEVELOPED_FIRST and (_zones[key] & Sc2ZoneLayout.CORNER_TOP_RIGHT[rotation]) == 0:
		return Rect2i()

	var raw_terrain := _terrains[key]
	var terrain := raw_terrain
	# a neighbor's altitude can turn surface water into a waterfall without a
	# change to this tile's inputs. keep bounds that fit both sprites
	var surface_water := raw_terrain >= TerrainTileIds.SURFACE_WATER_FIRST and raw_terrain <= TerrainTileIds.CHANNEL_LAST

	if surface_water:
		terrain = CityIsometricRenderer.surface_terrain_id(city, x, y)

	var screen_x := config.side_margin + _edge * config.half_width + (x - y) * config.half_width
	var flat_y := config.top_margin + (x + y) * config.half_height + config.tile_height
	var base_y := flat_y - (water_level if terrain >= TerrainTileIds.DEEP_WATER_FIRST else land_level) * config.altitude_step
	var size := _sprite_size(sprites, _ground_sprite(key, terrain, building, water, config.sprite_base) - config.sprite_base,
		config.sprite_base)

	if size.x < 0:
		return everywhere

	if surface_water:
		for variant in [raw_terrain, TerrainTileIds.WATERFALL]:
			var other := _sprite_size(sprites, _ground_sprite(key, variant, building, water, config.sprite_base) - config.sprite_base,
				config.sprite_base)

			if other.x < 0:
				return everywhere

			size = size.max(other)

	var bounds := Rect2i(screen_x, base_y - size.y, size.x, size.y)

	if building > Tiles.EMPTY:
		var entry := _sprite_size(sprites, building, config.sprite_base)

		if entry.x < 0:
			return everywhere

		var object_altitude := water_level if water else land_level

		if not _objects.is_empty() and _objects[key] >= 0:
			object_altitude = _objects[key]

		var object_y := flat_y - object_altitude * config.altitude_step
		object_y += CityIsometricRenderer.building_baseline_offset(building, terrain, entry.x, config.view_size)
		bounds = bounds.merge(Rect2i(screen_x, object_y - entry.y, entry.x, entry.y))

		if building >= Tiles.DEVELOPED_FIRST:
			var marker := _sprite_size(sprites, CityIsometricRenderer.POWER_MARKER_SPRITE_OFFSET, config.sprite_base)

			if marker.x >= 0:
				bounds = bounds.merge(Rect2i(screen_x + int(entry.x / 2) - int(marker.x / 2), object_y - marker.y, marker.x, marker.y))

	return bounds


# The ground sprite id of a bound tile, as IsometricStaticVisuals.ground_sprite_id
# finds it for `terrain`
func _ground_sprite(key: int, terrain: int, building: int, water: bool, sprite_base: int) -> int:
	var ground := _grounds[key] if not _grounds.is_empty() else -1

	if ground >= 0:
		return sprite_base + ground

	var zone := _zones[key] & Sc2ZoneLayout.TYPE_MASK

	if zone > 0 and IsometricStaticVisuals.shows_zone_under(terrain, building):
		return sprite_base + 290 + zone

	return _terrain_sprite(terrain, water, sprite_base)


# The archive width and height of sprite `sprite_base + offset`, or -1 when the
# archive lacks it. The tile painters use offsets below 500.
func _sprite_size(sprites: Sc2SpriteArchive, offset: int, sprite_base: int) -> Vector2i:
	if offset < 0 or offset >= 500:
		var found := sprites.find_sprite(sprite_base + offset)

		return Vector2i(found.width, found.height) if found != null else -Vector2i.ONE

	if _sprite_sizes.is_empty():
		_sprite_sizes.resize(1000)
		_sprite_sizes.fill(-2)

	if _sprite_sizes[offset * 2] == -2:
		var entry := sprites.find_sprite(sprite_base + offset)
		_sprite_sizes[offset * 2] = entry.width if entry != null else -1
		_sprite_sizes[offset * 2 + 1] = entry.height if entry != null else -1

	return Vector2i(_sprite_sizes[offset * 2], _sprite_sizes[offset * 2 + 1])


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
	bind_city(city)

	return _record_fast_tile(recorder.draws, city, palette, sprites, config, origin, x, y)


# the shortcut for the bound city. it reads the bound arrays in place of the
# city accessors, and it records the image key of each draw in `_fast_keys`
func _record_fast_tile(draws: Array[CityGpuDrawList.Draw], city: CityState, palette: Sc2Palette,
		sprites: Sc2SpriteArchive, config: CityViewConfiguration, origin: int, x: int, y: int) -> bool:
	var key := x * _edge + y
	var building := _buildings[key]
	_fast_keys.clear()

	if (building >= Tiles.POWER_LINE_STRAIGHT_1 and building < Tiles.DEVELOPED_FIRST) or x == _edge - 1 or y == _edge - 1:
		return false

	var flags := _flags[key]
	var word := _altitudes[key]
	var water := (flags & Sc2TileFlags.WATER) != 0
	var water_level := (word >> Sc2AltitudeLayout.WATER_SHIFT) & Sc2AltitudeLayout.LEVEL_MASK
	var land_level := word & Sc2AltitudeLayout.LAND_MASK

	if _visible_levels < 32 and (water_level if water else land_level) >= _visible_levels:
		return false

	var overlay := int(_overlays[key]) | ((int(_overlays[_edge * _edge + key]) << 8) if _overlay_high else 0)

	if overlay != 0 and OverlayData.is_thing(overlay):
		return false

	var terrain := _terrains[key]

	if terrain >= TerrainTileIds.SURFACE_WATER_FIRST and terrain <= TerrainTileIds.CHANNEL_LAST:
		terrain = CityIsometricRenderer.surface_terrain_id(city, x, y)

	var altitude := water_level if terrain >= TerrainTileIds.DEEP_WATER_FIRST else land_level
	var screen_x := origin + (x - y) * config.half_width
	var flat_y := config.top_margin + (x + y) * config.half_height + config.tile_height
	var base_y := flat_y - altitude * config.altitude_step

	if building < Tiles.DEVELOPED_FIRST:
		var ground_id := _ground_sprite(key, terrain, building, water, config.sprite_base)
		var ground_image := _sprite(sprites, palette, ground_id, false)
		draws.append(CityGpuDrawList.Draw.new(ground_image, Rect2i(Vector2i.ZERO, ground_image.get_size()),
			Vector2i(screen_x, base_y - ground_image.get_height())))
		_fast_keys.append(ground_id * 2)

	if building == Tiles.EMPTY:
		return true

	if building >= Tiles.DEVELOPED_FIRST and (_zones[key] & Sc2ZoneLayout.CORNER_TOP_RIGHT[rotation]) == 0:
		return true

	var flip := (flags & Sc2TileFlags.FLIPPED) != 0

	if building >= Tiles.DEVELOPED_FIRST and (rotation & 1) != 0:
		flip = not flip

	var sprite_id := config.sprite_base + building
	var image := _sprite(sprites, palette, sprite_id, flip)
	var object_altitude := water_level if water else land_level

	if not _objects.is_empty() and _objects[key] >= 0:
		object_altitude = _objects[key]

	var offset := (int(image.get_width() / 4) - config.half_height if building >= Tiles.DEVELOPED_FIRST
		else (-config.altitude_step if terrain == TerrainTileIds.RAISED else 0))
	var object_y := flat_y - object_altitude * config.altitude_step + offset
	draws.append(CityGpuDrawList.Draw.new(image, Rect2i(Vector2i.ZERO, image.get_size()),
		Vector2i(screen_x, object_y - image.get_height())))
	_fast_keys.append(sprite_id * 2 + int(flip))

	if building >= Tiles.DEVELOPED_FIRST and (flags & Sc2TileFlags.POWER_MASK) == Sc2TileFlags.POWERABLE:
		var marker_id := config.sprite_base + CityIsometricRenderer.POWER_MARKER_SPRITE_OFFSET
		var marker := _sprite(sprites, palette, marker_id, false)
		draws.append(CityGpuDrawList.Draw.new(marker, Rect2i(Vector2i.ZERO, marker.get_size()),
			Vector2i(screen_x + int(image.get_width() / 2) - int(marker.get_width() / 2), object_y - marker.get_height())))
		_fast_keys.append(marker_id * 2)

	return true


# Return the painter's image of a sprite. A miss fills both image caches.
func _sprite(sprites: Sc2SpriteArchive, palette: Sc2Palette, sprite_id: int, flip: bool) -> Image:
	var image_key := sprite_id * 2 + int(flip)
	var image: Image = _sprite_images.get(image_key)

	if image == null:
		image = CityIsometricRenderer.sprite_image(sprites, palette, images, sprite_id, flip)
		_sprite_images[image_key] = image

	return image


func _terrain_sprite(terrain: int, water: bool, sprite_base: int) -> int:
	var index := terrain * 2 + int(water)

	if _terrain_sprites.is_empty():
		_terrain_sprites.resize(512)
		_terrain_sprites.fill(-1)

	if _terrain_sprites[index] < 0:
		_terrain_sprites[index] = IsometricGeometry.terrain_sprite_id(terrain, water, sprite_base)

	return _terrain_sprites[index]


class Tile extends RefCounted:
	var draws: Array[CityGpuDrawList.Draw]
	# the draws with an area, in quad order, and their union
	var drawn: Array[CityGpuDrawList.Draw]
	var bounds: Rect2i
	var vertices: PackedVector2Array
	var uvs: PackedVector2Array
	var foreground: Array[CityStaticCommand]
	var revision := -1
	var reusable := false
	var inputs := 0
	var extras := 0
	var surface := -1


class ImageRole extends RefCounted:
	var sprite_id: int
	var flip: bool

	func _init(id: int, flipped: bool) -> void:
		sprite_id = id
		flip = flipped


func cached_tile_count() -> int:
	return native_cached_tiles if use_native else tiles.size()
