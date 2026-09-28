class_name ScurkCopyDifference
extends RefCounted
## Compares indexed artwork at its bottom-center anchor.

@warning_ignore_start("integer_division")

const CHANGED_COLOR := Color("#ff26a6")


static func compare(before: Sc2SpriteArchive.SpriteEntry, after: Sc2SpriteArchive.SpriteEntry, palette: Sc2Palette) -> Result:
	var result := Result.new()
	if before == null or after == null or palette == null or not palette.is_valid():
		return result
	var before_pixels := before.decode_indices()
	var after_pixels := after.decode_indices()
	if not before_pixels.ok or not after_pixels.ok:
		return result
	var size := Vector2i(maxi(before.width, after.width), maxi(before.height, after.height))
	var before_offset := Vector2i((size.x - before.width) / 2, size.y - before.height)
	var after_offset := Vector2i((size.x - after.width) / 2, size.y - after.height)
	result.image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var point := Vector2i(x, y)
			var old_index := _index_at(before_pixels.pixels, before, point - before_offset)
			var new_index := _index_at(after_pixels.pixels, after, point - after_offset)
			if old_index != new_index:
				result.image.set_pixel(x, y, CHANGED_COLOR)
				result.changed_pixels += 1
			elif new_index >= 0:
				var color := palette.color(new_index)
				var gray := (color.r + color.g + color.b) / 3.0
				result.image.set_pixel(x, y, Color(gray, gray, gray, 0.35))
	return result


static func _index_at(pixels: PackedInt32Array, entry: Sc2SpriteArchive.SpriteEntry, point: Vector2i) -> int:
	if point.x < 0 or point.x >= entry.width or point.y < 0 or point.y >= entry.height:
		return -1
	return pixels[point.y * entry.width + point.x]


class Result extends RefCounted:
	var image: Image
	var changed_pixels := 0
