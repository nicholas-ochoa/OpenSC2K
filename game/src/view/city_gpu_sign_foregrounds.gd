class_name CityGpuSignForegrounds
extends RefCounted


# worker-owned sign masks, clipped to the same region as their static pixels
static func build(region: Dictionary, requests: Array[Dictionary], palette: Sc2Palette,
		sprites: Sc2SpriteArchive, context: CityGpuBuildContext, divisor: int) -> Dictionary:
	var result := {}

	for request in requests:
		var source: Rect2i = request.bounds
		var first := Vector2i((Vector2(source.position) / divisor).floor())
		var end := Vector2i((Vector2(source.end) / divisor).ceil())
		var bounds := Rect2i(first, end - first).intersection(region.bounds)

		if not bounds.has_area():
			continue

		var masks: Array[Dictionary] = []
		for command: Dictionary in region.occlusion_commands:
			if int(command.depth_order) <= int(request.draw_order):
				continue

			if not bounds.intersects(Rect2i(command.position, command.size)):
				continue

			var image := CityIsometricRenderer.sprite_image(sprites, palette, context.images, int(command.sprite_id), bool(command.flip))

			if image != null:
				masks.append({"image": image, "position": Vector2i(command.position)})
		var sampled := CityGpuDrawList.paint(region.gpu_draws, bounds, region.background, region.gpu_draw_grid)
		var image := CitySignForeground.static_pixels(sampled, masks, bounds)
		result[int(request.key)] = {"image": image, "bounds": bounds,
			"source_bounds": source, "draw_order": int(request.draw_order), "texture_factor": 1}

	return result
