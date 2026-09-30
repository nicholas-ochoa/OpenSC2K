class_name IsometricPixelOperations
extends IsometricConstants


static func foreground_difference_mask(sprite: Image, background: Image) -> Image:
	if sprite == null:
		return null

	if background == null:
		return sprite

	return NativeSpriteCompositor.foreground_difference_mask(sprite, background)


static func build_occlusion_grid(
	commands: Array[CityStaticCommand], divisor: int
) -> Dictionary[Vector2i, Array]:
	var grid: Dictionary[Vector2i, Array] = {}

	for command_index in commands.size():
		var command := commands[command_index]
		var bounds := Rect2i(
			Vector2i(command.position) * divisor,
			Vector2i(command.size) * divisor,
		)

		append_occlusion_bounds(grid, bounds, command_index)

	return grid


static func append_occlusion_bounds(grid: Dictionary[Vector2i, Array], bounds: Rect2i, command_index: int) -> void:
	if bounds.get_area() <= 0:
		return

	var last_pixel := bounds.position + bounds.size - Vector2i.ONE
	var first_cell := Vector2i(
		floori(float(bounds.position.x) / float(OCCLUSION_CELL_SIZE)),
		floori(float(bounds.position.y) / float(OCCLUSION_CELL_SIZE)),
	)
	var last_cell := Vector2i(
		floori(float(last_pixel.x) / float(OCCLUSION_CELL_SIZE)),
		floori(float(last_pixel.y) / float(OCCLUSION_CELL_SIZE)),
	)

	for cell_y in range(first_cell.y, last_cell.y + 1):
		for cell_x in range(first_cell.x, last_cell.x + 1):
			var cell := Vector2i(cell_x, cell_y)
			var cell_indices: Array = grid.get(cell, [])
			cell_indices.append(command_index)
			grid[cell] = cell_indices


static func occlusion_candidate_indices(
	grid: Dictionary[Vector2i, Array], bounds: Rect2i
) -> Array[int]:
	var result: Array[int] = []

	if bounds.get_area() <= 0 or grid.is_empty():
		return result

	var last_pixel := bounds.position + bounds.size - Vector2i.ONE
	var first_cell := Vector2i(
		floori(float(bounds.position.x) / float(OCCLUSION_CELL_SIZE)),
		floori(float(bounds.position.y) / float(OCCLUSION_CELL_SIZE)),
	)
	var last_cell := Vector2i(
		floori(float(last_pixel.x) / float(OCCLUSION_CELL_SIZE)),
		floori(float(last_pixel.y) / float(OCCLUSION_CELL_SIZE)),
	)
	var seen := {}

	for cell_y in range(first_cell.y, last_cell.y + 1):
		for cell_x in range(first_cell.x, last_cell.x + 1):
			for value in grid.get(Vector2i(cell_x, cell_y), []):
				var command_index := int(value)

				if seen.has(command_index):
					continue

				seen[command_index] = true
				result.append(command_index)

	result.sort()

	return result


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
