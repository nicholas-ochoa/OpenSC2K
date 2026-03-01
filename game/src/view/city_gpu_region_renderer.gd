class_name CityGpuRegionRenderer
extends RefCounted
const Renderer = preload("res://src/view/city_isometric_renderer.gd")


static func render(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive,
		bounds: Rect2i, view: int, mode: String, pipes: bool, subways: bool,
		context: CityGpuBuildContext, revision: int, uploaded_atlas_revision: int, copy_atlas := true) -> Dictionary:
	if city == null or not city.is_valid() or palette == null or not palette.is_valid() or sprites == null or not sprites.is_valid() or view not in [0, 1, 2] or mode not in ["city", "underground"]:
		return {"ok": false, "error": "invalid GPU region assets"}

	context.set_revision(revision)
	context.rotation = city.compass_rotation()
	var configuration := Renderer.view_configuration(view)
	bounds = bounds.intersection(Rect2i(Vector2i.ZERO, Renderer.output_size_for_view(view, city.map_size)))

	if not bounds.has_area():
		return {"ok": false, "error": "empty GPU region"}

	var limit := Renderer._maximum_sprite_size(sprites)
	var origin := int(configuration.side_margin) + city.map_size * int(configuration.half_width)
	var bottom := int(configuration.tile_height) + int(IntegerMath.div_trunc(limit.x, 4)) + 1

	if mode == "underground":
		bottom += 31 * int(configuration.altitude_step)

	var top := 32 * int(configuration.altitude_step) + limit.y
	var first := maxi(0, floori(float(bounds.position.y - int(configuration.top_margin) - bottom) / int(configuration.half_height)))
	var last := mini(2 * (city.map_size - 1), ceili(float(bounds.end.y - int(configuration.top_margin) + top) / int(configuration.half_height)))
	var first_difference := floori(float(bounds.position.x - origin - limit.x - int(configuration.tile_width) - 1) / int(configuration.half_width))
	var last_difference := ceili(float(bounds.end.x - origin + limit.x) / int(configuration.half_width))
	var draws: Array[Dictionary] = []
	var foreground: Array[Dictionary] = []
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	if mode == "underground":
		if not context.images.has("gpu_background"):
			var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			white.fill(Color.WHITE)
			context.images["gpu_background"] = white

		var slot := context.slot(context.images.gpu_background)
		_append_quad(Rect2(Vector2.ZERO, Vector2(bounds.size)), Rect2(slot), vertices, uvs, indices)

	for diagonal in range(first, last + 1):
		var first_y := maxi(maxi(0, diagonal - city.map_size + 1), ceili(float(diagonal - last_difference) / 2.0))
		var last_y := mini(mini(city.map_size - 1, diagonal), floori(float(diagonal - first_difference) / 2.0))

		for y in range(first_y, last_y + 1):
			if not context.intersects(city, sprites, configuration, diagonal - y, y, bounds, mode):
				continue

			var tile := context.tile(city, palette, sprites, configuration, diagonal - y, y, mode, pipes, subways)
			for draw: Dictionary in tile.draws:
				var rectangle := Rect2i(draw.position, draw.source.size)
				var clipped := rectangle.intersection(bounds)

				if not clipped.has_area():
					continue

				var source := Rect2i(Vector2i(draw.source.position) + clipped.position - rectangle.position, clipped.size)
				var slot := context.slot(draw.image)

				if not context.error.is_empty():
					return {"ok": false, "error": context.error}

				var uv := Rect2i(slot.position + source.position, source.size)
				_append_quad(Rect2(clipped.position - bounds.position, clipped.size), Rect2(uv), vertices, uvs, indices)
				draws.append(draw)
			for command: Dictionary in tile.foreground:
				if Rect2i(command.position, command.size).intersects(bounds):
					foreground.append(command)

	var arrays := []

	# quads accumulate against the initial edge. growth can occur mid-region
	if context.atlas_edge != CityGpuBuildContext.ATLAS_EDGE:
		for index in uvs.size():
			uvs[index] *= float(CityGpuBuildContext.ATLAS_EDGE) / context.atlas_edge

	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	return {"ok": true, "error": "", "gpu_arrays": arrays, "gpu_draws": draws, "gpu_draw_grid": Renderer.build_occlusion_grid(draws, 1),
		"background": Color.WHITE if mode == "underground" else Color.TRANSPARENT,
		"bounds": bounds, "occlusion_commands": foreground,
		"occlusion_grid": Renderer.build_occlusion_grid(foreground, int(configuration.divisor)),
		"atlas_revision": context.atlas_revision,
		"atlas_edge": context.atlas_edge,
		"atlas_image": context.atlas.duplicate() if copy_atlas and context.atlas != null and context.atlas_revision != uploaded_atlas_revision else null}


static func _append_quad(rectangle: Rect2, uv: Rect2, vertices: PackedVector2Array,
		uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var first := vertices.size()
	vertices.append_array(PackedVector2Array([rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), rectangle.end, Vector2(rectangle.position.x, rectangle.end.y)]))
	var scaled := Rect2(uv.position / CityGpuBuildContext.ATLAS_EDGE, uv.size / CityGpuBuildContext.ATLAS_EDGE)
	uvs.append_array(PackedVector2Array([scaled.position, Vector2(scaled.end.x, scaled.position.y), scaled.end, Vector2(scaled.position.x, scaled.end.y)]))
	indices.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))
