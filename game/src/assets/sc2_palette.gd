class_name Sc2Palette
extends RefCounted
## The 256-color palette of the original graphics. The native formats library
## reads it and holds the color cycles; see native/core/assets/src/palette.rs.

const COLOR_COUNT := 256
const RGB_CHANNELS := 3
const RGB_BYTES := COLOR_COUNT * RGB_CHANNELS
# the entries of the fast and slow color cycles
const FAST_CYCLE_START := 0xab
const FAST_CYCLE_COUNT := 49
const SLOW_CYCLE_START := 0xe0
const SLOW_CYCLE_COUNT := 16
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

	# the native formats library reads the palette; see native/core/assets/src/palette.rs
	var parsed := NativePalette.bmp_colors(FileAccess.get_file_as_bytes(path))

	if not parsed.ok:
		palette.load_error = parsed.error

		return palette

	var rgb: PackedByteArray = parsed.rgb

	for offset in range(0, rgb.size(), RGB_CHANNELS):
		palette.colors.append(Color8(rgb[offset], rgb[offset + 1], rgb[offset + 2], 255))

	return palette


func is_valid() -> bool:
	return load_error.is_empty() and colors.size() == COLOR_COUNT


func to_rgb_bytes() -> PackedByteArray:
	if not is_valid():
		return PackedByteArray()
	var bytes := PackedByteArray()
	bytes.resize(RGB_BYTES)
	for index in COLOR_COUNT:
		var offset := index * RGB_CHANNELS
		bytes[offset] = colors[index].r8
		bytes[offset + 1] = colors[index].g8
		bytes[offset + 2] = colors[index].b8
	return bytes


# 256 RGBA colors for the native image builders. An invalid palette is empty
func to_rgba_bytes() -> PackedByteArray:
	if not is_valid():
		return PackedByteArray()

	var bytes := PackedByteArray()
	bytes.resize(COLOR_COUNT * 4)

	for index in COLOR_COUNT:
		bytes.encode_u32(index * 4, colors[index].to_abgr32())

	return bytes


static func from_rgb_bytes(bytes: PackedByteArray) -> Sc2Palette:
	var palette := Sc2Palette.new()
	if bytes.size() != RGB_BYTES:
		palette.load_error = "The palette must contain 256 RGB colors."
		return palette
	for index in COLOR_COUNT:
		var offset := index * RGB_CHANNELS
		palette.colors.append(Color8(bytes[offset], bytes[offset + 1], bytes[offset + 2]))
	return palette


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
	return NativePalette.index_map(base_ticks)


# scurk has its own palette clock, including the startup delay
func scurk_animation_index_map(timer_ticks: int) -> PackedInt32Array:
	return NativePalette.scurk_index_map(timer_ticks)


func animation_index_map_steps(fast_steps: int, slow_steps: int) -> PackedInt32Array:
	return NativePalette.index_map_steps(fast_steps, slow_steps)


func animation_image(base_ticks: int) -> Image:
	var image := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	var indices := animation_index_map(base_ticks)

	for index in 256:
		image.set_pixel(index, 0, color(indices[index]))

	return image


# the blue pipe is dry; the cycling blue pipe is wet
# apply the underground colors after cycling so water keeps its moving highlights
func underground_animation_image(base_ticks: int) -> Image:
	var image := animation_image(base_ticks)

	for index in 256:
		var source := image.get_pixel(index, 0)
		var high := maxf(source.r, maxf(source.g, source.b))
		var low := minf(source.r, minf(source.g, source.b))
		var remapped: Color

		if index >= 200 and index <= 207:
			remapped = Color(0.22, 0.66, 0.82).lerp(Color(0.66, 0.94, 1.0), source.g)
		elif index >= 140 and index <= 147:
			# the fixed blue pipe ramp means no water
			remapped = Color(0.36, 0.20, 0.12).lerp(Color(0.72, 0.46, 0.28), high)
		elif low > 0.97:
			remapped = Color(0.125, 0.157, 0.188)
		elif high - low < 0.08:
			remapped = Color(0.28, 0.33, 0.38).lerp(Color(0.60, 0.66, 0.70), high)
		elif source.b > source.r * 1.3 and source.b > source.g * 1.15:
			remapped = Color(0.18, 0.43, 0.65).lerp(Color(0.40, 0.78, 0.96), high)
		elif source.g > source.r * 1.2 and source.g > source.b * 1.2:
			remapped = Color(0.18, 0.43, 0.28).lerp(Color(0.45, 0.82, 0.56), high)
		else:
			remapped = source * 0.60

		remapped.a = source.a
		image.set_pixel(index, 0, remapped)

	return image
