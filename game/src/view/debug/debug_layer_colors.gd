class_name DebugLayerColors
extends RefCounted
## The 256-color tables of the debug tile layers. Index n tints the tiles whose
## layer value is n. A clear color leaves the city visible.

const Layer = DebugTileLayers.Layer
const Kind = DebugTileLayers.Kind
const CLEAR := Color(0, 0, 0, 0)
const UNKNOWN := Color("ff00ff")
const ZONE_COLORS := [CLEAR, Color("8be28b"), Color("2fae4a"), Color("8cc8ff"), Color("2f6bff"), Color("ffe066"),
	Color("ff9f1c"), Color("9a9a9a"), Color("b07cff"), Color("2ec4b6")]
const OVERLAY_COLORS := [CLEAR, Color("ffd166"), Color("06d6a0"), Color("ef476f"), Color("118ab2"), Color("c77dff")]
# one color for each bit, in bit order. a tile with several bits shows its lowest bit
const UNUSUAL_COLORS := [Color("ff00ff"), Color("ff7b00"), Color("00e5ff"), Color("ffee00"), Color("34c759")]
const CHANGE_COLORS := [Color("ff3b30"), Color("ffcc00"), Color("a2845e"), Color("ff9500"), Color("5ac8fa"),
	Color("af52de"), Color("007aff")]
const FLAG_COLOR := Color("ffd60a")
const MARK_COLOR := Color("ff2bd6")
const LOW_COLOR := Color("1d4ed8")
const HIGH_COLOR := Color("f43f5e")


static func table(layer: Layer) -> Image:
	var image := Image.create(256, 1, false, Image.FORMAT_RGBA8)

	for index in 256:
		image.set_pixel(index, 0, color(layer, index))

	return image


static func color(layer: Layer, value: int) -> Color:
	if layer == Layer.NONE:
		return CLEAR

	match DebugTileLayers.kind(layer):
		Kind.IDS:
			return CLEAR if value == 0 else id_color(value)
		Kind.FLAG:
			return FLAG_COLOR if value & DebugTileLayers.FLAG_BITS[layer] else CLEAR
		Kind.NETWORKS:
			return network_color(value)
		Kind.BITS:
			return _bit_color(layer, value)
		Kind.CATEGORIES:
			return _category_color(layer, value)
		Kind.MARK:
			return MARK_COLOR if value != 0 else CLEAR

	return gradient_color(layer, value)


# a stable color for an ID. the golden ratio spreads near IDs around the hue circle
static func id_color(value: int) -> Color:
	return Color.from_hsv(fmod(value * 0.61803398875, 1.0), 0.7, 0.95)


static func network_color(value: int) -> Color:
	if value == 0:
		return CLEAR

	var supplied := value >= NativeDebugTiles.SUPPLIED_BASE
	var hue := fmod((value & 0x7f) * 0.61803398875, 1.0)

	return Color.from_hsv(hue, 0.85, 1.0) if supplied else Color.from_hsv(hue, 0.35, 0.45)


static func gradient_color(layer: Layer, value: int) -> Color:
	if value == 0 and DebugTileLayers.DATA_CHUNKS.has(layer):
		return CLEAR

	var amount := clampf(float(value) / maxi(1, DebugTileLayers.maximum(layer)), 0.0, 1.0)

	return UNKNOWN if value > DebugTileLayers.maximum(layer) else LOW_COLOR.lerp(HIGH_COLOR, amount)


static func _category_color(layer: Layer, value: int) -> Color:
	if layer == Layer.ZONE_TYPE:
		var zone := value & Sc2ZoneLayout.TYPE_MASK

		return ZONE_COLORS[zone] if zone < ZONE_COLORS.size() else UNKNOWN

	return OVERLAY_COLORS[value] if value < OVERLAY_COLORS.size() else UNKNOWN


static func _bit_color(layer: Layer, value: int) -> Color:
	var colors: Array = UNUSUAL_COLORS if layer == Layer.UNUSUAL_VALUES else CHANGE_COLORS

	for bit in colors.size():
		if value & (1 << bit):
			return colors[bit]

	return CLEAR


# legend rows: [color, text]. gradients show their two ends
static func legend(layer: Layer) -> Array:
	var rows := []

	match DebugTileLayers.kind(layer):
		Kind.IDS:
			rows.append([id_color(1), "Each ID has its own color; 0 is clear"])
		Kind.FLAG:
			rows.append([FLAG_COLOR, "Flag 0x%02X set" % DebugTileLayers.FLAG_BITS[layer]])
		Kind.NETWORKS:
			rows.append([network_color(NativeDebugTiles.SUPPLIED_BASE + 5), "Bright: a network with a supplied tile"])
			rows.append([network_color(5), "Dark: a network without supply"])
			rows.append([network_color(NativeDebugTiles.SUPPLIED_BASE + 40), "Each network has its own hue"])
		Kind.BITS:
			var colors: Array = UNUSUAL_COLORS if layer == Layer.UNUSUAL_VALUES else CHANGE_COLORS
			var names := DebugTileLayers.category_names(layer)

			for bit in names.size():
				rows.append([colors[bit], names[bit]])
		Kind.MARK:
			rows.append([MARK_COLOR, "Needs a sprite that the artwork lacks"])
		Kind.CATEGORIES:
			var names := DebugTileLayers.category_names(layer)

			for value in range(1, names.size()):
				rows.append([_category_color(layer, value), names[value]])
		Kind.GRADIENT:
			rows.append([gradient_color(layer, 1), "Low"])
			rows.append([gradient_color(layer, DebugTileLayers.maximum(layer)), "High (%d)" % DebugTileLayers.maximum(layer)])

	return rows
