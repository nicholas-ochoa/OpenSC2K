class_name CityGpuDrawList
extends RefCounted

class Draw extends RefCounted:
	var image: Image
	var source: Rect2i
	var position: Vector2i

	func _init(sprite: Image, area: Rect2i, destination: Vector2i) -> void:
		image = sprite
		source = area
		position = destination


var draws: Array[Draw] = []


func blend_rect(image: Image, source: Rect2i, destination: Vector2i) -> void:
	draws.append(Draw.new(image, source, destination))


static func paint(draws_value: Array[Draw], bounds: Rect2i, background: Color, grid: Dictionary = {}, factor := 1) -> Image:
	assert(factor in [1, 2, 4])
	var image := Image.create(bounds.size.x * factor, bounds.size.y * factor, false, Image.FORMAT_RGBA8)
	image.fill(background)
	var candidates: Array[int] = []
	candidates.assign(CityIsometricRenderer.occlusion_candidate_indices(grid, bounds) if not grid.is_empty() else range(draws_value.size()))

	for index in candidates:
		var draw := draws_value[index]
		var rectangle := Rect2i(draw.position, draw.source.size)

		if rectangle.intersects(bounds):
			var texture: Image = draw.image
			var source: Rect2i = draw.source
			var target_size := rectangle.size * factor

			if source.size != target_size:
				texture = texture.get_region(source)
				texture.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
				source = Rect2i(Vector2i.ZERO, target_size)

			image.blend_rect(texture, source, (draw.position - bounds.position) * factor)

	image.convert(Image.FORMAT_LA8)

	return image


static func build_grid(draws_value: Array[Draw]) -> Dictionary[Vector2i, Array]:
	var grid: Dictionary[Vector2i, Array] = {}

	for index in draws_value.size():
		var draw := draws_value[index]
		IsometricPixelOperations.append_occlusion_bounds(grid, Rect2i(draw.position, draw.source.size), index)

	return grid
