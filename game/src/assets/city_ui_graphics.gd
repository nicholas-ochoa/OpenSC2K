class_name CityUiGraphics
extends RefCounted


const CONTROL_SIZES: Dictionary[String, Vector2i] = {
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
const TERRAIN_SIZES := {139: Vector2i(65, 65), 207: Vector2i(544, 19), "TERRAIN.BMP": Vector2i(341, 19)}
const TERRAIN_ROLES := ["raise", "lower", "stretch", "level", "sea_raise", "sea_lower", "water", "stream", "tree", "forest", "center", "zoom_out", "zoom_in", "rotate_left", "rotate_right", "help", "hills", "water_amount", "trees_amount"]
const TERRAIN_LOOSE_ROLES := ["raise", "lower", "stretch", "level", "sea_raise", "sea_lower", "water", "stream", "tree", "forest", "zoom_out", "zoom_in", "rotate_left", "rotate_right", "center", "help", "hills", "water_amount", "trees_amount"]
const TERRAIN_WIDTHS := [19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 16, 13, 8]
const MEDIA_IDS := [261, 262, 263, 264, 265, 266, 267, 268, 269, 270, "WILL0D.BMP", "WILL0U.BMP", "WILL1D.BMP", "WILL1U.BMP", "WILL2D.BMP", "WILL2U.BMP", "WILL3D.BMP", "WILL3U.BMP", "WILL4D.BMP", "WILL4U.BMP"]
const NOTICE_IDS := [400, 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411]
const PRESENTATION_SIZES: Dictionary[String, Vector2i] = {"128.BMP": Vector2i(106, 53), "2000WIN.BMP": Vector2i(371, 331), "ABOUT.BMP": Vector2i(480, 299), "PRESNTS.BMP": Vector2i(238, 198), "TITLESCR.BMP": Vector2i(644, 484), "PAL_LOAD.BMP": Vector2i(101, 101), "PAL_MSTR.BMP": Vector2i(101, 101), "PAL_STTC.BMP": Vector2i(101, 101)}
var error := ""
var controls: Dictionary[String, Image] = {}
var hourglass: Array[Image] = []
var portraits: Dictionary[int, Image] = {}
# integer pe ids and string loose-file names share these two lookups
var terrain: Dictionary = {}
var media: Dictionary = {}
var notices: Dictionary[int, Image] = {}
var presentation: Dictionary[String, Image] = {}
var presentation_palettes: Dictionary[String, Sc2Palette] = {}
var check_sheet: Image
var check_system_colors := false


static func load_manifest(value: Variant, read_png: Callable, palette: Sc2Palette) -> CityUiGraphics:
	var graphics := CityUiGraphics.new()
	graphics._load(value, read_png, palette)

	return graphics


static func load_original(reference_root: String) -> CityUiGraphics:
	var graphics := CityUiGraphics.new()
	graphics.check_sheet = PeBitmapResource.load_named(reference_root.path_join("SIMCITY.EXE"), CheckControlGraphics.RESOURCE_ID).image
	graphics.check_system_colors = true

	for id in CONTROL_SIZES:
		var image: Image

		if id.ends_with(".BMP"):
			var path := reference_root.path_join("BITMAPS/" + id)

			if FileAccess.file_exists(path):
				image = Image.load_from_file(path)
		else:
			var loaded := PeBitmapResource.load_named(reference_root.path_join("SIMCITY.EXE"), id)
			image = loaded.image

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

	for id in TERRAIN_SIZES:
		var image := _original_image(reference_root, id)

		if image != null:
			graphics.terrain[id] = image

	for id in MEDIA_IDS:
		var image := _original_image(reference_root, id)

		if image != null:
			graphics.media[id] = image

	for id in NOTICE_IDS:
		var image := _original_image(reference_root, "%d.BMP" % id)

		if image != null:
			graphics.notices[id] = image

	for id in PRESENTATION_SIZES:
		var image := _original_image(reference_root, id)

		if image != null:
			graphics.presentation[id] = image
			graphics.presentation_palettes[id] = Sc2Palette.load_bmp(reference_root.path_join("BITMAPS/" + id))

	return graphics


static func _original_image(reference_root: String, id: Variant) -> Image:
	if id is String:
		var path := reference_root.path_join("BITMAPS/" + id)

		return Image.load_from_file(path) if FileAccess.file_exists(path) else null

	return PeBitmapResource.load_numeric(reference_root.path_join("SIMCITY.EXE"), id).image


func _load(value: Variant, read_png: Callable, palette: Sc2Palette) -> void:
	if not value is Dictionary or value.is_empty():
		error = "city_ui must contain controls, hourglass, portraits, terrain, media, notices, presentation or checks"

		return

	for group in value:
		if group not in ["controls", "hourglass", "portraits", "terrain", "media", "notices", "presentation", "checks"]:
			error = "Unknown city_ui field: %s" % group

			return

		var ids: Array = {"controls": CONTROL_SIZES.keys(), "hourglass": HOURGLASS_IDS, "portraits": PORTRAIT_IDS, "terrain": TERRAIN_SIZES.keys(), "media": MEDIA_IDS, "notices": NOTICE_IDS, "presentation": PRESENTATION_SIZES.keys(), "checks": [CheckControlGraphics.RESOURCE_ID]}[group]
		var records: Variant = value[group]

		if not records is Array or records.size() != ids.size():
			error = "city_ui.%s requires %d records in resource order" % [group, ids.size()]

			return

		for i in ids.size():
			var record: Variant = records[i]

			if not record is Dictionary or not _matches_id(record.get("id"), ids[i]):
				error = "city_ui.%s record %d must have id %s" % [group, i, str(ids[i])]

				return

			var png: IndexedImageResult = read_png.call(record.get("png"))

			if png == null or not png.ok:
				error = "Cannot read city_ui image %s" % str(ids[i])

				return

			var size := PORTRAIT_SIZE

			if group == "checks":
				size = CheckControlGraphics.SHEET_SIZE

			if group == "controls":
				size = CONTROL_SIZES[ids[i]]
			elif group == "hourglass":
				size = Vector2i(15 if i == 7 else 16, 30)
			elif group == "terrain":
				size = TERRAIN_SIZES[ids[i]]
			elif group == "media":
				size = media_size(ids[i])
			elif group == "notices":
				size = Vector2i(154 if ids[i] == 411 else 155, 100)
			elif group == "presentation":
				size = PRESENTATION_SIZES[ids[i]]

			if Vector2i(png.width, png.height) != size or png.pixels.has(-1):
				error = "city_ui image %s must be opaque and %d by %d" % [str(ids[i]), size.x, size.y]

				return

			if group not in ["notices", "presentation"] and png.palette.colors != palette.colors:
				error = "city_ui image %s must use the pack palette" % str(ids[i])

				return

			var image: Image = Sc2SpriteArchive.entry_from_indices(0, size.x, size.y, png.pixels).create_image(png.palette).image

			if group == "checks":
				check_sheet = image
			elif group == "controls":
				controls[ids[i]] = image
			elif group == "hourglass":
				hourglass.append(image)
			elif group == "portraits":
				portraits[ids[i]] = image
			elif group == "terrain":
				terrain[ids[i]] = image
			elif group == "notices":
				notices[ids[i]] = image
			elif group == "presentation":
				presentation[ids[i]] = image
				presentation_palettes[ids[i]] = png.palette
			else:
				media[ids[i]] = image


static func _matches_id(value: Variant, expected: Variant) -> bool:
	if expected is String:
		return value is String and value == expected

	return (value is int or value is float) and value == expected


static func media_size(id: Variant) -> Vector2i:
	var wide := _matches_id(id, 261) or _matches_id(id, 262) or _matches_id(id, "WILL0D.BMP") or _matches_id(id, "WILL0U.BMP")

	return Vector2i(140 if wide else 70, 70)


static func terrain_region(index: int) -> Rect2i:
	assert(index >= 0 and index < TERRAIN_ROLES.size())
	var x := 0

	for i in index:
		x += TERRAIN_WIDTHS[i]

	var height: int = [7, 7, 10][index - 16] if index >= 16 else 19

	return Rect2i(x, 0, TERRAIN_WIDTHS[index], height)


func terrain_icon(role: String, loose := false) -> Image:
	var id: Variant = "TERRAIN.BMP" if loose else 207
	var index := (TERRAIN_LOOSE_ROLES if loose else TERRAIN_ROLES).find(role)

	if not terrain.has(id) or index < 0:
		return null

	return terrain[id].get_region(terrain_region(index))


func media_image(index: int, pressed: bool) -> Image:
	assert(index >= 0 and index < 5)

	return media.get(262 + index * 2 - int(pressed))
