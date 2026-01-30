class_name CityGpuDrawList
extends RefCounted

var draws: Array[Dictionary] = []

func blend_rect(image: Image, source: Rect2i, destination: Vector2i) -> void:
	draws.append({"image": image, "source": source, "position": destination, "size": source.size})

static func paint(draws_value: Array[Dictionary], bounds: Rect2i, background: Color, grid: Dictionary = {}) -> Image:
	var image := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	image.fill(background)
	var candidates: Array[int] = []
	candidates.assign(CityIsometricRenderer.occlusion_candidate_indices(grid, bounds) if not grid.is_empty() else range(draws_value.size()))
	for index in candidates:
		var draw: Dictionary = draws_value[index]
		var rectangle := Rect2i(draw.position, draw.source.size)
		if rectangle.intersects(bounds):
			image.blend_rect(draw.image, draw.source, draw.position - bounds.position)
	image.convert(Image.FORMAT_LA8)
	return image
