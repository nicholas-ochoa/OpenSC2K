class_name CityGpuSignForegrounds
extends RefCounted


# worker-owned sign masks, clipped to the same region as their static pixels
static func build(region: CityGpuRegionResult, requests: Array[CitySignRequest], palette: Sc2Palette,
		sprites: Sc2SpriteArchive, context: CityGpuBuildContext, divisor: int) -> Dictionary[int, CitySignForegroundPatch]:
	var result: Dictionary[int, CitySignForegroundPatch] = {}

	for request in requests:
		var source: Rect2i = request.bounds
		var first := Vector2i((Vector2(source.position) / divisor).floor())
		var end := Vector2i((Vector2(source.end) / divisor).ceil())
		var bounds := Rect2i(first, end - first).intersection(region.bounds)

		if not bounds.has_area():
			continue

		var masks: Array[CitySignForeground.Mask] = []
		for command: CityStaticCommand in region.occlusion_commands:
			if int(command.depth_order) <= int(request.draw_order):
				continue

			if not bounds.intersects(Rect2i(command.position, command.size)):
				continue

			var image := CityIsometricRenderer.sprite_image(sprites, palette, context.images, int(command.sprite_id), bool(command.flip))

			if image != null:
				masks.append(CitySignForeground.Mask.new(image, Vector2i(command.position)))
		var sampled := CityGpuDrawList.paint(region.gpu_draws, bounds, region.background, region.gpu_draw_grid)
		var image := CitySignForeground.static_pixels(sampled, masks, bounds)
		var patch := CitySignForegroundPatch.new()
		patch.image = image
		patch.bounds = bounds
		patch.source_bounds = source
		patch.draw_order = int(request.draw_order)
		result[int(request.key)] = patch

	return result
