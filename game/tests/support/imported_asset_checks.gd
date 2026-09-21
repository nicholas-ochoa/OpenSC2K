extends RefCounted
## compare the imported display data with the original decoder output


static func check(source: String, pack: String, assets: OriginalGameAssets) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pack.path_join("pack.json")))
	assert(not manifest.has("original_data") and manifest.runtime_data == "runtime")
	assert(not DirAccess.dir_exists_absolute(pack.path_join("original")))
	var files := PackedStringArray()
	OriginalCityImporter._collect(pack, "", "exe", files)
	assert(files.is_empty())
	assert(not FileAccess.file_exists(pack.path_join("runtime/unused.txt")))
	var expected := OriginalGameAssets.load_root(source)
	assert(assets.newspaper_data.grammar == expected.newspaper_data.grammar)
	assert(assets.newspaper_data.bases == expected.newspaper_data.bases)
	assert(assets.newspaper_data.counts == expected.newspaper_data.counts)
	assert(assets.newspaper_data.offsets == expected.newspaper_data.offsets)
	assert(assets.library_texts == expected.library_texts)
	assert(assets.original_credits == expected.original_credits)
	assert(FileAccess.get_sha256(pack.path_join("runtime/DEFAULT.SC2")) == FileAccess.get_sha256(source.path_join("DEFAULT.SC2")))
	assert(assets.city_ui_graphics.controls.is_empty() and assets.city_ui_graphics.hourglass.is_empty())
	assert(assets.city_ui_graphics.presentation.is_empty() and assets.city_ui_graphics.media.is_empty())

	for id in assets.city_ui_graphics.portraits:
		_same_image(assets.city_ui_graphics.portraits[id], expected.city_ui_graphics.portraits[id])

	for id in assets.city_ui_graphics.terrain:
		_same_image(assets.city_ui_graphics.terrain[id], expected.city_ui_graphics.terrain[id])

	for id in assets.city_ui_graphics.notices:
		_same_image(assets.city_ui_graphics.notices[id], expected.city_ui_graphics.notices[id])

	for app in ["city", "scurk"]:
		for id in assets.desktop_graphics.icons[app]:
			_same_image(assets.desktop_graphics.icons[app][id], expected.desktop_graphics.icons[app][id])

		for id in assets.desktop_graphics.cursors[app]:
			var actual: DesktopGraphics.Cursor = assets.desktop_graphics.cursors[app][id]
			var original: DesktopGraphics.Cursor = expected.desktop_graphics.cursors[app][id]
			assert(actual.hotspot == original.hotspot)
			assert(actual.masked.pixels == original.masked.pixels)
			assert(actual.masked.and_mask == original.masked.and_mask)
			assert(actual.masked.inverting_pixels == original.masked.inverting_pixels)

			for background_color in [Color.BLACK, Color.WHITE, Color(0.2, 0.4, 0.6)]:
				var background := Image.create(32, 32, false, Image.FORMAT_RGBA8)
				background.fill(background_color)
				_same_image(DesktopGraphics.render_cursor(actual, background), DesktopGraphics.render_cursor(original, background))

		for role in Sc2RuntimeExport._cursor_roles(app):
			for family in ([1000, 2000, 3000] if app == "city" else [31000]):
				assert(assets.desktop_graphics.cursor(app, family + role) != null)

	assert(assets.desktop_graphics.icons.city.size() == 1 and assets.desktop_graphics.icons.scurk.size() == 4)
	assert(assets.desktop_graphics.cursors.city.size() == Sc2RuntimeExport._cursor_roles("city").size() * 3)
	assert(assets.desktop_graphics.cursors.scurk.size() == Sc2RuntimeExport._cursor_roles("scurk").size() + 6)
	var textures := PeBitmapResource.load_numeric_indexed8_many(source.path_join("WINSCURK.EXE"), ScurkGraphics.TEXTURE_IDS)
	assert(textures.ok)

	for i in ScurkGraphics.TEXTURE_IDS.size():
		assert(assets.scurk_graphics.patterns[i] == textures.entries[i].pixels)


static func _same_image(actual: Image, expected: Image) -> void:
	assert(actual != null and expected != null)
	var a: Image = actual.duplicate()
	var b: Image = expected.duplicate()
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	assert(a.get_size() == b.get_size())

	for y in a.get_height():
		for x in a.get_width():
			var actual_color := a.get_pixel(x, y)
			var expected_color := b.get_pixel(x, y)
			assert(actual_color.a == expected_color.a)

			if actual_color.a != 0:
				assert(actual_color == expected_color)


static func check_invalid(pack: String) -> void:
	var loaded := GraphicsPack.load_root(pack)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pack.path_join("pack.json")))
	var cursor: Dictionary = manifest.desktop.city.cursors[0]

	for change in ["duplicate", "fractional", "hotspot", "mask_path", "mask_size", "mask_bits"]:
		var record := cursor.duplicate(true)
		var records := [record]
		var read_png: Callable = loaded._read_png

		match change:
			"duplicate":
				records.append(record.duplicate())
			"fractional":
				record.id += 0.5
			"hotspot":
				record.hotspot = [32, 0]
			"mask_path":
				record.and_png = "../outside.png"
			"mask_size", "mask_bits":
				var invalid := IndexedPng.load_path(pack.path_join(record.and_png))

				if change == "mask_size":
					invalid.width = 16
				else:
					invalid.pixels[0] = 2

				read_png = func(path): return invalid if path == record.and_png else loaded._read_png(path)

		var rejected := DesktopGraphics.load_manifest({"city": {"cursors": records}}, read_png, loaded.palette)
		assert(not rejected.error.is_empty(), change)
		loaded.error = ""

	for id in [197.5, 999]:
		var record: Dictionary = manifest.city_ui.portraits[0].duplicate()
		record.id = id
		var rejected := CityUiGraphics.load_manifest({"portraits": [record]}, loaded._read_png, loaded.palette)
		assert(not rejected.error.is_empty())

	var portrait: Dictionary = manifest.city_ui.portraits[0]
	assert(not CityUiGraphics.load_manifest({"portraits": [portrait, portrait]}, loaded._read_png, loaded.palette).error.is_empty())
