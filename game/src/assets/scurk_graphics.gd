class_name ScurkGraphics
extends RefCounted
# indexed paint instructions and display-only drawing backgrounds

const TEXTURE_IDS := [
	25039, 25040, 25041,
	25000, 25001, 25002, 25003, 25004, 25005, 25006, 25007, 25008, 25009,
	25010, 25011, 25012, 25013, 25014, 25015, 25016, 25017, 25018, 25019,
	25020, 25021, 25022, 25023, 25024, 25025, 25026, 25027, 25028, 25029,
	25030, 25031, 25032, 25033, 25034, 25035, 25036, 25037, 25038,
]
const BACKGROUND_IDS := [20015, 20018, 20019, 20020, 20021]

var error := ""
var patterns: Array[PackedInt32Array] = []
var pattern_names := PackedStringArray()
var backgrounds: Array[PackedInt32Array] = []


static func load_manifest(value: Variant, read_png: Callable, palette: Sc2Palette) -> ScurkGraphics:
	var graphics := ScurkGraphics.new()
	graphics._load(value, read_png, palette)
	return graphics


func _load(value: Variant, read_png: Callable, palette: Sc2Palette) -> void:
	if not value is Dictionary or value.size() != 2 or not value.has_all(["textures", "backgrounds"]):
		error = "scurk must contain textures and backgrounds"
		return
	for group in ["textures", "backgrounds"]:
		var records: Variant = value[group]
		var ids: Array = TEXTURE_IDS if group == "textures" else BACKGROUND_IDS
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
			var size := Vector2i(8, 8) if group == "textures" else Vector2i(128, 256)
			if Vector2i(png.width, png.height) != size or png.pixels.has(-1):
				error = "SCURK bitmap %d must be opaque and %d by %d" % [ids[i], size.x, size.y]
				return
			if png.palette.colors != palette.colors:
				error = "SCURK bitmap palette differs from the pack palette: %s" % record.png
				return
			if group == "textures":
				patterns.append(png.pixels)
				pattern_names.append(record.name)
			else:
				backgrounds.append(png.pixels)
