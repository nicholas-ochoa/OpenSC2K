class_name Sc2ImportBitmap
extends RefCounted
## Decode indexed Windows BMP/DIB resources without a PE-specific wrapper.

@warning_ignore_start("integer_division")


static func decode(data: PackedByteArray, file_header := false) -> IndexedImageResult:
	var start := 14 if file_header else 0

	if not Sc2ImportContainer.has_range(data, start, 40):
		return IndexedImageResult.failure("Truncated bitmap header.")

	if file_header and data.slice(0, 2).get_string_from_ascii() != "BM":
		return IndexedImageResult.failure("Missing BMP signature.")

	var header_size := int(data.decode_u32(start))
	var width := int(data.decode_u32(start + 4))
	var signed_height := int(data.decode_u32(start + 8))

	if signed_height >= 0x80000000:
		signed_height -= 0x100000000

	var height := absi(signed_height)
	var bits := int(data.decode_u16(start + 14))
	var compression := int(data.decode_u32(start + 16))
	var count := int(data.decode_u32(start + 32))

	if header_size < 40 or not Sc2ImportContainer.has_range(data, start, header_size) or width < 1 or width > 4096 or height < 1 or height > 4096 or data.decode_u16(start + 12) != 1:
		return IndexedImageResult.failure("Invalid bitmap dimensions or header.")

	if bits not in [1, 4, 8] or compression not in [0, 1] or (compression == 1 and (bits != 8 or signed_height < 0)):
		return IndexedImageResult.failure("Unsupported indexed bitmap encoding.")

	if count == 0:
		count = 1 << bits

	var palette_start := start + header_size

	if count < 1 or count > 1 << bits or not Sc2ImportContainer.has_range(data, palette_start, count * 4):
		return IndexedImageResult.failure("Invalid bitmap color table.")

	var pixels_start := int(data.decode_u32(10)) if file_header else palette_start + count * 4

	if pixels_start < palette_start + count * 4 or pixels_start > data.size():
		return IndexedImageResult.failure("Invalid bitmap pixel offset.")

	var result := IndexedImageResult.new()

	if compression == 1:
		var size := int(data.decode_u32(start + 20))

		if size <= 0 or not Sc2ImportContainer.has_range(data, pixels_start, size):
			return IndexedImageResult.failure("Truncated RLE8 bitmap data.")

		result = WindowsBitmapRle8.decode(data.slice(pixels_start, pixels_start + size), width, height)

		if not result.ok:
			return result
	else:
		var stride := ((width * bits + 31) / 32) * 4

		if not Sc2ImportContainer.has_range(data, pixels_start, stride * height):
			return IndexedImageResult.failure("Truncated bitmap rows.")

		result.pixels.resize(width * height)

		for y in height:
			var row := y if signed_height < 0 else height - 1 - y

			for x in width:
				var bit := x * bits
				var byte := int(data[pixels_start + row * stride + bit / 8])
				result.pixels[y * width + x] = (byte >> (8 - bits - bit % 8)) & ((1 << bits) - 1)

	for index in result.pixels:
		if index < 0 or index >= count:
			return IndexedImageResult.failure("Bitmap pixel exceeds the color table.")

	result.palette = Sc2Palette.new()

	for index in 256:
		var color := Color.BLACK

		if index < count:
			var offset := palette_start + index * 4
			color = Color8(data[offset + 2], data[offset + 1], data[offset])

		result.palette.colors.append(color)

	result.colors = result.palette.colors
	result.width = width
	result.height = height
	result.top_down = signed_height < 0
	result.ok = true
	return result
