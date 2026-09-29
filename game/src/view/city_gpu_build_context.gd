class_name CityGpuBuildContext
extends RefCounted
## Owned by one geometry worker. The native builder paints and packs regions;
## Godot uploads textures and meshes. Main-thread uploads use immutable atlas images.

const ATLAS_EDGE := 2048
const RECORD_SIZE := 14

var builder := NativeCityRegionBuilder.new()
var atlas_edge := ATLAS_EDGE
# Sprite images by painter key, for sign masks and the native artwork.
var images: Dictionary = {}
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
		revision: int, uploaded_revision: int, copy_atlas: bool, water_mains: bool) -> CityGpuRegionResult:
	if not error.is_empty():
		return CityGpuRegionResult.failed(error)

	var layout := [city.map_size, city.visible_altitude_levels, city.compass_rotation(),
		view, mode, pipes, subways, water_mains, palette, sprites]
	var configuration := CityIsometricRenderer.view_configuration(view)

	if layout != _layout:
		var artwork: Dictionary[int, Image] = {}

		for id: int in sprites.entries_by_id:
			if id >= configuration.sprite_base and id < configuration.sprite_base + 500:
				artwork[id] = CityIsometricRenderer.sprite_image(sprites, palette, images, id, false)

		var request := _snapshot(city)
		request.merge({"view": view, "underground_mode": int(mode == CityViewMode.Mode.UNDERGROUND),
			"pipes": int(pipes), "subways": int(subways), "mains": int(water_mains),
			"redraw_ground": int(sprites.redraw_small_highway_ground), "atlas_edge": atlas_edge})
		var failure := builder.configure(request, artwork, palette.color(0xa1).to_rgba32())
		atlas = null
		atlas_revision = -1
		tile_builds = 0
		tile_reuses = 0

		# A failed layout configures again on the next request.
		if not failure.is_empty():
			_layout = []

			return CityGpuRegionResult.failed(failure)

		_layout = layout
		_revision = revision
	elif revision != _revision:
		var failure := builder.update_city(_snapshot(city))

		if not failure.is_empty():
			return CityGpuRegionResult.failed(failure)

		_revision = revision

	var data := builder.build(bounds, atlas_revision)

	if data.has("error"):
		return CityGpuRegionResult.failed(data.error)

	if data.has("atlas"):
		atlas = data.atlas

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
	result.draw_records = data.records
	result.draw_images.assign(data.images)
	result.draws = data.draws

	return result


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
