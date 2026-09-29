class_name CityGpuRegionRenderer
extends RefCounted

@warning_ignore_start("integer_division")

const Renderer = preload("res://src/view/city_isometric_renderer.gd")


# gdstyle:ignore=quality/max-parameters
static func render(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		bounds: Rect2i, view: int, mode: CityViewMode.Mode, pipes: bool, subways: bool,
		context: CityGpuBuildContext, revision: int, uploaded_atlas_revision: int, copy_atlas := true,
		water_mains := true) -> CityGpuRegionResult:
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

	var limit := context.sprite_limit(sprites, configuration)
	var previous_builds := context.tile_builds
	var previous_reuses := context.tile_reuses
	var underground := mode == CityViewMode.Mode.UNDERGROUND
	var span := Renderer.region_tile_span(configuration, limit, bounds, city.map_size, underground,
		31 if underground else context.maximum_altitude(city))
	var draws: Array[CityGpuDrawList.Draw] = []
	var foreground: Array[CityStaticCommand] = []
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()

	if underground:
		if not context.images.has("gpu_background"):
			var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			white.fill(Color.WHITE)
			context.images["gpu_background"] = white

		var slot := context.slot(context.images.gpu_background)
		_append_quad(Rect2(bounds), Rect2(slot), vertices, uvs)

	# Cull tiles inline with packed arrays. A call per candidate tile costs
	# more than the check itself, and a region visits several candidates per tile.
	# Detach the bound arrays so that writes do not copy them.
	context.prepare_bounds(city)
	context.bind_city(city)
	var rects := context.bound_rects
	var inputs := context.bound_inputs
	var extras := context.bound_extras
	context.bound_rects = PackedInt32Array()
	context.bound_inputs = PackedInt64Array()
	context.bound_extras = PackedInt64Array()
	var edge := city.map_size
	var cells := edge * edge
	var altitudes := city.altitude_words
	var terrains := city.terrain
	var buildings := city.buildings
	var zones := city.zones
	var flags := city.tile_flags
	var overlays := city.text_overlays
	var overlay_planes := 0 if overlays.size() < cells else (2 if overlays.size() > cells else 1)
	var grounds := city.ground_overrides if city.ground_overrides.size() == cells else PackedInt32Array()
	var objects := city.object_altitude_overrides if city.object_altitude_overrides.size() == cells else PackedInt32Array()
	var left := bounds.position.x
	var top := bounds.position.y
	var right := bounds.end.x
	var bottom := bounds.end.y
	var error := ""

	for diagonal in range(span.first_diagonal, int(span.last_diagonal) + 1):
		var rows := Renderer.diagonal_rows(span, diagonal, edge)

		for y in range(rows.x, rows.y + 1):
			var x := diagonal - y
			var input := 0
			var extra := 0

			if not underground:
				var index := x * edge + y
				input = ((altitudes[index] & 0xffff) | (terrains[index] << 16) | (buildings[index] << 24)
					| (zones[index] << 32) | (flags[index] << 40) | (1 << 62))
				extra = 1 << 62

				if overlay_planes > 0:
					extra |= overlays[index] | ((overlays[cells + index] << 8) if overlay_planes == 2 else 0)

				if not grounds.is_empty():
					extra |= (grounds[index] + 1) << 16

				if not objects.is_empty():
					extra |= (objects[index] + 1) << 40

				var at := index * 4

				if inputs[index] != input or extras[index] != extra:
					var found := context.tile_bounds(city, sprites, configuration, x, y, mode)
					inputs[index] = input
					extras[index] = extra
					rects[at] = found.position.x
					rects[at + 1] = found.position.y
					rects[at + 2] = found.size.x
					rects[at + 3] = found.size.y

				var width := rects[at + 2]

				if width >= 0 and (width == 0 or rects[at + 3] == 0 or rects[at] >= right or rects[at] + width <= left
						or rects[at + 1] >= bottom or rects[at + 1] + rects[at + 3] <= top):
					continue

			var tile := context.build_tile(city, palette, sprites, configuration, x, y, mode, pipes, subways, water_mains,
				input, extra)

			if not context.error.is_empty():
				error = context.error

				break

			var tile_bounds := tile.bounds

			if (tile_bounds.position.x >= left and tile_bounds.position.y >= top and tile_bounds.end.x <= right
					and tile_bounds.end.y <= bottom):
				vertices.append_array(tile.vertices)
				uvs.append_array(tile.uvs)
				draws.append_array(tile.drawn)
				foreground.append_array(tile.foreground)

				continue

			for index in tile.drawn.size():
				var draw := tile.drawn[index]
				var rectangle := Rect2i(draw.position, draw.source.size)
				var clipped := rectangle.intersection(bounds)

				if not clipped.has_area():
					continue

				_append_quad(Rect2(clipped), Rect2(tile.uvs[index * 4] + Vector2(clipped.position - rectangle.position),
					clipped.size), vertices, uvs)
				draws.append(draw)

			for command: CityStaticCommand in tile.foreground:
				if Rect2i(command.position, command.size).intersects(bounds):
					foreground.append(command)

		if not error.is_empty():
			break

	context.bound_rects = rects
	context.bound_inputs = inputs
	context.bound_extras = extras

	if not error.is_empty():
		return CityGpuRegionResult.failed(error)

	# quads use world and atlas pixels until the region is complete
	var quads := vertices.size() / 4

	if quads > 0:
		vertices = Transform2D(0.0, -Vector2(bounds.position)) * vertices
		uvs = Transform2D.IDENTITY.scaled(Vector2.ONE / float(context.atlas_edge)) * uvs

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = context.quad_indices(quads)

	var result := CityGpuRegionResult.new()
	result.tile_builds = context.tile_builds - previous_builds
	result.tile_reuses = context.tile_reuses - previous_reuses
	result.ok = true
	result.error = ""
	result.gpu_arrays = arrays
	result.gpu_draws = draws
	result.background = Color.WHITE if mode == CityViewMode.Mode.UNDERGROUND else Color.TRANSPARENT
	result.bounds = bounds
	result.occlusion_commands = foreground
	result.occlusion_divisor = configuration.divisor
	result.atlas_revision = context.atlas_revision
	result.atlas_edge = context.atlas_edge
	result.atlas_image = (context.atlas.duplicate() if copy_atlas and context.atlas != null
		and context.atlas_revision != uploaded_atlas_revision else null)

	return result


static func _append_quad(rectangle: Rect2, uv: Rect2, vertices: PackedVector2Array, uvs: PackedVector2Array) -> void:
	vertices.append(rectangle.position)
	vertices.append(Vector2(rectangle.end.x, rectangle.position.y))
	vertices.append(rectangle.end)
	vertices.append(Vector2(rectangle.position.x, rectangle.end.y))
	uvs.append(uv.position)
	uvs.append(Vector2(uv.end.x, uv.position.y))
	uvs.append(uv.end)
	uvs.append(Vector2(uv.position.x, uv.end.y))
