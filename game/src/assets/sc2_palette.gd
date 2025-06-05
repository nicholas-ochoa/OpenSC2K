class_name Sc2Palette
extends RefCounted

var colors: Array[Color] = []
var load_error := ""


static func load_bmp(path: String) -> Sc2Palette:
	var palette := Sc2Palette.new()
	if not FileAccess.file_exists(path):
		palette.load_error = "Palette file does not exist: %s" % path
		return palette
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 54 or bytes[0] != 0x42 or bytes[1] != 0x4d:
		palette.load_error = "Palette file is not a Windows BMP"
		return palette

	var dib_size := _read_u32_le(bytes, 14)
	if dib_size < 40 or 14 + dib_size > bytes.size():
		palette.load_error = "BMP information header is invalid"
		return palette
	if _read_u16_le(bytes, 28) != 8:
		palette.load_error = "BMP does not use an 8-bit indexed palette"
		return palette

	var color_count := _read_u32_le(bytes, 46)
	if color_count == 0:
		color_count = 256
	if color_count > 256:
		palette.load_error = "BMP palette has more than 256 colors"
		return palette

	var palette_offset := 14 + dib_size
	if palette_offset + color_count * 4 > bytes.size():
		palette.load_error = "BMP palette extends past the file"
		return palette

	for index in color_count:
		var offset := palette_offset + index * 4
		palette.colors.append(
			Color8(bytes[offset + 2], bytes[offset + 1], bytes[offset], 255)
		)
	return palette


func is_valid() -> bool:
	return load_error.is_empty() and colors.size() == 256


func color(index: int) -> Color:
	if index < 0 or index >= colors.size():
		return Color.MAGENTA
	return colors[index]


static func _read_u16_le(bytes: PackedByteArray, offset: int) -> int:
	return bytes[offset] | (bytes[offset + 1] << 8)


static func _read_u32_le(bytes: PackedByteArray, offset: int) -> int:
	return (
		bytes[offset]
		| (bytes[offset + 1] << 8)
		| (bytes[offset + 2] << 16)
		| (bytes[offset + 3] << 24)
	)

