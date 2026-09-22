extends "res://tests/support/core_test_suite.gd"

## Scurk: placement checks.

@warning_ignore_start("integer_division")

const Palette = preload("res://src/assets/sc2_palette.gd")
const IndexedBitmap = preload("res://src/assets/indexed_bmp.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const ScurkOutput = preload("res://src/assets/scurk_city_output.gd")
const ScurkPickCopy = preload("res://src/tools/scurk/scurk_pick_copy.gd")
const ScurkPlace = preload("res://src/tools/scurk/scurk_place_command.gd")
const ScurkHistory = preload("res://src/tools/scurk/scurk_edit_history.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const Random = preload("res://src/simulation/random/sim_random.gd")
const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
const Zones = preload("res://src/tools/city/zone_command.gd")
const Signs = preload("res://src/tools/city/sign_command.gd")
const Landscapes = preload("res://src/tools/landscape/landscape_command.gd")
const Buildings = preload("res://src/tools/city/building_command.gd")
const Networks = preload("res://src/tools/city/network_command.gd")
const Highways = preload("res://src/tools/city/highway_command.gd")
const Demolish = preload("res://src/tools/city/demolish_command.gd")
const TerrainTools = preload("res://src/tools/landscape/terrain_command.gd")


func test_scurk_place_command(reference_root: String) -> void:
	_check(
		ScurkOutput.page_grid(1).count == 2
		and ScurkOutput.page_grid(1).columns == 2
		and ScurkOutput.page_grid(2).count == 8
		and ScurkOutput.page_grid(2).columns == 4
		and ScurkOutput.page_grid(4).count == 28
		and ScurkOutput.page_grid(4).columns == 7
		and ScurkOutput.page_grid(3) == null,
		"SCURK printing uses the executable's 2, 8, and 28-page grids",
	)
	_check(
		ScurkPlace.placeable_large_ids(ScurkPickCopy.GROUP_ALL).size() == 500
		and ScurkPlace.is_placeable_tile(Tiles.ROAD_STRAIGHT_1)
		and ScurkPlace.is_placeable_tile(0x167)
		and not ScurkPlace.is_placeable_tile(500),
		"SCURK Place & Print exposes every sprite family, including networks and artwork",
	)
	_check(
		ScurkPlace.footprint(0x70, Vector2i(20, 20))
			== Rect2i(20, 20, 1, 1)
		and ScurkPlace.footprint(0xae, Vector2i(20, 20))
			== Rect2i(19, 19, 3, 3)
		and ScurkPlace.footprint(0xcf, Vector2i(20, 20))
			== Rect2i(19, 19, 4, 4),
		"SCURK Place & Print uses the native object base and anchor rules",
	)

	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"SCURK Place & Print fixture clears %s" % chunk_id,
		)

	_check(
		document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0))
		and document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)),
		"SCURK Place & Print fixture clears labels and microsimulations",
	)
	_check(
		document.set_misc_i32(Buildings.MISC_FUNDS, 0)
		and document.set_misc_u32(Buildings.MISC_TILE_COUNTS, CityState.TILE_COUNT)
		and document.set_misc_u32(ToolAvailability.MISC_GRANTED_REWARDS, 0)
		and document.set_misc_u32(Buildings.MISC_SUBWAY_COUNT, 0),
		"SCURK Place & Print fixture removes game placement privileges",
	)
	var city := CityModel.from_document(document)
	var process_random := Random.new(0x2345)
	var initial_random_state := process_random.state
	var coal := ScurkPlace.apply(
		city, 0xcf, Vector2i(20, 20), process_random
	)
	_check(
		coal.ok
		and coal.site == Rect2i(19, 19, 4, 4)
		and city.funds() == 0
		and city.building_id(19, 19) == 0xcf
		and city.building_id(22, 22) == 0xcf
		and city.zones[19 * 128 + 19] == 0x10
		and city.tile_flags[19 * 128 + 19] & 0xe0 == 0xe0,
		"SCURK places a locked four-tile object without funds or development gates",
	)
	_check(
		coal.overlay_id == 61
		and city.microsim(10).tile_id == 0xcf
		and city.microsim(10).stat_1 == 200
		and not city.label(61).is_empty()
		and document.misc_u32(Buildings.MISC_TILE_COUNTS) == 16368
		and document.misc_u32(Buildings.MISC_TILE_COUNTS + 0xcf * 4) == 16,
		"SCURK object placement writes compatible counts, labels, and XMIC data",
	)
	var edit_history := ScurkHistory.new()
	edit_history.record(coal, "Object Placement")
	_check(
		edit_history.undo(city, process_random).ok
		and city.building_id(19, 19) == 0
		and city.text_overlay_id(19, 19) == 0
		and city.microsim(10).tile_id == 0
		and process_random.state == initial_random_state
		and not edit_history.can_undo()
		and edit_history.can_redo()
		and coal.scurk_tool_name == "Object Placement",
		"SCURK edit history records and applies the exact Undo transaction",
	)
	_check(
		edit_history.redo(city, process_random).ok
		and city.building_id(22, 22) == 0xcf
		and city.microsim(10).stat_1 == 200
		and edit_history.can_undo()
		and not edit_history.can_redo()
		and edit_history.current_command() == coal,
		"SCURK edit history applies the exact Redo transaction",
	)
	_check(
		edit_history.undo(city, process_random).ok,
		"SCURK Place & Print fixture removes the coal plant",
	)

	var city_hall := ScurkPlace.apply(
		city, 0xd0, Vector2i(30, 30), process_random
	)
	_check(
		city_hall.ok
		and city.microsim(10).stat_1 == 0
		and city.microsim(10).stat_2 == city.current_year()
		and document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0,
		"SCURK City Hall uses its separate zero-population initializer and keeps rewards",
	)
	_check(
		ScurkPlace.undo(city, city_hall, process_random).ok,
		"SCURK Place & Print fixture removes the City Hall",
	)

	var variable_zone := ScurkPlace.apply(
		city, 0xc2, Vector2i(40, 40), process_random, 5
	)
	_check(
		variable_zone.ok
		and variable_zone.zone_id == 5
		and city.zones[39 * 128 + 39] & 0x0f == 5,
		"SCURK transitional objects use the selected zone without a zoning restriction",
	)
	_check(
		ScurkPlace.undo(city, variable_zone, process_random).ok,
		"SCURK Place & Print fixture removes the transitional object",
	)

	_check(
		city.set_building_id(50, 50, Tiles.ROAD_STRAIGHT_1),
		"SCURK protected-site fixture places a road",
	)
	var blocked_random_state := process_random.state
	var blocked := ScurkPlace.apply(
		city, 0x70, Vector2i(50, 50), process_random
	)
	_check(
		not blocked.ok
		and not blocked.error.is_empty()
		and city.building_id(50, 50) == 0x1d
		and process_random.state == blocked_random_state,
		"SCURK object placement keeps native road and random-state protection",
	)
	_check(
		city.set_building_id(50, 50, Tiles.EMPTY),
		"SCURK protected-site fixture removes the road",
	)

	_check(
		city.set_terrain_id(60, 60, 1)
		and city.set_tile_flag(60, 60, 0x04, true),
		"SCURK hydro fixture installs water terrain",
	)
	var hydro := ScurkPlace.apply(
		city, 0xc6, Vector2i(60, 60), process_random
	)
	_check(
		hydro.ok
		and city.building_id(60, 60) == 0xc6
		and city.tile_flags[60 * 128 + 60] & 0xe4 == 0xe4
		and city.microsim(5).tile_id == 0xc6
		and city.microsim(5).stat_1 == 1
		and city.microsim(5).stat_2 == 20,
		"SCURK hydro object requires water and updates its fixed XMIC record",
	)
	_check(
		ScurkPlace.undo(city, hydro, process_random).ok,
		"SCURK Place & Print fixture removes the hydro object",
	)
	var dry_hydro := ScurkPlace.apply(
		city, 0xc6, Vector2i(61, 60), process_random
	)
	_check(
		not dry_hydro.ok and not dry_hydro.error.is_empty(),
		"SCURK hydro object rejects clear land",
	)

	for y in range(70, 73):
		_check(
			city.set_tile_flag(70, y, 0x04, true),
			"SCURK marina fixture stores one shoreline water tile",
		)

	var marina := ScurkPlace.apply(
		city, 0xf8, Vector2i(71, 71), process_random
	)
	_check(
		marina.ok and marina.site == Rect2i(70, 70, 3, 3),
		"SCURK marina accepts a mixed three-by-three land and water site",
	)
	_check(
		ScurkPlace.undo(city, marina, process_random).ok,
		"SCURK Place & Print fixture removes the marina",
	)

	var free_zone := Zones.apply_rectangle(
		city,
		8,
		0,
		Vector2i(80, 80),
		Vector2i(81, 81),
		true,
		true,
		7
	)
	free_zone.scurk_place_history = true
	_check(
		free_zone.ok
		and free_zone.cost == 0
		and city.funds() == 0
		and city.zone_id(80, 80) == 7
		and city.zone_id(81, 81) == 7,
		"SCURK zones include the free military zone without city funds",
	)
	_check(
		ScurkPlace.undo(city, free_zone, process_random).ok
		and city.zone_id(80, 80) == 0,
		"SCURK free zoning uses the shared exact Undo history",
	)
	_check(
		ScurkPlace.redo(city, free_zone, process_random).ok
		and city.zone_id(81, 81) == 7
		and ScurkPlace.undo(city, free_zone, process_random).ok,
		"SCURK free zoning uses the shared exact Redo history",
	)

	var free_road := Networks.apply(
		city,
		6,
		0,
		Vector2i(90, 90),
		Vector2i(92, 90),
		Networks.BRIDGE_UNSELECTED,
		Networks.CONNECTION_UNSELECTED,
		true
	)
	free_road.scurk_place_history = true
	_check(
		free_road.ok
		and free_road.cost == 0
		and free_road.listed_cost == 30
		and city.funds() == 0
		and city.building_id(91, 90) == 0x1e,
		"SCURK builds a connected road without changing city funds",
	)
	_check(
		ScurkPlace.undo(city, free_road, process_random).ok
		and city.building_id(91, 90) == 0
		and ScurkPlace.redo(city, free_road, process_random).ok
		and city.building_id(91, 90) == 0x1e
		and ScurkPlace.undo(city, free_road, process_random).ok,
		"SCURK free networks use exact shared Undo and Redo",
	)

	var free_water := Landscapes.apply_path(
		city, 1, 1, [Vector2i(100, 100)], process_random, true
	)
	free_water.scurk_place_history = true
	_check(
		free_water.ok
		and free_water.cost == 0
		and free_water.listed_cost == 100
		and city.funds() == 0
		and city.is_water(100, 100),
		"SCURK places surface water without changing city funds",
	)
	_check(
		ScurkPlace.undo(city, free_water, process_random).ok
		and not city.is_water(100, 100),
		"SCURK free landscape changes use exact shared Undo",
	)

	var free_raise_before := city.land_altitude(104, 104)
	var free_raise := TerrainTools.apply_path(
		city,
		0,
		2,
		Vector2i(104, 104),
		[Vector2i(104, 104)],
		process_random,
		true
	)
	free_raise.scurk_place_history = true
	_check(
		free_raise.ok
		and free_raise.cost == 0
		and free_raise.listed_cost == 25
		and city.funds() == 0
		and city.land_altitude(104, 104) == free_raise_before + 1,
		"SCURK raises terrain without changing city funds",
	)
	var free_raise_undo := ScurkPlace.undo(city, free_raise, process_random)
	_check(
		free_raise_undo.ok
		and city.land_altitude(104, 104) == free_raise_before,
		"SCURK free terrain changes use exact shared Undo: ok=%s before=%s current=%s error=%s"
		% [
			free_raise_undo.ok,
			free_raise_before,
			city.land_altitude(104, 104),
			free_raise_undo.error,
		],
	)

	var placed_for_bulldozer := ScurkPlace.apply(
		city, 0x70, Vector2i(108, 108), process_random
	)
	_check(placed_for_bulldozer.ok, "SCURK Bulldozer fixture places an object")
	var bulldozer_random_state := process_random.state
	var free_bulldozer := Demolish.apply_path(
		city,
		0,
		0,
		[Vector2i(108, 108)],
		process_random,
		false,
		true
	)
	free_bulldozer.scurk_place_history = true
	_check(
		free_bulldozer.ok
		and free_bulldozer.cost == 0
		and city.funds() == 0
		and city.building_id(108, 108) == 0
		and city.zone_id(108, 108) == 1
		and free_bulldozer.effect_events.is_empty()
		and free_bulldozer.sound_events.is_empty()
		and process_random.state == bulldozer_random_state,
		"SCURK Bulldozer removes an object without rubble, zoning loss, cost, or effects",
	)
	_check(
		ScurkPlace.undo(city, free_bulldozer, process_random).ok
		and city.building_id(108, 108) == 0x70,
		"SCURK Bulldozer uses exact shared Undo",
	)
	_check(
		ScurkPlace.undo(city, placed_for_bulldozer, process_random).ok,
		"SCURK Bulldozer fixture removes its restored object",
	)

	var free_highway := Highways.apply(
		city,
		6,
		1,
		Vector2i(116, 116),
		Vector2i(118, 116),
		Highways.CONNECTION_UNSELECTED,
		Highways.BRIDGE_UNSELECTED,
		true
	)
	free_highway.scurk_place_history = true
	_check(
		free_highway.ok
		and free_highway.cost == 0
		and free_highway.listed_cost == 200
		and city.funds() == 0
		and city.building_id(116, 116) >= 0x49,
		"SCURK builds a highway without changing city funds",
	)
	_check(
		ScurkPlace.undo(city, free_highway, process_random).ok
		and city.building_id(116, 116) == 0,
		"SCURK free highways use exact shared Undo",
	)

	# Output options and file encoding do not need a full original-size city.
	var print_city := CityModel.from_document(EmptyCityTemplate.create(16))
	var output_palette := Palette.load_bmp(
		reference_root.path_join("BITMAPS/PAL_MSTR.BMP")
	)
	var output_sprites := SpriteArchive.load_path(
		reference_root.path_join("DATA/SMALLMED.DAT")
	)
	var output_options := ScurkOutput.Options.new()
	output_options.entire_city = false
	output_options.selected_pages = PackedByteArray([1, 0])
	var print_sign := Signs.set_sign(print_city, Vector2i(8, 8), "PRINT TEST")
	var output_with_sign := ScurkOutput.render(
		print_city,
		Palette.index_encoding(),
		output_sprites,
		IsometricRenderer.VIEW_SMALL,
		output_options
	)
	var no_sign_options := output_options.copy()
	no_sign_options.surface_visibility.signs = false
	var output_without_sign := ScurkOutput.render(
		print_city,
		Palette.index_encoding(),
		output_sprites,
		IsometricRenderer.VIEW_SMALL,
		no_sign_options
	)
	_check(
		print_sign.ok
		and output_with_sign.ok
		and output_without_sign.ok
		and hash(output_with_sign.image.get_data())
			!= hash(output_without_sign.image.get_data()),
		"SCURK printable city output includes signs only when their layer is enabled",
	)

	if print_sign.ok:
		Signs.undo(print_city, print_sign)

	var monochrome_options := output_options.copy()
	monochrome_options.color = false
	var monochrome_output := ScurkOutput.render(
		print_city,
		output_palette,
		output_sprites,
		IsometricRenderer.VIEW_SMALL,
		monochrome_options
	)
	var monochrome_sample: Color = (
		monochrome_output.image.get_pixelv(monochrome_output.image.get_size() / 2)
		if monochrome_output.ok
		else Color.RED
	)
	_check(
		monochrome_output.ok
		and is_equal_approx(monochrome_sample.r, monochrome_sample.g)
		and is_equal_approx(monochrome_sample.g, monochrome_sample.b),
		"SCURK printable city output supports black-and-white pages",
	)
	var city_bmp_path := ProjectSettings.globalize_path("user://test-scurk-place-print-city.BMP")
	var city_bmp := ScurkOutput.save_small_bmp(
		city_bmp_path,
		print_city,
		Palette.index_encoding(),
		output_palette,
		output_sprites,
		output_options
	)
	var decoded_city_bmp := IndexedBitmap.decode(
		FileAccess.get_file_as_bytes(city_bmp_path)
	)
	_check(
		city_bmp.ok
		and decoded_city_bmp.ok
		and decoded_city_bmp.width
			== IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_SMALL, 16).x
		and decoded_city_bmp.height
			== IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_SMALL, 16).y,
		"SCURK Place & Print exports the complete small city as an indexed BMP",
	)
	var city_pdf_path := ProjectSettings.globalize_path("user://test-scurk-place-print-city.PDF")
	var city_pdf := ScurkOutput.save_pdf(
		city_pdf_path, print_city, output_palette, output_sprites, output_options
	)
	var pdf_bytes := FileAccess.get_file_as_bytes(city_pdf_path)
	_check(
		city_pdf.ok
		and city_pdf.page_count == 1
		and city_pdf.available_page_count == 2
		and pdf_bytes.size() > 100
		and pdf_bytes.slice(0, 8).get_string_from_ascii() == "%PDF-1.4",
		"SCURK Place & Print writes selected city pages to a printable PDF",
	)

	if OS.get_environment("OPENSC2K_KEEP_TEST_OUTPUT") != "1":
		DirAccess.remove_absolute(city_bmp_path)
		DirAccess.remove_absolute(city_pdf_path)
