class_name Sc2RuntimeExport
extends RefCounted
## export the interface graphics that the game uses. never retain either executable

var error := ""
var count := 0
var _root := ""
var _palette: Sc2Palette


func export_data(source: String, folder: String, manifest: Dictionary) -> void:
	_root = folder
	_palette = Sc2Palette.load_bmp(source.path_join("BITMAPS/PAL_MSTR.BMP"))
	var city_exe := source.path_join("SIMCITY.EXE")
	var scurk_exe := source.path_join("WINSCURK.EXE")
	var city_ui := {"portraits": [], "terrain": [], "notices": []}

	for id in CityUiGraphics.PORTRAIT_IDS:
		city_ui.portraits.append(_bitmap(city_exe, id, "city_ui"))

	city_ui.terrain.append(_bitmap(city_exe, 207, "city_ui"))

	for id in CityUiGraphics.NOTICE_IDS:
		city_ui.notices.append(_loose_bitmap(source.path_join("BITMAPS/%d.BMP" % id), id, "city_ui"))

	manifest.city_ui = city_ui
	var scurk := {"textures": [], "backgrounds": []}

	for i in ScurkGraphics.TEXTURE_IDS.size():
		var record := _bitmap(scurk_exe, ScurkGraphics.TEXTURE_IDS[i], "scurk")
		record.name = ScurkPixelCanvas.TEXTURE_NAMES[i]
		scurk.textures.append(record)

	for id in ScurkGraphics.BACKGROUND_IDS:
		scurk.backgrounds.append(_bitmap(scurk_exe, id, "scurk"))

	manifest.scurk = scurk
	manifest.desktop = {}

	for app in ["city", "scurk"]:
		var executable := city_exe if app == "city" else scurk_exe
		var desktop := {"icons": [], "cursors": []}

		for id in ([1] if app == "city" else [1, 3, 5, 7]):
			desktop.icons.append(_desktop(executable, id, app, false))

		var cursors: Array[int] = []

		if app == "city":
			for family in [1000, 2000, 3000]:
				for role in _cursor_roles(app):
					cursors.append(DesktopGraphics.cursor_id(app, family + role))
		else:
			cursors.assign([1, 2, 3, 4, 5, 6])

			for role in _cursor_roles(app):
				cursors.append(DesktopGraphics.cursor_id(app, 31000 + role))

		for id in cursors:
			desktop.cursors.append(_desktop(executable, id, app, true))

		manifest.desktop[app] = desktop


static func _cursor_roles(app: String) -> Array[int]:
	var roles: Array[int] = [10, 23] # panning and shift-query cursors

	if app == "city":
		for tool in ToolCatalog.all_tools():
			var role := DesktopCursorRules.city_tool(tool.group_index, tool.subtool_index)

			if role not in roles:
				roles.append(role)
	else:
		roles.append(9) # place an object

		for tool in ScurkPlacePrintControl.EDIT_TOOLS:
			var role := DesktopCursorRules.city_tool(tool.group, tool.subtool)

			if role not in roles:
				roles.append(role)

	roles.sort()
	return roles


func _bitmap(executable: String, id: int, group: String) -> Dictionary:
	var dib := PeBitmapResource.load_numeric_dib(executable, id)

	if not dib.ok:
		error = dib.error
		return {}

	var decoded := Sc2ImportBitmap.decode(dib.bytes)

	if decoded.ok and group == "scurk":
		decoded.palette = _palette

	return _image(decoded, id, group)


func _loose_bitmap(path: String, id: int, group: String) -> Dictionary:
	return _image(Sc2ImportBitmap.decode(FileAccess.get_file_as_bytes(path), true), id, group)


func _image(decoded: IndexedImageResult, id: int, group: String) -> Dictionary:
	if not decoded.ok:
		error = decoded.error
		return {}

	var path := "%s/%d.png" % [group, id]
	_png(path, decoded.width, decoded.height, decoded.pixels, decoded.palette)
	count += 1
	return {"id": id, "png": path}


func _desktop(executable: String, id: int, app: String, cursor: bool) -> Dictionary:
	var decoded := PeIconCursorResource.load_image(executable, id, cursor)

	if not decoded.ok:
		error = decoded.error
		return {}

	var path := "desktop/%s/%s-%d.png" % [app, "cursor" if cursor else "icon", id]
	var palette := Sc2Palette.new()
	palette.colors.assign(decoded.palette)

	while palette.colors.size() < 256:
		palette.colors.append(Color.BLACK)

	var pixels := decoded.pixels.duplicate()
	var record := {"id": id, "png": path}

	if cursor:
		var mask_palette := Sc2Palette.new()
		mask_palette.colors.resize(256)
		mask_palette.colors.fill(Color.BLACK)
		mask_palette.colors[1] = Color.WHITE
		var mask_path := path.get_basename() + "-and.png"
		_png(mask_path, decoded.width, decoded.height, PackedInt32Array(Array(decoded.and_mask)), mask_palette)
		record.and_png = mask_path
		record.hotspot = [decoded.hotspot.x, decoded.hotspot.y]
	else:
		if decoded.inverting_pixels > 0:
			error = "Application icon unexpectedly requires XOR compositing"
			return {}

		for i in pixels.size():
			if decoded.and_mask[i]:
				pixels[i] = -1

	_png(path, decoded.width, decoded.height, pixels, palette)
	count += 1
	return record


func _png(path: String, width: int, height: int, pixels: PackedInt32Array, palette: Sc2Palette) -> void:
	var encoded := IndexedPng.encode(width, height, pixels, palette)

	if not encoded.ok:
		error = encoded.error
		return

	_write(path, encoded.bytes)


func _write(relative: String, bytes: PackedByteArray) -> void:
	if error.is_empty():
		error = Sc2MediaImporter._write(_root.path_join(relative), bytes)
