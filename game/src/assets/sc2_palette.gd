class_name Sc2Palette
extends RefCounted

const FAST_CYCLE_START := 0xab
# can't just rotate the palette array, the groups have different cycles
const FAST_CYCLE_TABLE := [
	1, 2, 3, 4, 5, 6, 7, 0,
	9, 10, 11, 12, 13, 14, 15, 8,
	17, 18, 19, 20, 21, 22, 23, 16,
	25, 26, 27, 24, 28,
	36, 29, 30, 31, 32, 33, 34, 35,
	40, 37, 38, 39,
	48, 41, 42, 43, 44, 45, 46, 47,
]
const SLOW_CYCLE_START := 0xe0
const SLOW_CYCLE_TABLE := [
	1, 0, 3, 2, 5, 4, 7, 6,
	9, 8, 11, 10, 13, 12, 14, 0,
]
const SCURK_TIMER_INTERVAL_SECONDS := 0.055
const SCURK_INCREMENT_TIMER_TICKS := 5

var colors: Array[Color] = []
var load_error := ""
var is_index_encoding := false


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


# this gray is an address, not a color
static func index_encoding() -> Sc2Palette:
	var palette := Sc2Palette.new()
	palette.is_index_encoding = true

	for index in 256:
		palette.colors.append(Color8(index, index, index, 255))

	return palette


func animation_index_map(base_ticks: int) -> PackedInt32Array:
	var safe_ticks := maxi(0, base_ticks)
	var fast_steps := posmod(safe_ticks, 8)
	var slow_ticks := int(safe_ticks / 8)
	var slow_steps := 0 if slow_ticks == 0 else 1 + posmod(slow_ticks - 1, 2)

	return animation_index_map_steps(fast_steps, slow_steps)


# scurk has its own palette clock, including the startup delay
func scurk_animation_index_map(timer_ticks: int) -> PackedInt32Array:
	var safe_ticks := maxi(0, timer_ticks)
	var fast_steps := 0 if safe_ticks < 6 else 1 + int((safe_ticks - 6) / 5)
	var slow_steps := 0 if safe_ticks < 31 else 1 + int((safe_ticks - 31) / 30)

	return animation_index_map_steps(fast_steps, slow_steps)


func animation_index_map_steps(fast_steps: int, slow_steps: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	indices.resize(256)

	for index in 256:
		indices[index] = index

	for _step in posmod(maxi(0, fast_steps), 8):
		_apply_cycle(indices, FAST_CYCLE_START, FAST_CYCLE_TABLE)

	var applied_slow_steps := (
		0 if slow_steps <= 0 else 1 + posmod(slow_steps - 1, 2)
	)

	for _step in applied_slow_steps:
		_apply_cycle(indices, SLOW_CYCLE_START, SLOW_CYCLE_TABLE)

	return indices


func animation_image(base_ticks: int) -> Image:
	var image := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	var indices := animation_index_map(base_ticks)

	for index in 256:
		image.set_pixel(index, 0, color(indices[index]))

	return image


static func _apply_cycle(
	indices: PackedInt32Array, start: int, cycle_table: Array
) -> void:
	var previous := indices.duplicate()

	for destination in cycle_table.size():
		indices[start + destination] = previous[start + int(cycle_table[destination])]


static func _read_u16_le(bytes: PackedByteArray, offset: int) -> int:
	return bytes[offset] | (bytes[offset + 1] << 8)


static func _read_u32_le(bytes: PackedByteArray, offset: int) -> int:
	return (
		bytes[offset]
		| (bytes[offset + 1] << 8)
		| (bytes[offset + 2] << 16)
		| (bytes[offset + 3] << 24)
	)
