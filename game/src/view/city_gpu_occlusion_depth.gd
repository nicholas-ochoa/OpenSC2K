class_name CityGpuOcclusionDepth
extends RefCounted
# the extra one is for the train crossing mask, not an off-by-one
# build the static depth meshes that the moving-sprite shader samples
#
# each quad draws one static foreground silhouette with a 24-bit value in its
# vertex color. quads draw in ascending value order, so the last writer at a
# pixel holds the largest value. a moving sprite with draw order `d` is hidden
# where the stored value is `d + 2` or greater. the cpu rule unions the
# silhouettes of every later static sprite, so a maximum is sufficient
#
# the normal mesh stores `order + 1` for every silhouette. the train mesh
# applies the train crossing rules of `ApplicationMovingSprites`:
# - `train_ignore` commands do not draw
# - depth-limited crossing masks store `order + 2`, so an equal order hides
# - other crossing masks store `ALWAYS`, so any order hides
# - other commands store their silhouette at `order + 1`
# stored value 0 is the cleared background
const ALWAYS := 0xffffff
const MAX_ORDER := 0xfffffc


class Result extends RefCounted:
	var depth: Array = []
	var train: Array = []


class Quad extends RefCounted:
	var value: int
	var image: Image
	var source: Rect2i
	var position: Vector2i

	func _init(depth_value: int, sprite: Image, area: Rect2i, destination: Vector2i) -> void:
		value = depth_value
		image = sprite
		source = area
		position = destination


# RGB encodes depth here. Color correction would corrupt it.
static func encode(value: int) -> Color:
	value = clampi(value, 0, ALWAYS)

	return Color8((value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff, 255)


static func decode(color: Color) -> int:
	return (color.r8 << 16) | (color.g8 << 8) | color.b8


# return the normal and train depth meshes for one region
# vertex positions are relative to `bounds.position`, as in the region mesh
# uvs use the atlas_edge normalization of citygpuregionrenderer. the caller
# rescales them with the region uvs if the atlas grows
static func build(foreground: Array[Dictionary], draws: Array[Dictionary], bounds: Rect2i,
		context: CityGpuBuildContext, sprites: Sc2SpriteArchive, palette: Sc2Palette) -> Result:
	var normal: Array[Quad] = []
	var train: Array[Quad] = []

	for index in foreground.size():
		var command := foreground[index]
		var draw := draws[index]
		var order := mini(int(command.depth_order), MAX_ORDER)
		normal.append(Quad.new(order + 1, draw.image, draw.source, draw.position))

		if bool(command.get("train_ignore", false)):
			continue

		var crossing: bool = command.has("train_foreground_reference_sprite_id") or command.has("train_deck_thickness")

		if not crossing:
			train.append(normal.back())
			continue

		var mask := _train_mask(command, draw.image, context, sprites, palette)

		if mask == null:
			continue

		var depth_limited: bool = bool(command.get("train_foreground_requires_depth", false)) or command.has("train_deck_thickness")
		train.append(Quad.new(order + 2 if depth_limited else ALWAYS, mask,
			Rect2i(Vector2i.ZERO, mask.get_size()), draw.position))

	var depth := _arrays(normal, bounds, context)

	if not context.error.is_empty():
		return Result.new()

	var train_arrays := _arrays(train, bounds, context)

	if not context.error.is_empty():
		return Result.new()

	var result := Result.new()
	result.depth = depth
	result.train = train_arrays

	return result


static func _arrays(quads: Array[Quad], bounds: Rect2i, context: CityGpuBuildContext) -> Array:
	# a stable sort keeps painter order among equal values
	var ordered := range(quads.size())
	ordered.sort_custom(func(left: int, right: int) -> bool:
		var left_value := int(quads[left].value)
		var right_value := int(quads[right].value)

		return left_value < right_value or (left_value == right_value and left < right))
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for index in ordered:
		var quad: Quad = quads[index]
		var source: Rect2i = quad.source
		var rectangle := Rect2i(quad.position, source.size)
		var clipped := rectangle.intersection(bounds)

		if not clipped.has_area():
			continue

		var slot := context.slot(quad.image)

		if not context.error.is_empty():
			return []

		var uv := Rect2(Vector2(slot.position + source.position + clipped.position - rectangle.position), Vector2(clipped.size))
		var first := vertices.size()
		var area := Rect2(clipped.position - bounds.position, clipped.size)
		vertices.append_array(PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]))
		var scaled := Rect2(uv.position / CityGpuBuildContext.ATLAS_EDGE, uv.size / CityGpuBuildContext.ATLAS_EDGE)
		uvs.append_array(PackedVector2Array([scaled.position, Vector2(scaled.end.x, scaled.position.y), scaled.end, Vector2(scaled.position.x, scaled.end.y)]))
		var color := encode(int(quad.value))
		colors.append_array(PackedColorArray([color, color, color, color]))
		indices.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	return arrays


# the cpu train path builds the same masks from display-scale images, with the
# deck thickness scaled by the view divisor. native masks are the same pixels
# before the nearest-neighbor scale
static func _train_mask(command: Dictionary, surface: Image, context: CityGpuBuildContext,
		sprites: Sc2SpriteArchive, palette: Sc2Palette) -> Image:
	var flip := bool(command.flip)

	if command.has("train_deck_thickness"):
		var reference := int(command.get("train_deck_reference_sprite_id", 0))
		var key := "deck:%d:%d:%d:%d" % [int(command.sprite_id), int(flip), reference, int(command.train_deck_thickness)]

		if context.occlusion_masks.has(key):
			return context.occlusion_masks[key]

		var deck_surface := surface

		# a highway/power crossing uses the wire-free highway as its mask
		if reference != 0 and sprites.find_sprite(reference) != null:
			var background := CityIsometricRenderer.sprite_image(sprites, palette, context.images, reference, flip)
			deck_surface = Image.create(surface.get_width(), surface.get_height(), false, Image.FORMAT_RGBA8)
			deck_surface.blit_rect(background, Rect2i(Vector2i.ZERO, background.get_size()), Vector2i(0, surface.get_height() - background.get_height()))

		var deck := CityIsometricRenderer.highway_train_deck_mask(deck_surface, int(command.train_deck_thickness))
		context.occlusion_masks[key] = deck

		return deck

	var reference_sprite_id := int(command.train_foreground_reference_sprite_id)

	if reference_sprite_id < 0:
		return surface

	var mask_key := "foreground:%d:%d:%d" % [int(command.sprite_id), int(flip), reference_sprite_id]

	if context.occlusion_masks.has(mask_key):
		return context.occlusion_masks[mask_key]

	if sprites.find_sprite(reference_sprite_id) == null:
		return surface

	var reference_image := CityIsometricRenderer.sprite_image(sprites, palette, context.images, reference_sprite_id, flip)
	var foreground := CityIsometricRenderer.foreground_difference_mask(surface, reference_image)
	context.occlusion_masks[mask_key] = foreground

	return foreground
