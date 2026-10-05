class_name CitySeasonColors
extends RefCounted
## Natural artwork masks. Buildings, roads and water never receive these colors.

@warning_ignore_start("integer_division")

static func prepare(archive: Sc2SpriteArchive, palette: Sc2Palette) -> void:
	archive.visual_seasons.clear()
	for id: int in archive.entries_by_id:
		var offset := id % 500
		var trees := offset >= 6 and offset <= 12
		var ground := (offset >= 256 and offset <= 268) or (offset >= 270 and offset <= 283)
		if not trees and not ground:
			continue
		var entry := archive.find_sprite(id)
		var pixels := entry.decode_indices().pixels
		var image := Image.create(entry.width, entry.height, false, Image.FORMAT_RGBA8)
		for at in pixels.size():
			if pixels[at] < 0:
				continue
			var color := palette.color(pixels[at])
			var foliage := trees and color.g > color.r * 0.9 and color.g > color.b * 1.25
			var soil := ground and color.r > color.b * 1.3 and color.g > color.b * 1.15
			if foliage or soil:
				image.set_pixel(at % entry.width, at / entry.width, Color(float(foliage), float(soil), 0, 1))
		if not image.is_invisible():
			archive.visual_seasons[id] = image


static func weights(phase: float, transition: float) -> Vector4:
	var position := fposmod(phase, 4.0)
	var index := int(floor(position))
	var fraction := position - index
	var blend := smoothstep(1.0 - clampf(transition, 0.01, 1.0), 1.0, fraction)
	var result := Vector4.ZERO
	result[index] = 1.0 - blend
	result[(index + 1) % 4] += blend
	return result
