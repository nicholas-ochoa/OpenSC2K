class_name IsometricPixelOperations
extends IsometricConstants


static func foreground_difference_mask(sprite: Image, background: Image) -> Image:
	if sprite == null:
		return null

	if background == null:
		return sprite

	return NativeSpriteCompositor.foreground_difference_mask(sprite, background)


# the foreground commands in a grid of cells, scaled by `divisor`
static func build_occlusion_grid(commands: Array[CityStaticCommand], divisor: int) -> NativeRectIndex:
	var rects := PackedInt32Array()
	rects.resize(commands.size() * 4)

	for index in commands.size():
		var command := commands[index]
		rects[index * 4] = int(command.position.x)
		rects[index * 4 + 1] = int(command.position.y)
		rects[index * 4 + 2] = int(command.size.x)
		rects[index * 4 + 3] = int(command.size.y)

	return build_rect_grid(rects, divisor)


# x, y, width and height of each rectangle, scaled by `divisor`, in a grid of cells
static func build_rect_grid(rects: PackedInt32Array, divisor: int) -> NativeRectIndex:
	return NativeRectIndex.build(rects, divisor, OCCLUSION_CELL_SIZE)


# indices, in ascending order, of the rectangles in the cells that `bounds` touches
static func occlusion_candidate_indices(grid: NativeRectIndex, bounds: Rect2i) -> PackedInt32Array:
	if grid == null:
		return PackedInt32Array()

	return grid.candidates(bounds)


# hide the sprite pixels under `occluder_mask`, and the pixels over same-tile
# foreground artwork: those whose index in `index_image` is in
# `same_tile_foreground_indices`. `index_image` holds the whole map at the sprite
# `position`, or, with `index_covers_sprite`, only the area under the sprite
static func occlude_dynamic_with_mask(
	sprite: Image,
	occluder_mask: Image,
	position: Vector2i,
	index_image: Image = null,
	same_tile_foreground_indices := PackedInt32Array(),
	index_covers_sprite := false
) -> OcclusionResult:
	if sprite == null:
		return OcclusionResult.new(sprite)

	var result := NativeSpriteCompositor.occlude(sprite, occluder_mask, index_image,
		Vector2i.ZERO if index_covers_sprite else position, same_tile_foreground_indices)

	return OcclusionResult.new(result.image, result.occluded_pixels)


# darken the pixels of `output` under the opaque pixels of `mask`
static func _blend_shadow(
	output: Image, mask: Image, palette: Sc2Palette, destination: Vector2i
) -> void:
	NativeSpriteCompositor.blend_shadow(output, mask, destination, CityGpuBuildContext.shadow_colors(palette))


# return the decoded sprite image, flipped on request
# `cache` belongs to the caller and holds the result, so image identity stays
# usable as a sprite key
# the returned image belongs to the cache. do not change it
static func sprite_image(
	sprites: Sc2SpriteArchive,
	palette: Sc2Palette,
	cache: Dictionary,
	sprite_id: int,
	flip: bool
) -> Image:
	var key := "%d:%d" % [sprite_id, int(flip)]

	if cache.has(key):
		return cache[key]

	var entry := sprites.find_sprite(sprite_id)
	var rendered := entry.create_image(palette)
	var image: Image = rendered.image

	if flip:
		image = image.duplicate()
		image.flip_x()

	cache[key] = image

	return image


static func highway_train_deck_mask(surface: Image, thickness: int) -> Image:
	# keep separate bands around each indexed road surface (0xa1). a single
	# cutoff would retain pillars in the gap between a composite's two decks
	return NativeSpriteCompositor.highway_train_deck_mask(surface, thickness)


class OcclusionResult extends RefCounted:
	var image: Image
	var occluded_pixels: int

	func _init(visible: Image, count := 0) -> void:
		image = visible
		occluded_pixels = count
