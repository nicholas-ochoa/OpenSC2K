class_name CityGpuRegionRenderer
extends RefCounted
const Renderer = preload("res://src/view/city_isometric_renderer.gd")


static func render(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		bounds: Rect2i, view: int, mode: CityViewMode.Mode, pipes: bool, subways: bool,
		context: CityGpuBuildContext, revision: int, uploaded_atlas_revision: int, copy_atlas := true, water_mains := true) -> CityGpuRegionResult:
	if (city == null or not city.is_valid() or palette == null or not palette.is_valid() or sprites == null or not sprites.is_valid()
			or view not in [0, 1, 2] or not CityViewMode.is_map(mode)):
		return CityGpuRegionResult.failed("invalid GPU region assets")

	context.set_revision(revision, [city.map_size, city.visible_altitude_levels, city.compass_rotation(),
		view, mode, pipes, subways, water_mains, palette, sprites])
	context.rotation = city.compass_rotation()
	var configuration := Renderer.view_configuration(view)
	bounds = bounds.intersection(Rect2i(Vector2i.ZERO, Renderer.output_size_for_view(view, city.map_size)))

	if not bounds.has_area():
		return CityGpuRegionResult.failed("empty GPU region")

	var limit := Renderer.maximum_sprite_size(sprites)
	var previous_builds := context.tile_builds
	var previous_reuses := context.tile_reuses
	var span := Renderer.region_tile_span(configuration, limit, bounds, city.map_size, mode == CityViewMode.Mode.UNDERGROUND)
	var draws: Array[CityGpuDrawList.Draw] = []
	var foreground: Array[CityStaticCommand] = []
	var foreground_draws: Array[CityGpuDrawList.Draw] = []
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	if mode == CityViewMode.Mode.UNDERGROUND:
		if not context.images.has("gpu_background"):
			var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			white.fill(Color.WHITE)
			context.images["gpu_background"] = white

		var slot := context.slot(context.images.gpu_background)
		_append_quad(Rect2(Vector2.ZERO, Vector2(bounds.size)), Rect2(slot), vertices, uvs, indices)

	for diagonal in range(span.first_diagonal, int(span.last_diagonal) + 1):
		var rows := Renderer.diagonal_rows(span, diagonal, city.map_size)

		for y in range(rows.x, rows.y + 1):
			if not context.intersects(city, sprites, configuration, diagonal - y, y, bounds, mode):
				continue

			var tile := context.tile(city, palette, sprites, configuration, diagonal - y, y, mode, pipes, subways, water_mains)
			for draw: CityGpuDrawList.Draw in tile.draws:
				var rectangle := Rect2i(draw.position, draw.source.size)
				var clipped := rectangle.intersection(bounds)

				if not clipped.has_area():
					continue

				var source := Rect2i(draw.source.position + clipped.position - rectangle.position, clipped.size)
				var slot := context.slot(draw.image)

				if not context.error.is_empty():
					return CityGpuRegionResult.failed(context.error)

				var uv := Rect2i(slot.position + source.position, source.size)
				_append_quad(Rect2(clipped.position - bounds.position, clipped.size), Rect2(uv), vertices, uvs, indices)
				draws.append(draw)
			for index in tile.foreground.size():
				var command: CityStaticCommand = tile.foreground[index]

				if Rect2i(command.position, command.size).intersects(bounds):
					foreground.append(command)
					foreground_draws.append(tile.foreground_draws[index])

	var depth := CityGpuOcclusionDepth.Result.new()

	if mode == CityViewMode.Mode.CITY:
		depth = CityGpuOcclusionDepth.build(foreground, foreground_draws, bounds, context, sprites, palette)

		if not context.error.is_empty():
			return CityGpuRegionResult.failed(context.error)

	var arrays := []

	# quads accumulate against the initial edge. growth can occur mid-region
	if context.atlas_edge != CityGpuBuildContext.ATLAS_EDGE:
		for index in uvs.size():
			uvs[index] *= float(CityGpuBuildContext.ATLAS_EDGE) / context.atlas_edge

		for depth_arrays: Array in [depth.depth, depth.train]:
			if depth_arrays.is_empty():
				continue

			var depth_uvs: PackedVector2Array = depth_arrays[Mesh.ARRAY_TEX_UV]

			for index in depth_uvs.size():
				depth_uvs[index] *= float(CityGpuBuildContext.ATLAS_EDGE) / context.atlas_edge

			depth_arrays[Mesh.ARRAY_TEX_UV] = depth_uvs

	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var result := CityGpuRegionResult.new()
	result.tile_builds = context.tile_builds - previous_builds
	result.tile_reuses = context.tile_reuses - previous_reuses
	result.ok = true
	result.error = ""
	result.gpu_arrays = arrays
	result.gpu_draws = draws
	result.gpu_draw_grid = CityGpuDrawList.build_grid(draws)
	result.background = Color.WHITE if mode == CityViewMode.Mode.UNDERGROUND else Color.TRANSPARENT
	result.bounds = bounds
	result.occlusion_commands = foreground
	result.depth_arrays = depth.depth
	result.train_depth_arrays = depth.train
	result.occlusion_grid = Renderer.build_occlusion_grid(foreground, configuration.divisor)
	result.atlas_revision = context.atlas_revision
	result.atlas_edge = context.atlas_edge
	result.atlas_image = context.atlas.duplicate() if copy_atlas and context.atlas != null and context.atlas_revision != uploaded_atlas_revision else null

	return result


static func _append_quad(rectangle: Rect2, uv: Rect2, vertices: PackedVector2Array,
		uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var first := vertices.size()
	vertices.append(rectangle.position)
	vertices.append(Vector2(rectangle.end.x, rectangle.position.y))
	vertices.append(rectangle.end)
	vertices.append(Vector2(rectangle.position.x, rectangle.end.y))
	var scaled := Rect2(uv.position / CityGpuBuildContext.ATLAS_EDGE, uv.size / CityGpuBuildContext.ATLAS_EDGE)
	uvs.append(scaled.position)
	uvs.append(Vector2(scaled.end.x, scaled.position.y))
	uvs.append(scaled.end)
	uvs.append(Vector2(scaled.position.x, scaled.end.y))
	indices.append(first)
	indices.append(first + 1)
	indices.append(first + 2)
	indices.append(first)
	indices.append(first + 2)
	indices.append(first + 3)
