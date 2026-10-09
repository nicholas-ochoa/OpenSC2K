class_name CitySeasonColors
extends RefCounted
## Red/green mark natural artwork; blue 1 marks warnings, 0.25 water sides.

@warning_ignore_start("integer_division")

static func prepare(archive: Sc2SpriteArchive, palette: Sc2Palette) -> void:
	archive.visual_seasons.clear()
	var soil_indices: Dictionary[int, bool] = {}
	# Zone ground contains both soil and saturated zoning marks. Match the
	# soil palette indices of terrain (including shaded edges) instead of marks.
	for id: int in archive.entries_by_id:
		var offset := id % 500
		if not ((offset >= 256 and offset <= 268) or (offset >= 270 and offset <= 283)):
			continue
		for index: int in archive.find_sprite(id).decode_indices().pixels:
			if index >= 0 and _is_soil(palette.color(index)):
				soil_indices[index] = true
	for id: int in archive.entries_by_id:
		var offset := id % 500
		var trees := offset >= 6 and offset <= 12
		var power_warning := offset == 386
		var water_side := offset == 284
		# Channel and connecting-water sprites contain land banks too. Their
		# soil mask also carries terrain variation; water pixels stay unmarked.
		var ground := (offset >= 256 and offset <= 268) or (offset >= 270 and offset <= 283) or (offset >= 285 and offset <= 290)
		var zone_ground := offset >= 291 and offset <= 299
		if not trees and not ground and not zone_ground and not power_warning and not water_side:
			continue
		var entry := archive.find_sprite(id)
		var pixels := entry.decode_indices().pixels
		var image := Image.create(entry.width, entry.height, false, Image.FORMAT_RGBA8)
		for at in pixels.size():
			if pixels[at] < 0:
				continue
			var color := palette.color(pixels[at])
			var foliage := trees and color.g > color.r * 0.9 and color.g > color.b * 1.25
			var soil := (ground and _is_soil(color)) or (zone_ground and soil_indices.has(pixels[at]))
			if water_side:
				image.set_pixel(at % entry.width, at / entry.width, Color(0, 0, 0.25, 1))
			elif foliage or soil or power_warning:
				image.set_pixel(at % entry.width, at / entry.width, Color(float(foliage), float(soil), float(power_warning), 1))
		if not image.is_invisible():
			archive.visual_seasons[id] = image


static func _is_soil(color: Color) -> bool:
	return color.r > color.b * 1.3 and color.g > color.b * 1.15


static func weights(phase: float, transition: float) -> Vector4:
	var position := fposmod(phase, 4.0)
	var index := int(floor(position))
	var fraction := position - index
	var blend := smoothstep(1.0 - clampf(transition, 0.01, 1.0), 1.0, fraction)
	var result := Vector4.ZERO
	result[index] = 1.0 - blend
	result[(index + 1) % 4] += blend
	return result
