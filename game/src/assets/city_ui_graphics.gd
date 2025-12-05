class_name CityUiGraphics
extends RefCounted


const CONTROL_SIZES := {
	"ADVICED": Vector2i(30, 25), "ADVICEF": Vector2i(30, 25), "ADVICEU": Vector2i(30, 25),
	"BOOKD": Vector2i(30, 24), "BOOKF": Vector2i(30, 24), "BOOKU": Vector2i(30, 24),
	"CHECKD": Vector2i(16, 16), "CHECKF": Vector2i(16, 16), "CHECKU": Vector2i(16, 16),
	"MAPBUTTONIMAGED": Vector2i(26, 20), "MAPBUTTONIMAGEU": Vector2i(26, 20),
	"PAPERCLOSED": Vector2i(13, 12), "PAPERCLOSEU": Vector2i(13, 12),
	"ADVISBTN.BMP": Vector2i(20, 16), "BOOKBTN.BMP": Vector2i(40, 32),
}
const HOURGLASS_IDS := [189, 190, 191, 192, 193, 194, 195, 196]
const PORTRAIT_IDS := [197, 198, 199, 200, 201, 202, 203, 204]
const PORTRAIT_SIZE := Vector2i(64, 82)
var error := ""
var controls: Dictionary = {}
var hourglass: Array[Image] = []
var portraits: Dictionary = {}


static func load_manifest(value: Variant, read_png: Callable, palette: Sc2Palette) -> CityUiGraphics:
	var graphics := CityUiGraphics.new()
	graphics._load(value, read_png, palette)
	return graphics


static func load_original(reference_root: String) -> CityUiGraphics:
	var graphics := CityUiGraphics.new()
	for id in CONTROL_SIZES:
		var image: Image
		if id.ends_with(".BMP"):
			var path := reference_root.path_join("BITMAPS/" + id)
			if FileAccess.file_exists(path):
				image = Image.load_from_file(path)
		else:
			var loaded := PeBitmapResource.load_named(reference_root.path_join("SIMCITY.EXE"), id)
			image = loaded.get("image")
		if image != null:
			graphics.controls[id] = image
	for id in HOURGLASS_IDS:
		var loaded := PeBitmapResource.load_numeric(reference_root.path_join("SIMCITY.EXE"), id)
		if loaded.ok:
			graphics.hourglass.append(loaded.image)
	for id in PORTRAIT_IDS:
		var loaded := PeBitmapResource.load_numeric(reference_root.path_join("SIMCITY.EXE"), id)
		if loaded.ok:
			graphics.portraits[id] = loaded.image
	return graphics


func _load(value: Variant, read_png: Callable, palette: Sc2Palette) -> void:
	if not value is Dictionary or value.is_empty():
		error = "city_ui must contain controls, hourglass or portraits"
		return
	for group in value:
		if group not in ["controls", "hourglass", "portraits"]:
			error = "Unknown city_ui field: %s" % group
			return
		var ids: Array = {"controls": CONTROL_SIZES.keys(), "hourglass": HOURGLASS_IDS, "portraits": PORTRAIT_IDS}[group]
		var records: Variant = value[group]
		if not records is Array or records.size() != ids.size():
			error = "city_ui.%s requires %d records in resource order" % [group, ids.size()]
			return
		for i in ids.size():
			var record: Variant = records[i]
			if not record is Dictionary or not _matches_id(record.get("id"), ids[i]):
				error = "city_ui.%s record %d must have id %s" % [group, i, str(ids[i])]
				return
			var png: Dictionary = read_png.call(record.get("png"))
			if png.is_empty() or not png.get("ok", false):
				error = "Cannot read city_ui image %s" % str(ids[i])
				return
			var size := PORTRAIT_SIZE
			if group == "controls":
				size = CONTROL_SIZES[ids[i]]
			elif group == "hourglass":
				size = Vector2i(15 if i == 7 else 16, 30)
			if Vector2i(png.width, png.height) != size or png.pixels.has(-1) or png.palette.colors != palette.colors:
				error = "city_ui image %s must be opaque, %d by %d, with the pack palette" % [str(ids[i]), size.x, size.y]
				return
			var image: Image = Sc2SpriteArchive.entry_from_indices(0, size.x, size.y, png.pixels).create_image(palette).image
			if group == "controls":
				controls[ids[i]] = image
			elif group == "hourglass":
				hourglass.append(image)
			else:
				portraits[ids[i]] = image


static func _matches_id(value: Variant, expected: Variant) -> bool:
	if expected is String:
		return value is String and value == expected
	return (value is int or value is float) and value == expected
