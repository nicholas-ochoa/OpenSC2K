extends "res://tests/support/core_test_suite.gd"

## Rendering: sprite archives checks.

@warning_ignore_start("integer_division")

const Palette = preload("res://src/assets/sc2_palette.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const PeBitmap = preload("res://src/assets/pe_bitmap_resource.gd")
const TextUsa = preload("res://src/assets/text_usa_resource.gd")
const LibraryWindowLayout = preload("res://src/ui/city_windows/library_window_layout.gd")
const StaticImageTests = preload("res://tests/suites/core/rendering/static_image_tests.gd")
const StaticOverlayTests = preload("res://tests/suites/core/rendering/static_overlay_tests.gd")
const MovingVisualTests = preload("res://tests/suites/core/rendering/moving_visual_tests.gd")
const MapGeometryTests = preload("res://tests/suites/core/rendering/map_geometry_tests.gd")
const UndergroundFilterTests = preload("res://tests/suites/core/rendering/underground_filter_tests.gd")
const TrainMonsterVisualTests = preload("res://tests/suites/core/rendering/train_monster_visual_tests.gd")


func test_sprite_archives(reference_root: String) -> void:
	var toolbar := PeBitmap.load_numeric(reference_root.path_join("SIMCITY.EXE"), 2)
	_check(toolbar.ok, "Windows toolbar bitmap resource loads: %s" % toolbar.error)

	if toolbar.ok:
		_check(
			toolbar.image.get_size() == Vector2i(865, 23),
			"Windows toolbar bitmap resource has its confirmed size",
		)

	var scurk_executable := reference_root.path_join("WINSCURK.EXE")
	var scurk_bitmap_ids := PeBitmap.list_numeric_bitmap_ids(scurk_executable)
	_check(
		scurk_bitmap_ids.ok
		and scurk_bitmap_ids.ids.has(25000)
		and scurk_bitmap_ids.ids.has(25041),
		"Windows PE bitmap loader enumerates the complete SCURK texture range",
	)
	var scurk_foreground_texture := PeBitmap.load_numeric_indexed8(
		scurk_executable, 25039
	)
	var scurk_material_texture := PeBitmap.load_numeric_indexed8(
		scurk_executable, 25000
	)
	_check(
		scurk_foreground_texture.ok
		and scurk_foreground_texture.width == 8
		and scurk_foreground_texture.height == 8
		and scurk_foreground_texture.pixels.size() == 64
		and scurk_foreground_texture.pixels[0] == 0xff
		and scurk_foreground_texture.pixels[63] == 0xff
		and scurk_material_texture.ok
		and scurk_material_texture.pixels[0] == 0xff
		and scurk_material_texture.pixels[1] == 0xf5
		and scurk_material_texture.pixels[2] == 0x9b,
		"Windows PE bitmap loader preserves original SCURK texture indices",
	)
	var protest_bitmap := Image.load_from_file(
		reference_root.path_join("BITMAPS/403.BMP")
	)
	_check(
		protest_bitmap != null and not protest_bitmap.is_empty(),
		"Forest protest bitmap loads",
	)

	if protest_bitmap != null and not protest_bitmap.is_empty():
		_check(
			protest_bitmap.get_size() == Vector2i(155, 100),
			"Forest protest bitmap has its executable size",
		)

	_check(
		not PeBitmap.load_numeric(reference_root.path_join("SIMCITY.EXE"), 0xffff).ok,
		"Windows bitmap loader rejects a missing numeric resource",
	)
	var library_text := TextUsa.load_ids(
		reference_root.path_join("DATA/TEXT_USA.DAT"),
		reference_root.path_join("DATA/TEXT_USA.IDX"),
		PackedInt32Array([3000, 3001, 3002, 3003]),
	)
	_check(library_text.ok, "Indexed Library text loads: %s" % library_text.error)

	if library_text.ok:
		_check(library_text.strings.size() == 4, "Indexed Library text returns all four requested entries")

		for resource_id in range(3000, 3004):
			_check(not str(library_text.strings[resource_id]).is_empty(), "Library text entry %d is not empty" % resource_id)

	var library_rects := LibraryWindowLayout.rects(Vector2i(1280, 800))
	_check(library_rects.size() == 4, "Library presentation creates four windows")

	for rect in library_rects:
		_check(
			Rect2i(Vector2i.ZERO, Vector2i(1280, 800)).encloses(rect),
			"Library windows stay inside the viewport",
		)

	_check(
		not TextUsa.load_ids(
			reference_root.path_join("DATA/TEXT_USA.DAT"),
			reference_root.path_join("DATA/TEXT_USA.IDX"),
			PackedInt32Array([0x7fffffff]),
		).ok,
		"Indexed text loader rejects a missing resource ID",
	)
	var expected_counts := {
		"LARGE.DAT": 501,
		"SMALLMED.DAT": 904,
		"SPECIAL.DAT": 50,
	}

	for filename in expected_counts:
		var archive := SpriteArchive.load_path(reference_root.path_join("DATA").path_join(filename))
		_check(archive.is_valid(), "%s parses: %s" % [filename, archive.parse_error])

		if not archive.is_valid():
			continue

		_check(archive.entries.size() == expected_counts[filename], "%s entry count matches" % filename)

		for entry in archive.entries:
			var decoded := entry.decode_indices()
			_check(decoded.ok, "%s sprite %d decodes: %s" % [filename, entry.sprite_id, decoded.error])

	var palette := Palette.load_bmp(reference_root.path_join("BITMAPS/PAL_MSTR.BMP"))
	var large := SpriteArchive.load_path(reference_root.path_join("DATA/LARGE.DAT"))
	var small_medium_base := SpriteArchive.load_path(reference_root.path_join("DATA/SMALLMED.DAT"))
	var special := SpriteArchive.load_path(reference_root.path_join("DATA/SPECIAL.DAT"))
	var small_medium := SpriteArchive.combine([small_medium_base, special])
	_check(small_medium.is_valid(), "Small, medium, and special sprite archives combine")
	_check(small_medium.find_sprite(698) != null, "Special archive supplies medium hydro sprite 698")
	_check(
		IsometricPixelOperations.shadow_color(palette, palette.color(0x5f)).to_rgba32()
		== palette.color(0x64).to_rgba32(),
		"Aircraft shadow remaps palette index 0x5f to 0x64",
	)
	_check(
		IsometricPixelOperations.shadow_color(palette, palette.color(0x74)).to_rgba32()
		== palette.color(0x7e).to_rgba32(),
		"Aircraft shadow remaps the ground-color range to 0x7e",
	)
	_check(
		IsometricPixelOperations.shadow_color(palette, palette.color(0x73)).to_rgba32()
		== palette.color(0x73).to_rgba32(),
		"Aircraft shadow keeps colors outside its recovered ranges",
	)
	_check(
		IsometricRenderer.shadow_palette_index(0x5f) == 0x64
		and IsometricRenderer.shadow_palette_index(0x74) == 0x7e
		and IsometricRenderer.shadow_palette_index(0x73) == 0x73,
		"Indexed aircraft shadows use the recovered palette remap",
	)
	var sign_palette_indices := PackedInt32Array([0x9b, 0x9e, 0xa0, 0xa2, 0xa5, 0x6a])
	var sign_colors_ignore_shadow := true

	for palette_index in sign_palette_indices:
		if IsometricRenderer.shadow_palette_index(palette_index) != palette_index:
			sign_colors_ignore_shadow = false

	_check(
		sign_colors_ignore_shadow,
		"Aircraft shadows do not remap the recovered city-sign palette entries",
	)
	_check(
		palette.color(0x9b).to_rgba32() == Color("e3e3e3").to_rgba32()
		and palette.color(0x9e).to_rgba32() == Color("bbbbbb").to_rgba32()
		and palette.color(0xa0).to_rgba32() == Color("9f9f9f").to_rgba32()
		and palette.color(0xa2).to_rgba32() == Color("838383").to_rgba32()
		and palette.color(0xa5).to_rgba32() == Color("575757").to_rgba32(),
		"Recovered city-sign grays match their PAL_MSTR entries",
	)
	var terrain := large.find_sprite(1256)
	_check(terrain != null, "Large terrain sprite 1256 is present")

	if terrain != null:
		_check(terrain.width == 32 and terrain.height == 17, "Large terrain sprite is 32 by 17")
		var rendered := terrain.create_image(palette)
		_check(rendered.ok, "Large terrain sprite renders: %s" % rendered.error)

		if rendered.ok:
			_check(rendered.image.get_width() == 32, "Rendered terrain sprite width is 32")
			_check(rendered.image.get_height() == 17, "Rendered terrain sprite height is 17")

	var power_marker := large.find_sprite(1386)
	_check(
		power_marker != null and power_marker.width == 32 and power_marker.height == 16,
		"Large unpowered marker is the recovered 32 by 16 sprite",
	)
	var fire_frame := large.find_sprite(1396)
	_check(
		fire_frame != null and fire_frame.width == 32 and fire_frame.height == 24,
		"First large fire frame is the recovered 32 by 24 sprite",
	)
	var traffic_frame := large.find_sprite(1400)
	_check(
		traffic_frame != null and traffic_frame.width == 32 and traffic_frame.height == 17,
		"First large traffic frame is the recovered 32 by 17 sprite",
	)

	var starter_document := _load_fixture(reference_root.path_join("CITIES/STARTER.SC2"))
	var starter := CityModel.from_document(starter_document)
	var asset_errors := IsometricStaticVisuals.validate_assets(starter, large)
	_check(asset_errors.is_empty(), "Starter city has every required large sprite: %s" % asset_errors)
	var small_asset_errors := IsometricStaticVisuals.validate_assets(
		starter, small_medium, IsometricRenderer.VIEW_SMALL
	)
	_check(
		small_asset_errors.is_empty(),
		"Starter city has every required small sprite: %s" % small_asset_errors,
	)
	var medium_asset_errors := IsometricStaticVisuals.validate_assets(
		starter, small_medium, IsometricRenderer.VIEW_MEDIUM
	)
	_check(
		medium_asset_errors.is_empty(),
		"Starter city has every required medium sprite: %s" % medium_asset_errors,
	)
	StaticImageTests.new(context).run(small_medium)
	StaticOverlayTests.new(context).run(reference_root, large)
	# All archives decode above; representative city/view asset checks cover mapping.
	# Corpus parsing and byte-exact rebuilds belong to CityFilesTests.
	starter = MovingVisualTests.new(context).run(starter_document, starter, large)
	MapGeometryTests.new(context).run(reference_root, starter, large)
	UndergroundFilterTests.new(context).run(starter, large, small_medium)
	TrainMonsterVisualTests.new(context).run(starter, large, small_medium)
