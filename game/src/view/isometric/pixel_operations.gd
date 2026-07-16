class_name IsometricPixelOperations
extends IsometricConstants



static func foreground_difference_mask(sprite: Image, background: Image) -> Image:
	if sprite == null:
		return null

	if background == null:
		return sprite

	var mask := Image.create(
		sprite.get_width(), sprite.get_height(), false, Image.FORMAT_RGBA8
	)
	mask.fill(Color.TRANSPARENT)
	var background_y_offset := sprite.get_height() - background.get_height()

	for y in sprite.get_height():
		for x in sprite.get_width():
			var source := sprite.get_pixel(x, y)

			if source.a == 0.0:
				continue

			var background_y := y - background_y_offset
			var changed := (
				x >= background.get_width()
				or background_y < 0
				or background_y >= background.get_height()
			)

			if not changed:
				changed = (
					source.to_rgba32()
					!= background.get_pixel(x, background_y).to_rgba32()
				)

			if changed:
				mask.set_pixel(x, y, source)

	return mask


static func build_occlusion_grid(
	commands: Array[Dictionary], divisor: int
) -> Dictionary:
	var grid := {}

	for command_index in commands.size():
		var command := commands[command_index]
		var bounds := Rect2i(
			Vector2i(command.position) * divisor,
			Vector2i(command.size) * divisor,
		)

		if bounds.get_area() <= 0:
			continue

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

	return grid


static func occlusion_candidate_indices(
	grid: Dictionary, bounds: Rect2i
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


static func occlude_dynamic_with_mask(
	sprite: Image,
	occluder_mask: Image,
	position: Vector2i,
	index_image: Image = null,
	same_tile_foreground_indices := PackedInt32Array(),
	index_reader := Callable()
) -> Dictionary:
	if sprite == null:
		return {"image": sprite, "occluded_pixels": 0}

	var visible: Image
	var occluded_pixels := 0

	for source_y in sprite.get_height():
		for source_x in sprite.get_width():
			var source_color: Color = sprite.get_pixel(source_x, source_y)

			if source_color.a == 0.0:
				continue

			var hidden := (
				occluder_mask != null
				and occluder_mask.get_pixel(source_x, source_y).a > 0.0
			)
			var map_point := position + Vector2i(source_x, source_y)

			if (
				not hidden
				and (index_image != null or index_reader.is_valid())
				and not same_tile_foreground_indices.is_empty()
				and map_point.x >= 0
				and map_point.y >= 0
				and (index_reader.is_valid() or (map_point.x < index_image.get_width() and map_point.y < index_image.get_height()))
			):
				var encoded: Color = index_reader.call(map_point.x, map_point.y) if index_reader.is_valid() else index_image.get_pixelv(map_point)
				var palette_index := roundi(encoded.r * 255.0)
				hidden = same_tile_foreground_indices.has(palette_index)

			if not hidden:
				continue

			if visible == null:
				visible = sprite.duplicate()

			source_color.a = 0.0
			visible.set_pixel(source_x, source_y, source_color)
			occluded_pixels += 1

	return {
		"image": sprite if visible == null else visible,
		"occluded_pixels": occluded_pixels,
	}


static func shadow_color(palette: Sc2Palette, destination: Color) -> Color:
	if palette == null or not palette.is_valid():
		return destination

	var packed := destination.to_rgba32()

	if packed == palette.color(0x5f).to_rgba32():
		return palette.color(0x64)

	for palette_index in range(0x74, 0x7f):
		if packed == palette.color(palette_index).to_rgba32():
			return palette.color(0x7e)

	return destination


static func shadow_palette_index(index: int) -> int:
	if index == 0x5f:
		return 0x64

	if index >= 0x74 and index < 0x7f:
		return 0x7e

	return index


static func _blend_shadow(
	output: Image, mask: Image, palette: Sc2Palette, destination: Vector2i
) -> void:
	for source_y in mask.get_height():
		var output_y := destination.y + source_y

		if output_y < 0 or output_y >= output.get_height():
			continue

		for source_x in mask.get_width():
			if mask.get_pixel(source_x, source_y).a == 0.0:
				continue

			var output_x := destination.x + source_x

			if output_x < 0 or output_x >= output.get_width():
				continue

			var current := output.get_pixel(output_x, output_y)
			var changed := shadow_color(palette, current)

			if changed != current:
				output.set_pixel(output_x, output_y, changed)


# return the decoded sprite image, flipped on request
# `cache` belongs to the caller and holds the result. a caller that shares
# one cache with `IsometricImageRender.draw_tile` gets the same image
# instances, so image identity stays usable as a sprite key
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


static func _blend_on_base(
	output: Variant,
	sprite: Image,
	x: int,
	base_y: int,
	tile_height := TILE_HEIGHT
) -> void:
	var destination := Vector2i(x, base_y + tile_height - sprite.get_height())
	output.blend_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), destination)


static func _traffic_masked_image(
	sprite: Image,
	surface: Image,
	palette: Sc2Palette,
	cache: Dictionary = {},
	cache_key := ""
) -> Image:
	if not cache_key.is_empty() and cache.has(cache_key):
		return cache[cache_key]

	var masked: Image = sprite.duplicate()
	var target := palette.color(0xa1).to_rgba32()
	var vertical_offset := surface.get_height() - sprite.get_height()

	for source_y in sprite.get_height():
		var surface_y := source_y + vertical_offset

		for source_x in sprite.get_width():
			var keep := (
				source_x < surface.get_width()
				and surface_y >= 0
				and surface_y < surface.get_height()
				and surface.get_pixel(source_x, surface_y).to_rgba32() == target
			)

			if keep:
				continue

			var source_color: Color = masked.get_pixel(source_x, source_y)
			source_color.a = 0.0
			masked.set_pixel(source_x, source_y, source_color)

	if not cache_key.is_empty():
		cache[cache_key] = masked

	return masked


static func highway_train_deck_mask(surface: Image, thickness: int) -> Image:
	# keep separate bands around each indexed road surface (0xa1). a single
	# cutoff would retain pillars in the gap between a composite's two decks
	var mask := surface.duplicate()

	for x in surface.get_width():
		var near_deck := PackedByteArray()
		near_deck.resize(surface.get_height())

		for y in surface.get_height():
			var pixel := surface.get_pixel(x, y)

			if pixel.a > 0.0 and roundi(pixel.r * 255.0) == 0xa1:
				for row in range(maxi(0, y - thickness), mini(surface.get_height(), y + thickness + 1)):
					near_deck[row] = 1

		for y in surface.get_height():
			if near_deck[y] == 0:
				mask.set_pixel(x, y, Color.TRANSPARENT)

	return mask
