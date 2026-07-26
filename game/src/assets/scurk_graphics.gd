class_name ScurkGraphics
extends RefCounted


@warning_ignore_start("integer_division")

const TEXTURE_IDS := [
	25039, 25040, 25041,
	25000, 25001, 25002, 25003, 25004, 25005, 25006, 25007, 25008, 25009,
	25010, 25011, 25012, 25013, 25014, 25015, 25016, 25017, 25018, 25019,
	25020, 25021, 25022, 25023, 25024, 25025, 25026, 25027, 25028, 25029,
	25030, 25031, 25032, 25033, 25034, 25035, 25036, 25037, 25038,
]
const BACKGROUND_IDS := [20015, 20018, 20019, 20020, 20021]
const CONTROL_IDS := [
	20000, 20001, 20002, 20003, 20004, 20005, 20006, 20007,
	20008, 20009, 20010, 20011, 20012, 20013, 20016, 20017,
	21000, 21001, 21002, 21003, 21004, 21005, 21006, 21007,
	21018, 21019, 21020,
]
const WORKSPACE_SIZES := {
	1200: Vector2i(33, 25), 1201: Vector2i(32, 24), 1202: Vector2i(33, 25),
	1203: Vector2i(33, 25), 1204: Vector2i(33, 25), 1205: Vector2i(32, 24),
	1206: Vector2i(32, 24), 1207: Vector2i(32, 24), 1208: Vector2i(32, 24),
	1209: Vector2i(32, 24), 1210: Vector2i(32, 24), 1211: Vector2i(32, 24),
	1212: Vector2i(32, 24), 1213: Vector2i(32, 24), 1214: Vector2i(32, 24), 1215: Vector2i(32, 24),
	20014: Vector2i(64, 64), 21008: Vector2i(8, 8), 21009: Vector2i(8, 8), 21021: Vector2i(48, 208),
	22001: Vector2i(10, 10), 22002: Vector2i(10, 10), 22003: Vector2i(16, 16), 22004: Vector2i(16, 16),
	22005: Vector2i(256, 256), 22100: Vector2i(26, 26), 22101: Vector2i(26, 26),
	22103: Vector2i(24, 24), 22104: Vector2i(24, 24), 22105: Vector2i(100, 24), 22106: Vector2i(8, 8),
	22107: Vector2i(48, 8), 22108: Vector2i(48, 300), 22109: Vector2i(48, 8), 22110: Vector2i(64, 64),
	23000: Vector2i(400, 200),
}
const PRESENTATION_SIZES := {123: Vector2i(128, 256), 124: Vector2i(128, 256), 125: Vector2i(640, 480)}

var error := ""
var patterns: Array[PackedInt32Array] = []
var pattern_names := PackedStringArray()
var backgrounds: Array[PackedInt32Array] = []
var control_images: Dictionary = {}
var workspace_images: Dictionary = {}
var workspace_pixels: Dictionary = {}
var presentation_images: Dictionary = {}
var presentation_pixels: Dictionary = {}


static func load_manifest(value: Variant, read_png: Callable, palette: Sc2Palette) -> ScurkGraphics:
	var graphics := ScurkGraphics.new()
	graphics._load(value, read_png, palette)

	return graphics


func _load(value: Variant, read_png: Callable, palette: Sc2Palette) -> void:
	if not value is Dictionary or not value.has_all(["textures", "backgrounds"]):
		error = "scurk must contain textures and backgrounds"

		return

	for key in value:
		if key not in ["textures", "backgrounds", "controls", "workspace", "presentation"]:
			error = "Unknown SCURK graphics field: %s" % key

			return

	for group in ["textures", "backgrounds", "controls", "workspace", "presentation"]:
		if group in ["controls", "workspace", "presentation"] and not value.has(group):
			continue

		var records: Variant = value[group]
		var ids: Array = {"textures": TEXTURE_IDS, "backgrounds": BACKGROUND_IDS, "controls": CONTROL_IDS, "workspace": WORKSPACE_SIZES.keys(), "presentation": PRESENTATION_SIZES.keys()}[group]

		if not records is Array or records.size() != ids.size():
			error = "scurk.%s must contain %d records in resource order" % [group, ids.size()]

			return

		for i in ids.size():
			var record: Variant = records[i]

			if not record is Dictionary or record.get("id") != ids[i]:
				error = "scurk.%s record %d must have id %d" % [group, i, ids[i]]

				return

			if group == "textures" and (not record.get("name") is String or str(record.name).strip_edges().is_empty()):
				error = "SCURK texture name is required"

				return

			var png: Dictionary = read_png.call(record.get("png"))

			if png.is_empty() or not png.get("ok", false):
				error = "Cannot read SCURK bitmap %d" % ids[i]

				return

			var size: Vector2i = {"textures": Vector2i(8, 8), "backgrounds": Vector2i(128, 256), "controls": Vector2i(20, 20), "workspace": WORKSPACE_SIZES.get(ids[i], Vector2i.ZERO), "presentation": PRESENTATION_SIZES.get(ids[i], Vector2i.ZERO)}[group]
			var allows_alpha: bool = group == "presentation" and ids[i] in [123, 124]

			if Vector2i(png.width, png.height) != size:
				error = "SCURK bitmap %d must be %d by %d" % [ids[i], size.x, size.y]

				return

			if not allows_alpha and png.pixels.has(-1):
				error = "SCURK bitmap %d must be opaque" % ids[i]

				return

			if png.palette.colors != palette.colors:
				error = "SCURK bitmap palette differs from the pack palette: %s" % record.png

				return

			if group == "workspace" and ids[i] == 22005:
				for index in 256:
					var center := ((index / 16) * 16 + 8) * 256 + (index % 16) * 16 + 8

					if png.pixels[center] != index:
						error = "SCURK palette-sheet cell center must use index %d" % index

						return

			if group == "textures":
				patterns.append(png.pixels)
				pattern_names.append(record.name)
			elif group == "backgrounds":
				backgrounds.append(png.pixels)
			elif group == "controls":
				control_images[ids[i]] = Sc2SpriteArchive.entry_from_indices(ids[i], 20, 20, png.pixels).create_image(palette).image
			elif group == "workspace":
				workspace_images[ids[i]] = Sc2SpriteArchive.entry_from_indices(ids[i], size.x, size.y, png.pixels).create_image(palette).image
				workspace_pixels[ids[i]] = png.pixels
			else:
				presentation_images[ids[i]] = Sc2SpriteArchive.entry_from_indices(ids[i], size.x, size.y, png.pixels).create_image(palette).image
				presentation_pixels[ids[i]] = png.pixels
