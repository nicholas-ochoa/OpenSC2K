class_name DesktopGraphics
extends RefCounted
# optional folder-pack icons and cursors for both original applications

const CITY_SYSTEM_GROUPS := {30977: 11, 30979: 15, 30980: 12, 30981: 21, 30982: 14, 30983: 19, 30984: 17, 30985: 18, 30986: 20, 30987: 16, 30988: 13}
const ICON_GROUPS := {"city": {2: [1, 2], 3: [9, 10], 77: [7, 8], 181: [3, 4], 182: [5, 6]}, "scurk": {1: [3, 4], 2: [1, 2], 3: [5, 6], 4: [7, 8]}}
var error := ""
var icons := {"city": {}, "scurk": {}}
var cursors := {"city": {}, "scurk": {}}


static func load_manifest(value: Variant, read_png: Callable, palette: Sc2Palette) -> DesktopGraphics:
	var graphics := DesktopGraphics.new()
	graphics._load(value, read_png, palette)
	return graphics


static func load_original(reference_root: String) -> DesktopGraphics:
	var graphics := DesktopGraphics.new()
	for app in ["city", "scurk"]:
		var directory := PeBitmapResource._load_resource_directory(reference_root.path_join("SIMCITY.EXE" if app == "city" else "WINSCURK.EXE"))
		if not directory.ok:
			graphics.error = directory.error
			return graphics
		for kind in ["icons", "cursors"]:
			for id in resource_ids(app, kind):
				var resource := PeIconCursorResource.resource_from_directory(directory, 3 if kind == "icons" else 1, id)
				var decoded := PeIconCursorResource.decode_image(resource.bytes, kind == "cursors") if resource.ok else resource
				if not decoded.ok:
					graphics.error = decoded.error
					return graphics
				var image := PeIconCursorResource.transparent_image(decoded)
				if kind == "icons":
					if not image.ok:
						graphics.error = image.error
						return graphics
					graphics.icons[app][id] = image.image
				else:
					graphics.cursors[app][id] = {"image": image.get("image"), "hotspot": decoded.hotspot, "masked": decoded}
	return graphics


static func resource_ids(app: String, kind: String) -> Array:
	if kind == "icons":
		return range(1, 11 if app == "city" else 9)
	return range(11, 112) if app == "city" else range(1, 35)


static func native_size(app: String, kind: String, id: int) -> Vector2i:
	if kind == "cursors":
		return Vector2i(32, 32)
	var small := id % 2 == 0
	if app == "city" and id in [9, 10]:
		small = id == 9
	return Vector2i.ONE * (16 if small else 32)


static func cursor_id(app: String, group: int) -> int:
	if app == "city":
		if CITY_SYSTEM_GROUPS.has(group):
			return CITY_SYSTEM_GROUPS[group]
		if group / 1000 in [1, 2, 3] and group % 1000 < 30:
			return 22 + (group / 1000 - 1) * 30 + group % 1000
	elif app == "scurk":
		if group >= 30000 and group <= 30005:
			return group - 29999
		if group >= 31002 and group <= 31029:
			return group - 30995
	return -1


func cursor(app: String, group: int) -> Dictionary:
	return cursors.get(app, {}).get(cursor_id(app, group), {})


func icon(app: String, group: int, width: int) -> Image:
	for id in ICON_GROUPS.get(app, {}).get(group, []):
		if native_size(app, "icons", id).x == width:
			return icons[app].get(id)
	return null


static func render_cursor(record: Dictionary, background: Image) -> Image:
	if not record.get("masked", {}).is_empty():
		return PeIconCursorResource.composite(record.masked, background)
	var result := background.duplicate()
	var image: Image = record.image
	result.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	return result


func _load(value: Variant, read_png: Callable, palette: Sc2Palette) -> void:
	if not value is Dictionary or value.is_empty():
		error = "desktop must contain city or scurk graphics"
		return
	for app in value:
		if app not in ["city", "scurk"] or not value[app] is Dictionary or value[app].is_empty():
			error = "Invalid desktop application group"
			return
		for kind in value[app]:
			if kind not in ["icons", "cursors"]:
				error = "Unknown desktop image kind"
				return
			var ids := resource_ids(app, kind)
			var records: Variant = value[app][kind]
			if not records is Array or records.size() != ids.size():
				error = "desktop.%s.%s requires %d records in resource order" % [app, kind, ids.size()]
				return
			for i in ids.size():
				var record: Variant = records[i]
				if not record is Dictionary or not (record.get("id") is int or record.get("id") is float) or record.id != ids[i]:
					error = "Desktop image ID or record order is invalid"
					return
				var hotspot := Vector2i.ZERO
				if kind == "cursors":
					var coordinates: Variant = record.get("hotspot")
					if not coordinates is Array or coordinates.size() != 2:
						error = "Cursor hotspot requires two integer coordinates"
						return
					for coordinate in coordinates:
						if not (coordinate is int or coordinate is float) or coordinate != int(coordinate) or coordinate < 0 or coordinate >= 32:
							error = "Cursor hotspot must be inside its 32 by 32 image"
							return
					hotspot = Vector2i(int(coordinates[0]), int(coordinates[1]))
				var png: Dictionary = read_png.call(record.get("png"))
				if png.is_empty() or not png.get("ok", false):
					error = "Cannot load desktop indexed PNG"
					return
				var size := native_size(app, kind, ids[i])
				if Vector2i(png.width, png.height) != size or png.palette.colors != palette.colors:
					error = "Desktop PNG must use its native dimensions and the pack palette"
					return
				var image: Image = Sc2SpriteArchive.entry_from_indices(0, size.x, size.y, png.pixels).create_image(png.palette).image
				if kind == "icons":
					icons[app][ids[i]] = image
				else:
					cursors[app][ids[i]] = {"image": image, "hotspot": hotspot, "masked": {}}
