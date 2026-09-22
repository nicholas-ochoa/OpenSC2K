extends "res://tests/support/core_test_suite.gd"

## Rendering: palette minimap checks.

@warning_ignore_start("integer_division")

const Palette = preload("res://src/assets/sc2_palette.gd")
const Minimap = preload("res://src/view/city_minimap.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const CityMapWindow = preload("res://src/view/city_map_window_control.gd")


func test_view_configurations() -> void:
	# Native size table from IsometricGeometry before 4a089e29.
	var expected_rows: Array[Array] = [
		[IsometricRenderer.VIEW_SMALL, 4, 8, 5, 4, 2, 3, 128, 8, 0],
		[IsometricRenderer.VIEW_MEDIUM, 2, 16, 9, 8, 4, 6, 256, 16, 500],
		[IsometricRenderer.VIEW_LARGE, 1, 32, 17, 16, 8, 12, 512, 32, 1000],
	]

	for expected in expected_rows:
		var view_size: int = expected[0]
		var shared := CityViewConfigurations.for_size(view_size)
		_check(shared != null, "View size %d has a shared configuration" % view_size)

		if shared == null:
			continue

		_check(is_same(shared, CityViewConfigurations.for_size(view_size)),
			"View size %d reuses the same configuration instance" % view_size)
		_check(_view_configuration_values(shared) == expected,
			"View size %d preserves all ten native geometry values" % view_size)
		var variant := shared.with_top_margin(73)
		var expected_variant: Array = expected.duplicate()
		expected_variant[7] = 73
		_check(not is_same(shared, variant),
			"View size %d derives a separate configuration instance" % view_size)
		_check(_view_configuration_values(variant) == expected_variant,
			"View size %d changes only the derived top margin" % view_size)
		_check(is_same(shared, CityViewConfigurations.for_size(view_size))
			and _view_configuration_values(shared) == expected,
			"View size %d leaves the shared configuration untouched" % view_size)

	for view_size in [-1, IsometricRenderer.VIEW_LARGE + 1]:
		_check(CityViewConfigurations.for_size(view_size) == null,
			"Out-of-range view size %d has no configuration" % view_size)


func test_palette_and_minimap(reference_root: String) -> void:
	var loaded_palette := Palette.load_bmp(reference_root.path_join("BITMAPS/PAL_MSTR.BMP"))
	_check(loaded_palette.is_valid(), "Master Windows palette loads")

	if not loaded_palette.is_valid():
		return

	var encoded := Palette.index_encoding()
	_check(
		encoded.is_valid()
		and encoded.color(0xab).to_rgba32() == Color8(0xab, 0xab, 0xab).to_rgba32(),
		"Index palette preserves each sprite palette index",
	)
	var first_cycle := loaded_palette.animation_index_map(1)
	_check(
		first_cycle[0xab] == 0xac
		and first_cycle[0xb2] == 0xab
		and first_cycle[0xc8] == 0xcf
		and first_cycle[0xd0] == 0xd3,
		"Fast palette cycle follows the recovered forward and reverse groups",
	)
	var full_fast_cycle := loaded_palette.animation_index_map(8)
	_check(
		full_fast_cycle[0xab] == 0xab
		and full_fast_cycle[0xc3] == 0xc3
		and full_fast_cycle[0xd4] == 0xd4,
		"Fast palette groups return after eight base ticks",
	)
	_check(
		full_fast_cycle[0xe0] == 0xe1
		and full_fast_cycle[0xe1] == 0xe0
		and full_fast_cycle[0xee] == 0xee
		and full_fast_cycle[0xef] == 0xe0,
		"Slow palette cycle follows the recovered 16-entry table",
	)
	var second_slow_cycle := loaded_palette.animation_index_map(16)
	_check(
		second_slow_cycle[0xe0] == 0xe0
		and second_slow_cycle[0xe1] == 0xe1
		and second_slow_cycle[0xef] == 0xe1,
		"Slow palette buffer retains the executable's final-entry behavior",
	)
	var scurk_before_fast := loaded_palette.scurk_animation_index_map(5)
	var scurk_first_fast := loaded_palette.scurk_animation_index_map(6)
	var scurk_second_fast := loaded_palette.scurk_animation_index_map(11)
	_check(
		scurk_before_fast[0xab] == 0xab
		and scurk_first_fast[0xab] == 0xac
		and scurk_second_fast[0xab] == 0xad,
		"SCURK fast palette counter steps first at tick six and then every five ticks",
	)
	var scurk_before_slow := loaded_palette.scurk_animation_index_map(30)
	var scurk_first_slow := loaded_palette.scurk_animation_index_map(31)
	var scurk_second_slow := loaded_palette.scurk_animation_index_map(61)
	_check(
		scurk_before_slow[0xe0] == 0xe0
		and scurk_first_slow[0xe0] == 0xe1
		and scurk_second_slow[0xe0] == 0xe0,
		"SCURK slow palette counter steps first at tick 31 and then every 30 ticks",
	)
	var animation_image := loaded_palette.animation_image(1)
	_check(
		animation_image.get_size() == Vector2i(256, 1)
		and animation_image.get_pixel(0xab, 0).to_rgba32()
		== loaded_palette.color(0xac).to_rgba32(),
		"Animated palette image contains the cycled master colors",
	)
	_check(
		Palette.index_encoding().is_index_encoding,
		"The synthetic palette identifies its cache-safe index encoding",
	)

	var document := _load_fixture(reference_root.path_join("CITIES/STARTER.SC2"))
	var loaded_city := CityModel.from_document(document)
	_check(loaded_city.is_valid(), "Starter city loads for minimap test")

	if not loaded_city.is_valid():
		return

	for mode in ["structures", "power", "water", "traffic"]:
		var image := Minimap.create_image(loaded_city, loaded_palette, mode)
		_check(image.get_width() == 128, "%s minimap width is 128" % mode)
		_check(image.get_height() == 128, "%s minimap height is 128" % mode)

	var recovered_modes: Array[String] = []

	for group in CityMapWindow.TAB_MODES:
		for mode in group:
			recovered_modes.append(str(mode))

	_check(
		recovered_modes == Array(Minimap.MODES, TYPE_STRING, "", null),
		"City Map exposes all 18 modes in the recovered nine-tab order",
	)

	var point := Vector2i(0, 0)
	_check(loaded_city.set_building_id(point.x, point.y, Tiles.EMPTY), "City Map fixture clears a tile")
	_check(loaded_city.set_zone_id(point.x, point.y, 0), "City Map fixture clears a zone")
	_check(loaded_city.set_underground_id(point.x, point.y, UnderTiles.EMPTY), "City Map fixture clears underground")
	_check(loaded_city.set_land_altitude(point.x, point.y, 0), "City Map fixture clears altitude")

	for mask in [0x04, 0x10, 0x20, 0x40, 0x80]:
		_check(
			loaded_city.set_tile_flag(point.x, point.y, mask, false),
			"City Map fixture clears tile flag %02x" % mask,
		)

	_check(
		Minimap.color_index(loaded_city, point.x, point.y, "structures") == 0x80,
		"City Map uses the recovered level-zero ground color",
	)
	_check(loaded_city.set_building_id(point.x, point.y, Tiles.RUBBLE_1), "City Map fixture sets trees")
	_check(
		Minimap.color_index(loaded_city, point.x, point.y, "structures") == 0x35,
		"City Map uses the recovered tree color",
	)
	_check(loaded_city.set_building_id(point.x, point.y, Tiles.EMPTY), "City Map fixture clears trees")
	_check(loaded_city.set_tile_flag(point.x, point.y, 0x04, true), "City Map fixture sets water")
	_check(
		Minimap.color_index(loaded_city, point.x, point.y, "structures") == 0x62,
		"City Map uses the recovered water color",
	)
	_check(loaded_city.set_tile_flag(point.x, point.y, 0x04, false), "City Map fixture clears water")

	for zone_test in [[1, 0x3b], [3, 0x5c], [5, 0x32], [7, 0x00]]:
		_check(loaded_city.set_zone_id(point.x, point.y, zone_test[0]), "City Map fixture sets zone")
		_check(
			Minimap.color_index(loaded_city, point.x, point.y, "zones") == zone_test[1],
			"City Map uses the recovered zone %d color" % zone_test[0],
		)

	_check(loaded_city.set_zone_id(point.x, point.y, 0), "City Map fixture clears final zone")

	for network_test in [
		["roads", Tiles.ROAD_STRAIGHT_1], ["roads", Tiles.SUSPENSION_BRIDGE_5], ["rail", Tiles.RAIL_STRAIGHT_1],
		["rail", Tiles.RAIL_BRIDGE], ["traffic", Tiles.RAIL_STRAIGHT_1], ["power", Tiles.ROAD_POWER_CROSSING_1],
	]:
		_check(
			loaded_city.set_building_id(point.x, point.y, network_test[1]),
			"City Map fixture sets a network tile",
		)
		_check(
			Minimap.color_index(
				loaded_city, point.x, point.y, network_test[0]
			) == 0xff,
			"City Map highlights %s tile %02x" % network_test,
		)

	_check(loaded_city.set_building_id(point.x, point.y, Tiles.EMPTY), "City Map fixture clears networks")
	_check(loaded_city.set_tile_flag(point.x, point.y, 0x40, true), "City Map fixture sets power")
	_check(
		Minimap.color_index(loaded_city, point.x, point.y, "power") == 0x32,
		"City Map uses the recovered powered color",
	)
	_check(loaded_city.set_tile_flag(point.x, point.y, 0x40, false), "City Map fixture clears power")
	_check(loaded_city.set_tile_flag(point.x, point.y, 0x80, true), "City Map fixture sets powerable")
	_check(
		Minimap.color_index(loaded_city, point.x, point.y, "power") == 0x1d,
		"City Map uses the recovered unpowered color",
	)
	_check(loaded_city.set_tile_flag(point.x, point.y, 0x80, false), "City Map fixture clears powerable")
	_check(loaded_city.set_underground_id(point.x, point.y, UnderTiles.PIPE_LR), "City Map fixture sets pipe")
	_check(
		Minimap.color_index(loaded_city, point.x, point.y, "water") == 0xff,
		"City Map highlights the recovered pipe range",
	)
	_check(loaded_city.set_underground_id(point.x, point.y, UnderTiles.EMPTY), "City Map fixture clears pipe")

	for gradient_test in [
		["XTRF", "traffic", 64, 0xf0, 0xaa],
		["XPOP", "density", 32, 0x80, 0xa3],
		["XCRM", "crime", 64, 0x30, 0x9e],
		["XPLC", "police_power", 32, 0x40, 0x9f],
		["XPLT", "pollution", 64, 0x50, 0xa0],
		["XVAL", "land_value", 64, 0x60, 0xa1],
		["XFIR", "fire_power", 32, 0x70, 0xa2],
	]:
		var chunk = loaded_city.document.find_chunk(gradient_test[0])
		var values: PackedByteArray = chunk.decoded_payload.duplicate()
		values[0] = gradient_test[3]
		_check(chunk.set_decoded_payload(values), "City Map fixture sets %s" % gradient_test[0])
		_check(
			Minimap.color_index(
				loaded_city, point.x, point.y, gradient_test[1]
			) == gradient_test[4],
			"City Map expands %s with the recovered gradient" % gradient_test[0],
		)

	var growth_chunk = loaded_city.document.find_chunk("XROG")
	var growth_values: PackedByteArray = growth_chunk.decoded_payload.duplicate()

	for growth_test in [[0x7c, 0x1d], [0x80, 0x80], [0x83, 0x43]]:
		growth_values[0] = growth_test[0]
		_check(growth_chunk.set_decoded_payload(growth_values), "City Map fixture sets growth")
		_check(
			Minimap.color_index(loaded_city, point.x, point.y, "growth") == growth_test[1],
			"City Map uses the recovered growth threshold %02x" % growth_test[0],
		)

	for facility_test in [
		["police_stations", Tiles.POLICE_STATION], ["fire_stations", Tiles.FIRE_STATION],
		["schools", Tiles.SCHOOL], ["colleges", Tiles.COLLEGE],
	]:
		_check(loaded_city.set_building_id(point.x, point.y, facility_test[1]), "City Map fixture sets facility")
		_check(
			Minimap.color_index(
				loaded_city, point.x, point.y, facility_test[0]
			) == 0xff,
			"City Map highlights %s" % facility_test[0],
		)


func _view_configuration_values(configuration: CityViewConfiguration) -> Array[int]:
	return [configuration.view_size, configuration.divisor,
		configuration.tile_width, configuration.tile_height,
		configuration.half_width, configuration.half_height,
		configuration.altitude_step, configuration.top_margin,
		configuration.side_margin, configuration.sprite_base]
