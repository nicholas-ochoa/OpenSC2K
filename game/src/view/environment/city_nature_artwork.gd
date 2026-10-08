class_name CityNatureArtwork
extends RefCounted
## Small variations of the active artwork, composed once per archive. City data stays read-only.

@warning_ignore_start("integer_division")

const FIRST := 6000
const SPAN := 1500
const VARIANTS := 4
const GROUND_VARIANT := 64
static var _ground: ImageTexture


static func ground_texture() -> ImageTexture:
	if _ground == null:
		var pixels := Image.create(32, 32, false, Image.FORMAT_RGB8)
		for y in 32:
			for x in 32:
				var value := ((x * 374761393 + y * 668265263) ^ 1274126177) & 0x7fffffff
				value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
				pixels.set_pixel(x, y, Color(float(value & 255) / 255.0, float((value >> 8) & 255) / 255.0, 0))
		_ground = ImageTexture.create_from_image(pixels)
	return _ground


static func sprite_id(view: int, density: int, neighbors: int, variant: int) -> int:
	return FIRST + (neighbors * VARIANTS + variant) * SPAN + view * 500 + 5 + density


static func prepare(archive: Sc2SpriteArchive, palette: Sc2Palette) -> void:
	if not archive.visual_nature.is_empty():
		return
	for view in 3:
		if not archive.entries_by_id.has(view * 500 + 6):
			continue
		for neighbors in 16:
			for variant in VARIANTS:
				for density in range(1, 8):
					var source := archive.find_sprite(view * 500 + 5 + density)
					if source == null:
						continue
					var pixels := _group(source, palette, density, neighbors, variant)
					var mask := Image.create(source.width, source.height, false, Image.FORMAT_RGBA8)
					for at in pixels.size():
						if pixels[at] >= 0 and _foliage(palette.color(pixels[at])):
							mask.set_pixel(at % source.width, at / source.width, Color(1, 0, 0, 1))
					var id := sprite_id(view, density, neighbors, variant)
					archive.visual_nature[id] = Sc2SpriteArchive.entry_from_indices(id, source.width, source.height, pixels)
					archive.visual_nature_masks[id] = mask

		var ground := archive.find_sprite(view * 500 + 256)
		if ground != null:
			var id := FIRST + GROUND_VARIANT * SPAN + view * 500 + 256
			archive.visual_nature[id] = _ground_entry(ground, id)
			if archive.visual_seasons.has(ground.sprite_id):
				archive.visual_nature_masks[id] = archive.visual_seasons[ground.sprite_id]


static func _ground_entry(source: Sc2SpriteArchive.SpriteEntry, id: int) -> Sc2SpriteArchive.SpriteEntry:
	var original: PackedInt32Array = source.decode_indices().pixels
	var pixels := original.duplicate()
	if source.width < 8 or source.height < 5:
		return Sc2SpriteArchive.entry_from_indices(id, source.width, source.height, pixels)
	var inset := maxi(1, source.width / 16)
	for y in source.height:
		var left := source.width
		var right := -1
		for x in source.width:
			if original[y * source.width + x] >= 0:
				left = mini(left, x)
				right = x
		if right < left:
			continue
		for x in range(left, right + 1):
			if mini(x - left, right - x) >= inset and y < source.height - inset:
				continue
			# Keep the exact terrain silhouette. Only replace the dark drawn
			# grid edge with an existing interior soil pixel of the same tile.
			var sx := clampi(x, left + inset, maxi(left + inset, right - inset))
			var sy := y
			if right - left < inset * 3 or y >= source.height - inset:
				sx = source.width / 2
				sy = clampi(y, inset * 2, source.height - inset * 2 - 1)
			var value := original[sy * source.width + mini(sx, source.width - 1)]
			if value >= 0:
				pixels[y * source.width + x] = value
	return Sc2SpriteArchive.entry_from_indices(id, source.width, source.height, pixels)


static func _foliage(color: Color) -> bool:
	return color.g > color.r * 0.9 and color.g > color.b * 1.25


static func _group(source: Sc2SpriteArchive.SpriteEntry, palette: Sc2Palette,
		density: int, neighbors: int, variant: int) -> PackedInt32Array:
	var original: PackedInt32Array = source.decode_indices().pixels
	var pixels := original.duplicate()
	var width := source.width
	var height := source.height
	# Mirror complete groups, preserving every original trunk, tree and shade.
	if variant & 1 != 0:
		for y in height:
			for x in width:
				pixels[y * width + x] = original[y * width + width - 1 - x]
	var base := pixels.duplicate()
	# At the smallest size, preserve the few original silhouette pixels.
	if width < 16:
		return pixels
	for y in range(1, height - 2):
		for x in range(1, width - 1):
			var at := y * width + x
			var index := base[at]
			if index < 0 or not _foliage(palette.color(index)):
				continue
			# Extend existing needles by at most one pixel near a shared dense
			# edge. Open sides and tree roots retain the original outline.
			var side := (0 if y < height / 2 else 1) if x > width / 2 else (3 if y < height / 2 else 2)
			var shared := density >= 4 and neighbors & (1 << side) != 0
			var accent := variant >= 2 and (x * 7 + y * 11) % 9 == 0
			if not shared and not accent:
				continue
			var step := 1 if x > width / 2 else -1
			if base[at + step] < 0 and base[at + width] >= 0:
				pixels[at + step] = index
	return pixels
