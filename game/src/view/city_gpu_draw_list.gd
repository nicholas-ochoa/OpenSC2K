class_name CityGpuDrawList
extends RefCounted

var draws: Array[Draw] = []


func blend_rect(image: Image, source: Rect2i, destination: Vector2i) -> void:
	draws.append(Draw.new(image, source, destination))


# whole-sprite draws from native draw records, moved by `offset`
static func from_records(records: PackedInt64Array, images: Array, offset := Vector2i.ZERO) -> CityGpuDrawList:
	var list := CityGpuDrawList.new()

	for at in range(0, records.size(), CityGpuBuildContext.RECORD_SIZE):
		var size := Vector2i(records[at + 2], records[at + 3])
		var draw := Draw.new(images[records[at + 4]], Rect2i(Vector2i.ZERO, size),
			Vector2i(records[at], records[at + 1]) + offset)
		draw.sprite_id = records[at + 5]
		draw.flip = records[at + 6] != 0
		draw.size = size
		draw.depth_order = records[at + 7]
		list.draws.append(draw)

	return list


static func paint(
	draws_value: Array[Draw],
	bounds: Rect2i,
	background: Color,
	grid: Dictionary[Vector2i, Array] = {},
	factor := 1,
) -> Image:
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


# A recorded sprite blend. Tile painters and previews record draws before they
# paint them; the command fields remain for callers that need a foreground.
class Draw extends CityStaticCommand:
	var image: Image
	var source: Rect2i

	func _init(sprite: Image, area: Rect2i, destination: Vector2i) -> void:
		image = sprite
		source = area
		position = destination
