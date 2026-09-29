class_name CityNativeRegionBuilder
extends RefCounted
## One native context per geometry worker. Godot keeps mesh publication and display.

const RECORD_SIZE := 16

var builder := NativeCityRegionBuilder.new()
var _layout: Array = []
var _revision := -1
var _draws: Dictionary[int, CityGpuDrawList.Draw] = {}


# gdstyle:ignore=quality/max-parameters
func render(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		bounds: Rect2i, view: int, mode: CityViewMode.Mode, pipes: bool, subways: bool,
		context: CityGpuBuildContext, revision: int, uploaded_revision: int, copy_atlas: bool,
		water_mains: bool) -> CityGpuRegionResult:
	var layout := [city.map_size, city.visible_altitude_levels, city.compass_rotation(),
		view, mode, pipes, subways, water_mains, palette, sprites]
	var error := ""
	if layout != _layout:
		var images: Dictionary[int, Image] = {}
		var config := CityIsometricRenderer.view_configuration(view)
		for id: int in sprites.entries_by_id:
			if id >= config.sprite_base and id < config.sprite_base + 500:
				images[id] = CityIsometricRenderer.sprite_image(sprites, palette, context.images, id, false)
		var request := _snapshot(city)
		request.merge({"view": view, "underground_mode": int(mode == CityViewMode.Mode.UNDERGROUND),
			"pipes": int(pipes), "subways": int(subways), "mains": int(water_mains),
			"redraw_ground": int(sprites.redraw_small_highway_ground), "atlas_edge": context.atlas_edge})
		error = builder.configure(request, images, palette.color(0xa1).to_rgba32())
		_draws.clear()
		context.atlas = null
		context.atlas_revision = -1
		context.tile_builds = 0
		context.tile_reuses = 0
		_layout = layout
	elif revision != _revision:
		error = builder.update_city(_snapshot(city))

	if not error.is_empty():
		return CityGpuRegionResult.failed(error)
	_revision = revision
	var data := builder.build(bounds, context.atlas_revision)
	if data.has("error"):
		return CityGpuRegionResult.failed(data.error)
	if data.has("atlas"):
		context.atlas = data.atlas
	context.atlas_edge = data.atlas_edge
	context.atlas_revision = data.atlas_revision
	var prior_reuses := context.tile_reuses
	context.native_cached_tiles = data.cached_tiles
	context.tile_builds = data.total_builds
	context.tile_reuses = data.total_reuses
	var result := CityGpuRegionResult.new()
	result.ok = true
	result.bounds = data.bounds
	result.background = Color.WHITE if mode == CityViewMode.Mode.UNDERGROUND else Color.TRANSPARENT
	result.occlusion_divisor = CityIsometricRenderer.view_configuration(view).divisor
	result.gpu_arrays.resize(Mesh.ARRAY_MAX)
	result.gpu_arrays[Mesh.ARRAY_VERTEX] = data.vertices
	result.gpu_arrays[Mesh.ARRAY_TEX_UV] = data.uvs
	result.gpu_arrays[Mesh.ARRAY_INDEX] = data.indices
	result.tile_builds = data.builds
	result.tile_reuses = context.tile_reuses - prior_reuses
	result.atlas_revision = context.atlas_revision
	result.atlas_edge = context.atlas_edge
	result.atlas_image = context.atlas if copy_atlas and context.atlas_revision != uploaded_revision else null
	var records: PackedInt64Array = data.records
	var images: Dictionary = data.images
	for at in range(0, records.size(), RECORD_SIZE):
		var id := records[at]
		var draw: CityGpuDrawList.Draw = _draws.get(id)
		if draw == null:
			var size := Vector2i(records[at + 4], records[at + 5])
			draw = CityGpuDrawList.Draw.new(images[records[at + 1]], Rect2i(Vector2i.ZERO, size),
				Vector2i(records[at + 2], records[at + 3]))
			draw.sprite_id = records[at + 6]
			draw.flip = records[at + 7] != 0
			draw.depth_order = records[at + 8]
			draw.region_order = records[at + 9]
			draw.train_ignore = records[at + 10] != 0
			draw.train_foreground_reference_sprite_id = records[at + 11]
			draw.train_deck_thickness = records[at + 12]
			draw.train_deck_reference_sprite_id = records[at + 13]
			draw.train_foreground_requires_depth = records[at + 14] != 0
			if draw.depth_order >= 0:
				draw.size = size
			_draws[id] = draw
		result.gpu_draws.append(draw)
		if draw.depth_order >= 0:
			result.occlusion_commands.append(draw)
	# A large region can evict an early tile before its draws are returned.
	# The region owns those draws; do not retain them in the worker cache.
	for id in data.evicted:
		_draws.erase(id)
	return result


static func _snapshot(city: CityState) -> Dictionary:
	var traffic := city.document.find_chunk("XTRF")
	var things := city.document.find_chunk("XTHG")
	return {"edge": city.map_size, "visible": city.visible_altitude_levels, "rotation": city.compass_rotation(),
		"altitude": city.altitude_words, "terrain": city.terrain, "buildings": city.buildings,
		"zones": city.zones, "flags": city.tile_flags, "overlays": city.text_overlays, "underground": city.underground,
		"ground": city.ground_overrides if city.ground_overrides.size() == city.map_size * city.map_size else PackedInt32Array(),
		"objects": city.object_altitude_overrides if city.object_altitude_overrides.size() == city.map_size * city.map_size
			else PackedInt32Array(),
		"traffic": (traffic.decoded_payload if traffic != null
			and traffic.decoded_payload.size() == city.document.decoded_size("XTRF") else PackedByteArray()),
		"things": things.decoded_payload if things != null else PackedByteArray()}
