class_name ScurkImageImport
extends RefCounted
## Import indexed PNG, GIF, and BMP images into the SimCity 2000 palette. PNG and
## GIF transparency comes from the file. BMP index 0 is transparent, as in SCURK.

const FORMATS := ["png", "gif", "bmp"]


static func load_path(path: String, palette: Sc2Palette) -> IndexedImageResult:
	var extension := path.get_extension().to_lower()

	if extension not in FORMATS:
		return IndexedImageResult.failure("Select an indexed PNG, GIF, or BMP image.")

	if palette == null or not palette.is_valid():
		return IndexedImageResult.failure("The city palette is not available.")

	if extension == "bmp":
		return _load_bmp(path, palette)

	var decoded := IndexedPng.load_path(path, false) if extension == "png" else IndexedGif.load_path(path)

	if not decoded.ok:
		return decoded

	var mapping := {}
	var remapped := 0
	var pixels: PackedInt32Array = decoded.pixels.duplicate()

	for index in pixels.size():
		var color_index := pixels[index]

		if color_index < 0:
			continue

		if not mapping.has(color_index):
			var color: Color = decoded.palette.color(color_index)
			mapping[color_index] = color_index if IndexedBmp._same_rgb(color, palette.color(color_index)) else IndexedBmp._nearest_palette_index(color, palette)

			if mapping[color_index] != color_index:
				remapped += 1

		pixels[index] = mapping[color_index]

	return _result(decoded.width, decoded.height, pixels, remapped)


# uncompressed and RLE8 bitmaps with a color table of up to 256 entries
static func _load_bmp(path: String, palette: Sc2Palette) -> IndexedImageResult:
	if not FileAccess.file_exists(path):
		return IndexedImageResult.failure("BMP file does not exist: %s" % path)

	var decoded := Sc2ImportBitmap.decode(FileAccess.get_file_as_bytes(path), true)

	if not decoded.ok:
		return decoded

	var mapped := IndexedBmp.map_to_palette(decoded, palette)

	if not mapped.ok:
		return mapped

	return _result(decoded.width, decoded.height, mapped.pixels, mapped.remapped_color_count)


static func _result(width: int, height: int, pixels: PackedInt32Array, remapped: int) -> IndexedImageResult:
	var outcome := IndexedImageResult.new()
	outcome.ok = true
	outcome.error = ""
	outcome.width = width
	outcome.height = height
	outcome.pixels = pixels
	outcome.remapped_color_count = remapped

	return outcome
