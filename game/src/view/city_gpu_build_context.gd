class_name CityGpuBuildContext
extends RefCounted
## Owned by one geometry worker or one CPU painting job. The native builder paints
## and packs regions, and rasterizes CPU pixels; Godot uploads textures and meshes.
## Main-thread uploads use immutable atlas images.

@warning_ignore_start("integer_division")

const ATLAS_EDGE := 2048
const RECORD_SIZE := 14

var builder := NativeCityRegionBuilder.new()
var atlas_edge := ATLAS_EDGE
# Sprite images by painter key, for sign masks and the native artwork.
var images: Dictionary = {}
var season_atlas: Image
var _seasons: Dictionary = {}
var emission_atlas: Image
var _emission: Dictionary = {}
var atlas: Image
var atlas_revision := -1
var tile_builds := 0
var tile_reuses := 0
# A set error fails every later region. Tests use it to force the CPU fallback.
var error := ""
var _layout: Array = []
var _revision := -1


static func tile_cache_limit() -> int:
	return NativeCityRegionBuilder.tile_cache_limit()


func cached_tile_count() -> int:
	return builder.cached_tile_count()


# gdstyle:ignore=quality/max-parameters
func render(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		bounds: Rect2i, view: int, mode: CityViewMode.Mode, pipes: bool, subways: bool,
		revision: int, uploaded_revision: int, copy_atlas: bool, water_mains: bool, tunnels := true) -> CityGpuRegionResult:
	var failure := prepare(city, palette, sprites, view, mode, pipes, subways, water_mains, revision, true, false, 0, tunnels)

	if not failure.is_empty():
		return CityGpuRegionResult.failed(failure)

	var configuration := CityIsometricRenderer.view_configuration(view)
	var data := builder.build(bounds, atlas_revision)

	if data.has("error"):
		return CityGpuRegionResult.failed(data.error)

	if data.has("atlas"):
		atlas = data.atlas
		emission_atlas = builder.auxiliary_atlas(_emission)
		season_atlas = builder.auxiliary_atlas(_seasons)

	atlas_edge = data.atlas_edge
	atlas_revision = data.atlas_revision
	var prior_reuses := tile_reuses
	tile_builds = data.total_builds
	tile_reuses = data.total_reuses
	var result := CityGpuRegionResult.new()
	result.ok = true
	result.bounds = data.bounds
	result.background = Color.WHITE if mode == CityViewMode.Mode.UNDERGROUND else Color.TRANSPARENT
	result.command_scale = configuration.divisor
	result.gpu_arrays.resize(Mesh.ARRAY_MAX)
	result.gpu_arrays[Mesh.ARRAY_VERTEX] = data.vertices
	result.gpu_arrays[Mesh.ARRAY_TEX_UV] = data.uvs
	result.gpu_arrays[Mesh.ARRAY_INDEX] = data.indices
	result.tile_builds = data.builds
	result.tile_reuses = tile_reuses - prior_reuses
	result.atlas_revision = atlas_revision
	result.atlas_edge = atlas_edge
	# Native atlas images are new objects, so a result can share one.
	result.atlas_image = atlas if copy_atlas and atlas_revision != uploaded_revision else null
	result.emission_image = emission_atlas if copy_atlas and atlas_revision != uploaded_revision else null
	result.season_image = season_atlas if copy_atlas and atlas_revision != uploaded_revision else null
	result.draw_records = data.records
	result.draw_images.assign(data.images)
	result.draws = data.draws
	result.water = build_water(bounds, configuration.divisor, sprites, mode)

	return result


func build_water(bounds: Rect2i, divisor: int, sprites: Sc2SpriteArchive, mode: CityViewMode.Mode) -> WaterReflectionRegion:
	if not sprites.water_reflections or mode != CityViewMode.Mode.CITY:
		return null
	var data: Dictionary = builder.water_reflections(bounds.grow(WaterReflectionRegion.PADDING), sprites.water_indices,
			sprites.visual_emission, sprites.visual_seasons)
	return WaterReflectionRegion.from_native(data, bounds, divisor)


# Configure the builder for a layout, or pass a new city revision to it. GPU
# regions pack the sprite atlas; raster, record and tile queries do not need it.
# Special overlays draw the animated disaster markers as tile sprites.
# gdstyle:ignore=quality/max-parameters
func prepare(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive, view: int,
		mode := CityViewMode.Mode.CITY, pipes := true, subways := true, water_mains := true, revision := 0,
		pack_atlas := true, special_overlays := false, animation_phase := 0, tunnels := true) -> String:
	if not error.is_empty():
		return error

	if city == null or not city.is_valid() or palette == null or not palette.is_valid() or sprites == null or not sprites.is_valid():
		return "invalid native region assets"

	var layout := [city.map_size, city.visible_altitude_levels, city.compass_rotation(),
		view, mode, pipes, subways, water_mains, palette, sprites, pack_atlas, special_overlays, animation_phase, tunnels, sprites.visual_revision]
	var configuration := CityIsometricRenderer.view_configuration(view)

	if configuration == null:
		return "invalid native region view"

	if layout != _layout:
		_emission = sprites.visual_emission
		_seasons = sprites.visual_seasons
		var artwork: Dictionary[int, Image] = {}

		for id: int in sprites.entries_by_id:
			if id >= configuration.sprite_base and id < configuration.sprite_base + 500:
				artwork[id] = CityIsometricRenderer.sprite_image(sprites, palette, images, id, false)
		if (sprites.visual_nature_enabled or sprites.visual_terrain_enabled) and mode == CityViewMode.Mode.CITY:
			for id: int in sprites.visual_nature:
				if (id % CityNatureArtwork.SPAN) / 500 == view:
					if (id % 500 >= 256 and not sprites.visual_terrain_enabled) or (id % 500 < 256 and not sprites.visual_nature_enabled):
						continue
					artwork[id] = CityIsometricRenderer.sprite_image(sprites, palette, images, id, false)

		var request := _snapshot(city)
		request.merge({"view": view, "underground_mode": int(mode == CityViewMode.Mode.UNDERGROUND),
			"individual_traffic": int(sprites.visual_city_life_traffic and not special_overlays),
			"natural_forests": int(sprites.visual_nature_enabled and mode == CityViewMode.Mode.CITY),
			"natural_terrain": int(sprites.visual_terrain_enabled and mode == CityViewMode.Mode.CITY),
			"pipes": int(pipes), "subways": int(subways), "mains": int(water_mains), "tunnels": int(tunnels),
			"redraw_ground": int(sprites.redraw_small_highway_ground), "atlas_edge": atlas_edge,
			"atlas": int(pack_atlas), "special_overlays": int(special_overlays), "animation_phase": animation_phase,
			"shadow_colors": shadow_colors(palette)})
		var failure := builder.configure(request, artwork, palette.color(0xa1).to_rgba32())
		atlas = null
		atlas_revision = -1
		tile_builds = 0
		tile_reuses = 0

		# A failed layout configures again on the next request.
		if not failure.is_empty():
			_layout = []

			return failure

		_layout = layout
		_revision = revision
	elif revision != _revision:
		var failure := builder.update_city(_snapshot(city))

		if not failure.is_empty():
			return failure

		_revision = revision

	return ""


# Moving object draws of raster jobs, painted with their tiles. Commands come
# from `IsometricDynamicCommands`
func set_moving(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive, commands: Array[CityDynamicCommand]) -> String:
	var cells := PackedInt32Array()
	var positions := PackedVector2Array()
	var ids := PackedInt32Array()
	var flips := PackedByteArray()
	var shadows := PackedByteArray()
	var floating := PackedInt32Array()
	var moving_images := {}

	for command in commands:
		var order := int(command.depth_order)
		var y := order % city.map_size
		var x := int(order / city.map_size) - y
		cells.append(x * city.map_size + y)
		positions.append(Vector2(command.position))
		ids.append(command.sprite_id)
		flips.append(int(command.flip))
		shadows.append(int(command.shadow))
		floating.append(int(command.floating_altitude))

		if not moving_images.has(command.sprite_id):
			moving_images[command.sprite_id] = CityIsometricRenderer.sprite_image(sprites, palette, images, command.sprite_id, false)

	return builder.set_moving(cells, positions, ids, flips, shadows, floating, moving_images)


# one error for each sprite that the configured city needs and the artwork lacks
func missing_sprite_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	for sprite_id in builder.missing_sprites():
		errors.append("required large sprite %d is missing" % sprite_id)

	return errors


# CPU pixels of `bounds` over `background`: `{image, bounds, records, images, draws}`,
# or `{error}`. Call `prepare` first
func raster(bounds: Rect2i, background: Color) -> Dictionary:
	return builder.raster(bounds, background.to_rgba32())


# `{records, images}` of the draws that meet `bounds`, or `{error}`
func draw_records(bounds: Rect2i) -> Dictionary:
	return builder.draw_records(bounds)


# `{records, images}` of the draws of each tile, or `{error}`
func tile_draws(tiles: Array[Vector2i]) -> Dictionary:
	var packed := PackedInt32Array()

	for tile in tiles:
		packed.append_array([tile.x, tile.y])

	return builder.tile_draws(packed)


# the draws of each tile in painter order, moved by `offset`. an error gives no draws
func tile_draw_list(tiles: Array[Vector2i], offset := Vector2i.ZERO) -> CityGpuDrawList:
	var drawn := tile_draws(tiles)

	return CityGpuDrawList.new() if drawn.has("error") else CityGpuDrawList.from_records(drawn.records, drawn.images, offset)


# The foreground commands of draw records, in painter order. Whole-city lists
# leave the region order unset
static func foreground_commands(records: PackedInt64Array, region_orders := false) -> Array[CityStaticCommand]:
	var commands: Array[CityStaticCommand] = []

	for at in range(0, records.size(), RECORD_SIZE):
		if records[at + 7] < 0:
			continue

		var command := CityStaticCommand.new(records[at + 5], records[at + 6] != 0)
		command.position = Vector2i(records[at], records[at + 1])
		command.size = Vector2i(records[at + 2], records[at + 3])
		command.depth_order = records[at + 7]
		command.region_order = records[at + 8] if region_orders else -1
		command.train_ignore = records[at + 9] != 0
		command.train_foreground_reference_sprite_id = records[at + 10]
		command.train_deck_thickness = records[at + 11]
		command.train_deck_reference_sprite_id = records[at + 12]
		command.train_foreground_requires_depth = records[at + 13] != 0
		commands.append(command)

	return commands


# Shadows darken 0x5f to 0x64 and the 0x74 to 0x7e band to 0x7e. When colors
# repeat, the first rule wins, so it is inserted last
static func shadow_colors(palette: Sc2Palette) -> PackedInt32Array:
	var pairs := PackedInt32Array()

	for index in range(0x7e, 0x73, -1):
		pairs.append_array([palette.color(index).to_rgba32(), palette.color(0x7e).to_rgba32()])

	pairs.append_array([palette.color(0x5f).to_rgba32(), palette.color(0x64).to_rgba32()])

	return pairs


static func _snapshot(city: CityState) -> Dictionary:
	var cells := city.map_size * city.map_size
	var traffic := city.document.find_chunk("XTRF")
	var things := city.document.find_chunk("XTHG")

	return {"edge": city.map_size, "visible": city.visible_altitude_levels, "rotation": city.compass_rotation(),
		"altitude": city.altitude_words, "terrain": city.terrain, "buildings": city.buildings,
		"zones": city.zones, "flags": city.tile_flags, "overlays": city.text_overlays, "underground": city.underground,
		"ground": city.ground_overrides if city.ground_overrides.size() == cells else PackedInt32Array(),
		"objects": city.object_altitude_overrides if city.object_altitude_overrides.size() == cells else PackedInt32Array(),
		"traffic": (traffic.decoded_payload if traffic != null
			and traffic.decoded_payload.size() == city.document.decoded_size("XTRF") else PackedByteArray()),
		"things": things.decoded_payload if things != null else PackedByteArray()}
