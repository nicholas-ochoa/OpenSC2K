extends SceneTree

const RleCodec = preload("res://src/formats/maxis_rle.gd")
const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityModel = preload("res://src/model/city_state.gd")
const ScenarioModel = preload("res://src/model/scenario_state.gd")
const Palette = preload("res://src/assets/sc2_palette.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const Minimap = preload("res://src/view/city_minimap.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const PeBitmap = preload("res://src/assets/pe_bitmap_resource.gd")
const MapControl = preload("res://src/view/city_map_control.gd")
const Clock = preload("res://src/simulation/simulation_clock.gd")
const Random = preload("res://src/simulation/sim_random.gd")
const LfsrRandom = preload("res://src/simulation/sim_lfsr_random.gd")
const Power = preload("res://src/simulation/power_phase.gd")
const Water = preload("res://src/simulation/water_phase.gd")
const Traffic = preload("res://src/simulation/traffic_phase.gd")
const Pollution = preload("res://src/simulation/pollution_phase.gd")
const Graphs = preload("res://src/simulation/graph_history.gd")
const RciDemand = preload("res://src/simulation/rci_demand_phase.gd")
const EducationHealth = preload("res://src/simulation/education_health_phase.gd")
const MonthStart = preload("res://src/simulation/month_start_phase.gd")
const Budget = preload("res://src/simulation/budget_phase.gd")
const Milestones = preload("res://src/simulation/milestone_phase.gd")
const MilitaryProposal = preload("res://src/simulation/military_proposal_phase.gd")
const DisasterStart = preload("res://src/simulation/disaster_start_phase.gd")
const ScenarioPhaseRunner = preload("res://src/simulation/scenario_phase.gd")
const Bankruptcy = preload("res://src/simulation/bankruptcy_phase.gd")
const AnnualMicrosims = preload("res://src/simulation/microsim_annual_phase.gd")
const MayorApproval = preload("res://src/simulation/mayor_approval_phase.gd")
const Transport = preload("res://src/simulation/transport_trip.gd")
const Growth = preload("res://src/simulation/growth_phase.gd")
const MovingThings = preload("res://src/simulation/moving_thing_spawner.gd")
const MovingThingTick = preload("res://src/simulation/moving_thing_phase.gd")
const Simulation = preload("res://src/simulation/simulation_engine.gd")
const GameSpeed = preload("res://src/simulation/game_speed_controller.gd")
const Tools = preload("res://src/tools/tool_catalog.gd")
const Zones = preload("res://src/tools/zone_command.gd")
const Signs = preload("res://src/tools/sign_command.gd")
const Queries = preload("res://src/tools/query_info.gd")
const Landscapes = preload("res://src/tools/landscape_command.gd")
const Buildings = preload("res://src/tools/building_command.gd")
const GameRandom = preload("res://src/simulation/game_lcg_random.gd")
const Networks = preload("res://src/tools/network_command.gd")
const Hydro = preload("res://src/tools/hydro_command.gd")
const SubwayToRail = preload("res://src/tools/subway_to_rail_command.gd")
const Onramps = preload("res://src/tools/onramp_command.gd")
const Tunnels = preload("res://src/tools/tunnel_command.gd")
const Highways = preload("res://src/tools/highway_command.gd")
const Demolish = preload("res://src/tools/demolish_command.gd")
const TerrainTools = preload("res://src/tools/terrain_command.gd")
const Dispatch = preload("res://src/tools/dispatch_command.gd")
const CityRotation = preload("res://src/tools/city_rotation_command.gd")

var failures := 0
var checks := 0


class ZeroRandom:
	extends RefCounted

	func next_u15() -> int:
		return 0


class ZeroLfsrRandom:
	extends RefCounted

	func next_mask(_mask: int) -> int:
		return 0

	func next_mod(_divisor: int) -> int:
		return 0


class NonzeroLfsrRandom:
	extends RefCounted

	func next_mask(_mask: int) -> int:
		return 1

	func next_mod(divisor: int) -> int:
		return 1 % divisor


class MicrosimLfsrRandom:
	extends RefCounted

	func next_mask(mask: int) -> int:
		return 0 if mask == 3 else 1

	func next_mod(_divisor: int) -> int:
		return 0


class SequenceLfsrRandom:
	extends RefCounted

	var values := PackedInt32Array()
	var position := 0

	func _init(initial_values: Array[int]) -> void:
		values = PackedInt32Array(initial_values)

	func next_mask(mask: int) -> int:
		return _next() & mask

	func next_mod(divisor: int) -> int:
		return _next() % divisor

	func _next() -> int:
		if position >= values.size():
			return 1
		var value := int(values[position])
		position += 1
		return value


class SequenceRandom:
	extends RefCounted

	var values := PackedInt32Array()
	var position := 0

	func _init(initial_values: Array[int]) -> void:
		values = PackedInt32Array(initial_values)

	func next_u15() -> int:
		if position >= values.size():
			return 1
		var value := int(values[position])
		position += 1
		return value


class CountingRandom:
	extends RefCounted

	var position := 0

	func next_u15() -> int:
		position += 1
		return position & 0x7fff


class SequenceModuloRandom:
	extends RefCounted

	var values := PackedInt32Array()
	var position := 0

	func _init(initial_values: Array[int]) -> void:
		values = PackedInt32Array(initial_values)

	func next_mod(divisor: int) -> int:
		var value := int(values[position]) if position < values.size() else 0
		position += 1
		return value % divisor


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	var reference_root := ProjectSettings.globalize_path("res://../references")
	if not arguments.is_empty():
		reference_root = arguments[0]

	_test_rle()
	_test_invalid_rle()
	_test_palette_and_minimap(reference_root)
	_test_sprite_archives(reference_root)
	_test_reference_corpus(reference_root)
	_test_scenarios(reference_root)
	_test_simulation_clock()
	_test_random_and_power(reference_root)
	_test_water(reference_root)
	_test_traffic(reference_root)
	_test_pollution(reference_root)
	_test_graph_history(reference_root)
	_test_rci_demand(reference_root)
	_test_education_health(reference_root)
	_test_month_start(reference_root)
	_test_budget_phase(reference_root)
	_test_milestone_phase(reference_root)
	_test_military_proposal_phase(reference_root)
	_test_disaster_start_phase(reference_root)
	_test_annual_microsim_phase(reference_root)
	_test_annual_service_microsim_phase(reference_root)
	_test_annual_special_microsim_phase(reference_root)
	_test_arcology_launch_phase(reference_root)
	_test_mayor_approval_phase(reference_root)
	_test_transport_trip(reference_root)
	_test_growth_phase(reference_root)
	_test_moving_thing_phase(reference_root)
	_test_simulation_engine(reference_root)
	_test_game_speed_controller(reference_root)
	_test_modified_save(reference_root)
	_test_map_edits(reference_root)
	_test_tool_catalog()
	_test_zone_command(reference_root)
	_test_sign_command(reference_root)
	_test_query_info(reference_root)
	_test_landscape_command(reference_root)
	_test_building_command(reference_root)
	_test_network_command(reference_root)
	_test_hydro_command(reference_root)
	_test_subway_to_rail_command(reference_root)
	_test_onramp_command(reference_root)
	_test_tunnel_command(reference_root)
	_test_highway_command(reference_root)
	_test_demolish_command(reference_root)
	_test_terrain_command(reference_root)
	_test_dispatch_command(reference_root)
	_test_city_rotation(reference_root)

	if failures == 0:
		print("PASS: %d checks" % checks)
		quit(0)
	else:
		printerr("FAIL: %d of %d checks failed" % [failures, checks])
		quit(1)


func _test_rle() -> void:
	var cases: Array[PackedByteArray] = [
		PackedByteArray(),
		PackedByteArray([1]),
		PackedByteArray([7, 7]),
		PackedByteArray([1, 2, 3, 4, 5]),
		_filled_bytes(128, 0xaa),
		_filled_bytes(300, 0x00),
	]
	for original in cases:
		var encoded := RleCodec.encode(original)
		var result := RleCodec.decode(encoded, original.size())
		_check(result.ok, "RLE round trip decodes")
		if result.ok:
			_check(result.data == original, "RLE round trip preserves bytes")


func _test_invalid_rle() -> void:
	_check(not RleCodec.decode(PackedByteArray([0x80])).ok, "RLE rejects 0x80")
	_check(not RleCodec.decode(PackedByteArray([2, 1])).ok, "RLE rejects short literal")
	_check(not RleCodec.decode(PackedByteArray([0x81])).ok, "RLE rejects short run")
	_check(
		not RleCodec.decode(PackedByteArray([0x82, 4]), 2).ok,
		"RLE rejects output overflow"
	)


func _test_reference_corpus(reference_root: String) -> void:
	var paths := PackedStringArray([reference_root.path_join("DEFAULT.SC2")])
	paths.append_array(_files_with_extension(reference_root.path_join("CITIES"), "SC2"))
	paths.append_array(_files_with_extension(reference_root.path_join("SCENARIO"), "SCN"))
	_check(paths.size() >= 80, "Reference corpus contains at least 80 city and scenario files")

	for path in paths:
		var document := Sc2Document.load_path(path)
		_check(document.is_valid(), "%s parses: %s" % [path.get_file(), document.parse_error])
		if not document.is_valid():
			continue

		var rebuilt := document.serialize(true)
		_check(rebuilt.ok, "%s rebuilds" % path.get_file())
		if rebuilt.ok:
			_check(
				rebuilt.data == FileAccess.get_file_as_bytes(path),
				"%s rebuild is byte-identical" % path.get_file()
			)

		var city := CityModel.from_document(document)
		_check(city.is_valid(), "%s creates a city model: %s" % [path.get_file(), city.load_error])
		if city.is_valid():
			_check(city.index_of(0, 0) == 0, "%s map origin is stable" % path.get_file())
			_check(
				city.index_of(127, 127) == 16383,
				"%s map end is stable" % path.get_file()
			)
			_check(
				city.current_month() >= 1 and city.current_month() <= 12,
				"%s month is in range" % path.get_file()
			)
			_check(city.label(0).length() <= 23, "%s mayor label is bounded" % path.get_file())
			_check(city.microsim(149).size() == 5, "%s has 150 microsim records" % path.get_file())
			_check(city.thing(39).size() == 12, "%s has 40 thing records" % path.get_file())
			var graph := city.graph_series(15)
			_check(graph.year.size() == 12, "%s graph has 12 monthly values" % path.get_file())
			_check(graph.decade.size() == 20, "%s graph has 20 decade values" % path.get_file())
			_check(graph.century.size() == 20, "%s graph has 20 century values" % path.get_file())

		for chunk in document.chunks:
			if not chunk.is_compressed:
				continue
			var reencoded := RleCodec.encode(chunk.decoded_payload)
			var decoded := RleCodec.decode(reencoded, chunk.expected_decoded_size)
			_check(decoded.ok, "%s %s re-encodes" % [path.get_file(), chunk.chunk_id])
			if decoded.ok:
				_check(
					decoded.data == chunk.decoded_payload,
					"%s %s re-encode preserves bytes" % [path.get_file(), chunk.chunk_id]
				)

	var default_city := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	_check(default_city.is_valid(), "Default city parses")
	if default_city.is_valid():
		_check(default_city.city_name() == "New City", "Default city name is New City")
		_check(default_city.misc_u32(0) == 0x122, "Default MISC marker is 0x122")
		var render_copy := default_city.duplicate_document()
		_check(render_copy.is_valid(), "A render document copy stays valid")
		_check(
			render_copy.serialize().data == default_city.serialize().data,
			"A render document copy preserves all city bytes",
		)
		_check(render_copy.set_misc_u32(0x10, 123), "A render document copy can change")
		_check(
			default_city.misc_u32(0x10) != 123,
			"A render document copy does not change the live city",
		)
		var default_model := CityModel.from_document(default_city)
		_check(default_model.land_altitude(0, 0) == 4, "Default origin land altitude is 4")
		_check(default_model.water_altitude(0, 0) == 4, "Default origin water level is 4")
		_check(default_model.tunnel_levels(0, 0) == 0, "Default origin tunnel depth is 0")


func _test_palette_and_minimap(reference_root: String) -> void:
	var loaded_palette := Palette.load_bmp(reference_root.path_join("BITMAPS/PAL_MSTR.BMP"))
	_check(loaded_palette.is_valid(), "Master Windows palette loads")
	if not loaded_palette.is_valid():
		return

	var document := Sc2Document.load_path(reference_root.path_join("CITIES/STARTER.SC2"))
	var loaded_city := CityModel.from_document(document)
	_check(loaded_city.is_valid(), "Starter city loads for minimap test")
	if not loaded_city.is_valid():
		return
	for mode in ["structures", "zones", "power", "water"]:
		var image := Minimap.create_image(loaded_city, loaded_palette, mode)
		_check(image.get_width() == 128, "%s minimap width is 128" % mode)
		_check(image.get_height() == 128, "%s minimap height is 128" % mode)


func _test_sprite_archives(reference_root: String) -> void:
	var toolbar := PeBitmap.load_numeric(reference_root.path_join("SIMCITY.EXE"), 2)
	_check(toolbar.ok, "Windows toolbar bitmap resource loads: %s" % toolbar.error)
	if toolbar.ok:
		_check(
			toolbar.image.get_size() == Vector2i(865, 23),
			"Windows toolbar bitmap resource has its confirmed size",
		)
	_check(
		not PeBitmap.load_numeric(reference_root.path_join("SIMCITY.EXE"), 0xffff).ok,
		"Windows bitmap loader rejects a missing numeric resource",
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
		IsometricRenderer.shadow_color(palette, palette.color(0x5f)).to_rgba32()
		== palette.color(0x64).to_rgba32(),
		"Aircraft shadow remaps palette index 0x5f to 0x64",
	)
	_check(
		IsometricRenderer.shadow_color(palette, palette.color(0x74)).to_rgba32()
		== palette.color(0x7e).to_rgba32(),
		"Aircraft shadow remaps the ground-color range to 0x7e",
	)
	_check(
		IsometricRenderer.shadow_color(palette, palette.color(0x73)).to_rgba32()
		== palette.color(0x73).to_rgba32(),
		"Aircraft shadow keeps colors outside its recovered ranges",
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

	var starter_document := Sc2Document.load_path(reference_root.path_join("CITIES/STARTER.SC2"))
	var starter := CityModel.from_document(starter_document)
	var asset_errors := IsometricRenderer.validate_assets(starter, large)
	_check(asset_errors.is_empty(), "Starter city has every required large sprite: %s" % asset_errors)
	var small_asset_errors := IsometricRenderer.validate_assets(
		starter, small_medium, IsometricRenderer.VIEW_SMALL
	)
	_check(
		small_asset_errors.is_empty(),
		"Starter city has every required small sprite: %s" % small_asset_errors,
	)
	var medium_asset_errors := IsometricRenderer.validate_assets(
		starter, small_medium, IsometricRenderer.VIEW_MEDIUM
	)
	_check(
		medium_asset_errors.is_empty(),
		"Starter city has every required medium sprite: %s" % medium_asset_errors,
	)
	_check(IsometricRenderer.terrain_sprite_id(0x00, false) == 1256, "Flat land uses sprite 1256")
	_check(IsometricRenderer.terrain_sprite_id(0x10, true) == 1270, "Submerged land uses sprite 1270")
	_check(IsometricRenderer.terrain_sprite_id(0x45, true) == 1290, "Last water tile uses sprite 1290")
	_check(
		IsometricRenderer.terrain_sprite_id(0x00, false, 0) == 256,
		"Small flat land uses sprite 256",
	)
	_check(
		IsometricRenderer.terrain_sprite_id(0x00, false, 500) == 756,
		"Medium flat land uses sprite 756",
	)
	_check(
		IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_SMALL)
		== Vector2i(1040, 736),
		"Small city view has the recovered quarter-scale canvas",
	)
	_check(
		IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_MEDIUM)
		== Vector2i(2080, 1472),
		"Medium city view has the recovered half-scale canvas",
	)
	var small_terrain := small_medium.find_sprite(256)
	var medium_terrain := small_medium.find_sprite(756)
	_check(
		small_terrain != null and small_terrain.width == 8 and small_terrain.height == 5,
		"Small terrain sprite is 8 by 5",
	)
	_check(
		medium_terrain != null and medium_terrain.width == 16 and medium_terrain.height == 9,
		"Medium terrain sprite is 16 by 9",
	)
	var overlay_document := Sc2Document.load_path(reference_root.path_join("CITIES/STARTER.SC2"))
	var overlay_city := CityModel.from_document(overlay_document)
	var overlay_point := Vector2i(64, 64)
	var traffic_index := 32 * CityModel.COARSE_MAP_SIZE + 32
	var traffic_data: PackedByteArray = (
		overlay_document.find_chunk("XTRF").decoded_payload.duplicate()
	)
	_check(
		overlay_city.set_building_id(overlay_point.x, overlay_point.y, 0x1d),
		"Traffic view fixture installs a straight road",
	)
	traffic_data[traffic_index] = 85
	_check(
		overlay_document.find_chunk("XTRF").set_decoded_payload(traffic_data),
		"Traffic view fixture stores the first threshold",
	)
	_check(
		overlay_city.traffic_density(overlay_point.x, overlay_point.y) == 85,
		"City model reads the shared 64 by 64 traffic cell",
	)
	_check(
		IsometricRenderer.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).is_empty(),
		"Normal road traffic does not draw at density 85",
	)
	traffic_data[traffic_index] = 86
	_check(
		overlay_document.find_chunk("XTRF").set_decoded_payload(traffic_data),
		"Traffic view fixture crosses the first threshold",
	)
	var low_traffic := IsometricRenderer.traffic_overlay_visual(
		overlay_city, overlay_point.x, overlay_point.y
	)
	_check(
		low_traffic.sprite_id == 1400
		and low_traffic.variant == 1
		and not low_traffic.flip,
		"Normal road traffic selects the recovered low-density large sprite",
	)
	_check(
		IsometricRenderer.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_MEDIUM
		).sprite_id == 900,
		"Medium traffic uses its native sprite set",
	)
	_check(
		IsometricRenderer.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_SMALL
		).sprite_id == 400,
		"Small traffic uses its native sprite set",
	)
	traffic_data[traffic_index] = 171
	_check(
		overlay_document.find_chunk("XTRF").set_decoded_payload(traffic_data),
		"Traffic view fixture crosses the second threshold",
	)
	_check(
		IsometricRenderer.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).sprite_id == 1427,
		"Normal road traffic selects the recovered high-density variant",
	)
	_check(
		IsometricRenderer.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_SMALL
		).is_empty(),
		"Small view omits high-density variants absent from its source archive",
	)
	_check(
		overlay_city.set_building_id(overlay_point.x, overlay_point.y, 0x49),
		"Traffic view fixture installs a highway",
	)
	traffic_data[traffic_index] = 29
	_check(
		overlay_document.find_chunk("XTRF").set_decoded_payload(traffic_data),
		"Traffic view fixture crosses the highway threshold",
	)
	_check(
		IsometricRenderer.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).sprite_id == 1410,
		"Highway traffic uses the recovered lower threshold and lane sprite",
	)
	traffic_data[traffic_index] = 57
	_check(
		overlay_document.find_chunk("XTRF").set_decoded_payload(traffic_data),
		"Traffic view fixture crosses the second highway threshold",
	)
	_check(
		IsometricRenderer.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).sprite_id == 1437,
		"Highway traffic selects the recovered high-density lane sprite",
	)
	_check(
		overlay_city.set_building_corners(overlay_point.x, overlay_point.y, 0),
		"Highway coverage fixture clears zone anchor bits",
	)
	_check(
		not IsometricRenderer._should_draw_building(
			overlay_city, overlay_point.x, overlay_point.y, 0x61
		),
		"Elevated highway waits for its compass-selected anchor",
	)
	_check(
		IsometricRenderer._should_draw_building(
			overlay_city, overlay_point.x, overlay_point.y, 0x6c
		),
		"Subway-to-rail tiles draw without zone anchor bits",
	)
	var compass_masks := [0x80, 0x10, 0x20, 0x40]
	_check(
		overlay_city.set_building_corners(
			overlay_point.x, overlay_point.y,
			compass_masks[overlay_city.compass_rotation()]
		),
		"Highway coverage fixture sets the active anchor bit",
	)
	_check(
		IsometricRenderer._should_draw_building(
			overlay_city, overlay_point.x, overlay_point.y, 0x61
		),
		"Elevated highway draws from its compass-selected anchor",
	)
	_check(
		overlay_document.set_misc_u32(0x0008, 3),
		"Network orientation fixture sets an odd compass rotation",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x02, false),
		"Network orientation fixture clears the saved mirror",
	)
	_check(
		not IsometricRenderer.building_sprite_flip(
			overlay_city, overlay_point.x, overlay_point.y, 0x1d
		),
		"Compass rotation does not add a mirror to a network sprite",
	)
	_check(
		IsometricRenderer.building_sprite_flip(
			overlay_city, overlay_point.x, overlay_point.y, 0x70
		),
		"Odd compass rotation adds the original mirror to a building sprite",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x02, true),
		"Network orientation fixture sets the saved mirror",
	)
	_check(
		IsometricRenderer.building_sprite_flip(
			overlay_city, overlay_point.x, overlay_point.y, 0x2c
		)
		and not IsometricRenderer.building_sprite_flip(
			overlay_city, overlay_point.x, overlay_point.y, 0x70
		),
		"Saved mirror stays direct for rail and combines with compass for buildings",
	)
	_check(
		IsometricRenderer.building_baseline_offset(0x1d, 0x0d, 32) == -12
		and IsometricRenderer.building_baseline_offset(0x1d, 0x00, 32) == 0,
		"A network on terrain shape 0x0d uses the recovered raised baseline",
	)
	_check(
		IsometricRenderer.building_baseline_offset(0x70, 0x00, 128) == 24
		and IsometricRenderer.building_baseline_offset(
			0x70, 0x00, 64, IsometricRenderer.VIEW_MEDIUM
		) == 12
		and IsometricRenderer.building_baseline_offset(
			0x70, 0x00, 32, IsometricRenderer.VIEW_SMALL
		) == 6,
		"Large footprints use the native quarter-width baseline at every zoom",
	)
	_check(
		overlay_city.set_building_id(overlay_point.x, overlay_point.y, 0x70),
		"Power-marker fixture installs a zone building",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x80, true),
		"Power-marker fixture marks the building as powerable",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x40, false),
		"Power-marker fixture clears the powered flag",
	)
	_check(
		IsometricRenderer.power_marker_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).sprite_id == 1386,
		"Unpowered zone building selects the recovered large marker",
	)
	_check(
		IsometricRenderer.power_marker_visual(
			overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_SMALL
		).sprite_id == 386,
		"Small view selects its native unpowered marker",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x40, true),
		"Power-marker fixture sets the powered flag",
	)
	_check(
		IsometricRenderer.power_marker_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).is_empty(),
		"Powered zone building does not draw an unpowered marker",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xff),
		"Fire view fixture installs the fire marker",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x04, false),
		"Fire view fixture uses a land tile",
	)
	var fire_visual := IsometricRenderer.fire_overlay_visual(
		overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_LARGE, 3
	)
	_check(
		fire_visual.sprite_id == 1399 and not fire_visual.flip,
		"Fire view selects the recovered large frame from its visual phase",
	)
	var flipped_fire := IsometricRenderer.fire_overlay_visual(
		overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_LARGE, 4
	)
	_check(
		flipped_fire.sprite_id == 1396 and flipped_fire.flip,
		"Fire view changes frame and mirror without simulation random state",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x04, true),
		"Fire view fixture changes to a water tile",
	)
	_check(
		IsometricRenderer.fire_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).is_empty(),
		"Fire does not draw on a saved water tile",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xfb),
		"Special-overlay fixture installs marker 0xfb",
	)
	_check(
		IsometricRenderer.special_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).sprite_id == 1496,
		"Special marker 0xfb uses its recovered large sprite on water",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xfc),
		"Special-overlay fixture installs marker 0xfc",
	)
	_check(
		IsometricRenderer.special_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y,
			IsometricRenderer.VIEW_MEDIUM
		).sprite_id == 992,
		"Special marker 0xfc uses its native medium sprite on water",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xfd),
		"Special-overlay fixture installs marker 0xfd",
	)
	_check(
		IsometricRenderer.special_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).is_empty(),
		"Special marker 0xfd does not draw on a saved water tile",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x04, false),
		"Special-overlay fixture changes back to dry land",
	)
	var launch_effect := IsometricRenderer.special_overlay_visual(
		overlay_city, overlay_point.x, overlay_point.y,
		IsometricRenderer.VIEW_LARGE, 1
	)
	_check(
		launch_effect.sprite_id == 1494 and launch_effect.overlay == 0xfd,
		"Special marker 0xfd selects one of the recovered two-frame effects",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xfe),
		"Special-overlay fixture installs marker 0xfe",
	)
	_check(
		IsometricRenderer.special_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y,
			IsometricRenderer.VIEW_SMALL, 0
		).sprite_id == 493,
		"Special marker 0xfe uses its native small effect frame",
	)
	var edge_point := Vector2i(127, 64)
	_check(
		overlay_city.set_land_altitude(edge_point.x, edge_point.y, 3),
		"Edge-stack fixture sets three land levels",
	)
	var land_edges := IsometricRenderer.edge_stack_visuals(
		overlay_city, edge_point.x, edge_point.y
	)
	_check(
		land_edges.size() == 3
		and land_edges[0].sprite_id == 1269
		and land_edges[0].elevation == 0
		and land_edges[2].elevation == 24,
		"Large map edge repeats the land-side sprite at 12-pixel steps",
	)
	_check(
		overlay_city.set_water_altitude(edge_point.x, edge_point.y, 5),
		"Edge-stack fixture sets five water levels",
	)
	_check(
		overlay_city.set_tile_flag(edge_point.x, edge_point.y, 0x04, true),
		"Edge-stack fixture marks the edge as water",
	)
	var water_edges := IsometricRenderer.edge_stack_visuals(
		overlay_city, edge_point.x, edge_point.y
	)
	_check(
		water_edges.size() == 5
		and water_edges[3].sprite_id == 1284
		and water_edges[3].elevation == 36
		and water_edges[4].sprite_id == 1284,
		"Large map edge adds water-side sprites above the land stack",
	)
	var small_edges := IsometricRenderer.edge_stack_visuals(
		overlay_city, edge_point.x, edge_point.y, IsometricRenderer.VIEW_SMALL
	)
	_check(
		small_edges.size() == 5
		and small_edges[0].sprite_id == 269
		and small_edges[4].sprite_id == 284
		and small_edges[4].elevation == 12,
		"Small map edge uses native side sprites at three-pixel steps",
	)
	_check(
		IsometricRenderer.edge_stack_visuals(
			overlay_city, 126, 64, IsometricRenderer.VIEW_LARGE
		).is_empty(),
		"Interior tiles do not draw map-edge stacks",
	)
	var city_paths := _files_with_extension(reference_root.path_join("CITIES"), "SC2")
	city_paths.append_array(_files_with_extension(reference_root.path_join("SCENARIO"), "SCN"))
	for path in city_paths:
		var view_city := CityModel.from_document(Sc2Document.load_path(path))
		if not view_city.is_valid():
			continue
		for view_size in [IsometricRenderer.VIEW_SMALL, IsometricRenderer.VIEW_MEDIUM]:
			var view_errors := IsometricRenderer.validate_assets(
				view_city, small_medium, view_size
			)
			_check(
				view_errors.is_empty(),
				"%s has all required view-%d sprites: %s"
				% [path.get_file(), view_size, view_errors],
			)
	var plane_visual := IsometricRenderer.moving_thing_sprite({
		"type": 1, "direction": 4, "state": 2,
	})
	_check(
		plane_visual.sprite_id == 1362 and plane_visual.flip,
		"Airplane view uses the recovered direction offset and mirror",
	)
	var medium_plane := IsometricRenderer.moving_thing_sprite({
		"type": 1, "direction": 4, "state": 2,
	}, IsometricRenderer.VIEW_MEDIUM)
	_check(
		medium_plane.sprite_id == 862 and medium_plane.flip,
		"Airplane view selects the native medium direction sprite",
	)
	var small_plane := IsometricRenderer.moving_thing_sprite({
		"type": 1, "direction": 4, "state": 2,
	}, IsometricRenderer.VIEW_SMALL)
	_check(
		small_plane.sprite_id == 362 and small_plane.flip,
		"Airplane view selects the native small direction sprite",
	)
	var ship_visual := IsometricRenderer.moving_thing_sprite({
		"type": 3, "direction": 7, "state": 0,
	})
	_check(
		ship_visual.sprite_id == 1369 and not ship_visual.flip,
		"Cargo-ship view uses the recovered north-west sprite",
	)
	_check(
		IsometricRenderer.moving_thing_sprite({
			"type": 3, "direction": 7, "state": 0,
		}, IsometricRenderer.VIEW_SMALL).sprite_id == 369,
		"Cargo-ship view selects the native small sprite",
	)
	_check(
		IsometricRenderer.moving_thing_sprite({
			"type": 4, "direction": 2, "state": 0,
		}, IsometricRenderer.VIEW_MEDIUM).sprite_id == 891,
		"Bulldozer view selects the native medium direction sprite",
	)
	var sail_visual := IsometricRenderer.moving_thing_sprite({
		"type": 9, "direction": 2, "state": 0,
	})
	_check(
		sail_visual.sprite_id == 1381 and sail_visual.flip,
		"Sailboat view uses the recovered cardinal offset and mirror",
	)
	_check(
		IsometricRenderer.moving_thing_sprite({
			"type": 9, "direction": 2, "state": 1,
		}).sprite_id == 1379,
		"A distressed sailboat uses the Nessie sprite",
	)
	_check(
		IsometricRenderer.moving_thing_sprite({
			"type": 6, "direction": 2, "state": 0,
		}).sprite_id == 1389,
		"Explosion frame two uses the third recovered sprite",
	)
	_check(
		IsometricRenderer.moving_thing_sprite({
			"type": 6, "direction": 2, "state": 0,
		}, IsometricRenderer.VIEW_MEDIUM).sprite_id == 889,
		"Explosion view selects the native medium frame",
	)
	_check(
		IsometricRenderer.moving_thing_sprite({
			"type": 6, "direction": 2, "state": 0,
		}, IsometricRenderer.VIEW_SMALL).is_empty(),
		"Explosion stays hidden below its recovered minimum view",
	)
	_check(
		IsometricRenderer.moving_thing_sprite({
			"type": 2, "direction": 2, "state": 0,
		}, IsometricRenderer.VIEW_MEDIUM).is_empty(),
		"Helicopter stays hidden below its recovered minimum view",
	)
	_check(
		IsometricRenderer.moving_thing_sprite({
			"type": 10, "direction": 0, "state": 0,
		}).is_empty(),
		"The generic view defers trains to their custom renderer",
	)
	_check(
		starter_document.find_chunk("ALTM").set_decoded_payload(_filled_bytes(128 * 128 * 2, 0)),
		"Isometric lookup fixture clears altitude",
	)
	_check(
		starter_document.find_chunk("XTER").set_decoded_payload(_filled_bytes(128 * 128, 0)),
		"Isometric lookup fixture clears terrain",
	)
	starter = CityModel.from_document(starter_document)
	_check(starter.set_building_id(64, 64, 0), "Moving overlay fixture clears its tile")
	_check(starter.set_tile_flag(64, 64, 0x04, false), "Moving overlay fixture uses dry land")
	var plane_entry := large.find_sprite(plane_visual.sprite_id)
	var plane_commands := IsometricRenderer.moving_thing_draw_commands_for_visual(
		starter,
		large,
		{
			"sprite_id": plane_visual.sprite_id,
			"flip": plane_visual.flip,
			"type": 1,
			"x": 64,
			"y": 64,
			"z": 2,
			"px": 8,
			"py": 8,
			"train": false,
			"tornado": false,
			"monster": false,
		},
		IsometricRenderer.view_configuration(IsometricRenderer.VIEW_LARGE)
	)
	var expected_plane_position := Vector2i(
		2096 - int(plane_entry.width / 2), 1528 - plane_entry.height
	)
	_check(
		plane_commands.size() == 2
		and plane_commands[0].shadow
		and plane_commands[0].position == expected_plane_position
		and not plane_commands[1].shadow
		and plane_commands[1].position == expected_plane_position,
		"Moving overlay commands preserve the recovered sprite and shadow positions",
	)
	var static_signature := IsometricRenderer.static_visual_signature(starter)
	_check(
		starter.set_text_overlay_id(64, 64, 201),
		"Static-signature fixture adds an inactive moving-object link",
	)
	_check(
		IsometricRenderer.static_visual_signature(starter) == static_signature,
		"Moving-object links do not invalidate the static city image",
	)
	_check(
		starter.set_text_overlay_id(64, 64, 0xfb),
		"Static-signature fixture adds a special map marker",
	)
	_check(
		IsometricRenderer.static_visual_signature(starter) != static_signature,
		"A static special marker invalidates the static city image",
	)
	_check(starter.set_text_overlay_id(64, 64, 0), "Static-signature fixture clears its marker")
	for expected in [Vector2i.ZERO, Vector2i(24, 93), Vector2i(64, 64), Vector2i(127, 127)]:
		var polygon := IsometricRenderer.tile_polygon(starter, expected.x, expected.y)
		var center := (polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.25
		_check(
			IsometricRenderer.screen_to_tile(starter, center) == expected,
			"Isometric screen lookup finds tile %s" % expected,
		)
	var map_control := MapControl.new()
	map_control.city = starter
	_check(map_control.zoom_percent() == 100, "City view starts at native large-sprite scale")
	_check(map_control.zoom_in(), "City view accepts a fixed zoom-in step")
	_check(map_control.zoom_percent() == 200, "City view zoom-in doubles source pixels")
	_check(not map_control.zoom_in(), "City view rejects zoom above the largest fixed level")
	_check(map_control.zoom_out(), "City view accepts a fixed zoom-out step")
	_check(map_control.zoom_percent() == 100, "City view zoom-out restores native scale")
	var center_tile := Vector2i(64, 64)
	var center_polygon := IsometricRenderer.tile_polygon(starter, center_tile.x, center_tile.y)
	var expected_center := (
		center_polygon[0] + center_polygon[1] + center_polygon[2] + center_polygon[3]
	) * 0.25
	_check(map_control.center_on_tile(center_tile), "Center tool accepts a city tile")
	_check(map_control.source_center == expected_center, "Center tool uses the altitude-aware tile center")
	_check(
		map_control.center_tile() == center_tile,
		"Map control reports centered tile %s, got %s" % [center_tile, map_control.center_tile()],
	)
	_check(not map_control.center_on_tile(Vector2i(-1, 0)), "Center tool rejects an invalid tile")
	_check(not map_control.is_left_drag_active(), "Map control starts without an active left drag")
	map_control.selection_start = center_tile
	_check(map_control.is_left_drag_active(), "Map control reports an active left drag")
	map_control.set_dynamic_sprites([{"position": Vector2(10, 20)}])
	_check(map_control.dynamic_sprites.size() == 1, "Map control accepts a dynamic sprite layer")
	map_control.set_dynamic_sprites([])
	_check(map_control.dynamic_sprites.is_empty(), "Map control clears its dynamic sprite layer")
	map_control.free()
	_check(starter.set_building_id(64, 64, 0x2e), "Train drawing fixture adds a rail tile")
	var straight_train := IsometricRenderer.train_sprite(starter, 64, 64, {
		"type": 10, "dx": 0,
	})
	_check(
		straight_train.sprite_id == 1377 and straight_train.flip,
		"Train view maps a rail tile to its recovered sprite variant",
	)
	_check(starter.set_building_id(64, 64, 0x36), "Train drawing fixture adds a turn tile")
	var turning_train := IsometricRenderer.train_sprite(starter, 64, 64, {
		"type": 11, "dx": 1,
	})
	_check(
		turning_train.variant == 17 and turning_train.sprite_id == 1375,
		"Train view uses the saved transition on a turn tile",
	)
	_check(
		turning_train.screen_y == 6 and not turning_train.flip,
		"Train view applies the recovered turn position and mirror",
	)
	_check(starter.set_building_id(64, 64, 0x5a), "Train drawing fixture adds a tunnel tile")
	_check(starter.set_tile_flag(64, 64, 0x02, true), "Train drawing fixture mirrors the tunnel")
	var tunnel_train := IsometricRenderer.train_sprite(starter, 64, 64, {
		"type": 10, "dx": 0,
	})
	_check(
		tunnel_train.variant == 1 and tunnel_train.elevation == 12,
		"Tunnel train view uses the water level, raised track, and flip flag",
	)
	var tornado_visual := IsometricRenderer.tornado_sprite(starter, 64, 64, {
		"type": 15, "px": 8, "py": 8,
	}, 1)
	_check(
		tornado_visual.sprite_id == 1498
		and tornado_visual.flip
		and tornado_visual.tornado,
		"Tornado view selects a stable recovered frame and mirror",
	)
	var small_tornado := IsometricRenderer.tornado_sprite(starter, 64, 64, {
		"type": 15, "px": 8, "py": 8,
	}, 1, IsometricRenderer.VIEW_SMALL)
	_check(
		small_tornado.sprite_id == 498
		and small_tornado.elevation == 0
		and small_tornado.flip,
		"Tornado view selects its native small frame and altitude scale",
	)
	_check(
		IsometricRenderer.bridge_effect_position(starter, {
			"point": Vector2i(64, 64),
			"screen_offset": Vector2i(16, -8),
		}, 10) == Vector2i(2096, 1518),
		"Bridge debris view uses water altitude and the recovered screen offset",
	)
	var monster_layers := IsometricRenderer.monster_layers(starter, 64, 64, {
		"type": 5,
		"z": 10,
		"px": 8,
		"py": 8,
		"dx": 0xa5,
		"dy": 0x9b,
	}, 1)
	_check(monster_layers.size() == 15, "Monster view builds all composite sprite layers")
	_check(
		monster_layers[0].sprite_id == 1483
		and monster_layers[0].screen_x == -95
		and monster_layers[0].screen_y == 924
		and not monster_layers[0].flip,
		"Monster view positions the left upper outer layer",
	)
	_check(
		monster_layers[3].sprite_id == 1483
		and monster_layers[3].screen_x == 73
		and monster_layers[3].screen_y == 878
		and monster_layers[3].flip,
		"Monster view mirrors and positions the right upper outer layer",
	)
	_check(
		monster_layers[6].sprite_id == 1385
		and monster_layers[6].screen_x == -2
		and monster_layers[6].screen_y == 886,
		"Monster DX effect bit inserts the recovered effect sprite",
	)
	_check(
		monster_layers[7].sprite_id == 1491
		and monster_layers[7].screen_x == -48
		and monster_layers[7].screen_y == 794,
		"Monster DY effect bit selects a stable alternate head",
	)
	_check(
		monster_layers[14].sprite_id == 1488
		and monster_layers[14].screen_x == 12
		and monster_layers[14].screen_y == 932
		and monster_layers[14].flip,
		"Monster view mirrors and positions the right lower outer layer",
	)
	var small_monster_layers := IsometricRenderer.monster_layers(starter, 64, 64, {
		"type": 5,
		"z": 10,
		"px": 8,
		"py": 8,
		"dx": 0xa5,
		"dy": 0x9b,
	}, 1, IsometricRenderer.VIEW_SMALL)
	_check(
		small_monster_layers.size() == 15,
		"Small monster view keeps every composite layer",
	)
	_check(
		small_monster_layers[0].sprite_id == 483
		and small_monster_layers[0].screen_x == -23
		and small_monster_layers[0].screen_y == 231,
		"Small monster view uses native sprites and signed quarter-scale offsets",
	)
	_check(
		small_monster_layers[6].sprite_id == 385
		and small_monster_layers[7].sprite_id == 491,
		"Small monster view scales the effect and alternate head sprites",
	)


func _test_simulation_clock() -> void:
	var clock := Clock.new(0)
	var phases: Array[Dictionary] = []
	for unused in 25:
		phases.append(clock.advance_day())
	_check(phases[0].month_day == 1, "First simulation tick advances to day 1")
	_check(phases[0].actions == PackedStringArray(["power"]), "Day 1 schedules power")
	for month_day in range(3, 19):
		var phase := phases[month_day - 1]
		_check(phase.actions == PackedStringArray(["growth"]), "Day %d schedules growth" % month_day)
		_check(
			phase.growth_step == int((month_day - 3) / 4) % 4,
			"Day %d has the correct growth step" % month_day
		)
		_check(
			phase.growth_substep == (month_day + 1) % 4,
			"Day %d has the correct growth substep" % month_day
		)
	_check(phases[18].actions == PackedStringArray(["traffic"]), "Day 19 schedules traffic")
	_check(phases[19].actions == PackedStringArray(["water"]), "Day 20 schedules water")
	_check(phases[24].month_day == 0, "The 25th tick starts the next month")
	_check(
		phases[24].actions == PackedStringArray(["budget", "month_start"]),
		"Month start schedules budget work"
	)


func _test_scenarios(reference_root: String) -> void:
	var paths := _files_with_extension(reference_root.path_join("SCENARIO"), "SCN")
	_check(paths.size() == 18, "Supplied scenario count is 18")
	var legacy_count := 0
	var extended_count := 0
	for path in paths:
		var document := Sc2Document.load_path(path)
		var scenario := ScenarioModel.from_document(document)
		_check(scenario.is_valid(), "%s scenario model loads: %s" % [path.get_file(), scenario.load_error])
		if not scenario.is_valid():
			continue
		if scenario.format_size == ScenarioModel.LEGACY_SIZE:
			legacy_count += 1
		else:
			extended_count += 1
		_check(scenario.time_limit_months > 0, "%s has a positive time limit" % path.get_file())
		_check(not scenario.selection_description().is_empty(), "%s has selection text" % path.get_file())
		_check(not scenario.opening_description().is_empty(), "%s has opening text" % path.get_file())
		var picture := scenario.picture_indices()
		_check(picture.ok, "%s picture parses: %s" % [path.get_file(), picture.error])
		if picture.ok:
			_check(picture.width == 65, "%s picture width is 65" % path.get_file())
			_check(picture.height == 65 or picture.height == 66, "%s picture height is 65 or 66" % path.get_file())
			_check(
				picture.pixels.size() == picture.width * picture.height,
				"%s picture has the declared pixel count" % path.get_file()
			)
	_check(legacy_count == 15, "Fifteen supplied scenarios use the 52-byte SCEN layout")
	_check(extended_count == 3, "Three supplied scenarios use the 56-byte SCEN layout")

	var city_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(city_document)
	var goals := ScenarioModel.new()
	var all_disabled := goals.evaluate_goals(city)
	_check(all_disabled.ok and all_disabled.met, "Zero scenario goals are met")
	goals.cash_goal = all_disabled.values.cash_after_bonds + 1
	var cash_failure := goals.evaluate_goals(city)
	_check(not cash_failure.met, "Cash goal detects an insufficient city balance")
	_check(cash_failure.unmet == PackedStringArray(["cash"]), "Cash goal reports its exact failure")
	goals.cash_goal = 0
	goals.pollution_limit = maxi(city_document.misc_u32(0x34) - 1, 1)
	if city_document.misc_u32(0x34) > goals.pollution_limit:
		_check(
			goals.evaluate_goals(city).unmet.has("pollution"),
			"Pollution upper limit detects an excess"
		)

	var scenario_document := Sc2Document.load_path(paths[0])
	var countdown := ScenarioModel.from_document(scenario_document)
	var scenario_city := CityModel.from_document(scenario_document)
	_check(countdown.set_time_limit_months(1), "Scenario countdown stores one remaining month")
	countdown.city_size_goal = 0xffffffff
	var failure := ScenarioPhaseRunner.run(countdown, scenario_city)
	_check(
		failure.ok
		and failure.outcome == "failure"
		and failure.remaining_months == 0
		and failure.game_over_events[0].type == "scenario_failure",
		"An unmet scenario fails when its last month expires",
	)
	var reparsed_countdown := ScenarioModel.from_document(scenario_document)
	_check(reparsed_countdown.time_limit_months == 0, "Scenario countdown updates the SCEN chunk")

	var victory_document := Sc2Document.load_path(paths[0])
	var victory := ScenarioModel.from_document(victory_document)
	var victory_city := CityModel.from_document(victory_document)
	var victory_time := victory.time_limit_months
	victory.city_size_goal = 0
	victory.residential_goal = -2147483648
	victory.commercial_goal = -2147483648
	victory.industrial_goal = -2147483648
	victory.cash_goal = -2147483648
	victory.land_value_goal = -2147483648
	victory.life_expectancy_goal = 0
	victory.education_goal = 0
	victory.pollution_limit = 0
	victory.crime_limit = 0
	victory.traffic_limit = 0
	victory.first_building_id = 0
	victory.second_building_id = 0
	var won := ScenarioPhaseRunner.run(victory, victory_city)
	_check(
		won.ok
		and won.outcome == "victory"
		and won.game_over_events[0].type == "scenario_victory",
		"A scenario with all goals met emits victory",
	)
	_check(victory.time_limit_months == victory_time, "Scenario victory does not decrement time")

	var solvent := Bankruptcy.run(city)
	_check(solvent.ok and not solvent.bankrupt, "A solvent city passes the bankruptcy check")
	_check(city.set_funds(-100000), "Bankruptcy fixture reaches the exact limit")
	_check(not Bankruptcy.run(city).bankrupt, "Funds at negative one hundred thousand are allowed")
	_check(city.set_funds(-100001), "Bankruptcy fixture passes the strict limit")
	var bankrupt := Bankruptcy.run(city)
	_check(
		bankrupt.bankrupt
		and bankrupt.game_over_events.size() == 1
		and bankrupt.game_over_events[0].type == "bankruptcy",
		"Funds below negative one hundred thousand emit bankruptcy",
	)


func _test_random_and_power(reference_root: String) -> void:
	var random := Random.new(1)
	var sequence := PackedInt32Array()
	for unused in 5:
		sequence.append(random.next_u15())
	_check(
		sequence == PackedInt32Array([41, 18467, 6334, 26500, 19169]),
		"Simulation random sequence matches the executable runtime"
	)
	var lfsr := LfsrRandom.new(1)
	var lfsr_sequence := PackedInt32Array()
	for unused in 16:
		lfsr_sequence.append(lfsr.next_word())
	_check(
		lfsr_sequence == PackedInt32Array([
			2, 4, 8, 16, 32, 64, 128, 256,
			512, 1024, 2048, 4096, 8192, 16384, 32768, 7157,
		]),
		"Simulation LFSR sequence matches the executable",
	)
	_check(LfsrRandom.new(1).next_mask(0x03) == 2, "LFSR mask returns the low requested bits")

	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_building_id(10, 10, 0xc6), "Power test places a hydro plant")
	_check(city.set_building_id(10, 11, 0x0e), "Power test places a power line")
	_check(city.set_building_id(10, 12, 0x70), "Power test places a consumer")
	_check(city.set_building_id(20, 20, 0x70), "Power test places a disconnected consumer")
	for point in [Vector2i(10, 10), Vector2i(10, 11), Vector2i(10, 12), Vector2i(20, 20)]:
		_check(city.set_tile_flag(point.x, point.y, 0x80, true), "Power test tile is powerable")
	var result := Power.run(city, Random.new(1))
	_check(result.ok, "Power phase completes: %s" % result.error)
	if result.ok:
		_check(result.generation == 40, "Hydro plant generates 40 power units")
		_check(result.consumers == 1, "Connected component has one consumer")
		_check(result.supplied_consumers == 1, "Connected consumer receives power")
		_check(result.usage_percent == 2, "Power usage percentage uses integer division")
		_check(city.is_powered(10, 10), "Power source is marked powered")
		_check(city.is_powered(10, 11), "Power line is marked powered")
		_check(city.is_powered(10, 12), "Connected consumer is marked powered")
		_check(not city.is_powered(20, 20), "Disconnected consumer is not powered")


func _test_water(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_building_id(30, 30, 0xdc), "Water test places a pump")
	_check(city.set_building_id(30, 31, 0x00), "Water test clears a pipe tile")
	_check(city.set_building_id(30, 32, 0x70), "Water test places a consumer")
	_check(city.set_building_id(40, 40, 0x70), "Water test places a disconnected consumer")
	for point in [Vector2i(30, 30), Vector2i(30, 31), Vector2i(30, 32), Vector2i(40, 40)]:
		_check(city.set_tile_flag(point.x, point.y, 0x20, true), "Water test tile is piped")
	_check(city.set_tile_flag(30, 30, 0x40, true), "Water pump is powered")
	_check(city.set_tile_flag(29, 30, 0x04, true), "Fresh water is next to the pump")
	_check(city.set_tile_flag(29, 30, 0x01, false), "Pump water is not salt water")
	var expected_supply := int((document.misc_u32(0x68) & 0xff) / 2) + (
		document.misc_u32(0x0e40) * 5
	) + 10
	var result := Water.run(city)
	_check(result.ok, "Water phase completes: %s" % result.error)
	if result.ok:
		_check(result.supply == expected_supply, "Pump supply uses rain, water level, and fresh water")
		_check(result.consumers == 1, "Water component has one consumer")
		_check(result.watered_consumers == 1, "Connected consumer receives water")
		_check(city.is_watered(30, 30), "Powered pump is marked watered")
		_check(city.is_watered(30, 31), "Connected pipe is marked watered")
		_check(city.is_watered(30, 32), "Connected consumer is marked watered")
		_check(not city.is_watered(40, 40), "Disconnected consumer is not watered")


func _test_simulation_engine(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_age_in_days(0), "Simulation engine test resets the city day")
	var engine := Simulation.new(city, 1, 7)
	_check(engine.lfsr_random.state == 7, "Simulation engine accepts an explicit LFSR seed")
	var day_one := engine.advance_day()
	_check(day_one.ok, "Simulation engine advances day one")
	_check(day_one.day == 1 and city.age_in_days() == 1, "Simulation engine stores the new day")
	_check(day_one.applied == PackedStringArray(["power"]), "Simulation engine applies power on day one")
	_check(day_one.pending.is_empty(), "Day one has no unimplemented scheduled phase")
	_check(engine.lfsr_random.state == 7, "Non-growth phases preserve the LFSR state")
	var day_two := engine.advance_day()
	_check(day_two.ok, "Simulation engine advances day two")
	_check(
		day_two.applied == PackedStringArray(["pollution_terrain_land_value"]),
		"Simulation engine applies the combined day-two scan"
	)
	_check(day_two.pending.is_empty(), "Day two has no unimplemented scheduled phase")
	_check(engine.developed_tiles >= 0, "Simulation engine retains the developed-tile count")
	var day_three := engine.advance_day()
	_check(day_three.ok, "Simulation engine advances the first growth day")
	_check(day_three.phase_results.has("growth"), "Simulation engine runs the RCI growth core")
	_check(
		day_three.applied == PackedStringArray(["growth"]) and day_three.pending.is_empty(),
		"Simulation engine completes the full growth partition",
	)
	_check(engine.lfsr_random.state != 7, "Growth continues the engine LFSR sequence")
	var latest := day_three
	while latest.day < 19:
		latest = engine.advance_day()
	_check(latest.applied == PackedStringArray(["traffic"]), "Simulation engine applies traffic on day 19")
	_check(latest.pending.is_empty(), "Day 19 has no unimplemented scheduled phase")
	latest = engine.advance_day()
	_check(latest.applied == PackedStringArray(["water"]), "Simulation engine applies water on day 20")
	_check(latest.pending.is_empty(), "Day 20 has no unimplemented scheduled phase")
	latest = engine.advance_day()
	_check(
		latest.applied == PackedStringArray(["rci_demand", "education_health", "graphs"]),
		"Simulation engine applies demand, demographics, and graphs on day 21",
	)
	_check(latest.pending.is_empty(), "Day 21 has no unimplemented scheduled phase")
	latest = engine.advance_day()
	_check(latest.phase_results.has("milestones"), "Simulation engine runs milestones on day 22")
	_check(
		latest.applied == PackedStringArray(["milestones", "scenario", "bankruptcy"])
		and latest.pending.is_empty(),
		"Simulation engine applies all normal day-22 checks",
	)
	while latest.day < 25:
		latest = engine.advance_day()
	_check(
		latest.applied == PackedStringArray(["budget", "month_start"]),
		"Simulation engine applies budget before month start on day 25",
	)
	_check(latest.pending.is_empty(), "Normal month-start budget work is complete")
	_check(latest.phase_results.has("budget"), "Simulation engine exposes the budget result")

	var annual_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var annual_city := CityModel.from_document(annual_document)
	_check(annual_city.set_age_in_days(299), "Annual engine fixture selects the last day")
	_check(annual_document.set_misc_u32(0x0e3c, 1), "Annual engine fixture sets year end")
	_check(annual_document.set_misc_u32(0x0ff0, 0), "Annual engine fixture disables auto budget")
	var annual_engine := Simulation.new(annual_city, 1, 7, 13)
	annual_engine.bus_passengers = 11
	annual_engine.rail_passengers = 12
	annual_engine.subway_passengers = 13
	var annual_request := annual_engine.advance_day()
	_check(
		annual_request.ok
		and annual_request.day == 300
		and annual_request.interaction_requests.size() == 1
		and annual_request.interaction_requests[0].type == "annual_budget",
		"Simulation engine defers a manual annual budget",
	)
	var rejected_advance := annual_engine.advance_day()
	_check(
		not rejected_advance.ok and annual_city.age_in_days() == 300,
		"Simulation engine cannot skip a pending annual budget",
	)
	var annual_resolution := annual_engine.resolve_annual_budget(
		annual_request.interaction_requests[0].funding_values, true
	)
	_check(annual_resolution.ok, "Simulation engine resolves the annual budget")
	_check(
		annual_resolution.applied == PackedStringArray(["budget", "month_start"])
		and annual_resolution.pending.is_empty(),
		"Annual resolution completes the budget and microsimulation work",
	)
	_check(annual_document.misc_u32(0x0ff0) == 1, "Annual resolution stores Auto Budget")
	_check(
		annual_resolution.phase_results.has("annual_microsim")
		and annual_resolution.phase_results.annual_microsim.complete,
		"Annual resolution runs the facility-statistics phase",
	)
	_check(
		annual_engine.bus_passengers == 0
		and annual_engine.rail_passengers == 0
		and annual_engine.subway_passengers == 0,
		"Annual resolution clears the engine passenger counters",
	)

	var military_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var military_city := CityModel.from_document(military_document)
	_check(military_city.set_age_in_days(21), "Military engine fixture selects day 21")
	_check(military_document.set_misc_u32(0x0020, 3), "Military engine fixture sets progression")
	_check(military_document.set_misc_u32(0x102c, 60001), "Military engine fixture sets population")
	_check(military_city.set_funds(-100001), "Military engine fixture sets bankrupt funds")
	var military_engine := Simulation.new(military_city, 1, 7, 13)
	var military_request := military_engine.advance_day()
	_check(
		military_request.ok
		and military_request.day == 22
		and military_request.interaction_requests.size() == 1
		and military_request.interaction_requests[0].type == "military_proposal"
		and military_request.pending == PackedStringArray(["milestones", "scenario", "bankruptcy"]),
		"Simulation engine blocks the remaining day-22 checks on a military proposal",
	)
	_check(
		not military_engine.terminal_state and military_document.misc_u32(0x0020) == 4,
		"The pending proposal stores its milestone but defers bankruptcy",
	)
	var rejected_military_advance := military_engine.advance_day()
	_check(
		not rejected_military_advance.ok and military_city.age_in_days() == 22,
		"Simulation engine cannot skip a pending military proposal",
	)
	var military_resolution := military_engine.resolve_military_proposal(false)
	_check(
		military_resolution.ok
		and military_resolution.applied == PackedStringArray(["milestones", "scenario", "bankruptcy"])
		and military_resolution.pending.is_empty()
		and military_resolution.phase_results.military_proposal.base_type == MilitaryProposal.BASE_DECLINED,
		"A military decision resumes and completes the day-22 schedule",
	)
	_check(
		military_engine.terminal_state
		and military_resolution.phase_results.bankruptcy.game_over_events.size() == 1,
		"Deferred bankruptcy runs after the military decision",
	)

	var monster_scenario_document := Sc2Document.load_path(reference_root.path_join("SCENARIO/ATLANTA.SCN"))
	var monster_scenario_city := CityModel.from_document(monster_scenario_document)
	_check(monster_scenario_city.set_age_in_days(0), "Monster scenario engine fixture resets the day")
	_check(monster_scenario_document.set_misc_u32(0x0004, 1), "Monster scenario engine fixture selects city mode")
	var monster_scenario_engine := Simulation.new(monster_scenario_city, 1, 7, 13)
	var monster_start := monster_scenario_engine.advance_day()
	_check(
		monster_start.ok
		and monster_start.phase_results.has("disaster_start")
		and monster_start.phase_results.disaster_start.disaster_type == DisasterStart.DISASTER_MONSTER
		and monster_start.phase_results.disaster_start.started
		and monster_scenario_engine.active_disaster_type == DisasterStart.DISASTER_MONSTER,
		"A scenario starts its queued monster after the first calendar tick",
	)
	_check(
		monster_scenario_city.city_mode() == 2
		and monster_scenario_city.disaster_type() == 0,
		"A started scenario disaster clears the trigger and stores disaster mode",
	)
	var blocked_disaster_day := monster_scenario_engine.advance_day()
	_check(
		not blocked_disaster_day.ok and monster_scenario_city.age_in_days() == 1,
		"An active scenario disaster blocks direct calendar advancement",
	)
	var monster_things := _filled_bytes(CityState.THING_COUNT * CityState.THING_RECORD_SIZE, 0)
	_check(monster_scenario_document.find_chunk("XTHG").set_decoded_payload(monster_things), "Monster scenario fixture ends the moving object")
	var ended_monster := monster_scenario_engine.advance_disaster_tick()
	_check(
		ended_monster.ok
		and ended_monster.complete
		and ended_monster.ended_type == DisasterStart.DISASTER_MONSTER
		and monster_scenario_engine.active_disaster_type == 0
		and monster_scenario_city.city_mode() == 1,
		"The disaster controller restores city mode after the monster ends",
	)

	var unsupported_scenario_document := Sc2Document.load_path(reference_root.path_join("SCENARIO/BARCELON.SCN"))
	var unsupported_scenario_city := CityModel.from_document(unsupported_scenario_document)
	_check(unsupported_scenario_city.set_age_in_days(0), "Unsupported scenario fixture resets the day")
	var unsupported_scenario_engine := Simulation.new(unsupported_scenario_city, 1, 7, 13)
	var unsupported_start := unsupported_scenario_engine.advance_day()
	_check(
		unsupported_start.ok
		and unsupported_start.pending.has("disaster_start")
		and not unsupported_start.complete
		and unsupported_scenario_engine.unsupported_disaster_type == 9,
		"An unsupported scenario disaster stays explicit in the engine result",
	)


func _test_game_speed_controller(reference_root: String) -> void:
	var paused_document := Sc2Document.load_path(reference_root.path_join("CITIES/STARTER.SC2"))
	var paused_city := CityModel.from_document(paused_document)
	_check(paused_city.simulation_speed() == 1, "STARTER stores the paused simulation speed")
	_check(paused_city.set_age_in_days(0), "Speed fixture resets the city day")
	var paused_engine := Simulation.new(paused_city, 1, 7, 13)
	var paused := GameSpeed.new(paused_engine)
	_check(paused.speed == GameSpeed.Speed.PAUSED, "Speed controller loads the saved speed")
	var paused_result := paused.advance_time(1600.0, 1600)
	_check(paused_result.ok and paused_result.base_ticks == 8, "Pause retains the 200 ms base timer")
	_check(
		paused_result.day_results.is_empty() and paused_result.moving_results.is_empty(),
		"Pause stops days and moving things",
	)
	_check(paused.simulation_ready and paused_city.age_in_days() == 0, "Pause retains a pending day")
	_check(not paused.set_speed(0) and not paused.set_speed(6), "Speed rejects invalid values")
	_check(paused.set_speed(GameSpeed.Speed.TURTLE), "Speed changes to Turtle")
	_check(paused_city.simulation_speed() == 2, "Speed changes update the saved MISC field")
	var resumed := paused.advance_time(0.0, 1600)
	_check(
		resumed.ok and resumed.day_results.size() == 1 and paused_city.age_in_days() == 1,
		"Turtle consumes a day that became ready during pause",
	)
	var turtle_early := paused.advance_time(799.0, 2399)
	_check(
		turtle_early.base_ticks == 3
		and turtle_early.moving_results.size() == 3
		and turtle_early.day_results.is_empty(),
		"Turtle waits for four base ticks",
	)
	var turtle_due := paused.advance_time(1.0, 2400)
	_check(
		turtle_due.base_ticks == 1
		and turtle_due.moving_results.size() == 1
		and turtle_due.day_results.size() == 1
		and paused_city.age_in_days() == 2,
		"Turtle advances one day every 800 ms",
	)

	var llama_city := CityModel.from_document(Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2")))
	_check(llama_city.set_age_in_days(0), "Llama fixture resets the city day")
	_check(llama_city.set_simulation_speed(3), "Llama fixture stores its speed")
	var llama := GameSpeed.new(Simulation.new(llama_city, 1, 7, 13))
	var llama_early := llama.advance_time(399.0, 399)
	_check(
		llama_early.base_ticks == 1 and llama_early.day_results.is_empty(),
		"Llama waits for two base ticks",
	)
	var llama_due := llama.advance_time(1.0, 400)
	_check(
		llama_due.day_results.size() == 1 and llama_city.age_in_days() == 1,
		"Llama advances one day every 400 ms",
	)

	var cheetah_city := CityModel.from_document(Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2")))
	_check(cheetah_city.set_age_in_days(0), "Cheetah fixture resets the city day")
	_check(cheetah_city.set_simulation_speed(4), "Cheetah fixture stores its speed")
	var cheetah := GameSpeed.new(Simulation.new(cheetah_city, 1, 7, 13))
	var cheetah_due := cheetah.advance_time(200.0, 200)
	_check(
		cheetah_due.moving_results.size() == 1
		and cheetah_due.day_results.size() == 1
		and cheetah_city.age_in_days() == 1,
		"Cheetah advances moving things and one day every 200 ms",
	)
	var cheetah_suspended := cheetah.advance_time(200.0, 400, true)
	_check(
		cheetah_suspended.base_ticks == 1
		and cheetah_suspended.moving_results.is_empty()
		and cheetah_suspended.day_results.is_empty()
		and cheetah.simulation_ready,
		"A map drag keeps timer phase but suspends simulation work",
	)
	var cheetah_resumed := cheetah.advance_time(0.0, 400)
	_check(
		cheetah_resumed.day_results.size() == 1 and cheetah_city.age_in_days() == 2,
		"Simulation consumes the ready day after a map drag",
	)

	var swallow_city := CityModel.from_document(Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2")))
	_check(swallow_city.set_age_in_days(0), "Swallow fixture resets the city day")
	_check(swallow_city.set_simulation_speed(5), "Swallow fixture stores its speed")
	var swallow := GameSpeed.new(Simulation.new(swallow_city, 1, 7, 13))
	var swallow_due := swallow.advance_time(200.0, 200)
	_check(
		swallow_due.day_results.size() == 1 and swallow_city.age_in_days() == 1,
		"African Swallow advances on the 200 ms timer",
	)
	var swallow_idle := swallow.advance_time(0.0, 200)
	_check(
		swallow_idle.moving_results.is_empty()
		and swallow_idle.day_results.size() == 1
		and swallow_city.age_in_days() == 2,
		"African Swallow advances again on the next idle cycle",
	)

	var budget_city := CityModel.from_document(Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2")))
	_check(budget_city.set_age_in_days(24), "Controller budget fixture selects day 24")
	_check(budget_city.set_simulation_speed(4), "Controller budget fixture stores Cheetah speed")
	_check(budget_city.set_funds(100000), "Controller budget fixture sets ordinance funds")
	_check(budget_city.document.set_misc_u32(0x0fa0, 0), "Controller budget fixture clears ordinances")
	_check(budget_city.document.set_misc_u32(0x1000, 0), "Controller budget fixture enables random events")
	var budget_controller := GameSpeed.new(Simulation.new(budget_city, 3, 7, 13))
	var budget_tick := budget_controller.advance_time(200.0, 200)
	_check(
		budget_tick.ok
		and budget_tick.day_results.size() == 1
		and budget_tick.news_items.size() == 1
		and budget_tick.news_items[0].type == 0x29
		and budget_tick.news_items[0].argument == 14,
		"Controller forwards monthly ordinance news",
	)

	var annual_city := CityModel.from_document(Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2")))
	_check(annual_city.set_age_in_days(299), "Controller annual fixture selects the last day")
	_check(annual_city.set_simulation_speed(4), "Controller annual fixture stores Cheetah speed")
	_check(annual_city.document.set_misc_u32(0x0e3c, 1), "Controller annual fixture sets year end")
	_check(annual_city.document.set_misc_u32(0x0ff0, 0), "Controller annual fixture disables Auto Budget")
	var annual_controller := GameSpeed.new(Simulation.new(annual_city, 1, 7, 13))
	var annual_request := annual_controller.advance_time(200.0, 200)
	_check(
		annual_request.ok
		and annual_request.interaction_requests.size() == 1
		and annual_controller.interaction_blocked,
		"Controller blocks on the annual budget interaction",
	)
	var blocked_tick := annual_controller.advance_time(200.0, 400)
	_check(
		blocked_tick.ok
		and blocked_tick.base_ticks == 1
		and blocked_tick.day_results.is_empty()
		and blocked_tick.moving_results.is_empty(),
		"Annual budget interaction retains timer phase and suspends work",
	)
	var annual_resolution := annual_controller.resolve_annual_budget(
		annual_request.interaction_requests[0].funding_values, false
	)
	_check(
		annual_resolution.ok
		and not annual_controller.interaction_blocked
		and annual_resolution.day_results.size() == 1,
		"Controller resumes after annual budget resolution",
	)

	var military_city := CityModel.from_document(Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2")))
	_check(military_city.set_age_in_days(21), "Controller military fixture selects day 21")
	_check(military_city.set_simulation_speed(4), "Controller military fixture stores Cheetah speed")
	_check(military_city.document.set_misc_u32(0x0020, 3), "Controller military fixture sets progression")
	_check(military_city.document.set_misc_u32(0x102c, 60001), "Controller military fixture sets population")
	var military_controller := GameSpeed.new(Simulation.new(military_city, 1, 7, 13))
	var military_request := military_controller.advance_time(200.0, 200)
	_check(
		military_request.ok
		and military_request.interaction_requests.size() == 1
		and military_controller.interaction_blocked,
		"Controller blocks on the military proposal interaction",
	)
	var military_resolution := military_controller.resolve_military_proposal(false)
	_check(
		military_resolution.ok
		and not military_controller.interaction_blocked
		and military_resolution.day_results.size() == 1
		and military_resolution.pending_actions.is_empty(),
		"Controller resumes after the military decision",
	)

	var monster_city := CityModel.from_document(Sc2Document.load_path(reference_root.path_join("SCENARIO/ATLANTA.SCN")))
	_check(monster_city.set_age_in_days(0), "Controller monster scenario fixture resets the day")
	_check(monster_city.set_simulation_speed(4), "Controller monster scenario fixture stores Cheetah speed")
	var monster_controller := GameSpeed.new(Simulation.new(monster_city, 1, 7, 13))
	var monster_start := monster_controller.advance_time(200.0, 200)
	_check(
		monster_start.ok
		and monster_start.day_results.size() == 1
		and monster_start.sound_events.has(DisasterStart.SOUND_SIREN)
		and not monster_start.view_center_requests.is_empty(),
		"Controller forwards scenario monster start effects",
	)
	var monster_tick := monster_controller.advance_time(200.0, 400)
	_check(
		monster_tick.ok
		and monster_tick.moving_results.size() == 1
		and monster_tick.disaster_results.size() == 1
		and monster_city.age_in_days() == 1,
		"Controller updates an active monster without advancing the calendar",
	)

	var terminal_city := CityModel.from_document(Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2")))
	_check(terminal_city.set_age_in_days(21), "Terminal fixture selects day 21")
	_check(terminal_city.set_simulation_speed(4), "Terminal fixture stores Cheetah speed")
	_check(terminal_city.document.set_misc_u32(0x0020, 10), "Terminal fixture exhausts milestones")
	_check(terminal_city.set_funds(-100001), "Terminal fixture sets bankrupt funds")
	var terminal_controller := GameSpeed.new(Simulation.new(terminal_city, 1, 7, 13))
	var terminal_tick := terminal_controller.advance_time(200.0, 200)
	_check(
		terminal_tick.ok
		and terminal_tick.game_over_events.size() == 1
		and terminal_tick.game_over_events[0].type == "bankruptcy"
		and terminal_controller.terminal_blocked,
		"Controller exposes bankruptcy and enters terminal state",
	)
	var terminal_wait := terminal_controller.advance_time(200.0, 400)
	_check(
		terminal_wait.ok
		and terminal_wait.base_ticks == 1
		and terminal_wait.day_results.is_empty()
		and terminal_wait.moving_results.is_empty(),
		"Terminal state keeps timer phase and stops simulation work",
	)


func _test_month_start(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var original_values := PackedInt32Array()
	for index in 8:
		var value := (index + 1) * 13
		original_values.append(value)
		_check(
			document.set_misc_i32(0x05f0 + index * 4, value),
			"Month-start fixture sets zone population %d" % index,
		)
	_check(document.set_misc_i32(0x05ec, 0x12345678), "Month-start fixture sets preceding data")
	_check(document.set_misc_i32(0x0610, 0x23456789), "Month-start fixture sets following data")
	var city := CityModel.from_document(document)
	var result := MonthStart.run(city)
	_check(result.ok, "Month-start phase completes: %s" % result.error)
	_check(result.cleared_population_fields == 8, "Month-start phase reports eight cleared fields")
	for index in 8:
		_check(document.misc_i32(0x05f0 + index * 4) == 0, "Month-start clears zone population %d" % index)
	_check(document.misc_i32(0x05ec) == 0x12345678, "Month-start preserves preceding MISC data")
	_check(document.misc_i32(0x0610) == 0x23456789, "Month-start preserves following MISC data")


func _test_budget_phase(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_age_in_days(0), "Budget fixture selects January")
	var cleared_counts := true
	for tile_id in 256:
		cleared_counts = (
			document.set_misc_i32(0x01f0 + tile_id * 4, 0)
			and cleared_counts
		)
	_check(cleared_counts, "Budget fixture clears all tile counts")
	_check(document.set_misc_u32(0x0fe8, 4), "Budget fixture sets the subway count")
	for budget_id in 16:
		_check(
			document.set_misc_i32(0x077c + budget_id * 0x6c, 0)
			and document.set_misc_i32(0x077c + budget_id * 0x6c + 4, 0)
			and document.set_misc_i32(0x077c + budget_id * 0x6c + 8, 0),
			"Budget fixture clears record %d" % budget_id,
		)
	_check(document.set_misc_i32(0x077c, 900), "Budget fixture sets residential population")
	_check(document.set_misc_i32(0x0780, 7), "Budget fixture sets residential tax")
	_check(document.set_misc_i32(0x0bb4, 123), "Budget fixture sets prior road costs")
	_check(document.set_misc_i32(0x0bb8, 80), "Budget fixture sets road funding")
	_check(document.set_misc_u32(0x0fa0, (1 << 0) | (1 << 4)), "Budget fixture enables ordinances")
	for entry in [
		[0x1d, 2], [0x3f, 3], [0x45, 5], [0x51, 7], [0x61, 11], [0x6a, 13],
		[0x6c, 17], [0xd1, 18], [0xd2, 27], [0xd3, 36], [0xd6, 45], [0xd9, 32],
		[0xe9, 19], [0xec, 8], [0xed, 6],
	]:
		_check(
			document.set_misc_i32(0x01f0 + int(entry[0]) * 4, int(entry[1])),
			"Budget fixture sets tile count 0x%02X" % int(entry[0]),
		)
	var result := Budget.run(city, SequenceRandom.new([1]))
	_check(result.ok, "Budget phase completes: %s" % result.error)
	_check(document.misc_i32(0x0788) == 900, "Budget stores January residential count")
	_check(document.misc_i32(0x078c) == 7, "Budget stores January residential tax")
	_check(document.misc_i32(0x0784) == 6300, "Budget accumulates funded residential tax")
	_check(document.misc_i32(0x0bc0) == 123, "Budget stores prior January road costs")
	_check(document.misc_i32(0x0bc4) == 80, "Budget stores prior January road funding")
	_check(document.misc_i32(0x0bbc) == 9840, "Budget accumulates funded road costs")
	_check(result.current_costs[3] == 600, "Budget calculates active ordinance cost")
	_check(result.current_costs[4] == document.misc_i32(0x18), "Budget copies the bond count")
	_check(
		result.current_costs.slice(5, 10) == PackedInt32Array([3, 4, 2, 5, 2]),
		"Budget rebuilds service counts with the recovered footprint divisors",
	)
	_check(
		result.current_costs.slice(10, 16) == PackedInt32Array([510, 24, 20, 28, 23, 3]),
		"Budget rebuilds road, highway, bridge, rail, subway, and tunnel costs",
	)
	_check(document.misc_u32(0x0e3c) == 0, "January does not set the year-end flag")

	var december_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var december_city := CityModel.from_document(december_document)
	_check(december_city.set_age_in_days(275), "December budget fixture selects month 12")
	_check(december_document.set_misc_u32(0x0e3c, 0), "December budget fixture clears year end")
	var december := Budget.run(december_city, SequenceRandom.new([1]))
	_check(december.ok and december.month == 11, "December budget phase completes")
	_check(december_document.misc_u32(0x0e3c) == 1, "December sets the year-end flag")

	var annual_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var annual_city := CityModel.from_document(annual_document)
	_check(annual_city.set_age_in_days(300), "Annual budget fixture selects next January")
	_check(annual_city.set_funds(0), "Annual budget fixture clears funds")
	_check(annual_document.set_misc_u32(0x0e3c, 1), "Annual budget fixture sets year end")
	_check(annual_document.set_misc_u32(0x0ff0, 1), "Annual budget fixture enables auto budget")
	for budget_id in 16:
		_check(
			annual_document.set_misc_i32(0x077c + budget_id * 0x6c, 0)
			and annual_document.set_misc_i32(0x077c + budget_id * 0x6c + 4, 0)
			and annual_document.set_misc_i32(0x077c + budget_id * 0x6c + 8, 0),
			"Annual budget fixture clears record %d" % budget_id,
		)
	for entry in [[0, 900], [3, 900], [4, 1200], [5, 12], [10, 12000]]:
		_check(
			annual_document.set_misc_i32(0x077c + int(entry[0]) * 0x6c + 8, int(entry[1])),
			"Annual budget fixture sets year-to-date record %d" % int(entry[0]),
		)
	var annual := Budget.run(annual_city, SequenceRandom.new([1]))
	_check(annual.ok and annual.settled_year, "Budget settles the prior year in January")
	_check(annual_city.funds() == -1, "Budget applies the recovered annual divisors")
	_check(annual_document.misc_u32(0x0e3c) == 0, "Annual settlement clears year end")
	_check(
		annual.auto_budget_disabled and annual_document.misc_u32(0x0ff0) == 0,
		"Negative annual funds disable auto budget",
	)
	_check(
		annual.annual_microsim_update_pending and not annual.complete,
		"Annual microsimulation work stays visible",
	)

	var manual_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var manual_city := CityModel.from_document(manual_document)
	_check(manual_city.set_age_in_days(300), "Manual budget fixture selects January")
	_check(manual_document.set_misc_u32(0x0e3c, 1), "Manual budget fixture sets year end")
	_check(manual_document.set_misc_u32(0x0ff0, 0), "Manual budget fixture disables Auto Budget")
	var manual_before: PackedByteArray = manual_document.find_chunk("MISC").decoded_payload.duplicate()
	var manual := Budget.run(manual_city, SequenceRandom.new([1]))
	_check(
		manual.ok and manual.requires_annual_budget and not manual.complete,
		"Budget phase requests manual annual funding",
	)
	_check(
		manual_document.find_chunk("MISC").decoded_payload == manual_before,
		"A pending manual annual budget preserves MISC",
	)
	var funding_values := PackedInt32Array([
		8, 7, 6, 0, 0, 100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 50,
	])
	var stored_funding := Budget.set_funding(manual_city, funding_values, true)
	_check(stored_funding.ok, "Budget stores all funding values")
	_check(
		Budget.funding_values(manual_city) == funding_values,
		"Budget reads back all stored funding values",
	)
	_check(manual_document.misc_u32(0x0ff0) == 1, "Budget stores Auto Budget")
	var stored_misc: PackedByteArray = manual_document.find_chunk("MISC").decoded_payload.duplicate()
	var short_values := funding_values.duplicate()
	short_values.resize(15)
	var invalid_funding := Budget.set_funding(manual_city, short_values, false)
	_check(not invalid_funding.ok, "Budget rejects an incomplete funding array")
	_check(
		manual_document.find_chunk("MISC").decoded_payload == stored_misc,
		"A rejected funding update preserves MISC",
	)

	var ordinance_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var ordinance_city := CityModel.from_document(ordinance_document)
	_check(ordinance_city.set_age_in_days(25), "Ordinance fixture selects February")
	_check(ordinance_city.set_funds(60000), "Ordinance fixture sets sufficient funds")
	_check(ordinance_document.set_misc_u32(0x0fa0, 0), "Ordinance fixture clears ordinances")
	_check(ordinance_document.set_misc_u32(0x1000, 0), "Ordinance fixture enables random events")
	var ordinance := Budget.run(ordinance_city, SequenceRandom.new([0, 0, 5]))
	_check(ordinance.ok and ordinance.news_items.size() == 1, "Budget emits a random ordinance event")
	_check(
		ordinance_document.misc_u32(0x0fa0) == 1 << 5
		and ordinance.news_items[0].type == 0x29
		and ordinance.news_items[0].argument == 5,
		"Budget stores and reports the selected ordinance",
	)


func _test_milestone_phase(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(document.set_misc_u32(0x0020, 0), "Milestone fixture clears progression")
	_check(document.set_misc_u32(0x0078, 0), "Milestone fixture clears reward grants")
	_check(document.set_misc_u32(0x1020, 999999), "Milestone fixture sets arcology population")
	_check(document.set_misc_u32(0x102c, 2000), "Milestone fixture reaches the exact threshold")
	var exact := Milestones.run(city)
	_check(exact.ok and not exact.advanced, "A milestone needs population above its threshold")
	_check(document.misc_u32(0x0020) == 0, "Arcology population does not advance a milestone")

	_check(document.set_misc_u32(0x102c, 2001), "Milestone fixture exceeds the first threshold")
	var first := Milestones.run(city)
	_check(first.ok and first.advanced and first.progression == 1, "Milestone advances one level")
	_check(document.misc_u32(0x0078) == 1, "The first milestone grants the mayor house")
	_check(
		first.news_items.size() == 1
		and first.news_items[0].type == 3
		and first.news_items[0].argument == 0,
		"Milestone emits growth news with the old level",
	)

	_check(document.set_misc_u32(0x102c, 10001), "Milestone fixture exceeds the second threshold")
	var second := Milestones.run(city)
	_check(second.progression == 2, "A later milestone still advances only one level")
	_check(document.misc_u32(0x0078) == 3, "The second milestone preserves and adds reward bits")

	var military_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var military_city := CityModel.from_document(military_document)
	_check(military_document.set_misc_u32(0x0020, 3), "Military milestone fixture sets progression")
	_check(military_document.set_misc_u32(0x0078, 7), "Military milestone fixture sets prior rewards")
	_check(military_document.set_misc_u32(0x102c, 60001), "Military milestone fixture sets population")
	var military := Milestones.run(military_city)
	_check(
		military.ok
		and military.progression == 4
		and military.military_proposal_pending
		and not military.complete,
		"The fourth milestone keeps the military proposal visible",
	)
	_check(military_document.misc_u32(0x0078) == 7, "The military milestone does not grant a reward")

	_check(military_document.set_misc_u32(0x102c, 90001), "Llama milestone fixture sets population")
	var llama := Milestones.run(military_city)
	_check(llama.ok and llama.progression == 5 and llama.reward_id == 3, "The fifth milestone grants the llama dome")
	_check(military_document.misc_u32(0x0078) == 15, "The llama milestone stores reward bit three")

	var final_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var final_city := CityModel.from_document(final_document)
	_check(final_document.set_misc_u32(0x0020, 9), "Final milestone fixture sets progression")
	_check(final_document.set_misc_u32(0x102c, 10000001), "Final milestone fixture sets population")
	var final := Milestones.run(final_city)
	_check(final.ok and final.progression == 10, "The last recovered threshold advances progression")
	var exhausted := Milestones.run(final_city)
	_check(exhausted.ok and not exhausted.advanced, "Progression stops after the recovered threshold table")


func _test_military_proposal_phase(reference_root: String) -> void:
	var declined_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var declined_city := CityModel.from_document(declined_document)
	var declined := MilitaryProposal.resolve(declined_city, false, null)
	_check(declined.ok and not declined.accepted, "The player can decline a military proposal")
	_check(
		declined.base_type == MilitaryProposal.BASE_DECLINED
		and declined_document.misc_u32(MilitaryProposal.MISC_BASE_TYPE) == MilitaryProposal.BASE_DECLINED,
		"A declined proposal stores the original base type",
	)
	_check(declined.changed_indices.is_empty(), "A declined proposal does not change map zones")

	var air_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		_check(
			air_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(CityState.TILE_COUNT, 0)),
			"Air Force fixture clears %s" % chunk_id,
		)
	_check(
		air_document.find_chunk("ALTM").set_decoded_payload(_filled_bytes(CityState.TILE_COUNT * 2, 0)),
		"Air Force fixture levels the map",
	)
	_check(
		air_document.set_misc_u32(MilitaryProposal.MISC_TILE_COUNTS, CityState.TILE_COUNT),
		"Air Force fixture counts clear tiles",
	)
	_check(
		air_document.set_misc_u32(MilitaryProposal.MISC_MILITARY_TILE_COUNTS, 0),
		"Air Force fixture clears its military count",
	)
	var air_city := CityModel.from_document(air_document)
	var air_random := SequenceModuloRandom.new([10, 20])
	var air := MilitaryProposal.resolve(air_city, true, air_random)
	_check(
		air.ok
		and air.accepted
		and air.base_type == MilitaryProposal.BASE_AIR_FORCE
		and air.notice_id == MilitaryProposal.NOTICE_AIR_FORCE,
		"A level candidate becomes an Air Force base",
	)
	_check(
		air.site == Rect2i(10, 20, 8, 8)
		and air.view_center_requests == [Vector2i(14, 24)]
		and air_random.position == 2,
		"The Air Force search accepts the first suitable eight-by-eight plot",
	)
	_check(air.changed_indices.size() == 64, "The Air Force proposal zones all clear plot tiles")
	_check(
		air_city.zone_id(10, 20) == MilitaryProposal.ZONE_MILITARY
		and air_city.zone_id(17, 27) == MilitaryProposal.ZONE_MILITARY,
		"The Air Force proposal stores military zones at both plot corners",
	)
	_check(
		air_document.misc_u32(MilitaryProposal.MISC_TILE_COUNTS) == CityState.TILE_COUNT - 64
		and air_document.misc_u32(MilitaryProposal.MISC_MILITARY_TILE_COUNTS) == 64,
		"The Air Force proposal moves each zoned tile into the military count",
	)

	var army_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		_check(
			army_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(CityState.TILE_COUNT, 0)),
			"Army fixture clears %s" % chunk_id,
		)
	var army_altitude := _filled_bytes(CityState.TILE_COUNT * 2, 0)
	army_altitude[(10 * CityState.MAP_SIZE + 21) * 2 + 1] = 1
	_check(
		army_document.find_chunk("ALTM").set_decoded_payload(army_altitude),
		"Army fixture makes one plot tile uneven",
	)
	var army_city := CityModel.from_document(army_document)
	var army := MilitaryProposal.resolve(army_city, true, SequenceModuloRandom.new([10, 20]))
	_check(
		army.ok
		and army.base_type == MilitaryProposal.BASE_ARMY
		and army.notice_id == MilitaryProposal.NOTICE_ARMY,
		"A suitable uneven candidate becomes an Army base",
	)

	var missile_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var missile_buildings := _filled_bytes(CityState.TILE_COUNT, 0x0d)
	var expected_sites: Array[Rect2i] = []
	for origin in [Vector2i(5, 5), Vector2i(15, 15), Vector2i(25, 25), Vector2i(35, 35), Vector2i(45, 45), Vector2i(55, 55)]:
		expected_sites.append(Rect2i(origin, Vector2i(3, 3)))
		for x in range(origin.x, origin.x + 3):
			for y in range(origin.y, origin.y + 3):
				missile_buildings[x * CityState.MAP_SIZE + y] = 0
	_check(
		missile_document.find_chunk("XBLD").set_decoded_payload(missile_buildings),
		"Missile fixture installs six clear sites",
	)
	for chunk_id in ["XTER", "XZON", "XUND", "XBIT"]:
		_check(
			missile_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(CityState.TILE_COUNT, 0)),
			"Missile fixture clears %s" % chunk_id,
		)
	_check(
		missile_document.find_chunk("ALTM").set_decoded_payload(_filled_bytes(CityState.TILE_COUNT * 2, 0)),
		"Missile fixture levels the map",
	)
	_check(
		missile_document.set_misc_u32(MilitaryProposal.MISC_TILE_COUNTS, 54)
		and missile_document.set_misc_u32(MilitaryProposal.MISC_MILITARY_TILE_COUNTS, 0),
		"Missile fixture initializes tile counts",
	)
	var missile_values: Array[int] = []
	for _attempt in 24:
		missile_values.append_array([100, 100])
	for site in expected_sites:
		missile_values.append_array([site.position.x, site.position.y])
	var missile_random := SequenceModuloRandom.new(missile_values)
	var missile_city := CityModel.from_document(missile_document)
	var missile := MilitaryProposal.resolve(missile_city, true, missile_random)
	_check(
		missile.ok
		and missile.accepted
		and missile.base_type == MilitaryProposal.BASE_MISSILE_SILOS
		and missile.notice_id == MilitaryProposal.NOTICE_MISSILE_SILOS,
		"Six small candidates become missile silos when no large plot is suitable",
	)
	_check(
		missile.sites == expected_sites
		and missile.site == expected_sites[-1]
		and missile.view_center_requests == [expected_sites[-1].position]
		and missile_random.position == 60,
		"The missile search preserves the executable attempt order and final view target",
	)
	_check(missile.changed_indices.size() == 54, "The missile proposal zones six three-by-three sites")
	_check(
		missile_document.misc_u32(MilitaryProposal.MISC_TILE_COUNTS) == 0
		and missile_document.misc_u32(MilitaryProposal.MISC_MILITARY_TILE_COUNTS) == 54,
		"The missile proposal moves all site tiles into the military count",
	)


func _test_disaster_start_phase(reference_root: String) -> void:
	var monster_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var things := _filled_bytes(CityState.THING_COUNT * CityState.THING_RECORD_SIZE, 0)
	things[CityState.THING_RECORD_SIZE] = 14
	things[CityState.THING_RECORD_SIZE + 3] = 20
	things[CityState.THING_RECORD_SIZE + 4] = 20
	things[CityState.THING_RECORD_SIZE + 10] = 42
	_check(monster_document.find_chunk("XTHG").set_decoded_payload(things), "Monster start fixture installs an occupied record")
	var text := _filled_bytes(CityState.TILE_COUNT, 0)
	text[20 * CityState.MAP_SIZE + 20] = 202
	_check(monster_document.find_chunk("XTXT").set_decoded_payload(text), "Monster start fixture links the occupied record")
	var monster_city := CityModel.from_document(monster_document)
	var monster_random := SequenceRandom.new([3, 4, 0, 2])
	var monster := DisasterStart.start(monster_city, DisasterStart.DISASTER_MONSTER, Vector2i(20, 20), monster_random)
	_check(
		monster.ok
		and monster.started
		and monster.complete
		and monster.record == 1
		and monster.sound_events == [DisasterStart.SOUND_SIREN]
		and monster.view_center_requests == [Vector2i(20, 20)],
		"Monster disaster replaces an occupied moving object and reports runtime effects",
	)
	var monster_thing := monster_city.thing(1)
	_check(
		monster_thing.type == 5
		and monster_thing.direction == 2
		and monster_thing.state == 0
		and monster_thing.x == 20
		and monster_thing.y == 20
		and monster_thing.z == 15
		and monster_thing.px == 8
		and monster_thing.py == 8,
		"Monster disaster stores its fixed initial XTHG fields",
	)
	_check(
		monster_thing.dx == 3
		and monster_thing.dy == 4
		and monster_thing.label == 42
		and monster_thing.goal == 3
		and monster_city.text_overlay_id(20, 20) == 202,
		"Monster disaster stores its random fields, prior label, goal, and XTXT link",
	)
	_check(DisasterStart.has_active_object(monster_city, DisasterStart.DISASTER_MONSTER), "Monster activity is visible to the disaster controller")

	var tornado_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	_check(tornado_document.find_chunk("XTHG").set_decoded_payload(_filled_bytes(CityState.THING_COUNT * CityState.THING_RECORD_SIZE, 0)), "Tornado start fixture clears XTHG")
	_check(tornado_document.find_chunk("XTXT").set_decoded_payload(_filled_bytes(CityState.TILE_COUNT, 0)), "Tornado start fixture clears XTXT")
	var tornado_city := CityModel.from_document(tornado_document)
	_check(tornado_city.set_land_altitude(127, 0, 11), "Tornado start fixture raises the clamped point")
	var tornado := DisasterStart.start(tornado_city, DisasterStart.DISASTER_TORNADO, Vector2i(200, -3), SequenceRandom.new([5, 6, 7]))
	var tornado_thing := tornado_city.thing(1)
	_check(
		tornado.ok
		and tornado.started
		and tornado.point == Vector2i(127, 0)
		and tornado_thing.type == 15
		and tornado_thing.direction == 5
		and tornado_thing.z == 11,
		"Tornado disaster clamps its target and stores direction and terrain height",
	)
	_check(
		tornado_thing.dx == 6
		and tornado_thing.dy == 7
		and tornado_city.text_overlay_id(127, 0) == 202,
		"Tornado disaster stores its random animation fields and XTXT link",
	)

	var unsupported_before: PackedByteArray = tornado_document.find_chunk("XTHG").decoded_payload.duplicate()
	var unsupported := DisasterStart.start(tornado_city, 9, Vector2i(10, 10), SequenceRandom.new([]))
	_check(
		unsupported.ok and not unsupported.started and not unsupported.complete,
		"An unimplemented disaster remains explicit",
	)
	_check(
		tornado_document.find_chunk("XTHG").decoded_payload == unsupported_before,
		"An unimplemented disaster does not change moving objects",
	)


func _test_annual_microsim_phase(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	microsims[1 * 8] = 0xec
	microsims[2 * 8] = 0xed
	microsims[2 * 8 + 4] = 0x12
	microsims[2 * 8 + 5] = 0x34
	microsims[3 * 8] = 0xe9
	microsims[3 * 8 + 4] = 0x56
	microsims[3 * 8 + 5] = 0x78
	microsims[4 * 8] = 0xc6
	microsims[5 * 8] = 0xc8
	microsims[6 * 8] = 0xd0
	microsims[7 * 8] = 0xd4
	microsims[8 * 8] = 0xd5
	microsims[8 * 8 + 4] = 0x00
	microsims[8 * 8 + 5] = 0x64
	microsims[9 * 8] = 0xf5
	microsims[9 * 8 + 4] = 0x03
	microsims[9 * 8 + 5] = 0xe8
	_check(document.find_chunk("XMIC").set_decoded_payload(microsims), "Annual XMIC fixture installs facility records")
	_check(document.set_misc_u32(0x01f0 + 0xec * 4, 12), "Annual XMIC fixture counts bus tiles")
	_check(document.set_misc_u32(0x01f0 + 0xed * 4, 20), "Annual XMIC fixture counts rail tiles")
	_check(document.set_misc_u32(0x01f0 + 0xe9 * 4, 9), "Annual XMIC fixture counts subway tiles")
	_check(document.set_misc_u32(0x01f0 + 0xc6 * 4, 3), "Annual XMIC fixture counts first hydro tiles")
	_check(document.set_misc_u32(0x01f0 + 0xc7 * 4, 4), "Annual XMIC fixture counts second hydro tiles")
	_check(document.set_misc_u32(0x01f0 + 0xc8 * 4, 5), "Annual XMIC fixture counts wind tiles")
	_check(document.set_misc_u32(0x01f0 + 0xd4 * 4, 4), "Annual XMIC fixture counts museum tiles")
	_check(document.set_misc_u32(0x01f0 + 0x0d * 4, 18), "Annual XMIC fixture counts small park tiles")
	_check(document.set_misc_u32(0x01f0 + 0xd5 * 4, 9), "Annual XMIC fixture counts big park tiles")
	_check(document.set_misc_u32(0x01f0 + 0xf5 * 4, 2), "Annual XMIC fixture counts library tiles")
	_check(document.set_misc_u32(0x1020, 10000), "Annual XMIC fixture sets arcology population")
	_check(document.set_misc_u32(0x102c, 90000), "Annual XMIC fixture sets normal population")
	_check(document.set_misc_u32(0x077c + 8 * 0x006c + 4, 75), "Annual XMIC fixture sets school funding")
	_check(document.set_misc_u32(0x077c + 9 * 0x006c + 4, 80), "Annual XMIC fixture sets college funding")
	var result := AnnualMicrosims.run(city, 70000, 123, 456)
	_check(result.ok, "Annual microsimulation statistics complete: %s" % result.error)
	_check(
		result.updated_bus_records == 1
		and result.updated_rail_records == 1
		and result.updated_subway_records == 1,
		"Annual transit statistics report all updated records",
	)
	_check(
		result.updated_hydro_records == 1
		and result.updated_wind_records == 1
		and result.updated_city_hall_records == 1
		and result.updated_museum_records == 1
		and result.updated_park_records == 1
		and result.updated_library_records == 1,
		"Annual facility statistics report all deterministic records",
	)
	var bus := city.microsim(1)
	_check(
		bus.stat_1 == 3 and bus.stat_2 == 12 and bus.stat_3 == (70000 & 0xffff),
		"Annual bus statistics store depots and wrapped passengers",
	)
	var rail := city.microsim(2)
	_check(
		rail.stat_1 == 5 and rail.stat_2 == 0x1234 and rail.stat_3 == 123,
		"Annual rail statistics preserve statistic two",
	)
	var subway := city.microsim(3)
	_check(
		subway.stat_1 == 9 and subway.stat_2 == 0x5678 and subway.stat_3 == 456,
		"Annual subway statistics preserve statistic two",
	)
	var hydro := city.microsim(4)
	_check(hydro.stat_1 == 7 and hydro.stat_2 == 140, "Annual hydro statistics store capacity")
	var wind := city.microsim(5)
	_check(wind.stat_1 == 5 and wind.stat_2 == 20, "Annual wind statistics store capacity")
	_check(city.microsim(6).stat_1 == 111, "Annual city hall statistics apply the population cap")
	var museum := city.microsim(7)
	_check(museum.stat_1 == 1280 and museum.stat_2 == 32, "Annual museum statistics use college funding")
	var park := city.microsim(8)
	_check(
		park.stat_1 == 15000 and park.stat_2 == 27 and park.stat_3 == 3,
		"Annual big park statistics store capped visitors and park counts",
	)
	var library := city.microsim(9)
	_check(
		library.stat_0 == 0 and library.stat_1 == 600 and library.stat_2 == 1050,
		"Annual library statistics use school funding and population",
	)
	var before_invalid: PackedByteArray = document.find_chunk("XMIC").decoded_payload.duplicate()
	var invalid := AnnualMicrosims.run(city, -1, 0, 0)
	_check(not invalid.ok, "Annual microsimulation statistics reject a negative passenger count")
	_check(
		document.find_chunk("XMIC").decoded_payload == before_invalid,
		"A rejected annual transit update preserves XMIC",
	)


func _test_annual_service_microsim_phase(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	var service_tiles := [0xd1, 0xd2, 0xd3, 0xd6, 0xd7, 0xd8, 0xd9]
	for index in service_tiles.size():
		microsims[(index + 1) * 8] = service_tiles[index]
	microsims[1 * 8 + 1] = 10
	microsims[4 * 8 + 1] = 8
	microsims[6 * 8 + 2] = 0x1f
	microsims[6 * 8 + 3] = 0x40
	microsims[7 * 8 + 1] = 7
	_check(document.find_chunk("XMIC").set_decoded_payload(microsims), "Annual service fixture installs XMIC records")
	_check(document.set_misc_u32(0x002c, 900), "Annual service fixture sets crime")
	_check(document.set_misc_u32(0x007c + 1 * 12, 1000), "Annual service fixture sets first student cohort")
	_check(document.set_misc_u32(0x007c + 2 * 12, 2000), "Annual service fixture sets second student cohort")
	_check(document.set_misc_u32(0x007c + 3 * 12, 4000), "Annual service fixture sets college cohort")
	_check(document.set_misc_u32(0x01f0 + 0xd1 * 4, 18), "Annual service fixture counts hospital tiles")
	_check(document.set_misc_u32(0x01f0 + 0xd2 * 4, 9), "Annual service fixture counts police tiles")
	_check(document.set_misc_u32(0x01f0 + 0xd6 * 4, 18), "Annual service fixture counts school tiles")
	_check(document.set_misc_u32(0x01f0 + 0xd7 * 4, 16), "Annual service fixture counts stadium tiles")
	_check(document.set_misc_u32(0x01f0 + 0xd8 * 4, 16), "Annual service fixture counts prison tiles")
	_check(document.set_misc_u32(0x01f0 + 0xd9 * 4, 16), "Annual service fixture counts college tiles")
	_check(document.set_misc_u32(0x1020, 10000), "Annual service fixture sets arcology population")
	_check(document.set_misc_u32(0x102c, 90000), "Annual service fixture sets normal population")
	_check(document.set_misc_u32(0x1038, 400), "Annual service fixture sets old arrests")
	_check(document.set_misc_u32(0x103c, 1), "Annual service fixture sets prison bonus")
	_check(document.set_misc_u32(0x077c + 5 * 0x006c + 4, 80), "Annual service fixture sets police funding")
	_check(document.set_misc_u32(0x077c + 6 * 0x006c + 4, 60), "Annual service fixture sets fire funding")
	_check(document.set_misc_u32(0x077c + 7 * 0x006c + 4, 70), "Annual service fixture sets health funding")
	_check(document.set_misc_u32(0x077c + 8 * 0x006c + 4, 80), "Annual service fixture sets school funding")
	_check(document.set_misc_u32(0x077c + 9 * 0x006c + 4, 90), "Annual service fixture sets college funding")
	var random := SequenceRandom.new([5, 7, 3, 4, 9, 3, 7, 5, 10, 3, 11, 6])
	var result := AnnualMicrosims.run(city, 0, 0, 0, random)
	_check(result.ok, "Annual service statistics complete: %s" % result.error)
	_check(
		result.updated_hospital_records == 1
		and result.updated_police_records == 1
		and result.updated_fire_records == 1
		and result.updated_school_records == 1
		and result.updated_stadium_records == 1
		and result.updated_prison_records == 1
		and result.updated_college_records == 1,
		"Annual service statistics report each updated record",
	)
	var hospital := city.microsim(1)
	_check(
		hospital.stat_0 == 0
		and hospital.stat_1 == 1007
		and hospital.stat_2 == 69
		and hospital.stat_3 == 35,
		"Annual hospital statistics use population, health funding, and three random values",
	)
	var police := city.microsim(2)
	_check(
		police.stat_0 == 80 and police.stat_1 == 160 and police.stat_2 == 100 and police.stat_3 == 29,
		"Annual police statistics use crime, funding, and the old prison bonus",
	)
	var fire := city.microsim(3)
	_check(
		fire.stat_0 == 60 and fire.stat_1 == 30 and fire.stat_2 == 2 and fire.stat_3 == 11,
		"Annual fire statistics use funding and the process random value",
	)
	var school := city.microsim(4)
	_check(
		school.stat_0 == 7 and school.stat_1 == 1507 and school.stat_2 == 49 and school.stat_3 == 20,
		"Annual school statistics use student cohorts and school funding",
	)
	var stadium := city.microsim(5)
	_check(
		stadium.stat_0 == 12 and stadium.stat_1 == 6260,
		"Annual stadium statistics use adjusted population and two random values",
	)
	var prison := city.microsim(6)
	_check(
		prison.stat_0 == 0 and prison.stat_1 == 5000 and prison.stat_2 == 240 and prison.stat_3 == 64,
		"Annual prison statistics use old arrests and police funding",
	)
	var college := city.microsim(7)
	_check(
		college.stat_0 == 6 and college.stat_1 == 3333 and college.stat_2 == 166 and college.stat_3 == 90,
		"Annual college statistics use its cohort and college funding",
	)
	_check(document.misc_u32(0x1038) == 29, "Annual police statistics replace old arrests")
	_check(document.misc_u32(0x103c) == 1, "Annual prison statistics rebuild the prison bonus")
	_check(random.position == 12, "Annual services consume process random values in record order")


func _test_annual_special_microsim_phase(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	var special_tiles := [0xc9, 0xda, 0xdb, 0xf3, 0xf4, 0xf8, 0xfb, 0xfe, 0xff]
	for index in special_tiles.size():
		microsims[(index + 1) * 8] = special_tiles[index]
	microsims[1 * 8 + 1] = 10
	microsims[4 * 8 + 1] = 3
	microsims[4 * 8 + 4] = 0x12
	microsims[4 * 8 + 5] = 0x34
	microsims[4 * 8 + 6] = 0
	microsims[4 * 8 + 7] = 2
	microsims[7 * 8 + 1] = 12
	microsims[7 * 8 + 2] = 0
	microsims[7 * 8 + 3] = 10
	microsims[7 * 8 + 4] = 0
	microsims[7 * 8 + 5] = 100
	microsims[8 * 8 + 1] = 10
	microsims[8 * 8 + 2] = 0
	microsims[8 * 8 + 3] = 20
	microsims[8 * 8 + 4] = 0
	microsims[8 * 8 + 5] = 200
	_check(document.find_chunk("XMIC").set_decoded_payload(microsims), "Annual special fixture installs XMIC records")
	_check(document.set_misc_u32(0x01f0 + 0xf8 * 4, 9), "Annual special fixture counts marina tiles")
	_check(document.set_misc_u32(0x01f0 + 0xfb * 4, 16), "Annual special fixture counts first arcology tiles")
	_check(document.set_misc_u32(0x01f0 + 0xfe * 4, 16), "Annual special fixture counts launch arcology tiles")
	_check(document.set_misc_u32(0x077c + 0 * 0x006c + 4, 7), "Annual special fixture sets residential tax")
	_check(document.set_misc_u32(0x077c + 1 * 0x006c + 4, 7), "Annual special fixture sets commercial tax")
	_check(document.set_misc_u32(0x077c + 2 * 0x006c + 4, 7), "Annual special fixture sets industrial tax")
	_check(document.set_misc_u32(0x1020, 10000), "Annual special fixture sets arcology population")
	_check(document.set_misc_u32(0x102c, 90000), "Annual special fixture sets normal population")
	var process_random := SequenceRandom.new([6, 43, 5, 123, 31, 0xaa, 0x3ff, 0x7f, 0x3f])
	var lfsr := SequenceLfsrRandom.new([5, 7, 9])
	var game_lcg := SequenceLfsrRandom.new([101, 202, 303, 404])
	var result := AnnualMicrosims.run(
		city, 0, 0, 0, process_random, lfsr, game_lcg, 80, 70
	)
	_check(result.ok, "Annual special statistics complete: %s" % result.error)
	var power := city.microsim(1)
	_check(
		power.stat_0 == 11 and power.stat_2 == 86,
		"Annual power statistics age the plant and use the power percentage",
	)
	var zoo := city.microsim(2)
	_check(
		zoo.stat_0 == 1 and zoo.stat_1 == 2 and zoo.stat_2 == 3 and zoo.stat_3 == 4,
		"Annual zoo statistics use four game LCG values",
	)
	_check(city.microsim(3).stat_2 == 1, "Annual statue statistics use one process random value")
	var mayor_house := city.microsim(4)
	_check(
		mayor_house.stat_0 == 4 and mayor_house.stat_2 == 0 and mayor_house.stat_3 == 1,
		"Annual mayor house statistics advance the term and store process approval",
	)
	var water_facility := city.microsim(5)
	_check(
		water_facility.stat_0 == 75 and water_facility.stat_1 == 23 and water_facility.stat_2 == 166,
		"Annual water-facility statistics use water demand and three process random values",
	)
	_check(city.microsim(6).stat_1 == 77, "Annual marina statistics use tile count and one LFSR value")
	_check(city.microsim(7).stat_2 == 1109, "Annual first arcology statistics apply tax growth")
	_check(city.microsim(8).stat_2 == 1413, "Annual launch arcology statistics apply tax growth")
	_check(document.misc_u32(0x1020) == 2522, "Annual arcology statistics replace arcology population")
	var dome := city.microsim(9)
	_check(
		dome.stat_0 == 0xaa and dome.stat_1 == 12273 and dome.stat_2 == 1661 and dome.stat_3 == 830,
		"Annual Llama Dome statistics use four process random values",
	)
	_check(process_random.position == 9, "Annual special facilities consume process random values in order")
	_check(lfsr.position == 3, "Annual marinas and arcologies consume LFSR values in order")
	_check(game_lcg.position == 4, "Annual zoos consume game LCG values in order")
	_check(result.random_records_pending == 0, "Annual special statistics have all required random sources")

	var renewal_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var renewal_city := CityModel.from_document(renewal_document)
	var renewal_microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	renewal_microsims[8] = 0xc9
	renewal_microsims[9] = 50
	_check(renewal_document.find_chunk("XMIC").set_decoded_payload(renewal_microsims), "Annual renewal fixture installs an old power plant")
	var renewal_text: PackedByteArray = renewal_document.find_chunk("XTXT").decoded_payload.duplicate()
	renewal_text[1 * CityState.MAP_SIZE + 2] = 52
	_check(renewal_document.find_chunk("XTXT").set_decoded_payload(renewal_text), "Annual renewal fixture links the power plant")
	_check(renewal_document.set_misc_u32(0x0014, 3000), "Annual renewal fixture sets funds")
	_check(renewal_document.set_misc_u32(0x1000, 1), "Annual renewal fixture disables disasters")
	var renewal := AnnualMicrosims.run(renewal_city, 0, 0, 0, ZeroRandom.new(), null, null, 80, -1)
	_check(renewal.ok, "Annual power renewal completes: %s" % renewal.error)
	_check(renewal_city.microsim(1).stat_0 == 0, "Annual power renewal resets plant age")
	_check(renewal_city.funds() == 1000, "Annual gas-power renewal deducts the original cost")
	_check(renewal.expired_power_records.is_empty(), "A paid annual power renewal does not request demolition")

	var expiry_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			expiry_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Annual expiry fixture clears %s" % chunk_id,
		)
	_check(expiry_document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Annual expiry fixture clears XLAB")
	_check(expiry_document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Annual expiry fixture clears XMIC")
	_check(expiry_document.set_misc_i32(0x14, 10000), "Annual expiry fixture sets funds")
	_check(expiry_document.set_misc_u32(0x01f0, 16384), "Annual expiry fixture counts clear tiles")
	_check(expiry_document.set_misc_u32(0x01f0 + 0xc9 * 4, 0), "Annual expiry fixture clears gas count")
	_check(expiry_document.set_misc_u32(0x1000, 0), "Annual expiry fixture enables disasters")
	var expiry_city := CityModel.from_document(expiry_document)
	var gas := Buildings.apply(
		expiry_city, 3, 5, Vector2i(20, 20), GameRandom.new(1), Random.new(1)
	)
	_check(gas.ok and gas.overlay_id == 61, "Annual expiry fixture builds a gas plant")
	var old_power: PackedByteArray = expiry_document.find_chunk("XMIC").decoded_payload.duplicate()
	old_power[10 * 8 + 1] = 50
	_check(expiry_document.find_chunk("XMIC").set_decoded_payload(old_power), "Annual expiry fixture sets plant age 50")
	var expiry_random := CountingRandom.new()
	var expired := AnnualMicrosims.run(
		expiry_city, 0, 0, 0, expiry_random, null, null, 80, -1
	)
	_check(expired.ok, "Annual expired-power update completes: %s" % expired.error)
	_check(
		expired.demolished_power_records.size() == 1 and expired.expired_power_records.is_empty(),
		"Annual expired power completes its demolition",
	)
	_check(expiry_city.microsim(10).tile_id == 0, "Annual power demolition releases the XMIC record")
	_check(expiry_city.label(61).is_empty(), "Annual power demolition releases the facility label")
	_check(expiry_city.text_overlay_id(19, 19) == 0, "Annual power demolition clears XTXT")
	_check(
		expiry_city.building_id(19, 19) >= 1
		and expiry_city.building_id(19, 19) <= 4
		and expiry_city.building_id(22, 22) >= 1
		and expiry_city.building_id(22, 22) <= 4,
		"Annual power demolition changes the full plant to rubble",
	)
	_check(expiry_document.misc_u32(0x01f0 + 0xc9 * 4) == 0, "Annual power demolition clears the gas tile count")
	_check(expiry_random.position == 145, "Annual power demolition consumes plant and visual random values in order")
	_check(not expired.news_items.has({"type": 0x1f8, "argument": 0}), "Annual power demolition does not report sound as news")
	_check(expired.sound_events == [504], "Annual power demolition reports the explosion sound")

	var aus_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var aus_city := CityModel.from_document(aus_document)
	var aus_microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	aus_microsims[8] = 0xff
	aus_microsims[14] = 0x12
	aus_microsims[15] = 0x34
	_check(aus_document.find_chunk("XMIC").set_decoded_payload(aus_microsims), "Annual AUS fixture installs a Llama Dome")
	_check(aus_document.set_misc_u32(0x102c, 8000), "Annual AUS fixture sets normal population")
	var aus_random := SequenceRandom.new([1, 2, 3])
	var aus_result := AnnualMicrosims.run(
		aus_city, 0, 0, 0, aus_random, null, null, -1, -1, true
	)
	_check(aus_result.ok, "Annual AUS Llama Dome update completes: %s" % aus_result.error)
	var aus_dome := aus_city.microsim(1)
	_check(
		aus_dome.stat_0 == 2
		and aus_dome.stat_1 == 1001
		and aus_dome.stat_2 == 13
		and aus_dome.stat_3 == 0x1234,
		"The Australian Llama Dome path uses three values and preserves statistic three",
	)
	_check(aus_random.position == 3, "The Australian Llama Dome path consumes three process random values")


func _test_mayor_approval_phase(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	microsims[8] = 0xf3
	microsims[9] = 4
	microsims[14] = 0
	microsims[15] = 2
	_check(document.find_chunk("XMIC").set_decoded_payload(microsims), "Mayor approval fixture installs a mayor house")
	var graphs: PackedByteArray = document.find_chunk("XGRP").decoded_payload.duplicate()
	_write_u32_be(graphs, 4 * CityModel.GRAPH_VALUE_COUNT * 4, 10)
	_write_u32_be(graphs, 5 * CityModel.GRAPH_VALUE_COUNT * 4, 20)
	_write_u32_be(graphs, 6 * CityModel.GRAPH_VALUE_COUNT * 4, 30)
	_write_u32_be(graphs, 7 * CityModel.GRAPH_VALUE_COUNT * 4, 40)
	_check(document.find_chunk("XGRP").set_decoded_payload(graphs), "Mayor approval fixture installs graph values")
	_check(document.set_misc_u32(0x0048, 65), "Mayor approval fixture sets life expectancy")
	_check(document.set_misc_u32(0x004c, 90), "Mayor approval fixture sets education")
	_check(document.set_misc_u32(0x0fa4, 5), "Mayor approval fixture sets unemployment")
	_check(document.set_misc_u32(0x077c + 4, 7), "Mayor approval fixture sets residential tax")
	_check(document.set_misc_u32(0x102c, 1000), "Mayor approval fixture sets city population")
	var favorable_values: Array[int] = []
	for _index in 100:
		favorable_values.append(190)
	var favorable_random := SequenceRandom.new(favorable_values)
	var favorable := MayorApproval.run(city, favorable_random, 79)
	_check(favorable.ok, "Mayor approval calculation completes: %s" % favorable.error)
	_check(
		favorable.weights == PackedInt32Array([10, 20, 40, 5, 21, 10, 5]),
		"Mayor approval uses traffic, pollution, crime, unemployment, tax, education, and health",
	)
	_check(favorable.approval == 100, "Mayor approval counts all favorable survey samples")
	_check(favorable_random.position == 100, "Mayor approval consumes 100 process random values")
	_check(
		favorable.news_items == [{"type": 0x201, "argument": 0}],
		"Mayor approval reports the upward 80-percent threshold",
	)
	var mayor_house := city.microsim(1)
	_check(
		mayor_house.stat_0 == 5 and mayor_house.stat_2 == 100 and mayor_house.stat_3 == 1,
		"Mayor approval updates all mayor-house annual fields",
	)
	var complaint_values: Array[int] = []
	for _index in 100:
		complaint_values.append(0)
	var complaint_random := SequenceRandom.new(complaint_values)
	var complaints := MayorApproval.run(city, complaint_random, favorable.approval)
	_check(complaints.ok, "Mayor complaint calculation completes: %s" % complaints.error)
	_check(complaints.approval == 0, "Mayor approval excludes complaint survey samples")
	_check(complaints.survey_counts[0] == 100, "Mayor survey counts the first complaint")
	_check(complaints.ranking[0] == 0, "Mayor survey ranks the largest complaint first")
	mayor_house = city.microsim(1)
	_check(
		mayor_house.stat_0 == 6 and mayor_house.stat_2 == 0 and mayor_house.stat_3 == 0,
		"Repeated mayor-house queries advance the saved term fields",
	)


func _test_arcology_launch_phase(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Arcology launch fixture clears %s" % chunk_id,
		)
	_check(document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Arcology launch fixture clears XLAB")
	_check(document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Arcology launch fixture clears XMIC")
	_check(document.set_misc_i32(0x14, 20000000), "Arcology launch fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Arcology launch fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + 0xfe * 4, 0), "Arcology launch fixture clears launch count")
	var city := CityModel.from_document(document)
	var launch := Buildings.apply(
		city, 5, 8, Vector2i(20, 20), GameRandom.new(1), Random.new(1)
	)
	_check(launch.ok and launch.site == Rect2i(19, 19, 4, 4), "Arcology launch fixture builds a launch arcology")
	var text_overlays: PackedByteArray = document.find_chunk("XTXT").decoded_payload.duplicate()
	for index in launch.tile_indices:
		text_overlays[index] = 0xfe
	_check(document.find_chunk("XTXT").set_decoded_payload(text_overlays), "Arcology launch fixture installs launch markers")
	var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	for record_id in range(1, 101):
		var offset := record_id * CityState.MICROSIM_RECORD_SIZE
		microsims[offset] = 0xfe
		microsims[offset + 1] = 12
		microsims[offset + 2] = 0
		microsims[offset + 3] = 65
		microsims[offset + 4] = 0xea
		microsims[offset + 5] = 0x60
	_check(document.find_chunk("XMIC").set_decoded_payload(microsims), "Arcology launch fixture installs one hundred records")
	_check(document.set_misc_u32(0x01f0 + 0xfe * 4, 4816), "Arcology launch fixture crosses the tile threshold")
	_check(document.set_misc_u32(0x1020, 6000000), "Arcology launch fixture sets old arcology population")
	_check(document.set_misc_u32(0x102c, 20000000), "Arcology launch fixture sets normal population")
	for budget_id in 3:
		_check(document.set_misc_u32(0x077c + budget_id * 0x006c + 4, 0), "Arcology launch fixture clears tax %d" % budget_id)
	var lfsr_values: Array[int] = []
	for _index in 100:
		lfsr_values.append(0)
	var lfsr := SequenceLfsrRandom.new(lfsr_values)
	var process_random := CountingRandom.new()
	var result := AnnualMicrosims.run(city, 0, 0, 0, process_random, lfsr)
	_check(result.ok, "Arcology launch completes: %s" % result.error)
	_check(result.arcology_launched and not result.arcology_launch_pending, "Arcology launch resolves its threshold event")
	_check(result.launch_arcology_records == 100, "Arcology launch counts XMIC launch records")
	_check(
		result.launched_structures == 1,
		"Arcology launch demolishes each marked structure once: %s" % result.launched_structures,
	)
	_check(document.misc_u32(0x1020) == 6360000, "Arcology launch stores the new arcology population")
	_check(city.funds() == 29800000, "Arcology launch awards one hundred thousand dollars per record")
	_check(
		city.building_id(19, 19) >= 1
		and city.building_id(19, 19) <= 4
		and city.building_id(22, 22) >= 1
		and city.building_id(22, 22) <= 4,
		"Arcology launch changes the marked structure to rubble: %d, %d"
		% [city.building_id(19, 19), city.building_id(22, 22)],
	)
	_check(city.text_overlay_id(19, 19) == 0xfe, "Arcology launch preserves its special XTXT marker")
	_check(document.misc_u32(0x01f0 + 0xfe * 4) == 4800, "Arcology launch decrements demolished tile counts")
	_check(process_random.position == 144, "Arcology launch consumes visual and rubble random values")
	_check(lfsr.position == 100, "Arcology launch consumes one LFSR value per record")
	_check(
		result.news_items == [
			{"type": 0x211, "argument": 0},
			{"type": 0x212, "argument": 0},
		],
		"Arcology launch reports start and completion news: %s" % [result.news_items],
	)
	_check(result.sound_events == [504], "Arcology launch reports one explosion sound: %s" % [result.sound_events])
	_check(result.complete, "Arcology launch completes the annual microsimulation action")


func _test_transport_trip(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XZON", "XUND", "XTXT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Transport fixture clears %s" % chunk_id,
		)
	_check(
		document.find_chunk("XTRF").set_decoded_payload(_filled_bytes(64 * 64, 0)),
		"Transport fixture clears XTRF",
	)
	var city := CityModel.from_document(document)
	for point in [Vector2i(20, 21), Vector2i(20, 22), Vector2i(20, 23)]:
		_check(city.set_building_id(point.x, point.y, 0x1d), "Transport fixture places a road")
	_check(city.set_zone_id(20, 20, 1), "Transport fixture sets the origin zone")
	_check(city.set_zone_id(20, 24, 3), "Transport fixture sets a job destination")
	var result := Transport.run(city, Vector2i(20, 20), 1, 2, Random.new(1))
	_check(result.ok and result.reached_destination, "Road trip reaches a compatible zone")
	_check(result.path_length == 3, "Road trip records the three-tile path")
	var traffic := document.find_chunk("XTRF").decoded_payload
	_check(traffic[10 * 64 + 10] == 2, "Road trip adds traffic to its first coarse cell")
	_check(traffic[10 * 64 + 11] == 4, "Road trip accumulates two tiles in one coarse cell")

	_check(city.set_zone_id(20, 24, 1), "Transport fixture changes the destination to residential")
	var before_failed_trip: PackedByteArray = document.find_chunk("XTRF").decoded_payload.duplicate()
	var failed := Transport.run(city, Vector2i(20, 20), 1, 2, Random.new(1))
	_check(failed.ok and not failed.reached_destination, "Trip rejects an incompatible destination")
	_check(document.find_chunk("XTRF").decoded_payload == before_failed_trip, "Failed trip preserves XTRF")

	_check(city.set_building_id(1, 0, 0x1d), "Connection fixture places an edge road")
	_check(city.set_text_overlay_id(1, 0, 0xfa), "Connection fixture marks a city connection")
	var connection := Transport.run(city, Vector2i(1, 1), 5, 1, Random.new(7))
	_check(connection.ok and connection.reached_destination, "Trip can leave through a city connection")
	_check(
		document.find_chunk("XTRF").decoded_payload[0] == 1,
		"Connection trip adds its density to the edge traffic cell",
	)


func _test_growth_phase(reference_root: String) -> void:
	var normal := _growth_fixture(reference_root, 0xae, 1, 2000)
	var normal_result := Growth.run(normal.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(normal_result.ok, "Normal growth scan completes: %s" % normal_result.error)
	_check(normal_result.scanned_tiles == 1024, "Growth scan processes one sixteenth of the map")
	_check(normal_result.rci_tiles == 1, "Growth scan processes the controlled RCI anchor")
	_check(normal.document.misc_u32(0x05f4) == 36, "Density four adds 36 residential units")
	_check(normal_result.successful_trips == 1, "Developed zone completes its transport trip")
	_check(normal.city.building_id(20, 20) == 0xae, "Stable density-four zone keeps its building")

	var bare := _growth_fixture(reference_root, 0, 1, 2000)
	var bare_result := Growth.run(bare.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(bare_result.ok, "Bare-zone growth scan completes: %s" % bare_result.error)
	_check(bare_result.started_construction == 1, "Bare powered zone starts construction")
	_check(bare.city.building_id(20, 20) == 0x88, "Bare zone gets the first construction tile")
	_check(bare.city.building_corners(20, 20) == 0xf0, "One-tile construction sets all corner bits")
	_check(
		bare.city.tile_flags[20 * 128 + 20] & 0xe0 == 0xe0,
		"Construction sets utility flags",
	)

	var declining := _growth_fixture(reference_root, 0x70, 1, -2000)
	var decline_result := Growth.run(declining.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(decline_result.ok, "Declining-zone scan completes: %s" % decline_result.error)
	_check(decline_result.abandoned_buildings == 1, "Low demand abandons the controlled building")
	_check(declining.city.building_id(20, 20) == 0x8a, "Density-one zone uses an abandoned tile")
	_check(declining.document.misc_u32(0x05f4) == 1, "Population is counted before abandonment")

	var abandoned := _growth_fixture(reference_root, 0x8a, 1, 2000)
	var recovery_result := Growth.run(abandoned.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(recovery_result.ok, "Abandoned-zone scan completes: %s" % recovery_result.error)
	_check(recovery_result.recovered_buildings == 1, "High demand recovers an abandoned building")
	_check(abandoned.city.building_id(20, 20) == 0x70, "Recovered residence uses value group zero")
	_check(abandoned.document.misc_u32(0x060c) == 1, "Abandoned population is counted before recovery")

	var construction := _growth_fixture(reference_root, 0x88, 1, 2000)
	var construction_result := Growth.run(
		construction.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(construction_result.ok, "Construction completion scan completes: %s" % construction_result.error)
	_check(construction_result.completed_construction == 1, "Construction completes on the controlled roll")
	_check(construction.city.building_id(20, 20) == 0x70, "Residential construction becomes occupied")

	var church := _growth_fixture(reference_root, 0xa6, 1, 2000)
	for point in [Vector2i(20, 19), Vector2i(21, 19), Vector2i(21, 20)]:
		_check(church.city.set_building_id(point.x, point.y, 0xa6), "Church fixture fills construction footprint")
		_check(church.city.set_zone_id(point.x, point.y, 1), "Church fixture zones construction footprint")
	_check(church.document.set_misc_u32(0x01f0 + 0xa6 * 4, 4), "Church fixture counts construction tiles")
	_check(church.document.set_misc_u32(0x01f0 + 0xf7 * 4, 0), "Church fixture clears church count")
	_check(church.document.set_misc_u32(0x102c, 1000), "Church fixture sets city population")
	var church_result := Growth.run(church.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(church_result.ok, "Church growth scan completes: %s" % church_result.error)
	_check(church_result.churches_built == 1, "Residential density construction can make a church")
	for point in [Vector2i(20, 19), Vector2i(21, 19), Vector2i(20, 20), Vector2i(21, 20)]:
		_check(church.city.building_id(point.x, point.y) == 0xf7, "Church fills its two-by-two footprint")
		_check(church.city.zone_id(point.x, point.y) == 0, "Church clears the RCI zone nibble")

	_test_special_zone_growth(reference_root)
	_test_transport_maintenance(reference_root)


func _test_special_zone_growth(reference_root: String) -> void:
	var airport := _special_growth_fixture(reference_root)
	for x in range(20, 25):
		_check(airport.city.set_zone_id(x, 21, 8), "Airport fixture zones its runway strip")
	_check(airport.city.set_tile_flag(20, 21, 0x40, true), "Airport fixture powers its origin")
	var airport_result := Growth.run(
		airport.city, ZeroRandom.new(), 0, 1, NonzeroLfsrRandom.new()
	)
	_check(airport_result.ok, "Airport growth scan completes: %s" % airport_result.error)
	_check(airport_result.special_tiles_placed == 5, "Airport growth places a five-tile runway")
	for x in range(20, 25):
		_check(airport.city.building_id(x, 21) == 0xdd, "Airport runway uses tile 0xdd")
		_check(airport.city.building_corners(x, 21) == 0xf0, "Airport runway sets all corner bits")
		_check(
			airport.city.tile_flags[x * 128 + 21] & 0xc0 == 0xc0,
			"Civilian runway tiles are powered and powerable",
		)
	_check(airport.document.misc_u32(0x01f0 + 0xdd * 4) == 5, "Airport growth counts runway tiles")

	var seaport := _special_growth_fixture(reference_root)
	_check(seaport.city.set_zone_id(20, 20, 9), "Seaport fixture zones its crane origin")
	_check(seaport.city.set_tile_flag(20, 20, 0x40, true), "Seaport fixture powers its origin")
	for y in range(21, 26):
		_check(seaport.city.set_tile_flag(20, y, 0x04, true), "Seaport fixture marks pier water")
	_check(seaport.city.set_land_altitude(20, 25, 0), "Seaport fixture lowers the last water tile")
	_check(seaport.city.set_water_altitude(20, 25, 2), "Seaport fixture makes the last tile deep")
	var seaport_result := Growth.run(
		seaport.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(seaport_result.ok, "Seaport growth scan completes: %s" % seaport_result.error)
	_check(seaport_result.special_tiles_placed == 5, "Seaport growth places one crane and four piers")
	_check(seaport.city.building_id(20, 20) == 0xe0, "Seaport growth places its crane")
	_check(seaport.city.zone_id(20, 20) == 9, "Seaport crane stays in the seaport zone")
	for y in range(21, 25):
		_check(seaport.city.building_id(20, y) == 0xdf, "Seaport growth places a pier tile")
		_check(seaport.city.building_corners(20, y) == 0xf0, "Seaport pier sets all corner bits")
	_check(seaport.city.building_id(20, 25) == 0, "Seaport growth keeps the depth-check tile clear")
	_check(seaport.document.misc_u32(0x01f0 + 0xe0 * 4) == 1, "Seaport growth counts its crane")
	_check(seaport.document.misc_u32(0x01f0 + 0xdf * 4) == 4, "Seaport growth counts its piers")

	var silos := _special_growth_fixture(reference_root)
	for x in range(18, 21):
		for y in range(18, 21):
			_check(silos.city.set_zone_id(x, y, 7), "Missile fixture zones its military plot")
	_check(silos.document.set_misc_u32(0x0e4c, 5), "Missile fixture selects a missile base")
	_check(silos.document.set_misc_u32(0x01f0, 16375), "Missile fixture excludes military tiles from the normal count")
	_check(silos.document.set_misc_u32(0x0fa8, 9), "Missile fixture counts military other tiles")
	var silo_result := Growth.run(silos.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(silo_result.ok, "Missile growth scan completes: %s" % silo_result.error)
	_check(silo_result.special_tiles_placed == 9, "Missile growth places a three-by-three silo")
	for x in range(18, 21):
		for y in range(18, 21):
			_check(silos.city.building_id(x, y) == 0xf9, "Missile growth fills the surface plot")
			_check(silos.city.underground_id(x, y) == 0x22, "Missile growth fills the underground plot")
	_check(silos.document.misc_u32(0x0fa8) == 0, "Missile growth consumes military other tiles")
	_check(silos.document.misc_u32(0x0fa8 + 15 * 4) == 9, "Missile growth counts silo tiles")
	_check(silos.document.misc_u32(0x0fe8) == 0, "Military silo subway tiles do not change the city subway count")

	var army := _special_growth_fixture(reference_root)
	for x in range(20, 22):
		for y in range(20, 22):
			_check(army.city.set_zone_id(x, y, 7), "Army fixture zones its building plot")
			_check(army.city.set_tile_flag(x, y, 0xe0, true), "Army fixture sets utility flags")
	_check(army.document.set_misc_u32(0x0e4c, 2), "Army fixture selects an army base")
	_check(army.document.set_misc_u32(0x01f0, 16380), "Army fixture excludes military tiles from the normal count")
	_check(army.document.set_misc_u32(0x0fa8, 4), "Army fixture counts military other tiles")
	var army_result := Growth.run(army.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(army_result.ok, "Army growth scan completes: %s" % army_result.error)
	_check(army_result.special_growth_attempts == 1, "Army growth attempts one controlled building")
	_check(army_result.special_tiles_placed == 0, "Win95 military item placement rejects its own zone")
	for x in range(20, 22):
		for y in range(20, 22):
			_check(army.city.building_id(x, y) == 0, "Win95 military placement leaves the plot clear")
			_check(army.city.tile_flags[x * 128 + y] & 0xf0 == 0, "Win95 military placement clears utility flags")

	var air_force := _special_growth_fixture(reference_root)
	for x in range(21, 26):
		_check(air_force.city.set_zone_id(x, 21, 7), "Air Force fixture zones its runway strip")
	_check(air_force.city.set_building_id(10, 10, 0xdd), "Air Force fixture places one civilian runway")
	_check(air_force.city.set_building_id(23, 21, 0x1d), "Air Force fixture places a military road")
	_check(air_force.city.set_terrain_id(23, 21, 1), "Air Force fixture sets terrain under the road")
	_check(air_force.city.set_underground_id(23, 21, 1), "Air Force fixture sets a subway under the road")
	_check(air_force.document.set_misc_u32(0x0e4c, 3), "Air Force fixture selects an air base")
	_check(air_force.document.set_misc_u32(0x01f0, 16378), "Air Force fixture counts normal clear tiles")
	_check(air_force.document.set_misc_u32(0x01f0 + 0xdd * 4, 1), "Air Force fixture counts its civilian runway")
	_check(air_force.document.set_misc_u32(0x0fa8, 5), "Air Force fixture counts military other tiles")
	var air_force_result := Growth.run(
		air_force.city, ZeroRandom.new(), 1, 1, NonzeroLfsrRandom.new()
	)
	_check(air_force_result.ok, "Air Force growth scan completes: %s" % air_force_result.error)
	_check(air_force_result.special_tiles_placed == 5, "Air Force growth places a five-tile runway")
	for x in range(21, 26):
		_check(air_force.city.building_id(x, 21) == 0xdd, "Air Force growth follows normal-runway parity")
	_check(air_force.city.terrain_id(23, 21) == 1, "Win95 military runway growth preserves underlying terrain")
	_check(air_force.city.underground_id(23, 21) == 1, "Win95 military runway growth preserves its subway")
	_check(air_force.document.misc_u32(0x01f0 + 0xdd * 4) == 1, "Military runways do not change the normal runway count")
	_check(air_force.document.misc_u32(0x0fa8) == 0, "Air Force growth consumes military other tiles")
	_check(air_force.document.misc_u32(0x0fa8 + 4) == 5, "Air Force growth counts military runway tiles")

	var aircraft := _special_growth_fixture(reference_root)
	_check(aircraft.city.set_zone_id(20, 20, 8), "Aircraft fixture sets an airport zone")
	_check(aircraft.city.set_building_id(20, 20, 0xdd), "Aircraft fixture places a runway")
	_check(aircraft.city.set_tile_flag(20, 20, 0x40, true), "Aircraft fixture powers its runway")
	_check(aircraft.document.set_misc_u32(0x01f0, 16383), "Aircraft fixture counts clear tiles")
	_check(aircraft.document.set_misc_u32(0x01f0 + 0xdd * 4, 1), "Aircraft fixture counts its runway")
	var aircraft_result := Growth.run(
		aircraft.city, SequenceRandom.new([1, 0, 0]), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(aircraft_result.ok, "Aircraft growth scan completes: %s" % aircraft_result.error)
	_check(aircraft_result.spawned_helicopters == 1, "Powered airport runway spawns a helicopter")
	_check(aircraft.city.text_overlay_id(20, 20) == 202, "Helicopter attaches record one to its runway")
	var helicopter: Dictionary = aircraft.city.thing(1)
	_check(
		helicopter.type == 2
		and helicopter.direction == 2
		and helicopter.state == 0
		and helicopter.x == 20
		and helicopter.y == 20,
		"Helicopter stores its recovered type, direction, state, and position",
	)
	_check(
		helicopter.px == 8
		and helicopter.py == 8
		and helicopter.dx == 1
		and helicopter.dy == 1,
		"Helicopter stores its recovered sub-tile and random destination fields",
	)

	var airplane := _special_growth_fixture(reference_root)
	_check(airplane.city.set_zone_id(20, 20, 8), "Airplane fixture sets an airport zone")
	_check(airplane.city.set_building_id(20, 20, 0xdd), "Airplane fixture places a runway")
	_check(airplane.city.set_tile_flag(20, 20, 0x40, true), "Airplane fixture powers its runway")
	_check(airplane.document.set_misc_u32(0x01f0, 16383), "Airplane fixture counts clear tiles")
	_check(airplane.document.set_misc_u32(0x01f0 + 0xdd * 4, 1), "Airplane fixture counts its runway")
	var airplane_result := Growth.run(
		airplane.city, SequenceRandom.new([1, 0, 4, 9]), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(airplane_result.ok and airplane_result.spawned_airplanes == 1, "Airport spawns an airplane")
	var plane: Dictionary = airplane.city.thing(1)
	_check(
		plane.type == 1
		and plane.direction == 0
		and plane.state == 0
		and plane.x == 20
		and plane.y == 20
		and plane.z == 0,
		"Local airplane stores its recovered position and runway direction",
	)
	_check(
		plane.px == 8 and plane.py == 8 and plane.dx == 20 and plane.dy == 20,
		"Local airplane stores its recovered sub-tile and destination fields",
	)
	_check(airplane.city.text_overlay_id(20, 20) == 202, "Airplane attaches its XTHG record")
	var edge_things := _filled_bytes(40 * 12, 0)
	var edge_text := _filled_bytes(128 * 128, 0)
	var edge_result := MovingThings.spawn_airplane(
		edge_things, edge_text, Vector2i(20, 20), 2, SequenceRandom.new([0, 2, 7])
	)
	_check(edge_result.spawned, "Airplane creator accepts an empty moving-thing pool")
	_check(
		edge_things[12 + 1] == 7
		and edge_things[12 + 2] == 0x23
		and edge_things[12 + 3] == 127
		and edge_things[12 + 4] == 17
		and edge_things[12 + 5] == 16,
		"Map-edge airplane stores its selected edge, direction, height, and runway state",
	)
	_check(
		edge_things[12 + 8] == 4
		and edge_things[12 + 9] == 20
		and edge_text[127 * 128 + 17] == 202,
		"Map-edge airplane stores its runway target and attached XTXT record",
	)

	var ship_fixture := _special_growth_fixture(reference_root)
	_check(ship_fixture.city.set_zone_id(20, 20, 9), "Ship fixture sets a seaport zone")
	_check(ship_fixture.city.set_building_id(20, 20, 0xe0), "Ship fixture places a crane")
	_check(ship_fixture.city.set_terrain_id(2, 10, 0x10), "Ship fixture places edge water")
	var stale_ship_record: PackedByteArray = ship_fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	stale_ship_record[12 + 8] = 77
	stale_ship_record[12 + 9] = 88
	_check(
		ship_fixture.document.find_chunk("XTHG").set_decoded_payload(stale_ship_record),
		"Ship fixture sets stale target bytes",
	)
	var ship_result := Growth.run(
		ship_fixture.city, SequenceRandom.new([1, 0, 0]), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(
		ship_result.ok
		and ship_result.spawned_ships == 1
		and ship_result.ship_home == Vector2i(2, 10)
		and ship_result.news_items == [{"type": 0x205, "argument": 0}],
		"Seaport crane spawns a cargo ship and reports its home and immediate news",
	)
	var ship: Dictionary = ship_fixture.city.thing(1)
	_check(
		ship.type == 3
		and ship.direction == 3
		and ship.x == 2
		and ship.y == 10
		and ship.z == 1,
		"Cargo ship uses the last water tile on its selected edge",
	)
	_check(ship.px == 8 and ship.py == 8, "Cargo ship stores its recovered sub-tile position")
	_check(ship.dx == 77 and ship.dy == 88, "Cargo-ship creation keeps stale target bytes")
	_check(ship_fixture.city.text_overlay_id(2, 10) == 202, "Cargo ship attaches its XTHG record")

	_test_growth_microsimulations(reference_root)


func _test_growth_microsimulations(reference_root: String) -> void:
	var station := _special_growth_fixture(reference_root)
	_check(station.city.set_building_id(20, 20, 0xed), "Train fixture places a rail station")
	_check(station.city.set_tile_flag(20, 20, 0x40, true), "Train fixture powers its station")
	_check(station.city.set_building_id(20, 18, 0x2c), "Train fixture places its spawn rail")
	_check(station.city.set_building_id(19, 18, 0x2c), "Train fixture places its west route rail")
	_check(station.city.set_building_id(21, 18, 0x2c), "Train fixture places its east route rail")
	_check(station.document.set_misc_u32(0x01f0 + 0xed * 4, 4), "Train fixture sets the station count")
	var train_result := Growth.run(
		station.city,
		ZeroRandom.new(),
		0,
		0,
		MicrosimLfsrRandom.new(),
		NonzeroLfsrRandom.new()
	)
	_check(train_result.ok and train_result.spawned_trains == 1, "Rail station spawns a train")
	_check(station.city.text_overlay_id(20, 18) == 202, "Train engine attaches to its rail tile")
	var engine: Dictionary = station.city.thing(1)
	var first_car: Dictionary = station.city.thing(2)
	var second_car: Dictionary = station.city.thing(3)
	_check(
		engine.type == 10
		and engine.direction == 1
		and engine.state == 2
		and engine.x == 20
		and engine.y == 18
		and engine.px == 21
		and engine.py == 18,
		"Train engine links its first car and follows the game-LCG search order",
	)
	_check(
		first_car.type == 11
		and first_car.state == 3
		and second_car.type == 11
		and first_car.px == 20
		and first_car.py == 18,
		"Train stores two linked car records at its initial tile",
	)
	var full_buildings := _filled_bytes(128 * 128, 0)
	var full_things := _filled_bytes(40 * 12, 0)
	var full_text := _filled_bytes(128 * 128, 0)
	full_buildings[20 * 128 + 18] = 0x2c
	full_buildings[20 * 128 + 17] = 0x2c
	for record in range(1, 40):
		full_things[record * 12] = 7
	_check(
		MovingThings.spawn_train(
			full_buildings, full_things, full_text, Vector2i(20, 20),
			ZeroLfsrRandom.new(), ZeroLfsrRandom.new()
		),
		"Full-pool train creator keeps the supplied unchecked-allocation result",
	)
	_check(
		full_things[0] == 11 and full_text[20 * 128 + 18] == 201,
		"Full-pool train creator writes reserved record zero like the supplied executable",
	)

	var marina := _special_growth_fixture(reference_root)
	_check(marina.city.set_building_id(20, 20, 0xf8), "Sailboat fixture places a marina")
	_check(marina.city.set_tile_flag(20, 20, 0x40, true), "Sailboat fixture powers its marina")
	_check(marina.city.set_tile_flag(20, 19, 0x04, true), "Sailboat fixture marks north water")
	_check(marina.document.set_misc_u32(0x01f0 + 0xf8 * 4, 9), "Sailboat fixture sets the marina count")
	var sailboat_result := Growth.run(
		marina.city, ZeroRandom.new(), 0, 0, MicrosimLfsrRandom.new()
	)
	_check(
		sailboat_result.ok and sailboat_result.spawned_sailboats == 1,
		"Marina spawns one sailboat on its valid adjacent water tile",
	)
	var sailboat: Dictionary = marina.city.thing(1)
	_check(
		sailboat.type == 9
		and sailboat.direction == 0
		and sailboat.x == 20
		and sailboat.y == 19
		and sailboat.px == 4
		and sailboat.py == 4,
		"Sailboat stores its recovered direction and sub-tile position",
	)
	_check(marina.city.text_overlay_id(20, 19) == 202, "Sailboat attaches its XTHG record")

	var arcology := _special_growth_fixture(reference_root)
	_check(arcology.city.set_building_id(20, 20, 0xfb), "Arcology fixture places an arcology tile")
	_check(arcology.city.set_building_corners(20, 20, 0x80), "Arcology fixture sets the absolute anchor bit")
	_check(arcology.city.set_text_overlay_id(20, 20, 61), "Arcology fixture attaches dynamic XMIC record ten")
	_check(arcology.city.set_tile_flag(20, 20, 0x40, true), "Arcology fixture powers the tile")
	_check(arcology.document.set_misc_u32(0x0008, 3), "Arcology fixture rotates the city")
	var microsims: PackedByteArray = arcology.document.find_chunk("XMIC").decoded_payload.duplicate()
	microsims[10 * 8] = 0xfb
	_check(arcology.document.find_chunk("XMIC").set_decoded_payload(microsims), "Arcology fixture sets its XMIC type")
	var coarse_index := 10 * 64 + 10
	var land_value: PackedByteArray = arcology.document.find_chunk("XVAL").decoded_payload.duplicate()
	land_value[coarse_index] = 224
	_check(arcology.document.find_chunk("XVAL").set_decoded_payload(land_value), "Arcology fixture sets land value")
	var crime: PackedByteArray = arcology.document.find_chunk("XCRM").decoded_payload.duplicate()
	crime[coarse_index] = 64
	_check(arcology.document.find_chunk("XCRM").set_decoded_payload(crime), "Arcology fixture sets crime")
	var pollution: PackedByteArray = arcology.document.find_chunk("XPLT").decoded_payload.duplicate()
	pollution[coarse_index] = 32
	_check(arcology.document.find_chunk("XPLT").set_decoded_payload(pollution), "Arcology fixture sets pollution")
	var arcology_result := Growth.run(
		arcology.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(arcology_result.ok and arcology_result.arcologies_updated == 1, "Arcology updates its XMIC statistic")
	_check(arcology.city.microsim(10).stat_0 == 8, "Arcology rating uses land value, crime, pollution, power, and water")


func _test_moving_thing_phase(reference_root: String) -> void:
	var explosion := _special_growth_fixture(reference_root)
	_set_explosion(explosion, 1, Vector2i(20, 20), 5, 0, 0)
	_check(explosion.city.set_building_id(20, 20, 0x90), "Explosion fixture places its center building")
	var first_explosion_frame := MovingThingTick.run(
		explosion.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	var second_explosion_frame := MovingThingTick.run(
		explosion.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	var final_explosion_frame := MovingThingTick.run(
		explosion.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		first_explosion_frame.ok
		and first_explosion_frame.complete
		and first_explosion_frame.news_items.size() == 1
		and first_explosion_frame.news_items[0].type == 0x1f8
		and second_explosion_frame.ok
		and final_explosion_frame.ok,
		"Explosion record requests news and advances through two animation frames",
	)
	_check(
		explosion.city.thing(1).type == 0
		and explosion.city.building_id(20, 20) == 0
		and explosion.city.text_overlay_id(20, 20) == 0,
		"Finished non-spreading explosion removes its record, center building, and link: %s %d %d"
		% [explosion.city.thing(1), explosion.city.building_id(20, 20), explosion.city.text_overlay_id(20, 20)],
	)

	var spreading_explosion := _special_growth_fixture(reference_root)
	_set_explosion(spreading_explosion, 1, Vector2i(20, 20), 5, 1, 2)
	var spreading_traffic: PackedByteArray = spreading_explosion.document.find_chunk("XTRF").decoded_payload.duplicate()
	spreading_traffic[10 * 64 + 10] = 200
	_check(
		spreading_explosion.document.find_chunk("XTRF").set_decoded_payload(spreading_traffic),
		"Spreading explosion fixture sets traffic",
	)
	var spread_result := MovingThingTick.run(
		spreading_explosion.city,
		SequenceRandom.new([1]),
		SequenceLfsrRandom.new([2, 2, 3, 2, 2, 3, 1, 2])
	)
	_check(
		spread_result.ok and spread_result.spread_explosion_fires == 4,
		"Spreading explosion applies four LFSR-selected fire attempts",
	)
	_check(
		spreading_explosion.city.text_overlay_id(20, 20) == 0xff
		and spreading_explosion.city.text_overlay_id(21, 20) == 0xff
		and spreading_explosion.city.text_overlay_id(20, 21) == 0xff
		and spreading_explosion.city.text_overlay_id(19, 20) == 0xff,
		"Explosion damage writes fire overlays at the recovered positions",
	)
	_check(
		spreading_explosion.document.find_chunk("XTRF").decoded_payload[10 * 64 + 10] == 0,
		"Explosion fire clears coarse traffic",
	)

	var labeled_explosion := _special_growth_fixture(reference_root)
	_set_explosion(labeled_explosion, 1, Vector2i(20, 20), 5, 1, 2)
	_check(labeled_explosion.city.set_label(1, "Blast Zone"), "Explosion fixture sets a user label")
	_check(labeled_explosion.city.set_text_overlay_id(21, 20, 1), "Explosion fixture places a user label")
	var label_damage := MovingThingTick.run(
		labeled_explosion.city,
		SequenceRandom.new([1]),
		SequenceLfsrRandom.new([3, 2, 3, 2, 3, 2, 3, 2])
	)
	_check(
		label_damage.ok
		and labeled_explosion.city.label(1).is_empty()
		and labeled_explosion.city.text_overlay_id(21, 20) == 0xff,
		"Explosion damage releases a user label before it starts fire",
	)

	var rubble_explosion := _special_growth_fixture(reference_root)
	_set_explosion(rubble_explosion, 1, Vector2i(20, 20), 5, 1, 2)
	_check(rubble_explosion.city.set_building_id(21, 20, 0x90), "Rubble explosion fixture places a building")
	_check(rubble_explosion.city.set_text_overlay_id(21, 20, 241), "Rubble explosion fixture places overlay 241")
	var rubble_result := MovingThingTick.run(
		rubble_explosion.city,
		SequenceRandom.new([1]),
		SequenceLfsrRandom.new([3, 2, 0, 3, 2, 0, 3, 2, 0, 3, 2, 0])
	)
	_check(
		rubble_result.ok
		and rubble_result.rubble_explosion_hits == 4
		and rubble_explosion.city.building_id(21, 20) == 1
		and rubble_explosion.city.text_overlay_id(21, 20) == 241,
		"Explosion overlay 241 through 249 changes the building to LFSR-selected rubble: %s %d %d"
		% [rubble_result, rubble_explosion.city.building_id(21, 20), rubble_explosion.city.text_overlay_id(21, 20)],
	)

	var facility_explosion := _special_growth_fixture(reference_root)
	_set_explosion(facility_explosion, 1, Vector2i(20, 20), 5, 1, 2)
	_check(facility_explosion.city.set_building_id(21, 20, 0x8b), "Facility explosion fixture places a building")
	_check(facility_explosion.document.set_misc_u32(0x01f0, 16383), "Facility explosion fixture counts occupied land")
	_check(facility_explosion.document.set_misc_u32(0x01f0 + 0x8b * 4, 1), "Facility explosion fixture counts its building")
	var facility_microsims: PackedByteArray = facility_explosion.document.find_chunk("XMIC").decoded_payload.duplicate()
	facility_microsims[10 * 8] = 0x8b
	_check(
		facility_explosion.document.find_chunk("XMIC").set_decoded_payload(facility_microsims),
		"Facility explosion fixture stores its XMIC record",
	)
	_check(facility_explosion.city.set_label(61, "Blast Facility"), "Facility explosion fixture sets its XLAB record")
	_check(facility_explosion.city.set_text_overlay_id(21, 20, 61), "Facility explosion fixture places XMIC overlay 61")
	var facility_result := MovingThingTick.run(
		facility_explosion.city,
		SequenceRandom.new([1]),
		SequenceLfsrRandom.new([3, 2, 3, 2, 3, 2, 3, 2])
	)
	_check(
		facility_result.ok
		and facility_result.damaged_facilities == 1
		and facility_result.deferred_facility_explosion_hits == 0
		and facility_result.explosion_map_damage_complete,
		"Explosion applies the full linked-facility damage path once",
	)
	_check(
		facility_explosion.city.building_id(21, 20) == 2
		and facility_explosion.city.text_overlay_id(21, 20) == 0xff
		and facility_explosion.city.microsim(10).tile_id == 0
		and facility_explosion.city.label(61).is_empty(),
		"Facility blast creates rubble and fire and releases XMIC and XLAB",
	)

	var connection_explosion := _special_growth_fixture(reference_root)
	_set_explosion(connection_explosion, 1, Vector2i(20, 20), 5, 1, 2)
	_check(connection_explosion.city.set_building_id(21, 20, 0x1d), "Connection blast fixture places a road")
	_check(connection_explosion.city.set_text_overlay_id(21, 20, 250), "Connection blast fixture places a neighbor label")
	var connection_result := MovingThingTick.run(
		connection_explosion.city,
		SequenceRandom.new([1]),
		SequenceLfsrRandom.new([3, 2, 3, 2, 3, 2, 3, 2])
	)
	_check(
		connection_result.ok
		and connection_result.connection_count_changes.size() == 1
		and connection_result.connection_count_changes[0].kind == "commerce"
		and connection_result.connection_count_changes[0].delta == -1
		and connection_result.connection_count_changes[0].point == Vector2i(21, 20)
		and connection_result.explosion_map_damage_complete,
		"Explosion damage reports the original commerce-connection decrement",
	)

	var tornado := _special_growth_fixture(reference_root)
	_set_tornado(tornado, 1, Vector2i(20, 20), 2)
	_check(tornado.city.set_building_id(20, 20, 0x1d), "Tornado fixture places a road")
	_check(tornado.document.set_misc_u32(0x01f0, 16383), "Tornado fixture counts occupied land")
	_check(tornado.document.set_misc_u32(0x01f0 + 0x1d * 4, 1), "Tornado fixture counts its road")
	var tornado_result := MovingThingTick.run(
		tornado.city,
		SequenceRandom.new([0, 1, 0, 1]),
		NonzeroLfsrRandom.new()
	)
	_check(
		tornado_result.ok
		and tornado_result.active_tornadoes == 1
		and tornado_result.tornado_demolitions == 1
		and tornado_result.moved_tornadoes == 1,
		"Tornado demolishes a structure and makes its first movement",
	)
	_check(
		tornado.city.building_id(20, 20) == 1
		and tornado.city.thing(1).px == 16
		and tornado.city.thing(1).py == 16,
		"Tornado stores rubble and its eight-unit sub-tile movement",
	)

	var fast_tornado := _special_growth_fixture(reference_root)
	_set_tornado(fast_tornado, 1, Vector2i(20, 20), 2)
	var fast_tornado_result := MovingThingTick.run(
		fast_tornado.city,
		SequenceRandom.new([0, 0, 1, 0, 0, 1]),
		NonzeroLfsrRandom.new()
	)
	_check(
		fast_tornado_result.ok
		and fast_tornado_result.moved_tornadoes == 2
		and fast_tornado.city.thing(1).x == 21
		and fast_tornado.city.thing(1).px == 8,
		"Tornado makes a second movement over a low tile",
	)

	var expired_tornado := _special_growth_fixture(reference_root)
	_set_tornado(expired_tornado, 1, Vector2i(20, 20), 2)
	var expired_tornado_result := MovingThingTick.run(
		expired_tornado.city,
		SequenceRandom.new([0, 0, 0]),
		NonzeroLfsrRandom.new()
	)
	_check(
		expired_tornado_result.ok
		and expired_tornado_result.removed_tornadoes == 1
		and expired_tornado.city.thing(1).type == 0
		and expired_tornado.city.text_overlay_id(20, 20) == 0,
		"Tornado expires on its recovered first low-byte random gate",
	)

	var maxis_man := _special_growth_fixture(reference_root)
	_set_maxis_man(maxis_man, 1, Vector2i(20, 20), 0, 241, Vector2i(30, 20))
	_check(maxis_man.city.set_text_overlay_id(30, 20, 241), "Maxis Man fixture places its fixed target")
	var maxis_result := MovingThingTick.run(
		maxis_man.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		maxis_result.ok
		and maxis_result.active_maxis_men == 1
		and maxis_result.moved_maxis_men == 2,
		"Maxis Man moves twice toward a clear fixed target",
	)
	_check(
		maxis_man.city.thing(1).x == 22
		and maxis_man.city.thing(1).y == 20
		and maxis_man.city.thing(1).direction == 2,
		"Maxis Man stores its pursuit direction and moved coordinates",
	)

	var firefighting_maxis := _special_growth_fixture(reference_root)
	_set_maxis_man(firefighting_maxis, 1, Vector2i(20, 20), 0, 241, Vector2i(21, 20))
	_check(firefighting_maxis.city.set_text_overlay_id(21, 20, 0xff), "Maxis Man fixture starts target fire")
	var firefighting_result := MovingThingTick.run(
		firefighting_maxis.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		firefighting_result.ok
		and firefighting_result.maxis_man_extinguished_fires == 1
		and firefighting_result.moved_maxis_men == 1
		and firefighting_maxis.city.thing(1).x == 21
		and firefighting_maxis.city.text_overlay_id(21, 20) == 202,
		"Maxis Man clears a fire and moves into its cell on an odd random bit",
	)

	var attacking_maxis := _special_growth_fixture(reference_root)
	_set_idle_thing(attacking_maxis, 1, Vector2i(21, 20), 14, 5)
	_set_maxis_man(attacking_maxis, 39, Vector2i(20, 20), 0, 1, Vector2i.ZERO)
	var attack_result := MovingThingTick.run(
		attacking_maxis.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		attack_result.ok
		and attack_result.maxis_man_destroyed_targets == 1
		and attack_result.maxis_man_explosions == 1
		and attack_result.news_items.size() == 1
		and attack_result.news_items[0].type == 0x1f8
		and attacking_maxis.city.thing(39).state == 2,
		"Maxis Man destroys its exact XTHG target on the recovered random gate",
	)
	_check(
		attacking_maxis.city.thing(1).type == 6
		and attacking_maxis.city.thing(1).direction == 0
		and attacking_maxis.city.thing(1).z == 5
		and attacking_maxis.city.text_overlay_id(21, 20) == 202,
		"Maxis Man replaces the target with a spreading explosion",
	)

	var monster := _special_growth_fixture(reference_root)
	_check(monster.document.set_misc_u32(0x1018, 30), "Monster fixture sets city-center X")
	_check(monster.document.set_misc_u32(0x101c, 20), "Monster fixture sets city-center Y")
	_set_monster(monster, 1, Vector2i(20, 20), 2, 0, 10, 0)
	var monster_result := MovingThingTick.run(
		monster.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		monster_result.ok
		and monster_result.active_monsters == 1
		and monster_result.moved_monsters == 1
		and monster.city.thing(1).z == 9
		and monster.city.thing(1).direction == 2,
		"Descending monster moves toward the saved city center",
	)

	var radioactive_monster := _special_growth_fixture(reference_root)
	_set_monster(radioactive_monster, 1, Vector2i(20, 20), 2, 1, 8, 1)
	_check(radioactive_monster.city.set_building_id(21, 21, 0x8b), "Monster damage fixture places a building")
	_check(radioactive_monster.document.set_misc_u32(0x01f0, 16383), "Monster damage fixture counts occupied land")
	_check(radioactive_monster.document.set_misc_u32(0x01f0 + 0x8b * 4, 1), "Monster damage fixture counts its building")
	var radioactive_result := MovingThingTick.run(
		radioactive_monster.city,
		SequenceRandom.new([1, 0, 0, 1, 0, 2]),
		NonzeroLfsrRandom.new()
	)
	_check(
		radioactive_result.ok
		and radioactive_result.monster_damage_hits == 1
		and radioactive_result.moved_monsters == 1
		and radioactive_result.news_items.size() == 1
		and radioactive_result.news_items[0].type == 0x202,
		"Goal-one monster demolishes its diagonal target and marks a damage effect",
	)
	_check(
		radioactive_monster.city.building_id(21, 21) == 11
		and radioactive_monster.city.thing(1).dx == 0x80,
		"Goal-one monster replaces the target with process-random radiation",
	)

	var military_monster := _special_growth_fixture(reference_root)
	_check(military_monster.document.set_misc_u32(0x1018, 30), "Monster collision fixture sets city-center X")
	_check(military_monster.document.set_misc_u32(0x101c, 20), "Monster collision fixture sets city-center Y")
	_set_monster(military_monster, 1, Vector2i(20, 20), 2, 0, 10, 0)
	_set_idle_thing(military_monster, 2, Vector2i(21, 20), 14, 0)
	var military_result := MovingThingTick.run(
		military_monster.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		military_result.ok
		and military_result.monster_military_collisions == 1
		and military_monster.city.thing(1).state == 3
		and military_monster.city.thing(1).x == 20,
		"Monster enters state three when a military unit blocks its next cell",
	)

	var fleeing_plane := _special_growth_fixture(reference_root)
	_set_airplane(fleeing_plane, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 14)
	_set_monster(fleeing_plane, 2, Vector2i(30, 30), 2, 0, 10, 0)
	var fleeing_result := MovingThingTick.run(
		fleeing_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		fleeing_result.ok
		and fleeing_result.monster_forced_airplanes == 1
		and fleeing_plane.city.thing(1).state == 7,
		"Monster forces airplanes already scanned in the tick into falling state",
	)

	var expired_monster := _special_growth_fixture(reference_root)
	_set_monster(expired_monster, 1, Vector2i(20, 20), 2, 3, 10, 0)
	var expired_monster_result := MovingThingTick.run(
		expired_monster.city, ZeroRandom.new(), ZeroLfsrRandom.new()
	)
	_check(
		expired_monster_result.ok
		and expired_monster_result.removed_monsters == 1
		and expired_monster.city.thing(1).type == 0,
		"State-three monster expires on its LFSR modulo-100 gate",
	)

	var airplane := _special_growth_fixture(reference_root)
	_set_airplane(airplane, 1, Vector2i(20, 20), Vector2i(20, 20), 2, 0, 0)
	_check(airplane.city.set_building_id(20, 20, 0xdd), "Airplane takeoff fixture places a runway")
	_check(airplane.city.set_zone_id(20, 20, 8), "Airplane takeoff fixture sets the airport zone")
	var takeoff_plane_result := MovingThingTick.run(
		airplane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		takeoff_plane_result.ok
		and takeoff_plane_result.active_airplanes == 1
		and takeoff_plane_result.moved_airplanes == 1
		and takeoff_plane_result.news_items.size() == 1
		and takeoff_plane_result.news_items[0].type == 0x206
		and airplane.city.thing(1).x == 21
		and airplane.city.thing(1).z == 1,
		"Airplane takeoff moves at sixteen sub-tiles, gains height, and requests news",
	)

	var cruising_plane := _special_growth_fixture(reference_root)
	_set_airplane(cruising_plane, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 14)
	_check(cruising_plane.city.set_building_id(23, 20, 0xfb), "Airplane obstacle fixture places an arcology")
	var cruise_plane_result := MovingThingTick.run(
		cruising_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		cruise_plane_result.ok
		and cruising_plane.city.thing(1).direction == 3
		and cruising_plane.city.thing(1).x == 21
		and cruising_plane.city.thing(1).y == 21,
		"Airplane cruise avoids an arcology and moves one diagonal tile",
	)

	var approaching_plane := _special_growth_fixture(reference_root)
	_set_airplane(approaching_plane, 1, Vector2i(10, 20), Vector2i(12, 20), 2, 3, 16)
	var approach_result := MovingThingTick.run(
		approaching_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		approach_result.ok
		and approaching_plane.city.thing(1).x == 11
		and approaching_plane.city.thing(1).state == 4
		and approaching_plane.city.thing(1).direction == 1,
		"Inbound airplane enters alignment when it reaches its runway target",
	)
	var alignment_result := MovingThingTick.run(
		approaching_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		alignment_result.ok
		and approaching_plane.city.thing(1).x == 12
		and approaching_plane.city.thing(1).state == 1
		and approaching_plane.city.thing(1).direction == 0,
		"Inbound airplane completes alignment and starts descent",
	)

	var landing_plane := _special_growth_fixture(reference_root)
	_set_airplane(landing_plane, 1, Vector2i(20, 20), Vector2i(21, 20), 2, 1, 1)
	_check(landing_plane.city.set_building_id(21, 20, 0xdd), "Landing airplane fixture places its destination runway")
	var landing_plane_result := MovingThingTick.run(
		landing_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		landing_plane_result.ok
		and landing_plane_result.landed_airplanes == 1
		and landing_plane_result.news_items.size() == 1
		and landing_plane_result.news_items[0].type == 0x207
		and landing_plane.city.thing(1).type == 0
		and landing_plane.city.text_overlay_id(21, 20) == 0,
		"Airplane completes descent and releases its record on a runway",
	)

	var missed_runway := _special_growth_fixture(reference_root)
	_set_airplane(missed_runway, 1, Vector2i(20, 20), Vector2i(21, 20), 2, 1, 1)
	var missed_result := MovingThingTick.run(
		missed_runway.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		missed_result.ok
		and missed_result.crashed_airplanes == 1
		and missed_runway.city.thing(1).type == 6
		and missed_runway.city.thing(1).state == 5
		and missed_runway.city.thing(1).goal == 1
		and missed_runway.city.text_overlay_id(21, 20) == 0,
		"Airplane landing outside a runway becomes an unlinked spreading explosion",
	)

	var low_plane := _special_growth_fixture(reference_root)
	_set_airplane(low_plane, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 11)
	_check(low_plane.city.set_building_id(20, 20, 0xbb), "Low airplane fixture places the tallest small-map building sprite")
	var low_plane_result := MovingThingTick.run(
		low_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		low_plane_result.ok
		and low_plane_result.crashed_airplanes == 1
		and low_plane.city.thing(1).type == 6
		and low_plane.city.thing(1).goal == 1,
		"Airplane collision uses one third of the recovered building sprite height",
	)

	var arcology_plane := _special_growth_fixture(reference_root)
	_set_airplane(arcology_plane, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 16)
	_check(arcology_plane.city.set_building_id(20, 20, 0xfb), "Airplane crash fixture places an arcology")
	var arcology_plane_result := MovingThingTick.run(
		arcology_plane.city, SequenceRandom.new([1]), ZeroLfsrRandom.new()
	)
	_check(
		arcology_plane_result.ok
		and arcology_plane.city.thing(1).type == 6
		and arcology_plane.city.thing(1).goal == 1,
		"Airplane arcology collision selects a spreading explosion on its LFSR gate",
	)

	var falling_plane := _special_growth_fixture(reference_root)
	_set_airplane(falling_plane, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 7, 9)
	var falling_result := MovingThingTick.run(
		falling_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		falling_result.ok
		and falling_result.news_items.size() == 1
		and falling_result.news_items[0].type == 0x203
		and falling_plane.city.thing(1).z == 8
		and falling_plane.city.thing(1).direction == 3
		and falling_plane.city.thing(1).x == 21
		and falling_plane.city.thing(1).y == 20,
		"Falling airplane rotates its saved direction but moves in its prior direction",
	)

	var ship := _special_growth_fixture(reference_root)
	_set_ship(ship, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 0)
	_check(ship.city.set_tile_flag(20, 20, 0x04, true), "Cargo-ship fixture marks current water")
	_check(ship.city.set_tile_flag(24, 20, 0x04, true), "Cargo-ship fixture marks look-ahead water")
	var first_ship_move := MovingThingTick.run(
		ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	var second_ship_move := MovingThingTick.run(
		ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		first_ship_move.ok
		and second_ship_move.ok
		and first_ship_move.moved_ships == 1
		and second_ship_move.moved_ships == 1,
		"Cargo ship advances on a valid four-cell look-ahead route",
	)
	_check(
		ship.city.thing(1).x == 21
		and ship.city.thing(1).y == 20
		and ship.city.thing(1).px == 4
		and ship.city.thing(1).py == 8,
		"Cargo ship uses the recovered twelve-unit sub-tile grid",
	)
	_check(ship.city.text_overlay_id(20, 20) == 0, "Cargo ship clears its old XTXT cell")
	_check(ship.city.text_overlay_id(21, 20) == 202, "Cargo ship links its new XTXT cell")

	var docking_ship := _special_growth_fixture(reference_root)
	_set_ship(docking_ship, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 0)
	_check(docking_ship.city.set_tile_flag(20, 20, 0x04, true), "Docking ship marks current water")
	_check(docking_ship.city.set_tile_flag(24, 20, 0x04, true), "Docking ship marks route water")
	_check(docking_ship.city.set_building_id(22, 20, 0xdf), "Docking ship places a pier two cells away")
	var dock_result := MovingThingTick.run(
		docking_ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		dock_result.ok
		and dock_result.docked_ships == 1
		and docking_ship.city.thing(1).state == 3,
		"Cargo ship enters dock wait beside a pier",
	)
	var depart_result := MovingThingTick.run(
		docking_ship.city,
		SequenceRandom.new([1]),
		ZeroLfsrRandom.new(),
		null,
		Vector2i(2, 10)
	)
	_check(
		depart_result.ok
		and depart_result.departing_ships == 1
		and depart_result.news_items.size() == 1
		and depart_result.news_items[0].type == 0x205
		and docking_ship.city.thing(1).state == 4
		and docking_ship.city.thing(1).dx == 2
		and docking_ship.city.thing(1).dy == 10,
		"Cargo ship leaves dock toward its process-local home coordinates",
	)

	var blocked_ship := _special_growth_fixture(reference_root)
	_set_ship(blocked_ship, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 0)
	_check(blocked_ship.city.set_tile_flag(20, 20, 0x04, true), "Blocked ship marks current water")
	var block_result := MovingThingTick.run(
		blocked_ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		block_result.ok and blocked_ship.city.thing(1).state == 1,
		"Cargo ship starts a target turn when its look-ahead route is blocked",
	)
	_check(blocked_ship.city.set_tile_flag(24, 20, 0x04, true), "Turning ship opens its target route")
	MovingThingTick.run(blocked_ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new())
	MovingThingTick.run(blocked_ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new())
	_check(
		blocked_ship.city.thing(1).direction == 2 and blocked_ship.city.thing(1).state == 0,
		"Cargo ship turns one step per tick and resumes travel when its target route opens",
	)

	var escaping_ship := _special_growth_fixture(reference_root)
	_set_ship(escaping_ship, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2)
	_check(escaping_ship.city.set_tile_flag(20, 20, 0x04, true), "Escaping ship marks current water")
	_check(escaping_ship.city.set_tile_flag(23, 23, 0x04, true), "Escaping ship opens its diagonal route")
	var escape_result := MovingThingTick.run(
		escaping_ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		escape_result.ok
		and escaping_ship.city.thing(1).direction == 3
		and escaping_ship.city.thing(1).state == 0,
		"Cargo ship escape search selects the first valid recovered direction",
	)

	var trapped_ship := _special_growth_fixture(reference_root)
	_set_ship(trapped_ship, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2)
	_check(trapped_ship.city.set_tile_flag(20, 20, 0x04, true), "Trapped ship marks current water")
	var trapped_result := MovingThingTick.run(
		trapped_ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		trapped_result.ok
		and trapped_result.removed_ships == 1
		and trapped_ship.city.thing(1).type == 0,
		"Cargo ship releases its record when all eight escape routes fail",
	)

	var grounded_ship := _special_growth_fixture(reference_root)
	_set_ship(grounded_ship, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 0)
	var grounded_result := MovingThingTick.run(
		grounded_ship.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		grounded_result.ok
		and grounded_result.crashed_ships == 1
		and grounded_ship.city.thing(1).type == 6
		and grounded_ship.city.thing(1).state == 0
		and grounded_ship.city.thing(1).goal == 0,
		"Cargo ship on dry land becomes the recovered explosion record",
	)

	var helicopter := _special_growth_fixture(reference_root)
	_set_helicopter(helicopter, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 0, 0)
	var takeoff_result := MovingThingTick.run(
		helicopter.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		takeoff_result.ok
		and takeoff_result.active_helicopters == 1
		and helicopter.city.thing(1).direction == 3
		and helicopter.city.thing(1).z == 1,
		"Helicopter takeoff rotates and gains one height unit",
	)

	var flight := _special_growth_fixture(reference_root)
	_set_helicopter(flight, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 10)
	var first_flight := MovingThingTick.run(
		flight.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	var second_flight := MovingThingTick.run(
		flight.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		first_flight.ok
		and second_flight.ok
		and first_flight.moved_helicopters == 1
		and second_flight.moved_helicopters == 1,
		"Cruising helicopter advances on each off-cycle tick",
	)
	_check(
		flight.city.thing(1).x == 21
		and flight.city.thing(1).y == 20
		and flight.city.thing(1).px == 8
		and flight.city.thing(1).py == 8,
		"Helicopter uses the recovered eight-unit sub-tile speed",
	)
	_check(flight.city.text_overlay_id(20, 20) == 0, "Helicopter clears its old XTXT cell")
	_check(flight.city.text_overlay_id(21, 20) == 202, "Helicopter links its new XTXT cell")

	var traffic_helicopter := _special_growth_fixture(reference_root)
	_set_helicopter(traffic_helicopter, 1, Vector2i(20, 20), Vector2i(40, 20), 2, 2, 10)
	_check(
		traffic_helicopter.document.find_chunk("XTRF").set_decoded_payload(_filled_bytes(64 * 64, 200)),
		"Traffic-news fixture fills the traffic map",
	)
	var first_traffic_news := MovingThingTick.run(
		traffic_helicopter.city, ZeroRandom.new(), NonzeroLfsrRandom.new(), null,
		Vector2i(-1, -1), true, 1000, 0
	)
	var throttled_traffic_news := MovingThingTick.run(
		traffic_helicopter.city, ZeroRandom.new(), NonzeroLfsrRandom.new(), null,
		Vector2i(-1, -1), true, 6000, first_traffic_news.traffic_news_deadline_msec
	)
	var resumed_traffic_news := MovingThingTick.run(
		traffic_helicopter.city, ZeroRandom.new(), NonzeroLfsrRandom.new(), null,
		Vector2i(-1, -1), true, 6001, throttled_traffic_news.traffic_news_deadline_msec
	)
	_check(
		first_traffic_news.ok
		and first_traffic_news.news_items.size() == 1
		and first_traffic_news.news_items[0].type == 0x1fe
		and first_traffic_news.traffic_news_deadline_msec == 6000
		and throttled_traffic_news.news_items.is_empty()
		and resumed_traffic_news.news_items.size() == 1,
		"Helicopter traffic news uses the recovered strict five-second deadline",
	)

	var avoiding := _special_growth_fixture(reference_root)
	_set_helicopter(avoiding, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 10)
	_check(avoiding.city.set_building_id(23, 20, 0xfb), "Helicopter obstacle fixture places an arcology")
	var avoid_result := MovingThingTick.run(
		avoiding.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		avoid_result.ok and avoiding.city.thing(1).direction == 3,
		"Helicopter selects the first clear recovered obstacle-avoidance direction",
	)

	var retargeting := _special_growth_fixture(reference_root)
	_check(retargeting.document.set_misc_u32(0x1018, 50), "Helicopter fixture sets city-center X")
	_check(retargeting.document.set_misc_u32(0x101c, 60), "Helicopter fixture sets city-center Y")
	_set_helicopter(retargeting, 1, Vector2i(20, 20), Vector2i(20, 20), 2, 2, 10)
	var retarget_result := MovingThingTick.run(
		retargeting.city, SequenceRandom.new([32, 32, 1]), NonzeroLfsrRandom.new()
	)
	_check(
		retarget_result.ok
		and retargeting.city.thing(1).dx == 50
		and retargeting.city.thing(1).dy == 60
		and retargeting.city.thing(1).state == 3,
		"Helicopter selects a city-center target and can start landing on clear ground",
	)

	var landing := _special_growth_fixture(reference_root)
	_set_helicopter(landing, 1, Vector2i(20, 20), Vector2i(20, 20), 2, 3, 3)
	MovingThingTick.run(landing.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new())
	MovingThingTick.run(landing.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new())
	_check(
		landing.city.thing(1).state == 4 and landing.city.thing(1).z == 2,
		"Helicopter landing rotates, descends, and enters its ground wait state",
	)
	MovingThingTick.run(landing.city, ZeroRandom.new(), NonzeroLfsrRandom.new())
	_check(landing.city.thing(1).state == 0, "Helicopter ground wait restarts on its process-random gate")

	var forced_crash := _special_growth_fixture(reference_root)
	_set_helicopter(forced_crash, 1, Vector2i(20, 20), Vector2i(20, 20), 2, 5, 2)
	var forced_crash_result := MovingThingTick.run(
		forced_crash.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		forced_crash_result.ok
		and forced_crash_result.crashed_helicopters == 1
		and forced_crash.city.thing(1).type == 6
		and forced_crash.city.thing(1).state == 0x11
		and forced_crash.city.thing(1).goal == 1,
		"Helicopter emergency descent becomes the recovered explosion record",
	)

	var building_crash := _special_growth_fixture(reference_root)
	_set_helicopter(building_crash, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 10)
	_check(building_crash.city.set_building_id(20, 20, 0xfb), "Helicopter crash fixture places an arcology")
	var building_crash_result := MovingThingTick.run(
		building_crash.city, ZeroRandom.new(), NonzeroLfsrRandom.new()
	)
	_check(
		building_crash_result.ok
		and building_crash.city.thing(1).type == 6
		and building_crash.city.thing(1).state == 5
		and building_crash.city.thing(1).goal == 0,
		"Helicopter collision with an arcology becomes a non-spreading explosion",
	)

	var moving := _special_growth_fixture(reference_root)
	_set_sailboat(moving, 1, Vector2i(20, 20), 1)
	_check(moving.city.set_tile_flag(20, 20, 0x04, true), "Moving sailboat fixture marks its current water")
	_check(moving.city.set_tile_flag(21, 20, 0x04, true), "Moving sailboat fixture marks its next water")
	var move_result := MovingThingTick.run(
		moving.city, ZeroRandom.new(), SequenceLfsrRandom.new([1])
	)
	_check(move_result.ok and move_result.moved_sailboats == 1, "Sailboat tick moves on a clear water route")
	var moved_sailboat: Dictionary = moving.city.thing(1)
	_check(
		moved_sailboat.x == 21
		and moved_sailboat.y == 20
		and moved_sailboat.px == 4
		and moved_sailboat.py == 4,
		"Sailboat movement advances one tile and keeps its recovered sub-tile position",
	)
	_check(moving.city.text_overlay_id(20, 20) == 0, "Sailboat movement clears its old XTXT cell")
	_check(moving.city.text_overlay_id(21, 20) == 202, "Sailboat movement links its new XTXT cell")

	var turning := _special_growth_fixture(reference_root)
	_set_sailboat(turning, 1, Vector2i(20, 20), 1)
	_check(turning.city.set_tile_flag(20, 20, 0x04, true), "Turning sailboat fixture marks water")
	var turn_result := MovingThingTick.run(
		turning.city, SequenceRandom.new([2]), SequenceLfsrRandom.new([0, 1])
	)
	_check(turn_result.ok and turn_result.turned_sailboats == 1, "Sailboat turns on its LFSR gate")
	_check(
		turning.city.thing(1).direction == 2
		and turning.city.thing(1).x == 20
		and turning.city.thing(1).y == 20,
		"Sailboat turn uses the process generator and stays on its tile",
	)

	var distress := _special_growth_fixture(reference_root)
	_set_sailboat(distress, 1, Vector2i(20, 20), 0)
	_check(distress.city.set_tile_flag(20, 20, 0x04, true), "Distress fixture marks water")
	var distress_result := MovingThingTick.run(
		distress.city, ZeroRandom.new(), SequenceLfsrRandom.new([0, 0])
	)
	_check(
		distress_result.ok
		and distress_result.distressed_sailboats == 1
		and distress_result.news_items.size() == 1
		and distress_result.news_items[0].type == 0x20f,
		"Sailboat distress sets its state and returns news item 0x20f",
	)
	_check(distress.city.thing(1).state == 1, "Distressed sailboat stores state one")
	var removal_result := MovingThingTick.run(
		distress.city, ZeroRandom.new(), SequenceLfsrRandom.new([0])
	)
	_check(removal_result.ok and removal_result.removed_sailboats == 1, "Distressed sailboat expires on its LFSR gate")
	_check(distress.city.thing(1).type == 0, "Expired sailboat releases its XTHG record")
	_check(distress.city.text_overlay_id(20, 20) == 0, "Expired sailboat clears its XTXT cell")

	var marina := _special_growth_fixture(reference_root)
	_set_sailboat(marina, 1, Vector2i(20, 20), 1)
	_check(marina.city.set_building_id(21, 20, 0xf8), "Sailboat destination fixture places a marina")
	var marina_result := MovingThingTick.run(
		marina.city, ZeroRandom.new(), SequenceLfsrRandom.new([1])
	)
	_check(marina_result.ok and marina_result.removed_sailboats == 1, "Sailboat disappears when it reaches a marina")
	_check(marina.city.thing(1).type == 0, "Marina arrival releases the sailboat record")
	_check(marina.city.text_overlay_id(20, 20) == 0, "Marina arrival clears the sailboat link")

	var train := _special_growth_fixture(reference_root)
	for x in range(20, 23):
		_check(train.city.set_building_id(x, 20, 0x2c), "Moving train fixture places surface rail")
	_set_train(train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var train_result := MovingThingTick.run(
		train.city, ZeroRandom.new(), SequenceLfsrRandom.new([0, 1]), ZeroLfsrRandom.new()
	)
	_check(train_result.ok and train_result.moved_trains == 1, "Train tick advances a clear consist")
	var moved_engine: Dictionary = train.city.thing(1)
	_check(
		moved_engine.x == 21
		and moved_engine.y == 20
		and moved_engine.px == 22
		and moved_engine.py == 20
		and moved_engine.direction == 1
		and moved_engine.dx == 2,
		"Train engine moves and plans its next straight rail cell",
	)
	_check(
		train.city.thing(2).x == 20
		and train.city.thing(2).px == 21
		and train.city.thing(3).x == 20
		and train.city.thing(3).px == 20,
		"Train cars copy the prior engine and first-car states in order",
	)
	_check(train.city.text_overlay_id(20, 20) == 0, "Train movement restores the tail XTXT value")
	_check(train.city.text_overlay_id(21, 20) == 202, "Train movement attaches the engine at its new cell")

	var station := _special_growth_fixture(reference_root)
	_check(station.city.set_building_id(20, 20, 0x2c), "Pausing train fixture places current rail")
	_check(station.city.set_building_id(21, 20, 0x2c), "Pausing train fixture places destination rail")
	_check(station.city.set_building_id(20, 19, 0xed), "Pausing train fixture places an adjacent station")
	_set_train(station, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var pause_result := MovingThingTick.run(
		station.city, ZeroRandom.new(), SequenceLfsrRandom.new([1]), ZeroLfsrRandom.new()
	)
	_check(pause_result.ok and pause_result.paused_trains == 1, "Surface train pauses beside a station")
	_check(
		station.city.thing(1).x == 20 and station.city.thing(1).px == 21,
		"Station pause keeps the train position and destination",
	)

	var turning_train := _special_growth_fixture(reference_root)
	_check(turning_train.city.set_building_id(20, 20, 0x2c), "Turning train fixture places current rail")
	_check(turning_train.city.set_building_id(21, 20, 0x2c), "Turning train fixture places destination rail")
	_check(turning_train.city.set_building_id(21, 19, 0x2c), "Turning train fixture places north rail")
	_set_train(turning_train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var train_turn_result := MovingThingTick.run(
		turning_train.city,
		SequenceRandom.new([0]),
		SequenceLfsrRandom.new([0, 0, 0]),
		ZeroLfsrRandom.new()
	)
	_check(
		train_turn_result.ok
		and train_turn_result.turned_trains == 1
		and train_turn_result.news_items.size() == 1
		and train_turn_result.news_items[0].type == 0x20c,
		"Train side turn returns the recovered random news item",
	)
	_check(
		turning_train.city.thing(1).x == 21
		and turning_train.city.thing(1).y == 20
		and turning_train.city.thing(1).px == 21
		and turning_train.city.thing(1).py == 19
		and turning_train.city.thing(1).direction == 1
		and turning_train.city.thing(1).dx == 0,
		"Random train turn keeps the supplied prior-direction field quirk",
	)

	var subway_train := _special_growth_fixture(reference_root)
	_check(subway_train.city.set_building_id(20, 20, 0x2c), "Subway train fixture places current rail")
	_check(subway_train.city.set_building_id(21, 20, 0x6c), "Subway train fixture places a transition tile")
	_check(subway_train.city.set_underground_id(22, 20, 1), "Subway train fixture places its next subway")
	_set_train(subway_train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var subway_train_result := MovingThingTick.run(
		subway_train.city,
		ZeroRandom.new(),
		SequenceLfsrRandom.new([0, 1]),
		ZeroLfsrRandom.new()
	)
	_check(subway_train_result.ok and subway_train_result.moved_trains == 1, "Train enters a subway transition")
	_check(
		subway_train.city.thing(1).type == 12
		and subway_train.city.thing(1).x == 21
		and subway_train.city.thing(1).px == 22,
		"Surface engine becomes a subway engine and plans an underground route",
	)

	var reversing_train := _special_growth_fixture(reference_root)
	_check(reversing_train.city.set_building_id(20, 20, 0x2c), "Reversing train fixture places its old rail")
	_check(reversing_train.city.set_building_id(21, 20, 0x2c), "Reversing train fixture places its current rail")
	_set_train(reversing_train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var reversing_things: PackedByteArray = reversing_train.document.find_chunk("XTHG").decoded_payload.duplicate()
	reversing_things[2 * 12 + 10] = 7
	reversing_things[3 * 12 + 10] = 201
	_check(
		reversing_train.document.find_chunk("XTHG").set_decoded_payload(reversing_things),
		"Reversing train fixture sets its preserved tail labels",
	)
	var reverse_result := MovingThingTick.run(
		reversing_train.city,
		ZeroRandom.new(),
		SequenceLfsrRandom.new([0, 1]),
		ZeroLfsrRandom.new()
	)
	_check(reverse_result.ok and reverse_result.reversed_trains == 1, "Train reverses when no next route is open")
	_check(
		reversing_train.city.thing(1).x == 20
		and reversing_train.city.thing(1).px == 20
		and reversing_train.city.thing(1).direction == 3
		and reversing_train.city.thing(1).dx == 7
		and reversing_train.city.thing(1).label == 7,
		"Dead-end reversal moves the engine to the tail and faces it backward",
	)
	_check(
		reversing_train.city.thing(3).x == 21
		and reversing_train.city.thing(3).px == 21,
		"Dead-end reversal moves the tail record to the prior engine position",
	)

	var crashed_train := _special_growth_fixture(reference_root)
	_set_train(crashed_train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var crash_result := MovingThingTick.run(
		crashed_train.city,
		ZeroRandom.new(),
		SequenceLfsrRandom.new([0]),
		ZeroLfsrRandom.new()
	)
	_check(
		crash_result.ok
		and crash_result.removed_trains == 1
		and crash_result.created_train_crash_explosions == 1,
		"Train without a route removes its consist and creates a crash explosion",
	)
	_check(
		crashed_train.city.thing(1).type == 6
		and crashed_train.city.thing(1).direction == 0
		and crashed_train.city.thing(1).state == 0
		and crashed_train.city.thing(1).z == 0
		and crashed_train.city.thing(1).px == 8
		and crashed_train.city.thing(1).py == 8
		and crashed_train.city.thing(1).goal == 0
		and crashed_train.city.thing(2).type == 0
		and crashed_train.city.thing(3).type == 0,
		"Train crash reuses the first released record for a non-spreading explosion",
	)
	_check(crashed_train.city.text_overlay_id(20, 20) == 202, "Train crash links its explosion to XTXT")


func _set_sailboat(
	fixture: Dictionary, record: int, point: Vector2i, direction: int, state := 0
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 9
	things[offset + 1] = direction
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 6] = 4
	things[offset + 7] = 4
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Sailboat fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Sailboat fixture links its XTXT record")


func _set_helicopter(
	fixture: Dictionary,
	record: int,
	point: Vector2i,
	target: Vector2i,
	direction: int,
	state: int,
	height: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 2
	things[offset + 1] = direction
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = height
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 8] = target.x
	things[offset + 9] = target.y
	things[offset + 10] = fixture.city.text_overlay_id(point.x, point.y)
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Helicopter fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Helicopter fixture links its XTXT record")


func _set_ship(
	fixture: Dictionary,
	record: int,
	point: Vector2i,
	target: Vector2i,
	direction: int,
	state: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 3
	things[offset + 1] = direction
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = 1
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 8] = target.x
	things[offset + 9] = target.y
	things[offset + 10] = fixture.city.text_overlay_id(point.x, point.y)
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Cargo-ship fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Cargo-ship fixture links its XTXT record")


func _set_airplane(
	fixture: Dictionary,
	record: int,
	point: Vector2i,
	target: Vector2i,
	direction: int,
	state: int,
	height: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 1
	things[offset + 1] = direction
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = height
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 8] = target.x
	things[offset + 9] = target.y
	things[offset + 10] = fixture.city.text_overlay_id(point.x, point.y)
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Airplane fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Airplane fixture links its XTXT record")


func _set_explosion(
	fixture: Dictionary,
	record: int,
	point: Vector2i,
	state: int,
	goal: int,
	frame: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 6
	things[offset + 1] = frame
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 10] = fixture.city.text_overlay_id(point.x, point.y)
	things[offset + 11] = goal
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Explosion fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Explosion fixture links its XTXT record")


func _set_tornado(
	fixture: Dictionary, record: int, point: Vector2i, direction: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 15
	things[offset + 1] = direction
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 6] = 8
	things[offset + 7] = 8
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Tornado fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Tornado fixture links its XTXT record")


func _set_maxis_man(
	fixture: Dictionary,
	record: int,
	point: Vector2i,
	state: int,
	goal: int,
	target: Vector2i
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 16
	things[offset + 1] = 2
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = 5
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 8] = target.x
	things[offset + 9] = target.y
	things[offset + 11] = goal
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Maxis Man fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Maxis Man fixture links its XTXT record")


func _set_monster(
	fixture: Dictionary,
	record: int,
	point: Vector2i,
	direction: int,
	state: int,
	height: int,
	goal: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = 5
	things[offset + 1] = direction
	things[offset + 2] = state
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = height
	things[offset + 6] = 8
	things[offset + 7] = 8
	things[offset + 11] = goal
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Monster fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Monster fixture links its XTXT record")


func _set_idle_thing(
	fixture: Dictionary, record: int, point: Vector2i, type: int, height: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := record * 12
	things[offset] = type
	things[offset + 3] = point.x
	things[offset + 4] = point.y
	things[offset + 5] = height
	things[offset + 6] = 8
	things[offset + 7] = 8
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Target fixture stores its XTHG record")
	_check(fixture.city.set_text_overlay_id(point.x, point.y, record + 201), "Target fixture links its XTXT record")


func _set_train(
	fixture: Dictionary,
	current: Vector2i,
	destination: Vector2i,
	direction: int,
	engine_type: int
) -> void:
	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	for record in range(1, 4):
		var offset := record * 12
		things[offset] = engine_type if record == 1 else engine_type + 1
		things[offset + 1] = direction
		things[offset + 2] = record + 1 if record < 3 else 0
		things[offset + 3] = current.x
		things[offset + 4] = current.y
		things[offset + 6] = destination.x if record == 1 else current.x
		things[offset + 7] = destination.y if record == 1 else current.y
	_check(fixture.document.find_chunk("XTHG").set_decoded_payload(things), "Train fixture stores its linked XTHG records")
	_check(fixture.city.set_text_overlay_id(current.x, current.y, 202), "Train fixture links its engine XTXT record")


func _test_transport_maintenance(reference_root: String) -> void:
	var road := _maintenance_fixture(reference_root, 0x1d, 0)
	_check(road.city.set_tile_flag(20, 20, 0x80, true), "Road decay fixture sets powerable")
	_check(road.document.set_misc_i32(0x077c + 10 * 0x6c + 4, 0), "Road decay fixture removes funding")
	var road_result := Growth.run(road.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(road_result.ok and road_result.decayed_roads == 1, "Unfunded road decays on the rare check")
	_check(road.city.building_id(20, 20) == 1, "Road decay makes process-selected rubble")
	_check(road.city.tile_flags[20 * 128 + 20] & 0x80 == 0, "Road decay clears powerable")

	var rail := _maintenance_fixture(reference_root, 0x2c, 0)
	_check(rail.city.set_tile_flag(20, 20, 0x80, true), "Rail decay fixture sets powerable")
	_check(rail.document.set_misc_i32(0x077c + 13 * 0x6c + 4, 0), "Rail decay fixture removes funding")
	var rail_result := Growth.run(rail.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(rail_result.ok and rail_result.decayed_rails == 1, "Unfunded rail decays on the rare check")
	_check(rail.city.building_id(20, 20) == 1, "Rail decay makes process-selected rubble")
	_check(rail.city.tile_flags[20 * 128 + 20] & 0x80 == 0, "Rail decay clears powerable")

	var highway := _maintenance_fixture(reference_root, 0x49, 0)
	for point in [Vector2i(21, 20), Vector2i(20, 21), Vector2i(21, 21)]:
		_check(highway.city.set_building_id(point.x, point.y, 0x49), "Highway decay fixture fills its section")
	_check(highway.city.set_tile_flag(21, 20, 0x04, true), "Highway decay fixture sets one water tile")
	_check(highway.document.set_misc_u32(0x01f0 + 0x49 * 4, 4), "Highway decay fixture counts its tiles")
	_check(highway.document.set_misc_i32(0x077c + 11 * 0x6c + 4, 0), "Highway decay fixture removes funding")
	var highway_result := Growth.run(highway.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(highway_result.ok and highway_result.decayed_highway_tiles == 4, "Unfunded highway decays as one section")
	_check(highway.city.building_id(21, 20) == 0, "Highway decay clears a water tile")
	for point in [Vector2i(20, 20), Vector2i(20, 21), Vector2i(21, 21)]:
		_check(highway.city.building_id(point.x, point.y) == 1, "Highway decay makes rubble on dry land")

	var subway := _maintenance_fixture(reference_root, 0, 0x01)
	_check(subway.document.set_misc_i32(0x077c + 14 * 0x6c + 4, 0), "Subway decay fixture removes funding")
	var subway_result := Growth.run(subway.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(subway_result.ok and subway_result.decayed_subway_tiles == 1, "Unfunded subway decays on the rare check")
	_check(subway.city.underground_id(20, 20) == 0, "Subway decay clears a subway tile")
	_check(subway.document.misc_u32(0x0fe8) == 0, "Subway decay decrements the saved XUND count")

	var crossover := _maintenance_fixture(reference_root, 0, 0x1f)
	_check(crossover.document.set_misc_i32(0x077c + 14 * 0x6c + 4, 0), "Crossover decay fixture removes funding")
	var crossover_result := Growth.run(crossover.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(crossover_result.ok and crossover_result.decayed_subway_tiles == 1, "Subway crossover loses its rail layer")
	_check(crossover.city.underground_id(20, 20) == 0x11, "Subway crossover preserves its pipe layer")
	_check(crossover.document.misc_u32(0x0fe8) == 0, "Crossover decay decrements the saved XUND count")

	var station := _maintenance_fixture(reference_root, 0xe9, 0x23)
	_check(station.city.set_text_overlay_id(20, 20, 54), "Station decay fixture sets its microsim label")
	_check(station.city.set_tile_flag(20, 20, 0xe2, true), "Station decay fixture sets utility and flip flags")
	_check(station.document.set_misc_i32(0x077c + 14 * 0x6c + 4, 0), "Station decay fixture removes funding")
	var station_result := Growth.run(station.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(station_result.ok and station_result.removed_subway_stations == 1, "Unfunded subway station is removed")
	_check(station_result.decayed_subway_tiles == 1, "Station removal counts one decayed subway tile")
	_check(station.city.building_id(20, 20) == 1, "Station decay makes process-selected rubble")
	_check(station.city.underground_id(20, 20) == 0, "Station decay clears its entrance")
	_check(station.city.text_overlay_id(20, 20) == 0, "Station decay clears its fixed microsim overlay")
	_check(
		station.city.tile_flags[20 * 128 + 20] == 0x20,
		"Station decay clears powered, powerable, and flip flags",
	)
	_check(station.document.misc_u32(0x0fe8) == 0, "Station decay decrements the subway count")

	var bridge := _maintenance_fixture(reference_root, 0x51, 0)
	for x in range(18, 25):
		for y in range(19, 22):
			_check(bridge.city.set_land_altitude(x, y, 0), "Bridge decay fixture levels the waterbed")
	for x in range(20, 23):
		_check(bridge.city.set_building_id(x, 20, 0x51), "Bridge decay fixture places a span tile")
		_check(bridge.city.set_terrain_id(x, 20, 0x30), "Bridge decay fixture places water terrain")
		_check(bridge.city.set_tile_flag(x, 20, 0x06, true), "Bridge decay fixture marks horizontal water")
	for x in [19, 23]:
		_check(bridge.city.set_building_id(x, 20, 0x1d), "Bridge decay fixture places a bank road")
		_check(bridge.city.set_land_altitude(x, 20, 1), "Bridge decay fixture raises a bank")
	_check(bridge.document.set_misc_u32(0x01f0, 16379), "Bridge decay fixture counts clear tiles")
	_check(bridge.document.set_misc_u32(0x01f0 + 0x51 * 4, 3), "Bridge decay fixture counts span tiles")
	_check(bridge.document.set_misc_u32(0x01f0 + 0x1d * 4, 2), "Bridge decay fixture counts bank roads")
	_check(bridge.document.set_misc_u32(0x0e40, 1), "Bridge decay fixture sets sea level")
	_check(bridge.document.set_misc_i32(0x077c + 12 * 0x6c + 4, 0), "Bridge decay fixture removes funding")
	var bridge_random := SequenceRandom.new([0, 2, 1, 3, 0, 1, 1])
	var bridge_result := Growth.run(bridge.city, bridge_random, 0, 0, ZeroLfsrRandom.new())
	_check(bridge_result.ok and bridge_result.collapsed_bridges == 1, "Unfunded bridge span collapses")
	_check(
		bridge_result.deferred_bridge_effects == 0
		and bridge_result.bridge_effects.size() == 3
		and bridge_random.position == 7,
		"Bridge collapse creates debris and consumes its process-random values",
	)
	_check(
		bridge_result.bridge_effects[0].sprite_id == 1394
		and bridge_result.bridge_effects[0].flip
		and bridge_result.bridge_effects[1].sprite_id == 1395
		and not bridge_result.bridge_effects[1].flip
		and bridge_result.bridge_effects[2].sprite_id == 1393
		and bridge_result.bridge_effects[2].flip,
		"Bridge collapse selects each debris sprite and mirror in original order",
	)
	_check(
		bridge_result.view_center_requests == [Vector2i(20, 20)]
		and bridge_result.sound_events == [504]
		and bridge_result.news_items.size() == 1
		and bridge_result.news_items[0].type == 39
		and bridge_result.news_items[0].argument == 0,
		"Bridge collapse requests view centering, sound, and newspaper type 39",
	)
	for x in range(20, 23):
		_check(bridge.city.building_id(x, 20) == 0, "Bridge collapse clears each span tile")
	for x in [19, 23]:
		_check(bridge.city.building_id(x, 20) == 0, "Bridge collapse clears a bank road")
		_check(
			bridge.city.land_altitude(x, 20) == 0,
			"Bridge collapse lowers a dry bank: %d" % bridge.city.land_altitude(x, 20),
		)
		_check(
			bridge.city.tile_flags[x * 128 + 20] & 0x04 != 0,
			"Bridge collapse restores bank water: 0x%02x" % bridge.city.tile_flags[x * 128 + 20],
		)
	_check(bridge.document.misc_u32(0x01f0 + 0x51 * 4) == 0, "Bridge collapse clears its tile count")

	var reinforced := _maintenance_fixture(reference_root, 0x6a, 0)
	_check(reinforced.document.set_misc_i32(0x077c + 12 * 0x6c + 4, 0), "Reinforced bridge fixture removes funding")
	var reinforced_result := Growth.run(
		reinforced.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new()
	)
	_check(reinforced_result.ok and reinforced_result.deferred_bridge_collapses == 1, "Reinforced bridge collapse stays explicit")
	_check(reinforced.city.building_id(20, 20) == 0x6a, "Malformed reinforced bridge stays unchanged")

	var reinforced_span := _maintenance_fixture(reference_root, 0, 0)
	for x in range(18, 29):
		for y in range(19, 23):
			_check(
				reinforced_span.city.set_land_altitude(x, y, 0),
				"Reinforced collapse fixture levels the waterbed",
			)
	for section in 3:
		var section_tile := 0x6b if section != 1 else 0x6a
		for x_offset in 2:
			for y_offset in 2:
				var point := Vector2i(20 + section * 2 + x_offset, 20 + y_offset)
				_check(
					reinforced_span.city.set_building_id(point.x, point.y, section_tile),
					"Reinforced collapse fixture places a span tile",
				)
				_check(
					reinforced_span.city.set_terrain_id(point.x, point.y, 0x30),
					"Reinforced collapse fixture places water terrain",
				)
				_check(
					reinforced_span.city.set_tile_flag(point.x, point.y, 0x04, true),
					"Reinforced collapse fixture marks span water",
				)
	_check(reinforced_span.city.set_building_id(26, 20, 0x49), "Reinforced collapse fixture places its forward bank")
	_check(reinforced_span.city.set_land_altitude(26, 20, 1), "Reinforced collapse fixture raises its forward bank")
	_check(reinforced_span.document.set_misc_u32(0x01f0, 16371), "Reinforced collapse fixture counts clear tiles")
	_check(reinforced_span.document.set_misc_u32(0x01f0 + 0x6a * 4, 4), "Reinforced collapse fixture counts pylons")
	_check(reinforced_span.document.set_misc_u32(0x01f0 + 0x6b * 4, 8), "Reinforced collapse fixture counts normal spans")
	_check(reinforced_span.document.set_misc_u32(0x01f0 + 0x49 * 4, 1), "Reinforced collapse fixture counts its bank")
	_check(reinforced_span.document.set_misc_u32(0x0e40, 1), "Reinforced collapse fixture sets sea level")
	_check(reinforced_span.document.set_misc_i32(0x077c + 12 * 0x6c + 4, 0), "Reinforced collapse fixture removes funding")
	var reinforced_span_random := SequenceRandom.new([
		0,
		3, 1, 0, 1, 0,
		2, 0, 1, 0, 1,
		1, 1, 1, 0, 0,
	])
	var reinforced_span_result := Growth.run(
		reinforced_span.city, reinforced_span_random, 0, 0, ZeroLfsrRandom.new()
	)
	_check(
		reinforced_span_result.ok
		and reinforced_span_result.collapsed_bridges == 1
		and reinforced_span_result.deferred_bridge_collapses == 0,
		"A valid unfunded reinforced span collapses",
	)
	_check(
		reinforced_span_result.bridge_effects.size() == 12
		and reinforced_span_random.position == 16,
		"Reinforced collapse creates four debris effects per section",
	)
	_check(
		reinforced_span_result.bridge_effects[0].sprite_id == 1395
		and reinforced_span_result.bridge_effects[4].sprite_id == 1394
		and reinforced_span_result.bridge_effects[8].sprite_id == 1393
		and reinforced_span_result.bridge_effects[1].screen_offset == Vector2i(16, -8)
		and reinforced_span_result.bridge_effects[3].screen_offset == Vector2i(32, 8),
		"Reinforced collapse shares one sprite across each recovered four-part layout",
	)
	for x in range(20, 26):
		for y in range(20, 22):
			_check(
				reinforced_span.city.building_id(x, y) == 0,
				"Reinforced collapse clears each two-wide span tile",
			)
	_check(reinforced_span.city.building_id(26, 20) == 0, "Reinforced collapse clears the original forward-bank cell")
	_check(reinforced_span.city.land_altitude(26, 20) == 0, "Reinforced collapse lowers the forward-bank cell")
	_check(
		reinforced_span.city.tile_flags[26 * 128 + 20] & 0x04 != 0,
		"Reinforced collapse restores water on the forward-bank cell",
	)
	_check(reinforced_span.document.misc_u32(0x01f0 + 0x6a * 4) == 0, "Reinforced collapse clears its pylon count")
	_check(reinforced_span.document.misc_u32(0x01f0 + 0x6b * 4) == 0, "Reinforced collapse clears its normal-span count")

	var funded := _maintenance_fixture(reference_root, 0x1d, 0)
	var funded_result := Growth.run(funded.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(funded_result.ok and funded_result.decayed_roads == 0, "Full road funding prevents decay")
	_check(funded.city.building_id(20, 20) == 0x1d, "Full road funding preserves the road")


func _maintenance_fixture(reference_root: String, surface_tile: int, underground_tile: int) -> Dictionary:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var buildings := _filled_bytes(128 * 128, 0)
	var zones := _filled_bytes(128 * 128, 0)
	var underground := _filled_bytes(128 * 128, 0)
	var flags := _filled_bytes(128 * 128, 0)
	var index := 20 * 128 + 20
	buildings[index] = surface_tile
	underground[index] = underground_tile
	for entry in [
		["XBLD", buildings],
		["XZON", zones],
		["XUND", underground],
		["XBIT", flags],
		["XTRF", _filled_bytes(64 * 64, 0)],
		["XVAL", _filled_bytes(64 * 64, 0)],
	]:
		_check(document.find_chunk(entry[0]).set_decoded_payload(entry[1]), "Maintenance fixture sets %s" % entry[0])
	for budget_index in range(10, 16):
		_check(
			document.set_misc_i32(0x077c + budget_index * 0x6c + 4, 100),
			"Maintenance fixture fully funds budget %d" % budget_index,
		)
	_check(document.set_misc_u32(0x01f0, 16384 - int(surface_tile != 0)), "Maintenance fixture counts clear tiles")
	if surface_tile != 0:
		_check(document.set_misc_u32(0x01f0 + surface_tile * 4, 1), "Maintenance fixture counts its surface tile")
	_check(document.set_misc_u32(0x0fe8, int(underground_tile != 0)), "Maintenance fixture counts its subway tile")
	return {"document": document, "city": CityModel.from_document(document)}


func _special_growth_fixture(reference_root: String) -> Dictionary:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for entry in [
		["XBLD", _filled_bytes(128 * 128, 0)],
		["XZON", _filled_bytes(128 * 128, 0)],
		["XUND", _filled_bytes(128 * 128, 0)],
		["XTXT", _filled_bytes(128 * 128, 0)],
		["XBIT", _filled_bytes(128 * 128, 0)],
		["XTER", _filled_bytes(128 * 128, 0)],
		["XTRF", _filled_bytes(64 * 64, 0)],
		["XPLT", _filled_bytes(64 * 64, 0)],
		["XVAL", _filled_bytes(64 * 64, 0)],
		["XCRM", _filled_bytes(64 * 64, 0)],
		["XMIC", _filled_bytes(150 * 8, 0)],
		["XTHG", _filled_bytes(40 * 12, 0)],
	]:
		_check(
			document.find_chunk(entry[0]).set_decoded_payload(entry[1]),
			"Special growth fixture sets %s" % entry[0],
		)
	for tile in 256:
		_check(document.set_misc_u32(0x01f0 + tile * 4, 0), "Special growth fixture clears tile count")
	_check(document.set_misc_u32(0x01f0, 16384), "Special growth fixture counts clear tiles")
	for military_index in 16:
		_check(
			document.set_misc_u32(0x0fa8 + military_index * 4, 0),
			"Special growth fixture clears military tile count",
		)
	for budget_index in range(10, 16):
		_check(
			document.set_misc_i32(0x077c + budget_index * 0x6c + 4, 100),
			"Special growth fixture fully funds transport",
		)
	_check(document.set_misc_u32(0x0008, 0), "Special growth fixture sets compass rotation")
	_check(document.set_misc_u32(0x0e4c, 0), "Special growth fixture clears military base type")
	_check(document.set_misc_u32(0x0fe8, 0), "Special growth fixture clears the subway count")
	return {"document": document, "city": CityModel.from_document(document)}


func _growth_fixture(
	reference_root: String, origin_building: int, origin_zone: int, demand: int
) -> Dictionary:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var buildings := _filled_bytes(128 * 128, 0)
	for point in [Vector2i(20, 21), Vector2i(20, 22), Vector2i(20, 23), Vector2i(20, 24)]:
		buildings[point.x * 128 + point.y] = 0x1d
	buildings[20 * 128 + 20] = origin_building
	var zones := _filled_bytes(128 * 128, 0)
	zones[20 * 128 + 20] = 0x80 | origin_zone
	zones[20 * 128 + 25] = 3
	var flags := _filled_bytes(128 * 128, 0)
	flags[20 * 128 + 20] = 0x40
	for entry in [
		["XBLD", buildings],
		["XZON", zones],
		["XBIT", flags],
		["XUND", _filled_bytes(128 * 128, 0)],
		["XTXT", _filled_bytes(128 * 128, 0)],
		["XTRF", _filled_bytes(64 * 64, 0)],
		["XVAL", _filled_bytes(64 * 64, 0)],
	]:
		_check(
			document.find_chunk(entry[0]).set_decoded_payload(entry[1]),
			"Growth fixture sets %s" % entry[0],
		)
	for index in 8:
		_check(document.set_misc_u32(0x05f0 + index * 4, 0), "Growth fixture clears population %d" % index)
	_check(document.set_misc_i32(0x0718, demand), "Growth fixture sets residential demand")
	_check(document.set_misc_i32(0x071c, 0), "Growth fixture clears commercial demand")
	_check(document.set_misc_i32(0x0720, 0), "Growth fixture clears industrial demand")
	_check(document.set_misc_u32(0x0008, 0), "Growth fixture sets compass rotation")
	_check(document.set_misc_u32(0x102c, 0), "Growth fixture clears normal population")
	_check(document.set_misc_u32(0x01f0, 16379), "Growth fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + origin_building * 4, 1), "Growth fixture counts origin tile")
	return {"document": document, "city": CityModel.from_document(document)}


func _test_rci_demand(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for index in 8:
		_check(document.set_misc_i32(0x05f0 + index * 4, 0), "RCI fixture clears zone population")
	for entry in [[1, 100], [2, 50], [3, 40], [4, 10], [5, 20], [6, 5]]:
		_check(
			document.set_misc_i32(0x05f0 + entry[0] * 4, entry[1]),
			"RCI fixture sets zone population %d" % entry[0],
		)
	for offset in [0x0718, 0x071c, 0x0720, 0x0fa0, 0x1030]:
		_check(document.set_misc_i32(offset, 0), "RCI fixture clears MISC 0x%x" % offset)
	for tile_id in [0xd5, 0xd7, 0xda, 0xdd, 0xde, 0xe0, 0xf8]:
		_check(
			document.set_misc_i32(0x01f0 + tile_id * 4, 0),
			"RCI fixture clears tile count %d" % tile_id,
		)
	for category in 3:
		_check(document.set_misc_i32(0x077c + category * 0x6c + 4, 0), "RCI fixture clears tax rate")
	_check(document.set_misc_i32(0x0074, 100), "RCI fixture sets old residential population")
	_check(document.set_misc_i32(0x0040, 10), "RCI fixture sets garbage")
	_check(document.set_misc_i32(0x1020, 120), "RCI fixture sets arcology population")
	_check(document.set_misc_i32(0x102c, 1000), "RCI fixture sets old total population")
	_check(document.set_misc_i32(0x001c, 1), "RCI fixture sets difficulty")
	var text_overlays := _filled_bytes(128 * 128, 0)
	text_overlays[0] = 0xfa
	text_overlays[1] = 0xfa
	_check(document.find_chunk("XTXT").set_decoded_payload(text_overlays), "RCI fixture sets connection labels")
	var buildings := document.find_chunk("XBLD").decoded_payload.duplicate()
	buildings[0] = 0x1d
	buildings[1] = 0x2c
	_check(document.find_chunk("XBLD").set_decoded_payload(buildings), "RCI fixture sets road and rail connections")
	var city := CityModel.from_document(document)
	var result := RciDemand.run(city)
	_check(result.ok, "RCI demand phase completes: %s" % result.error)
	if not result.ok:
		return
	_check(result.tax_population == PackedInt64Array([150, 50, 25]), "RCI phase combines light and dense populations")
	_check(result.normal_population == 2250, "RCI phase calculates normal population")
	_check(result.commerce_connections == 1, "RCI phase counts road neighbor connections")
	_check(result.industry_connections == 1, "RCI phase counts rail neighbor connections")
	_check(
		result.demands == PackedInt32Array([-90, -265, 510]),
		"RCI phase reproduces controlled demand changes: %s" % result.demands,
	)
	_check(document.misc_i32(0x05f0) == 225, "RCI phase stores the total zone population")
	_check(document.misc_i32(0x102c) == 2250, "RCI phase stores normal population")
	_check(document.misc_i32(0x0040) == 2260, "RCI phase accumulates garbage")
	_check(document.misc_i32(0x0074) == 150, "RCI phase stores residential tax population")
	_check(document.misc_i32(0x077c) == 1520, "RCI phase stores residential budget population")
	_check(document.misc_i32(0x07e8) == 510, "RCI phase stores commercial budget population")
	_check(document.misc_i32(0x0854) == 260, "RCI phase stores industrial budget population")


func _test_education_health(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for cohort in 20:
		for field in [0, 4, 8]:
			_check(
				document.set_misc_u32(0x007c + cohort * 12 + field, 0),
				"Demographic fixture clears cohort %d field %d" % [cohort, field],
			)
	for setting in [
		[0x102c, 600],
		[0x0034, 0],
		[0x0044, 0],
		[0x0048, 0],
		[0x004c, 60],
		[0x060c, 0],
		[0x077c, 400],
		[0x0fa0, 0x0760],
		[0x01f0 + 0xd1 * 4, 9],
		[0x01f0 + 0xd6 * 4, 9],
		[0x01f0 + 0xd9 * 4, 16],
		[0x077c + 7 * 0x006c + 4, 100],
		[0x077c + 8 * 0x006c + 4, 100],
		[0x077c + 9 * 0x006c + 4, 100],
		[0x007c + 2 * 12, 300],
		[0x0080 + 2 * 12, 18000],
		[0x0084 + 2 * 12, 24000],
		[0x007c + 10 * 12, 300],
		[0x0080 + 10 * 12, 18000],
		[0x0084 + 10 * 12, 24000],
	]:
		_check(
			document.set_misc_u32(setting[0], setting[1]),
			"Demographic fixture sets MISC 0x%x" % setting[0],
		)
	var city := CityModel.from_document(document)
	var result := EducationHealth.run(city, Random.new(1))
	_check(result.ok, "Education and health phase completes: %s" % result.error)
	if not result.ok:
		return
	_check(result.population == 600, "Demographic phase preserves the controlled population")
	_check(result.deaths == 0 and result.births == 0, "Healthy fixture has no deaths or births")
	_check(result.immigrants == 0 and result.emigrants == 0, "Balanced fixture needs no migration")
	_check(result.health_capacity == 26, "Hospitals and free clinics calculate health capacity")
	_check(result.school_capacity == 15, "Funded schools calculate education capacity")
	_check(result.college_capacity == 50, "Funded colleges calculate education capacity")
	_check(result.newborn_life_expectancy == 100, "Health ordinances raise newborn life expectancy")
	_check(document.misc_u32(0x007c + 2 * 12) == 295, "One sixtieth of a cohort ages each month")
	_check(document.misc_u32(0x007c + 3 * 12) == 5, "Aged residents enter the next cohort")
	_check(document.misc_u32(0x0080 + 2 * 12) == 17700, "Aging transfers source education points")
	_check(document.misc_u32(0x0080 + 3 * 12) == 450, "College capacity increases transferred education")
	_check(document.misc_u32(0x0084 + 2 * 12) == 23600, "Aging transfers source life points")
	_check(document.misc_u32(0x0084 + 3 * 12) == 400, "The next cohort receives life points")
	_check(result.workforce_population == 295, "Workforce uses cohorts four through ten")
	_check(document.misc_u32(0x0044) == 49, "Demographic phase stores workforce percentage")
	_check(document.misc_u32(0x0048) == 80, "Demographic phase stores workforce life expectancy")
	_check(document.misc_u32(0x004c) == 60, "Demographic phase stores workforce education quotient")

	var empty_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	_check(empty_document.set_misc_u32(0x102c, 0), "Empty demographic fixture clears city population")
	_check(empty_document.set_misc_u32(0x007c, 99), "Empty demographic fixture installs a stale cohort")
	var empty_result := EducationHealth.run(CityModel.from_document(empty_document), Random.new(1))
	_check(empty_result.ok and empty_result.empty_city, "Zero population takes the empty-city path")
	_check(empty_document.misc_u32(0x007c) == 0, "Empty-city path clears demographic tables")

	var mortality_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for cohort in 20:
		for field in [0, 4, 8]:
			_check(
				mortality_document.set_misc_u32(0x007c + cohort * 12 + field, 0),
				"Mortality fixture clears cohort %d field %d" % [cohort, field],
			)
	_check(mortality_document.set_misc_u32(0x102c, 230), "Mortality fixture sets city population")
	_check(mortality_document.set_misc_u32(0x007c + 19 * 12, 240), "Mortality fixture sets oldest population")
	_check(mortality_document.set_misc_u32(0x0080 + 19 * 12, 24000), "Mortality fixture sets education points")
	var mortality_result := EducationHealth.run(
		CityModel.from_document(mortality_document), Random.new(1)
	)
	_check(mortality_result.ok, "Mortality fixture completes: %s" % mortality_result.error)
	if mortality_result.ok:
		_check(mortality_result.deaths == 10, "Mortality uses the recovered two-stage divisor")
		_check(mortality_document.misc_u32(0x007c + 19 * 12) == 230, "Mortality removes residents")
		_check(mortality_document.misc_u32(0x0080 + 19 * 12) == 23000, "Mortality removes education in proportion")

	var migration_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for cohort in 20:
		for field in [0, 4, 8]:
			_check(
				migration_document.set_misc_u32(0x007c + cohort * 12 + field, 0),
				"Migration fixture clears cohort %d field %d" % [cohort, field],
			)
	_check(migration_document.set_misc_u32(0x102c, 16), "Migration fixture sets city population")
	var migration_result := EducationHealth.run(
		CityModel.from_document(migration_document), Random.new(1)
	)
	_check(migration_result.ok, "Migration fixture completes: %s" % migration_result.error)
	if migration_result.ok:
		_check(migration_result.immigrants == 16, "Demographic phase adds missing residents")
		for cohort in range(0, 8):
			_check(
				migration_document.misc_u32(0x007c + cohort * 12) == 2,
				"Migration uses recovered cohort order at cohort %d" % cohort,
			)
		_check(migration_document.misc_u32(0x0044) == 47, "Migration updates workforce percentage")
		_check(migration_document.misc_u32(0x0048) == 59, "Migration installs default workforce life points")
		_check(migration_document.misc_u32(0x004c) == 84, "Migration installs default workforce education points")


func _test_traffic(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("CITIES/STARTER.SC2"))
	var city := CityModel.from_document(document)
	var original := document.find_chunk("XTRF").decoded_payload.duplicate()
	var expected_total := 0
	for value in original:
		expected_total += int(value) - (int(value) >> 2)
	var result := Traffic.run(city)
	_check(result.ok, "Traffic phase completes: %s" % result.error)
	if not result.ok:
		return
	_check(result.traffic_count == expected_total, "Traffic phase returns the decayed total")
	_check(document.misc_u32(0x30) == expected_total, "Traffic phase stores the city traffic count")
	var changed := document.find_chunk("XTRF").decoded_payload
	for index in original.size():
		_check(
			changed[index] == int(original[index]) - (int(original[index]) >> 2),
			"Traffic value %d decays by one quarter" % index
		)


func _test_pollution(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var buildings := PackedByteArray()
	buildings.resize(CityModel.TILE_COUNT)
	buildings[20 * CityModel.MAP_SIZE + 20] = 0xc9
	buildings[20 * CityModel.MAP_SIZE + 21] = 0xcb
	buildings[21 * CityModel.MAP_SIZE + 20] = 0x05
	_check(document.find_chunk("XBLD").set_decoded_payload(buildings), "Pollution test installs buildings")
	var traffic := PackedByteArray()
	traffic.resize(64 * 64)
	traffic[10 * 64 + 10] = 100
	_check(document.find_chunk("XTRF").set_decoded_payload(traffic), "Pollution test installs traffic")
	var previous := PackedByteArray()
	previous.resize(64 * 64)
	previous[10 * 64 + 10] = 20
	_check(document.find_chunk("XPLT").set_decoded_payload(previous), "Pollution test installs old pollution")
	_check(document.set_misc_u32(0x0fa0, 0), "Pollution test clears ordinances")
	_check(document.set_misc_u32(0x1034, 0), "Pollution test clears the pollution bonus")
	_check(document.set_misc_u32(0x1050, 0), "Pollution test clears the sewer bonus")
	var city := CityModel.from_document(document)
	var result := Pollution.run(city)
	_check(result.ok, "Pollution map phase completes: %s" % result.error)
	if not result.ok:
		return
	var pollution := document.find_chunk("XPLT").decoded_payload
	_check(pollution[10 * 64 + 10] == 63, "Pollution source uses traffic, history, and tile weights")
	for point in [Vector2i(9, 10), Vector2i(11, 10), Vector2i(10, 9), Vector2i(10, 11)]:
		_check(pollution[point.x * 64 + point.y] == 31, "Pollution spreads to a direct neighbor")
	var nonzero_count := 0
	for value in pollution:
		if value != 0:
			nonzero_count += 1
	_check(nonzero_count == 5, "Pollution smoothing changes only the source and direct neighbors")
	_check(result.pollution_total == 187, "Pollution phase returns the smoothed total")
	_check(document.misc_u32(0x34) == 187, "Pollution phase stores the city pollution total")

	var clean_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XBIT"]:
		_check(
			clean_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Combined scan test clears %s" % chunk_id
		)
	for chunk_id in ["XTRF", "XPLT", "XVAL", "XCRM"]:
		_check(
			clean_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(64 * 64, 0)),
			"Combined scan test clears %s" % chunk_id
		)
	for chunk_id in ["XPLC", "XFIR", "XPOP", "XROG"]:
		_check(
			clean_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(32 * 32, 0)),
			"Combined scan test clears %s" % chunk_id
		)
	var clean_buildings := clean_document.find_chunk("XBLD").decoded_payload.duplicate()
	clean_buildings[40 * 128 + 40] = 0x1d
	_check(
		clean_document.find_chunk("XBLD").set_decoded_payload(clean_buildings),
		"Combined scan test places one road tile"
	)
	for offset in [0x0fa0, 0x1034, 0x103c, 0x1050]:
		_check(clean_document.set_misc_u32(offset, 0), "Combined scan test clears MISC 0x%x" % offset)
	var clean_city := CityModel.from_document(clean_document)
	var clean_result := Pollution.run(clean_city)
	_check(clean_result.ok, "Combined day-two scan completes: %s" % clean_result.error)
	if not clean_result.ok:
		return
	_check(clean_result.developed_tiles == 1, "Combined scan counts one developed tile")
	_check(clean_result.city_center == Vector2i.ZERO, "Roads do not enter the city-center average")
	_check(clean_result.pollution_total == 0, "Clean road fixture has no pollution")
	_check(clean_result.land_value_total == 96, "Land-value scan stores the exact fixture total")
	_check(
		clean_document.find_chunk("XVAL").decoded_payload[20 * 64 + 20] == 96,
		"Land-value scan uses quarter-map smoothing and center distance"
	)
	_check(clean_city.tile_flags[20 * 128 + 20] & 0x08, "Developed area sets the temporary mark")
	_check(clean_document.find_chunk("XPOP").decoded_payload[10 * 32 + 10] == 0, "Road adds no population")
	_check(clean_document.find_chunk("XROG").decoded_payload[10 * 32 + 10] == 16, "Growth map uses the recovered bias")
	_check(clean_result.crime_total == 0, "Negative crime pressure clamps to zero")
	_check(clean_document.misc_u32(0x28) == 96, "Combined scan stores the land-value total")
	_check(clean_document.misc_u32(0x2c) == 0, "Combined scan stores the crime total")


func _test_graph_history(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	var data := PackedByteArray()
	data.resize(CityModel.GRAPH_COUNT * CityModel.GRAPH_VALUE_COUNT * 4)
	for series in CityModel.GRAPH_COUNT:
		for index in CityModel.GRAPH_VALUE_COUNT:
			_write_u32_be(data, (series * CityModel.GRAPH_VALUE_COUNT + index) * 4, series * 1000 + index)
	_check(document.find_chunk("XGRP").set_decoded_payload(data), "Graph test installs known history")
	_check(city.set_age_in_days(150), "Graph test selects July")
	for index in 8:
		_check(
			document.set_misc_u32(0x05f0 + index * 4, [0, 10, 20, 5, 7, 3, 4, 9][index]),
			"Graph test installs zone population %d" % index
		)
	for tile_id in range(0xfb, 0xff):
		_check(
			document.set_misc_u32(0x01f0 + tile_id * 4, 600),
			"Graph test installs arcology tile count %d" % tile_id
		)
	for setting in [
		[0x1020, 1000],
		[0x0030, 1000],
		[0x0bb4, 9],
		[0x0c20, 10],
		[0x0c8c, 5],
		[0x0048, 78],
		[0x004c, 91],
		[0x0050, 54321],
		[0x0054, 98765],
		[0x0058, 8],
	]:
		_check(
			document.set_misc_u32(setting[0], setting[1]),
			"Graph test installs MISC value 0x%x" % setting[0]
		)
	var developed_tiles := 400
	var developed_divisor := int(developed_tiles / 4) + 1
	_check(document.set_misc_u32(0x0034, developed_divisor * 11), "Graph test installs pollution")
	_check(document.set_misc_u32(0x0028, developed_divisor * 22), "Graph test installs land value")
	_check(document.set_misc_u32(0x002c, developed_divisor * 33), "Graph test installs crime")
	var expected := PackedInt64Array(
		[
			201490,
			100800,
			50370,
			50320,
			40,
			11,
			22,
			33,
			77,
			55,
			78,
			91,
			15,
			98765,
			54321,
			8,
		]
	)
	var result := Graphs.run(city, developed_tiles, 23, 45)
	_check(result.ok, "Graph statistics and history advance: %s" % result.error)
	if not result.ok:
		return
	_check(result.values == expected, "Graph phase calculates all sixteen current values")
	_check(result.unemployment == 15, "Graph phase calculates unemployment")
	_check(document.misc_u32(0x0fa4) == 15, "Graph phase stores unemployment in MISC")
	for series in CityModel.GRAPH_COUNT:
		var values := city.graph_series(series)
		_check(values.year[0] == expected[series], "Graph %d stores its current month" % series)
		_check(values.year[1] == series * 1000, "Graph %d shifts monthly history" % series)
		_check(values.decade[0] == expected[series], "Graph %d stores its July half-year value" % series)
		_check(values.decade[1] == series * 1000 + 12, "Graph %d shifts half-year history" % series)
		_check(values.century[0] == series * 1000 + 32, "Graph %d leaves century history in July" % series)


func _write_u32_be(data: PackedByteArray, offset: int, value: int) -> void:
	data[offset] = (value >> 24) & 0xff
	data[offset + 1] = (value >> 16) & 0xff
	data[offset + 2] = (value >> 8) & 0xff
	data[offset + 3] = value & 0xff


func _test_modified_save(reference_root: String) -> void:
	var source_path := reference_root.path_join("DEFAULT.SC2")
	var document := Sc2Document.load_path(source_path)
	var loaded_city := CityModel.from_document(document)
	_check(loaded_city.set_age_in_days(311), "City age can change")
	_check(loaded_city.set_funds(-12345), "City funds can change")
	_check(loaded_city.set_label(0, "Test Mayor"), "Mayor label can change")
	var serialized := document.serialize()
	_check(serialized.ok, "Modified city serializes")
	if not serialized.ok:
		return
	_check(serialized.data != FileAccess.get_file_as_bytes(source_path), "Modified save bytes change")

	var reparsed := Sc2Document.new()
	_check(reparsed.parse(serialized.data), "Modified save parses again: %s" % reparsed.parse_error)
	if reparsed.is_valid():
		_check(reparsed.misc_u32(0x10) == 311, "Modified city age is preserved")
		_check(reparsed.misc_i32(0x14) == -12345, "Modified city funds are preserved")
		var reparsed_city := CityModel.from_document(reparsed)
		_check(reparsed_city.mayor_name() == "Test Mayor", "Modified mayor label is preserved")

	var original := Sc2Document.load_path(source_path)
	for original_chunk in original.chunks:
		if original_chunk.chunk_id == "MISC" or original_chunk.chunk_id == "XLAB":
			continue
		var modified_chunk := reparsed.find_chunk(original_chunk.chunk_id)
		_check(modified_chunk != null, "%s stays present after edit" % original_chunk.chunk_id)
		if modified_chunk != null:
			_check(
				modified_chunk.stored_payload == original_chunk.stored_payload,
				"%s stored bytes stay unchanged after MISC edit" % original_chunk.chunk_id
			)


func _test_map_edits(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_terrain_id(4, 5, 0x2a), "Terrain tile can change")
	_check(city.set_building_id(4, 5, 0x8a), "Building tile can change")
	_check(city.set_zone_id(4, 5, 0x05), "Zone can change")
	_check(city.set_building_corners(4, 5, 0xa0), "Building corners can change")
	_check(city.set_underground_id(4, 5, 0x22), "Underground tile can change")
	_check(city.set_text_overlay_id(4, 5, 0x31), "Text overlay can change")
	_check(city.set_tile_flag(4, 5, 0x40, true), "Tile powered flag can change")
	_check(city.set_land_altitude(4, 5, 17), "Land altitude can change")
	_check(city.set_water_altitude(4, 5, 19), "Water altitude can change")
	_check(city.set_tunnel_levels(4, 5, 41), "Tunnel depth can change")
	var serialized := document.serialize()
	_check(serialized.ok, "Map-edited city serializes")
	if not serialized.ok:
		return
	var reparsed := Sc2Document.new()
	_check(reparsed.parse(serialized.data), "Map-edited city parses")
	if not reparsed.is_valid():
		return
	var result := CityModel.from_document(reparsed)
	_check(result.terrain_id(4, 5) == 0x2a, "Terrain edit persists")
	_check(result.building_id(4, 5) == 0x8a, "Building edit persists")
	_check(result.zone_id(4, 5) == 0x05, "Zone edit persists")
	_check(result.building_corners(4, 5) == 0xa0, "Building corners persist")
	_check(result.underground_id(4, 5) == 0x22, "Underground edit persists")
	_check(result.text_overlay_id(4, 5) == 0x31, "Text overlay edit persists")
	_check(result.is_powered(4, 5), "Tile flag edit persists")
	_check(result.land_altitude(4, 5) == 17, "Land altitude edit persists")
	_check(result.water_altitude(4, 5) == 19, "Water altitude edit persists")
	_check(result.tunnel_levels(4, 5) == 41, "Tunnel depth edit persists")
	_check(not result.set_zone_id(-1, 0, 1), "Out-of-range map edits fail")
	_check(not result.set_land_altitude(0, 0, 32), "Out-of-range altitude fails")


func _test_tool_catalog() -> void:
	_check(Tools.GROUPS.size() == 18, "Tool catalog has all eighteen original groups")
	_check(Tools.all_tools().size() == 69, "Tool catalog has all sixty-nine original entries")
	var coal := Tools.tool(3, 2)
	_check(coal.name == "Coal Power Plant", "Tool catalog preserves the coal plant position")
	_check(coal.cost == 4000 and coal.area == 4, "Coal plant uses the executable cost and area")
	var road := Tools.tool(6, 0)
	_check(road.cost == 10 and road.area == 1, "Road uses the executable cost and area")
	var college := Tools.tool(12, 1)
	_check(college.cost == 1000 and college.area == 4, "College uses the executable cost and area")
	var prison := Tools.tool(13, 3)
	_check(prison.cost == 3000 and prison.area == 4, "Prison uses the executable cost and area")
	var marina := Tools.tool(14, 4)
	_check(marina.cost == 1000 and marina.area == 3, "Marina uses the executable cost and area")
	_check(Tools.tool(-1, 0).is_empty(), "Tool catalog rejects an invalid group")
	_check(Tools.tool(0, 12).is_empty(), "Tool catalog rejects an invalid subtool")


func _test_zone_command(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Zone command test clears %s" % chunk_id
		)
	var buildings := document.find_chunk("XBLD").decoded_payload.duplicate()
	buildings[11 * 128 + 11] = 0x1d
	_check(document.find_chunk("XBLD").set_decoded_payload(buildings), "Zone test places a road")
	var flags := document.find_chunk("XBIT").decoded_payload.duplicate()
	flags[12 * 128 + 12] = 0x04
	_check(document.find_chunk("XBIT").set_decoded_payload(flags), "Zone test places water")
	var zones := document.find_chunk("XZON").decoded_payload.duplicate()
	zones[10 * 128 + 10] = 0xa0
	zones[12 * 128 + 11] = 0x07
	_check(document.find_chunk("XZON").set_decoded_payload(zones), "Zone test installs corner and military bits")
	_check(document.set_misc_i32(0x14, 100), "Zone test sets city funds")
	var city := CityModel.from_document(document)
	var command := Zones.apply_rectangle(city, 9, 0, Vector2i(10, 10), Vector2i(12, 12))
	_check(command.ok, "Residential zone rectangle applies: %s" % command.error)
	if not command.ok:
		return
	_check(command.zone_type == 1, "Light residential maps to zone type one")
	_check(command.tile_indices.size() == 6, "Zone command skips road, water, and military tiles")
	_check(command.cost == 30 and city.funds() == 70, "Zone command charges per changed tile")
	_check(city.zones[10 * 128 + 10] == 0xa1, "Zone command preserves building-corner bits")
	_check(city.zone_id(11, 11) == 0, "Zone command leaves a road unchanged")
	_check(city.zone_id(12, 12) == 0, "Zone command leaves water unchanged")
	_check(city.zone_id(12, 11) == 7, "Zone command leaves a military zone unchanged")
	var undo := Zones.undo(city, command)
	_check(undo.ok and undo.restored_tiles == 6, "Zone command undo restores all changed tiles")
	_check(city.funds() == 100, "Zone command undo restores funds")
	_check(city.zones[10 * 128 + 10] == 0xa0, "Zone command undo restores original XZON bytes")
	var later := Zones.apply_rectangle(city, 11, 1, Vector2i(10, 10), Vector2i(12, 12))
	_check(later.ok, "Later zoning command succeeds")
	_check(later.cost == 60, "Later zoning command uses changed-tile cost")
	var stale := Zones.undo(city, command)
	_check(not stale.ok, "Undo rejects a command after later zone changes")
	_check(city.set_building_id(10, 10, 3), "De-zone test places rubble")
	var dezone := Zones.apply_rectangle(city, 0, 4, Vector2i(10, 10), Vector2i(12, 12))
	_check(dezone.ok and dezone.cost == 6, "De-zone removes six zones for one dollar each")
	_check(city.zone_id(10, 10) == 0, "De-zone clears the zone nibble")
	_check(city.building_id(10, 10) == 0, "De-zone clears rubble tile IDs one through four")
	var undo_dezone := Zones.undo(city, dezone)
	_check(undo_dezone.ok, "De-zone command can be undone")
	_check(city.zone_id(10, 10) == 6, "De-zone undo restores the zone")
	_check(city.building_id(10, 10) == 3, "De-zone undo restores rubble")
	_check(city.set_funds(3), "Insufficient-funds fixture sets city funds")
	var zones_before_failure := city.zones.duplicate()
	var buildings_before_failure := city.buildings.duplicate()
	var rejected := Zones.apply_rectangle(city, 10, 0, Vector2i(10, 10), Vector2i(12, 12))
	_check(not rejected.ok and rejected.cost == 30, "Zone command reports insufficient funds")
	_check(city.funds() == 3, "Rejected zone command preserves funds")
	_check(
		city.zones == zones_before_failure and city.buildings == buildings_before_failure,
		"Rejected zone command preserves map data",
	)


func _test_sign_command(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	_check(
		document.find_chunk("XTXT").set_decoded_payload(_filled_bytes(128 * 128, 0)),
		"Sign fixture clears text overlays",
	)
	var city := CityModel.from_document(document)
	_check(city.set_label(1, ""), "Sign fixture clears first user label")
	var created := Signs.set_sign(city, Vector2i(4, 5), "Harbor District")
	_check(created.ok, "Sign command creates a sign: %s" % created.error)
	_check(created.label_id == 1, "Sign command allocates the first free user label")
	_check(city.text_overlay_id(4, 5) == 1, "Sign command stores the XTXT label ID")
	_check(city.label(1) == "Harbor District", "Sign command stores XLAB text")
	var edited := Signs.set_sign(city, Vector2i(4, 5), "New Harbor")
	_check(edited.ok and edited.label_id == 1, "Sign command edits its existing label")
	_check(Signs.undo(city, edited).ok, "Sign edit can be undone")
	_check(city.label(1) == "Harbor District", "Sign undo restores the exact text")
	var removed := Signs.set_sign(city, Vector2i(4, 5), "")
	_check(removed.ok, "Empty sign text removes the sign")
	_check(city.text_overlay_id(4, 5) == 0 and city.label(1).is_empty(), "Sign removal clears XTXT and XLAB")
	_check(Signs.undo(city, removed).ok, "Sign removal can be undone")
	_check(city.text_overlay_id(4, 5) == 1 and city.label(1) == "Harbor District", "Sign removal undo restores both chunks")
	_check(city.set_text_overlay_id(9, 9, 51), "Sign fixture sets a protected label")
	var protected := Signs.set_sign(city, Vector2i(9, 9), "Blocked")
	_check(not protected.ok, "Sign command rejects a protected simulation label")


func _test_query_info(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XTXT", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Query fixture clears %s" % chunk_id,
		)
	var traffic := _filled_bytes(64 * 64, 0)
	traffic[4 * 64 + 5] = 8
	traffic[5 * 64 + 4] = 8
	traffic[5 * 64 + 5] = 8
	_check(document.find_chunk("XTRF").set_decoded_payload(traffic), "Query fixture sets traffic")
	for entry in [["XVAL", 9], ["XCRM", 61], ["XPLT", 181]]:
		var values := _filled_bytes(64 * 64, 0)
		values[5 * 64 + 5] = entry[1]
		_check(document.find_chunk(entry[0]).set_decoded_payload(values), "Query fixture sets %s" % entry[0])
	_check(document.set_misc_u32(0x0e40, 4), "Query fixture sets water level")
	var city := CityModel.from_document(document)
	_check(city.set_building_id(10, 10, 0x1d), "Query fixture places a road")
	_check(city.set_zone_id(10, 10, 1), "Query fixture zones the road")
	_check(city.set_land_altitude(10, 10, 6), "Query fixture sets altitude")
	_check(city.set_tile_flag(10, 10, 0x40, true), "Query fixture powers the road")
	var info := Queries.inspect(city, Vector2i(10, 10))
	_check(info.ok and info.kind == "general", "General query succeeds: %s" % info.error)
	_check(info.title == "Road", "General query classifies the tile")
	_check(info.zone_name == "Residential" and info.zone_density == "low-density", "Query reports zone type and density")
	_check(info.traffic == 4, "Query reproduces adjacent road traffic calculation")
	_check(info.altitude_feet == 250 and not info.altitude_is_depth, "Query reproduces clear-terrain altitude")
	_check(info.land_value == 10, "Query reports land value in thousands per acre")
	_check(info.crime_level == "Medium", "Query uses the recovered crime thresholds")
	_check(info.pollution_level == "Very High", "Query uses the recovered pollution thresholds")
	_check(info.shows_utilities and info.powered, "Query reports utility state")
	_check(Queries._level_name(1) == "None", "Query threshold one is None")
	_check(Queries._level_name(2) == "Low", "Query threshold two is Low")
	_check(Queries._level_name(60) == "Low", "Query threshold sixty is Low")
	_check(Queries._level_name(61) == "Medium", "Query threshold sixty-one is Medium")
	_check(Queries._level_name(120) == "Medium", "Query threshold one-twenty is Medium")
	_check(Queries._level_name(121) == "High", "Query threshold one-twenty-one is High")
	_check(Queries._level_name(180) == "High", "Query threshold one-eighty is High")
	_check(Queries._level_name(181) == "Very High", "Query threshold one-eighty-one is Very High")
	_check(document.set_misc_u32(0x68, 8), "Query pump fixture sets rain")
	_check(city.set_building_id(20, 20, 0xdc), "Query pump fixture places a pump")
	_check(city.set_tile_flag(20, 20, 0x40, true), "Query pump fixture powers the pump")
	_check(city.set_tile_flag(19, 20, 0x04, true), "Query pump fixture places fresh water")
	var pump := Queries.inspect(city, Vector2i(20, 20))
	_check(pump.title == "Water pump", "Query identifies a water pump")
	_check(pump.water_detail == "Water: 24480 gallons per month", "Query reports recovered pump output")
	for tower_tile in [Vector2i(30, 30), Vector2i(31, 30), Vector2i(30, 29), Vector2i(31, 29)]:
		_check(city.set_building_id(tower_tile.x, tower_tile.y, 0xeb), "Query tower fixture places a tower tile")
	for watered_tile in [Vector2i(30, 30), Vector2i(31, 30), Vector2i(30, 29)]:
		_check(city.set_tile_flag(watered_tile.x, watered_tile.y, 0x10, true), "Query tower fixture stores water")
	var tower := Queries.inspect(city, Vector2i(31, 29))
	_check(tower.title == "Water tower", "Query identifies a water tower")
	_check(tower.water_detail == "Water: 30000 stored gallons", "Query counts stored tower water")

	var microsim_data := document.find_chunk("XMIC").decoded_payload.duplicate()
	microsim_data[0] = 0xd0
	microsim_data[1] = 7
	microsim_data[2] = 0x01
	microsim_data[3] = 0x02
	microsim_data[4] = 0x03
	microsim_data[5] = 0x04
	microsim_data[6] = 0x05
	microsim_data[7] = 0x06
	_check(document.find_chunk("XMIC").set_decoded_payload(microsim_data), "Query fixture sets microsim data")
	_check(city.set_label(51, "Civic Center"), "Query fixture names a microsim")
	_check(city.set_text_overlay_id(10, 10, 51), "Query fixture attaches a microsim")
	var specific := Queries.inspect(city, Vector2i(10, 10))
	_check(specific.ok and specific.kind == "specific", "Specific query follows XTXT to XMIC")
	_check(specific.title == "Civic Center" and specific.microsim.stat_0 == 7, "Specific query reports its label and rating")
	_check(specific.microsim.stat_1 == 0x0102, "Specific query reads big-endian statistic one")
	_check(specific.microsim.stat_2 == 0x0304, "Specific query reads big-endian statistic two")
	_check(specific.microsim.stat_3 == 0x0506, "Specific query reads big-endian statistic three")


func _test_landscape_command(reference_root: String) -> void:
	var tree_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XTXT", "XBIT"]:
		_check(
			tree_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Tree fixture clears %s" % chunk_id,
		)
	_check(tree_document.set_misc_i32(0x14, 100), "Tree fixture sets funds")
	_check(tree_document.set_misc_u32(0x01f0, 16384), "Tree fixture counts clear tiles")
	for tree_id in range(6, 13):
		_check(tree_document.set_misc_u32(0x01f0 + tree_id * 4, 0), "Tree fixture clears tree count")
	var tree_city := CityModel.from_document(tree_document)
	var tree_random := Random.new(1)
	var first_tree := Landscapes.apply_path(
		tree_city, 1, 0, [Vector2i(10, 10)], tree_random
	)
	_check(first_tree.ok, "Tree tool places a tree: %s" % first_tree.error)
	_check(tree_city.building_id(10, 10) == 7, "Tree tool uses the executable random first tree ID")
	_check(tree_city.funds() == 97, "Tree tool charges three dollars")
	_check(tree_document.misc_u32(0x01f0) == 16383, "Tree tool decrements the old tile count")
	_check(tree_document.misc_u32(0x01f0 + 7 * 4) == 1, "Tree tool increments the new tile count")
	var denser_tree := Landscapes.apply_path(
		tree_city, 1, 0, [Vector2i(10, 10)], tree_random
	)
	_check(denser_tree.ok and tree_city.building_id(10, 10) == 8, "Tree tool advances an existing tree")
	_check(Landscapes.undo(tree_city, denser_tree, tree_random).ok, "Later tree action can be undone")
	_check(tree_city.building_id(10, 10) == 7 and tree_city.funds() == 97, "Tree undo restores map and funds")
	_check(Landscapes.undo(tree_city, first_tree, tree_random).ok, "First tree action can be undone")
	_check(tree_city.building_id(10, 10) == 0 and tree_random.state == 1, "Tree undo restores tile and random state")
	_check(tree_city.funds() == 100, "Tree undo restores original funds")
	_check(tree_city.set_tile_flag(11, 11, 0x04, true), "Tree rejection fixture marks water")
	var rejected_tree := Landscapes.apply_path(
		tree_city, 1, 0, [Vector2i(11, 11)], tree_random
	)
	_check(not rejected_tree.ok, "Tree tool rejects water")

	var water_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XTXT", "XBIT"]:
		_check(
			water_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Water fixture clears %s" % chunk_id,
		)
	_check(water_document.set_misc_i32(0x14, 500), "Water fixture sets funds")
	_check(water_document.set_misc_u32(0x01f0, 16383), "Water fixture counts clear tiles")
	_check(water_document.set_misc_u32(0x01f0 + 6 * 4, 1), "Water fixture counts one tree")
	var water_city := CityModel.from_document(water_document)
	_check(water_city.set_building_id(10, 10, 6), "Water fixture places a tree")
	_check(water_city.set_zone_id(10, 10, 1), "Water fixture places a zone")
	_check(water_city.set_building_corners(10, 10, 0xa0), "Water fixture sets corner bits")
	_check(water_city.set_land_altitude(10, 10, 5), "Water fixture sets land altitude")
	_check(water_city.set_water_altitude(10, 10, 2), "Water fixture sets old water altitude")
	_check(water_city.set_tile_flag(9, 10, 0x04, true), "Water fixture places adjacent water")
	_check(water_city.set_terrain_id(9, 10, 0x3d), "Water fixture sets adjacent water shape")
	var water_random := Random.new(123)
	var water := Landscapes.apply_path(
		water_city, 1, 1, [Vector2i(10, 10)], water_random
	)
	_check(water.ok, "Water tool places water: %s" % water.error)
	_check(water_city.funds() == 400 and water.cost == 100, "Water tool charges one hundred dollars")
	_check(water_city.is_water(10, 10) and water_city.building_id(10, 10) == 0, "Water tool clears the building and sets XBIT water")
	_check(water_city.zone_id(10, 10) == 0 and water_city.building_corners(10, 10) == 0xa0, "Water tool clears only the zone nibble")
	_check(water_city.water_altitude(10, 10) == 5, "Water tool copies land altitude to water altitude")
	_check(water_city.terrain_id(10, 10) == 0x44, "Water tool selects the west-connected surface shape")
	_check(water_city.terrain_id(9, 10) == 0x42, "Water tool retiles adjacent water")
	_check(water_document.misc_u32(0x01f0 + 6 * 4) == 0, "Water tool decrements the cleared tree count")
	_check(water_document.misc_u32(0x01f0) == 16384, "Water tool increments the clear building count")
	_check(Landscapes.undo(water_city, water, water_random).ok, "Water action can be undone")
	_check(not water_city.is_water(10, 10) and water_city.building_id(10, 10) == 6, "Water undo restores map data")
	_check(water_city.zone_id(10, 10) == 1 and water_city.building_corners(10, 10) == 0xa0, "Water undo restores XZON")
	_check(water_city.land_altitude(10, 10) == 5 and water_city.water_altitude(10, 10) == 2, "Water undo restores ALTM")
	_check(water_city.funds() == 500, "Water undo restores funds")
	_check(water_city.set_text_overlay_id(12, 12, 250), "Water rejection fixture sets protected text")
	var protected_water := Landscapes.apply_path(
		water_city, 1, 1, [Vector2i(12, 12)], water_random
	)
	_check(not protected_water.ok, "Water tool rejects XTXT values above 249")
	_check(water_city.set_funds(99), "Water funds fixture sets insufficient funds")
	var unaffordable_water := Landscapes.apply_path(
		water_city, 1, 1, [Vector2i(13, 13)], water_random
	)
	_check(not unaffordable_water.ok and unaffordable_water.error == "insufficient funds", "Water tool reports insufficient funds")


func _test_building_command(reference_root: String) -> void:
	_check(Buildings.tile_for_tool(3, 2) == 0xcf, "Building table maps coal power")
	_check(Buildings.tile_for_tool(14, 4) == 0xf8, "Building table maps the marina")
	_check(Buildings.supports_tool(13, 0), "Building command supports police stations")
	_check(not Buildings.supports_tool(3, 3), "Hydroelectric power remains a special tool")
	_check(Buildings.footprint(Vector2i(20, 20), 1) == Rect2i(20, 20, 1, 1), "One-tile footprint starts at the pointer")
	_check(Buildings.footprint(Vector2i(20, 20), 2) == Rect2i(20, 20, 2, 2), "Two-tile footprint starts at the pointer")
	_check(Buildings.footprint(Vector2i(20, 20), 4) == Rect2i(19, 19, 4, 4), "Four-tile footprint starts one tile before the pointer")

	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Building fixture clears %s" % chunk_id,
		)
	_check(document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Building fixture clears XLAB")
	_check(document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Building fixture clears XMIC")
	_check(document.set_misc_i32(0x14, 20000), "Building fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Building fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + 0xcf * 4, 0), "Building fixture clears coal count")
	_check(document.set_misc_u32(0x077c + 5 * 0x6c, 2), "Building fixture sets police count")
	var city := CityModel.from_document(document)
	var random := GameRandom.new(1)
	var process_random := Random.new(1)
	var coal := Buildings.apply(city, 3, 2, Vector2i(20, 20), random, process_random)
	_check(coal.ok, "Coal plant placement succeeds: %s" % coal.error)
	_check(coal.site == Rect2i(19, 19, 4, 4), "Coal plant uses the original asymmetric footprint")
	_check(coal.tile_indices.size() == 16, "Coal plant changes sixteen map tiles")
	_check(city.funds() == 16000, "Coal plant charges its tool cost once")
	_check(city.building_id(19, 19) == 0xcf and city.building_id(22, 22) == 0xcf, "Coal plant fills its footprint")
	_check(city.tile_flags[19 * 128 + 19] & 0xe0 == 0xe0, "Coal plant sets structure utility flags")
	_check(city.zones[19 * 128 + 19] == 0x10, "Rotation zero stores the bottom-left corner")
	_check(city.zones[22 * 128 + 19] == 0x20, "Rotation zero stores the bottom-right corner")
	_check(city.zones[22 * 128 + 22] == 0x40, "Rotation zero stores the top-left corner")
	_check(city.zones[19 * 128 + 22] == 0x80, "Rotation zero stores the top-right corner")
	_check(coal.overlay_id == 61 and city.text_overlay_id(19, 19) == 61, "Coal plant attaches the first dynamic microsim label")
	_check(city.label(61) == "Coal Power", "Coal plant gets the original default label")
	_check(city.microsim(10).tile_id == 0xcf and city.microsim(10).stat_1 == 200, "Coal plant initializes its XMIC capacity")
	_check(document.misc_u32(0x01f0) == 16368, "Coal plant decrements clear tile count")
	_check(document.misc_u32(0x01f0 + 0xcf * 4) == 16, "Coal plant increments its tile count")
	_check(Buildings.undo(city, coal, random, process_random).ok, "Coal plant placement can be undone")
	_check(city.funds() == 20000 and city.building_id(19, 19) == 0, "Building undo restores funds and tiles")
	_check(city.text_overlay_id(19, 19) == 0 and city.microsim(10).tile_id == 0, "Building undo restores XTXT and XMIC")

	var police := Buildings.apply(city, 13, 0, Vector2i(30, 30), random, process_random)
	_check(police.ok, "Police station placement succeeds")
	_check(document.misc_u32(0x077c + 5 * 0x6c) == 3, "Police station increments the current budget count")
	_check(Buildings.undo(city, police, random, process_random).ok, "Police station placement can be undone")
	var park := Buildings.apply(city, 14, 0, Vector2i(40, 40), random, process_random)
	_check(park.ok, "Small park placement succeeds")
	_check(city.tile_flags[40 * 128 + 40] & 0xe0 == 0x20, "Small park gets only the piped structure flag")
	_check(city.building_corners(40, 40) == 0xf0, "One-tile building gets all corner bits")
	_check(Buildings.undo(city, park, random, process_random).ok, "Small park placement can be undone")
	var first_bus := Buildings.apply(city, 6, 4, Vector2i(70, 70), random, process_random)
	var second_bus := Buildings.apply(city, 6, 4, Vector2i(73, 70), random, process_random)
	_check(first_bus.ok and second_bus.ok, "Bus depots use the shared placement command")
	_check(first_bus.overlay_id == 52 and second_bus.overlay_id == 52, "Bus depots share fixed microsim record one")
	_check(city.label(52) == "SimBus System", "Fixed bus microsim gets its default system label")
	_check(city.microsim(1).tile_id == 0xec and city.microsim(1).stat_1 == 2, "Fixed bus microsim aggregates two depots")
	_check(Buildings.undo(city, second_bus, random, process_random).ok, "Fixed microsim aggregation can be undone")
	_check(city.microsim(1).stat_1 == 1, "Fixed microsim undo restores the prior aggregate")
	var mayor_random_before := process_random.state
	var mayor_house := Buildings.apply(city, 5, 0, Vector2i(80, 80), random, process_random)
	_check(mayor_house.ok and mayor_house.overlay_id == 61, "Mayor house allocates a dynamic microsim")
	_check(city.label(61) == "Mayor's House", "Mayor house gets its default label")
	_check(city.microsim(10).stat_1 == city.current_year(), "Mayor house stores its construction year")
	_check(city.microsim(10).stat_2 >= 10 and city.microsim(10).stat_2 <= 39, "Mayor house initializes the recovered age statistic")
	_check(Buildings.undo(city, mayor_house, random, process_random).ok, "Mayor house placement can be undone")
	_check(process_random.state == mayor_random_before, "Building undo restores the process random state")

	_check(city.set_underground_id(59, 60, 0x1e), "Pump fixture places an adjacent isolated pipe")
	var pump := Buildings.apply(city, 4, 1, Vector2i(60, 60), random, process_random)
	_check(pump.ok, "Water pump placement succeeds")
	_check(city.underground_id(59, 60) == 0x11 and city.underground_id(60, 60) == 0x11, "Water pump reconnects its adjacent pipe")
	_check(city.is_piped(60, 60), "Water pump keeps the piped flag")
	_check(Buildings.undo(city, pump, random, process_random).ok, "Water pump underground changes can be undone")
	_check(city.underground_id(59, 60) == 0x1e and city.underground_id(60, 60) == 0, "Pump undo restores both underground tiles")

	_check(city.set_underground_id(64, 65, 0x0f), "Subway fixture places an adjacent isolated subway")
	var subway_station := Buildings.apply(city, 7, 3, Vector2i(65, 65), random, process_random)
	_check(subway_station.ok, "Subway station placement succeeds")
	_check(city.underground_id(65, 65) == 0x23, "Subway station writes the underground entrance")
	_check(city.underground_id(64, 65) == 0x02, "Subway station reconnects its adjacent subway")
	_check(not city.is_piped(65, 65) and city.is_powered(65, 65) and city.is_powerable(65, 65), "Subway station clears only the piped structure flag")
	_check(Buildings.undo(city, subway_station, random, process_random).ok, "Subway station underground changes can be undone")

	var statue := Buildings.apply(city, 5, 2, Vector2i(68, 68), random, process_random)
	_check(statue.ok, "Statue placement succeeds")
	_check(city.is_piped(68, 68) and city.is_powered(68, 68) and not city.is_powerable(68, 68), "Statue clears the powerable flag")
	_check(Buildings.undo(city, statue, random, process_random).ok, "Statue placement can be undone")

	var edge := Buildings.apply(city, 3, 2, Vector2i(1, 1), random, process_random)
	_check(not edge.ok and edge.error.contains("fit"), "Four-tile building rejects the inner map edge")
	_check(city.set_building_id(20, 20, 0x1d), "Blocked-site fixture places a road")
	var blocked := Buildings.apply(city, 3, 2, Vector2i(20, 20), random, process_random)
	_check(not blocked.ok and blocked.error.contains("protected"), "Building placement rejects a road")
	_check(city.set_building_id(20, 20, 0), "Blocked-site fixture removes the road")
	_check(city.set_zone_id(20, 20, 7), "Military fixture sets a military zone")
	var military := Buildings.apply(city, 3, 2, Vector2i(20, 20), random, process_random)
	_check(not military.ok and military.error.contains("military"), "Building placement rejects military zones")
	_check(city.set_zone_id(20, 20, 0), "Military fixture clears the military zone")

	for x in range(50, 53):
		for y in range(50, 53):
			_check(city.set_tile_flag(x, y, 0x04, x == 50), "Marina fixture sets shoreline water")
	var marina := Buildings.apply(city, 14, 4, Vector2i(51, 51), random, process_random)
	_check(marina.ok, "Marina placement accepts mixed land and water")
	_check(Buildings.undo(city, marina, random, process_random).ok, "Marina placement can be undone")
	for y in range(50, 53):
		_check(city.set_tile_flag(50, y, 0x04, false), "Marina dry fixture removes water")
	var dry_marina := Buildings.apply(city, 14, 4, Vector2i(51, 51), random, process_random)
	_check(not dry_marina.ok and dry_marina.error.contains("land and water"), "Marina rejects an all-dry site")

	_check(city.set_funds(3999), "Building funds fixture sets insufficient funds")
	var unaffordable := Buildings.apply(city, 3, 2, Vector2i(60, 60), random, process_random)
	_check(not unaffordable.ok and unaffordable.error == "insufficient funds", "Building command reports insufficient funds")


func _test_network_command(reference_root: String) -> void:
	_check(Networks.supports_tool(6, 0), "Network command supports roads")
	_check(Networks.supports_tool(7, 1), "Network command supports subways")
	_check(not Networks.supports_tool(6, 1), "Highways remain a separate network tool")
	_check(
		Networks.route(Vector2i(10, 10), Vector2i(13, 12))
		== [Vector2i(10, 10), Vector2i(11, 10), Vector2i(11, 11), Vector2i(12, 11), Vector2i(12, 12), Vector2i(13, 12)],
		"Network route follows the recovered dominant-axis rule",
	)

	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Network fixture clears %s" % chunk_id,
		)
	_check(document.set_misc_i32(0x14, 10000), "Network fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Network fixture counts clear tiles")
	var city := CityModel.from_document(document)

	var road := Networks.apply(city, 6, 0, Vector2i(10, 10), Vector2i(14, 10))
	_check(road.ok and road.points.size() == 5, "Road drag builds five tiles")
	_check(road.cost == 50 and city.funds() == 9950, "Road drag charges ten dollars per route tile")
	for x in range(10, 15):
		_check(city.building_id(x, 10) == 0x1e, "Road drag stores a connected road shape")
	_check(Networks.undo(city, road).ok, "Road drag can be undone")
	_check(city.funds() == 10000 and city.building_id(12, 10) == 0, "Road undo restores funds and tiles")

	_check(city.set_building_id(20, 20, 0x1d), "Rail crossover fixture places a road")
	var rail_crossing := Networks.apply(city, 7, 0, Vector2i(20, 20), Vector2i(21, 20))
	_check(rail_crossing.ok and city.building_id(20, 20) == 0x45, "Rail tool creates the recovered road crossover")
	_check(Networks.undo(city, rail_crossing).ok, "Rail crossover can be undone")

	var pipes := Networks.apply(city, 4, 0, Vector2i(10, 30), Vector2i(12, 30))
	_check(pipes.ok and pipes.cost == 9, "Pipe drag charges three dollars per tile")
	for x in range(10, 13):
		_check(city.underground_id(x, 30) == 0x11, "Pipe drag stores connected pipe shapes")
		_check(city.is_piped(x, 30), "Pipe drag sets the piped flag")
	_check(Networks.undo(city, pipes).ok, "Pipe drag can be undone")

	var subway := Networks.apply(city, 7, 1, Vector2i(30, 30), Vector2i(30, 32))
	_check(subway.ok and subway.cost == 300, "Subway drag charges one hundred dollars per tile")
	for y in range(30, 33):
		_check(city.underground_id(30, y) == 0x01, "Subway drag stores connected subway shapes")
	_check(Networks.undo(city, subway).ok, "Subway drag can be undone")

	_check(city.set_building_id(42, 40, 0x51), "Partial-route fixture places an obstruction")
	var partial := Networks.apply(city, 6, 0, Vector2i(40, 40), Vector2i(44, 40))
	_check(partial.ok and partial.stopped_early, "Road route stops at an obstruction")
	_check(partial.points == [Vector2i(40, 40), Vector2i(41, 40)], "Road route keeps the clear prefix")
	_check(partial.cost == 20, "Partial road route charges only its planned prefix")
	_check(Networks.undo(city, partial).ok, "Partial road route can be undone")

	_check(city.set_funds(1), "Network funds fixture sets insufficient funds")
	var unaffordable := Networks.apply(city, 3, 0, Vector2i(50, 50), Vector2i(51, 50))
	_check(not unaffordable.ok and unaffordable.error == "insufficient funds", "Network command reports insufficient funds")


func _test_hydro_command(reference_root: String) -> void:
	_check(Hydro.supports_tool(3, 3), "Hydroelectric command supports the hydro tool")
	_check(not Hydro.supports_tool(3, 2), "Hydroelectric command rejects coal power")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XZON", "XBIT", "XTXT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Hydroelectric fixture clears %s" % chunk_id,
		)
	_check(document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Hydroelectric fixture clears XLAB")
	_check(document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Hydroelectric fixture clears XMIC")
	_check(document.set_misc_i32(0x14, 1000), "Hydroelectric fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Hydroelectric fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + 0xc7 * 4, 0), "Hydroelectric fixture clears hydro count")
	var city := CityModel.from_document(document)
	_check(city.set_terrain_id(20, 20, 0x2e), "Hydroelectric fixture places a waterfall")
	_check(city.set_land_altitude(20, 20, 5), "Hydroelectric fixture sets waterfall altitude")
	_check(city.set_land_altitude(20, 19, 6), "Hydroelectric fixture sets a higher north tile")
	var process_random := Random.new(33)
	var command := Hydro.apply(city, 3, 3, Vector2i(20, 20), process_random)
	_check(command.ok, "Hydroelectric placement succeeds: %s" % command.error)
	_check(command.tile_id == 0xc7 and city.building_id(20, 20) == 0xc7, "Hydroelectric tile follows the recovered slope orientation")
	_check(city.funds() == 600 and city.is_powerable(20, 20), "Hydroelectric placement charges cost and sets powerable")
	_check(city.zones[20 * 128 + 20] == 0xf0, "Hydroelectric placement sets all corner bits")
	_check(command.overlay_id == 56 and city.label(56) == "Hydro Power", "Hydroelectric placement uses fixed XMIC record five")
	_check(city.microsim(5).stat_1 == 1 and city.microsim(5).stat_2 == 20, "Hydroelectric placement increments fixed XMIC totals")
	_check(Hydro.undo(city, command, process_random).ok, "Hydroelectric placement can be undone")
	_check(city.building_id(20, 20) == 0 and city.funds() == 1000, "Hydroelectric undo restores the tile and funds")
	var wrong_terrain := Hydro.apply(city, 3, 3, Vector2i(21, 21), process_random)
	_check(not wrong_terrain.ok and wrong_terrain.error.contains("waterfall"), "Hydroelectric placement requires waterfall terrain")


func _test_subway_to_rail_command(reference_root: String) -> void:
	_check(SubwayToRail.supports_tool(7, 4), "Subway-to-rail command supports its catalog tool")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Subway-to-rail fixture clears %s" % chunk_id,
		)
	_check(document.set_misc_i32(0x14, 0), "Subway-to-rail fixture clears funds")
	_check(document.set_misc_u32(0x01f0, 16383), "Subway-to-rail fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + 0x2c * 4, 1), "Subway-to-rail fixture counts rail")
	var city := CityModel.from_document(document)
	_check(city.set_building_id(21, 20, 0x2c), "Subway-to-rail fixture places adjacent rail")
	_check(city.set_zone_id(20, 20, 3), "Subway-to-rail fixture places a commercial zone")
	var surface := SubwayToRail.apply(city, 7, 4, Vector2i(20, 20))
	_check(surface.ok, "Subway-to-rail placement beside surface rail succeeds: %s" % surface.error)
	_check(surface.tile_id == 0x6c and city.building_id(20, 20) == 0x6c, "East rail selects connector orientation zero")
	_check(city.underground_id(20, 20) == 0x23, "Subway-to-rail placement writes underground entrance 0x23")
	_check(city.zones[20 * 128 + 20] == 0xf3, "Subway-to-rail placement preserves the zone and sets all corners")
	_check(city.funds() == 0 and surface.cost == 0 and surface.listed_cost == 250, "Subway-to-rail reproduces the executable's missing cost deduction")
	_check(SubwayToRail.undo(city, surface).ok, "Subway-to-rail placement can be undone")
	_check(city.building_id(20, 20) == 0 and city.underground_id(20, 20) == 0, "Subway-to-rail undo restores surface and underground maps")

	_check(city.set_building_id(21, 20, 0), "Underground connection fixture removes surface rail")
	_check(city.set_underground_id(21, 20, 0x01), "Underground connection fixture places adjacent subway")
	var underground := SubwayToRail.apply(city, 7, 4, Vector2i(20, 20))
	_check(underground.ok and underground.tile_id == 0x6e, "East subway selects the opposite connector orientation")
	_check(SubwayToRail.undo(city, underground).ok, "Underground-oriented connector can be undone")
	_check(city.set_underground_id(21, 20, 0), "Missing-neighbor fixture removes adjacent subway")
	var no_neighbor := SubwayToRail.apply(city, 7, 4, Vector2i(20, 20))
	_check(not no_neighbor.ok and no_neighbor.error.contains("adjacent"), "Subway-to-rail placement requires an adjacent network")


func _test_onramp_command(reference_root: String) -> void:
	_check(Onramps.supports_tool(6, 3), "On-ramp command supports its catalog tool")
	_check(not Onramps.supports_tool(6, 1), "On-ramp command rejects the highway tool")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"On-ramp fixture clears %s" % chunk_id,
		)
	_check(document.set_misc_i32(0x14, 100), "On-ramp fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16382), "On-ramp fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + 0x49 * 4, 1), "On-ramp fixture counts highway")
	_check(document.set_misc_u32(0x01f0 + 0x1d * 4, 1), "On-ramp fixture counts road")
	var city := CityModel.from_document(document)
	_check(city.set_building_id(21, 20, 0x49), "On-ramp fixture places east highway")
	_check(city.set_building_id(20, 19, 0x1d), "On-ramp fixture places north road")
	var north := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(north.ok, "North-road on-ramp succeeds: %s" % north.error)
	_check(north.tile_id == 0x5f and city.building_id(20, 20) == 0x5f, "East highway and north road select ramp 0x5f")
	_check(city.building_id(20, 19) == 0x2b, "On-ramp converts its adjacent road to tile 0x2b")
	_check((city.tile_flags[20 * 128 + 20] & 0x02) != 0, "North-road on-ramp sets the flipped flag")
	_check(city.funds() == 75 and north.cost == 25, "On-ramp charges the catalog cost")
	_check(Onramps.undo(city, north).ok, "On-ramp placement can be undone")
	_check(city.building_id(20, 20) == 0 and city.building_id(20, 19) == 0x1d, "On-ramp undo restores both surface tiles")
	_check(city.funds() == 100, "On-ramp undo restores funds")

	_check(city.set_building_id(21, 20, 0), "Second on-ramp fixture removes east highway")
	_check(city.set_building_id(20, 19, 0), "Second on-ramp fixture removes north road")
	_check(city.set_building_id(20, 19, 0x49), "Second on-ramp fixture places north highway")
	_check(city.set_building_id(21, 20, 0x1d), "Second on-ramp fixture places east road")
	var east := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(east.ok and east.tile_id == 0x5d, "North highway and east road select ramp 0x5d")
	_check(Onramps.undo(city, east).ok, "East-road on-ramp can be undone")
	_check(city.set_building_id(20, 19, 0), "Invalid arrangement fixture removes north highway")
	_check(city.set_building_id(21, 20, 0), "Invalid arrangement fixture removes east road")
	_check(city.set_building_id(21, 20, 0x49), "Invalid arrangement fixture places east highway")
	_check(city.set_building_id(19, 20, 0x1d), "Invalid arrangement fixture places west road")
	var parallel := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(not parallel.ok and parallel.error.contains("perpendicular"), "On-ramp rejects a road parallel to the highway")
	_check(city.set_funds(24), "On-ramp funds fixture sets insufficient funds")
	_check(city.set_building_id(19, 20, 0), "On-ramp funds fixture removes west road")
	_check(city.set_building_id(20, 19, 0x1d), "On-ramp funds fixture places north road")
	var unaffordable := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(not unaffordable.ok and unaffordable.error == "insufficient funds", "On-ramp command reports insufficient funds")


func _test_tunnel_command(reference_root: String) -> void:
	_check(Tunnels.supports_tool(6, 2), "Tunnel command supports its catalog tool")
	_check(not Tunnels.supports_tool(6, 1), "Tunnel command rejects the highway tool")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(size, 0)),
			"Tunnel fixture clears %s" % chunk_id,
		)
	_check(document.set_misc_i32(0x14, 1000), "Tunnel fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16383), "Tunnel fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + 0x1d * 4, 1), "Tunnel fixture counts road")
	var city := CityModel.from_document(document)
	_check(city.set_terrain_id(20, 20, 3), "Tunnel fixture places an east-facing slope")
	_check(city.set_land_altitude(20, 20, 5), "Tunnel fixture sets start altitude")
	_check(city.set_land_altitude(21, 20, 6), "Tunnel fixture raises the hill interior")
	_check(city.set_terrain_id(22, 20, 1), "Tunnel fixture places the opposite slope")
	_check(city.set_land_altitude(22, 20, 5), "Tunnel fixture sets finish altitude")
	_check(city.set_building_id(19, 20, 0x1d), "Tunnel fixture places an adjacent road")
	var command := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(command.ok, "East-facing tunnel succeeds: %s" % command.error)
	_check(command.finish == Vector2i(22, 20) and command.points.size() == 3, "Tunnel finds the first tile at the start altitude")
	_check(city.building_id(20, 20) == 0x41 and city.building_id(22, 20) == 0x3f, "Tunnel writes paired east and west entrances")
	_check(city.tunnel_levels(20, 20) == 1 and city.tunnel_levels(21, 20) == 2 and city.tunnel_levels(22, 20) == 1, "Tunnel writes recovered ALTM depths")
	_check(city.building_id(19, 20) == 0x1e, "Tunnel reconnects an adjacent road")
	_check(command.cost == 450 and city.funds() == 550, "Tunnel charges each traversed tile")
	_check(Tunnels.undo(city, command).ok, "Tunnel placement can be undone")
	_check(city.building_id(20, 20) == 0 and city.building_id(22, 20) == 0, "Tunnel undo restores both entrances")
	_check(city.tunnel_levels(21, 20) == 0 and city.funds() == 1000, "Tunnel undo restores ALTM and funds")

	_check(city.set_tunnel_levels(21, 20, 1), "Tunnel conflict fixture places an existing tunnel")
	var conflict := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(not conflict.ok and conflict.error.contains("another tunnel"), "Tunnel rejects an existing ALTM tunnel path")
	_check(city.set_tunnel_levels(21, 20, 0), "Tunnel conflict fixture removes existing tunnel")
	_check(city.set_underground_id(21, 20, 0x10), "Tunnel conflict fixture places a pipe at depth two")
	var pipe_conflict := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(not pipe_conflict.ok and pipe_conflict.error.contains("underground"), "Tunnel rejects a pipe at the matching depth")
	_check(city.set_underground_id(21, 20, 0), "Tunnel conflict fixture removes pipe")
	_check(city.set_terrain_id(22, 20, 2), "Tunnel exit fixture changes the opposite slope")
	var no_exit := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(not no_exit.ok and no_exit.error.contains("opposite slope"), "Tunnel requires the recovered opposite exit slope")
	_check(city.set_terrain_id(22, 20, 1), "Tunnel funds fixture restores the exit slope")
	_check(city.set_funds(449), "Tunnel funds fixture sets insufficient funds")
	var unaffordable := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(not unaffordable.ok and unaffordable.error == "insufficient funds", "Tunnel command reports insufficient funds")


func _test_highway_command(reference_root: String) -> void:
	_check(Highways.supports_tool(6, 1), "Highway command supports its catalog tool")
	_check(not Highways.supports_tool(6, 0), "Highway command rejects the road tool")
	_check(Highways.snap_anchor(Vector2i(11, 13)) == Vector2i(10, 12), "Highway pointer snaps to even coordinates")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(size, 0)),
			"Highway fixture clears %s" % chunk_id,
		)
	_check(document.set_misc_i32(0x14, 1000), "Highway fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Highway fixture counts clear tiles")
	var city := CityModel.from_document(document)
	var straight := Highways.apply(city, 6, 1, Vector2i(10, 10), Vector2i(14, 10))
	_check(straight.ok and straight.sections.size() == 3, "Highway drag builds three 2-by-2 sections")
	_check(straight.cost == 300 and city.funds() == 700, "Highway drag charges one hundred dollars per section")
	for x in range(10, 16):
		for y in range(10, 12):
			_check(city.building_id(x, y) == 0x4a, "Horizontal highway stores straight tile 0x4a")
			_check(city.zones[x * 128 + y] == 0xf0, "Straight highway sets all XZON corner bits")
	_check(Highways.undo(city, straight).ok, "Straight highway can be undone")
	_check(city.funds() == 1000 and city.building_id(12, 10) == 0, "Highway undo restores funds and tiles")

	var turn := Highways.apply(city, 6, 1, Vector2i(10, 10), Vector2i(12, 12))
	_check(turn.ok and turn.sections == [Vector2i(10, 10), Vector2i(10, 12), Vector2i(12, 12)], "Highway route follows the recovered dominant-axis rule")
	_check(city.building_id(10, 10) == 0x49, "Highway turn starts with a vertical section")
	_check(city.building_id(10, 12) == 0x65, "North-east highway turn uses shaped tile 0x65")
	_check(city.building_id(12, 12) == 0x4a, "Highway turn ends with a horizontal section")
	_check((city.zones[10 * 128 + 12] & 0xf0) != 0xf0, "Shaped highway stores a 2-by-2 corner mask")
	_check(Highways.undo(city, turn).ok, "Turning highway can be undone")

	_check(city.set_building_id(10, 10, 0x1e), "Highway crossing fixture places a horizontal road")
	_check(document.set_misc_u32(0x01f0, 16383), "Highway crossing fixture updates clear count")
	_check(document.set_misc_u32(0x01f0 + 0x1e * 4, 1), "Highway crossing fixture counts road")
	var crossing_city := CityModel.from_document(document)
	var crossing := Highways.apply(crossing_city, 6, 1, Vector2i(10, 10), Vector2i(10, 12))
	_check(crossing.ok, "Highway can cross a perpendicular road: %s" % crossing.error)
	_check(crossing_city.building_id(10, 10) == 0x4b, "Vertical highway and horizontal road use crossover 0x4b")
	_check(Highways.undo(crossing_city, crossing).ok, "Highway crossover can be undone")
	_check(crossing_city.set_building_id(10, 10, 0), "Highway obstruction fixture removes road")
	_check(crossing_city.set_building_id(14, 10, 0xd0), "Highway obstruction fixture places a building")
	var partial := Highways.apply(crossing_city, 6, 1, Vector2i(10, 10), Vector2i(16, 10))
	_check(partial.ok and partial.stopped_early, "Highway route stops at an obstruction")
	_check(partial.sections == [Vector2i(10, 10), Vector2i(12, 10)], "Highway route keeps its clear prefix")
	_check(partial.cost == 200, "Partial highway charges only its clear sections")
	_check(Highways.undo(crossing_city, partial).ok, "Partial highway can be undone")
	_check(crossing_city.set_tile_flag(10, 10, 0x04, true), "Highway water fixture sets water")
	var water := Highways.apply(crossing_city, 6, 1, Vector2i(10, 10), Vector2i(10, 10))
	_check(not water.ok and water.error.contains("bridges"), "Highway reports its unimplemented bridge path")


func _test_demolish_command(reference_root: String) -> void:
	_check(Demolish.supports_tool(0, 0), "Demolish command supports its catalog tool")
	_check(not Demolish.supports_tool(0, 4), "Demolish command rejects De-zone")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Demolish fixture clears %s" % chunk_id,
		)
	_check(document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Demolish fixture clears XLAB")
	_check(document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Demolish fixture clears XMIC")
	_check(document.set_misc_i32(0x14, 1000), "Demolish fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Demolish fixture counts clear tiles")
	var city := CityModel.from_document(document)
	var placement_random := GameRandom.new(11)
	var process_random := Random.new(17)
	var hospital := Buildings.apply(city, 13, 2, Vector2i(20, 20), placement_random, process_random)
	_check(hospital.ok and hospital.overlay_id == 61, "Demolish fixture places a dynamic hospital")
	var demolition_random := Random.new(29)
	var building := Demolish.apply_path(city, 0, 0, [Vector2i(20, 20)], demolition_random)
	_check(building.ok and building.action_count == 1 and building.tile_indices.size() == 9, "Demolish removes a complete 3-by-3 building")
	for x in range(19, 22):
		for y in range(19, 22):
			_check(city.building_id(x, y) >= 1 and city.building_id(x, y) <= 4, "Demolished dry building becomes rubble")
			_check((city.zones[x * 128 + y] & 0xf0) == 0, "Demolish clears building corner bits")
			_check((city.tile_flags[x * 128 + y] & 0xc2) == 0, "Demolish clears flip, powered, and powerable flags")
			_check(city.text_overlay_id(x, y) == 0, "Demolish clears dynamic text overlays")
	_check(city.microsim(10).tile_id == 0 and city.label(61).is_empty(), "Demolish releases dynamic XMIC and XLAB records")
	_check(building.cost == 1 and city.funds() == 499, "One building demolition costs one dollar")
	_check(Demolish.undo(city, building, demolition_random).ok, "Building demolition can be undone")
	_check(city.building_id(20, 20) == 0xd1 and city.funds() == 500, "Demolish undo restores the building and funds")

	var simple_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			simple_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Simple demolish fixture clears %s" % chunk_id,
		)
	_check(simple_document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Simple demolish fixture clears XLAB")
	_check(simple_document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Simple demolish fixture clears XMIC")
	_check(simple_document.set_misc_i32(0x14, 10), "Simple demolish fixture sets funds")
	_check(simple_document.set_misc_u32(0x01f0, 16383), "Simple demolish fixture counts clear tiles")
	_check(simple_document.set_misc_u32(0x01f0 + 3 * 4, 1), "Simple demolish fixture counts rubble")
	var simple_city := CityModel.from_document(simple_document)
	_check(simple_city.set_building_id(10, 10, 3), "Simple demolish fixture places rubble")
	var rubble := Demolish.apply_path(simple_city, 0, 0, [Vector2i(10, 10)], demolition_random)
	_check(rubble.ok and simple_city.building_id(10, 10) == 0, "Demolish clears rubble")
	_check(rubble.cost == 1 and simple_city.funds() == 9, "Rubble demolition charges one dollar")
	_check(Demolish.undo(simple_city, rubble, demolition_random).ok, "Rubble demolition can be undone")
	_check(simple_city.set_zone_id(10, 10, 7), "Protected demolish fixture sets military zone")
	var military := Demolish.apply_path(simple_city, 0, 0, [Vector2i(10, 10)], demolition_random)
	_check(not military.ok and military.error.contains("eligible"), "Demolish rejects military zones")
	_check(simple_city.set_zone_id(10, 10, 0), "Highway demolish fixture clears military zone")
	_check(simple_city.set_building_id(10, 10, 0x49), "Highway demolish fixture places highway")
	var highway := Demolish.apply_path(simple_city, 0, 0, [Vector2i(10, 10)], demolition_random)
	_check(not highway.ok and highway.error.contains("malformed"), "Demolish rejects a malformed highway section")
	_check(simple_city.set_building_id(10, 10, 0), "Highway demolition fixture removes its malformed tile")
	_check(simple_document.set_misc_i32(0x14, 500), "Highway demolition fixture sets funds")
	var placed_highway := Highways.apply(simple_city, 6, 1, Vector2i(10, 10), Vector2i(10, 10))
	_check(placed_highway.ok, "Highway demolition fixture builds one complete section")
	var removed_highway := Demolish.apply_path(simple_city, 0, 0, [Vector2i(11, 11)], demolition_random)
	_check(removed_highway.ok and removed_highway.tile_indices.size() == 4, "Demolish removes a complete 2-by-2 highway section")
	for x in range(10, 12):
		for y in range(10, 12):
			_check(simple_city.building_id(x, y) >= 1 and simple_city.building_id(x, y) <= 4, "Demolished highway becomes rubble")
	_check(Demolish.undo(simple_city, removed_highway, demolition_random).ok, "Highway demolition can be undone")
	_check(Highways.undo(simple_city, placed_highway).ok, "Highway fixture can be removed after demolition undo")

	var special_document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			special_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(size, 0)),
			"Special demolition fixture clears %s" % chunk_id,
		)
	_check(special_document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Special demolition fixture clears XLAB")
	_check(special_document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Special demolition fixture clears XMIC")
	_check(special_document.set_misc_i32(0x14, 100), "Special demolition fixture sets funds")
	_check(special_document.set_misc_u32(0x0e40, 0), "Special demolition fixture sets sea level")
	_check(special_document.set_misc_u32(0x01f0, 16384), "Special demolition fixture counts clear tiles")
	var special_city := CityModel.from_document(special_document)
	_check(special_city.set_building_id(30, 30, 0x3f), "Tunnel demolition fixture places its first entrance")
	_check(special_city.set_building_id(28, 30, 0x41), "Tunnel demolition fixture places its second entrance")
	for x in range(28, 31):
		_check(special_city.set_tunnel_levels(x, 30, 3), "Tunnel demolition fixture stores tunnel depth")
	var tunnel := Demolish.apply_path(special_city, 0, 0, [Vector2i(30, 30)], demolition_random)
	_check(tunnel.ok and tunnel.tile_indices.size() == 3, "Demolish follows a tunnel to its paired entrance")
	_check(special_city.building_id(30, 30) == 0 and special_city.building_id(28, 30) == 0, "Tunnel demolition clears both entrances")
	for x in range(28, 31):
		_check(special_city.tunnel_levels(x, 30) == 0, "Tunnel demolition clears each saved depth")
	_check(Demolish.undo(special_city, tunnel, demolition_random).ok, "Tunnel demolition can be undone")

	for point in [Vector2i(40, 40), Vector2i(41, 40), Vector2i(41, 41)]:
		_check(special_city.set_building_id(point.x, point.y, 0xdd), "Runway demolition fixture places a connected tile")
	_check(special_city.set_building_id(45, 45, 0xdd), "Runway demolition fixture places a separate tile")
	var runway := Demolish.apply_path(special_city, 0, 0, [Vector2i(40, 40)], demolition_random)
	_check(runway.ok and runway.tile_indices.size() == 3, "Demolish removes one connected runway component")
	_check(special_city.building_id(45, 45) == 0xdd, "Runway demolition preserves a separate component")
	for point in [Vector2i(40, 40), Vector2i(41, 40), Vector2i(41, 41)]:
		_check(special_city.building_id(point.x, point.y) >= 1 and special_city.building_id(point.x, point.y) <= 4, "Demolished runway becomes rubble")
	_check(Demolish.undo(special_city, runway, demolition_random).ok, "Runway demolition can be undone")

	for point in [Vector2i(50, 50), Vector2i(50, 51)]:
		_check(special_city.set_building_id(point.x, point.y, 0xdf), "Pier demolition fixture places a connected tile")
	var pier := Demolish.apply_path(special_city, 0, 0, [Vector2i(50, 50)], demolition_random)
	_check(pier.ok and special_city.building_id(50, 50) == 0 and special_city.building_id(50, 51) == 0, "Demolish clears a connected pier component")
	_check(Demolish.undo(special_city, pier, demolition_random).ok, "Pier demolition can be undone")

	_check(special_document.set_misc_u32(0x0e40, 1), "Bridge demolition fixture sets sea level")
	for x in range(70, 73):
		_check(special_city.set_building_id(x, 70, 0x51 + x - 70), "Bridge demolition fixture places a span tile")
		_check(special_city.set_terrain_id(x, 70, 0x30), "Bridge demolition fixture places water terrain")
		_check(special_city.set_tile_flag(x, 70, 0x04, true), "Bridge demolition fixture marks span water")
		_check(special_city.set_tile_flag(x, 70, 0x02, true), "Bridge demolition fixture sets a horizontal span")
	for x in [69, 73]:
		_check(special_city.set_land_altitude(x, 70, 1), "Bridge demolition fixture raises a bank")
		_check(special_city.set_building_id(x, 70, 0x1d), "Bridge demolition fixture places a bank road")
	var bridge := Demolish.apply_path(special_city, 0, 0, [Vector2i(71, 70)], demolition_random)
	_check(
		bridge.ok
		and bridge.tile_indices.size() == 5
		and bridge.effect_events.size() == 3
		and bridge.sound_events == [504],
		"Demolish clears one bridge span and requests its debris and sound",
	)
	for x in range(70, 73):
		_check(special_city.building_id(x, 70) == 0, "Bridge demolition clears each span tile")
	for x in [69, 73]:
		_check(special_city.land_altitude(x, 70) == 0, "Bridge demolition lowers each dry bank")
		_check((special_city.tile_flags[x * 128 + 70] & 0x04) != 0, "Bridge demolition restores bank water")
	_check(Demolish.undo(special_city, bridge, demolition_random).ok, "Bridge demolition can be undone")

	for section in 3:
		var reinforced_tile := 0x6b if section != 1 else 0x6a
		for x_offset in 2:
			for y_offset in 2:
				var point := Vector2i(80 + section * 2 + x_offset, 80 + y_offset)
				_check(special_city.set_building_id(point.x, point.y, reinforced_tile), "Reinforced demolition fixture places a span tile")
				_check(special_city.set_terrain_id(point.x, point.y, 0x30), "Reinforced demolition fixture places water terrain")
				_check(special_city.set_tile_flag(point.x, point.y, 0x04, true), "Reinforced demolition fixture marks span water")
	for bank_point in [Vector2i(78, 80), Vector2i(86, 80)]:
		_check(special_city.set_building_id(bank_point.x, bank_point.y, 0x49), "Reinforced demolition fixture places a bank")
		_check(special_city.set_land_altitude(bank_point.x, bank_point.y, 1), "Reinforced demolition fixture raises a bank")
	var reinforced_bridge := Demolish.apply_path(
		special_city, 0, 0, [Vector2i(80, 80)], demolition_random
	)
	_check(
		reinforced_bridge.ok
		and reinforced_bridge.tile_indices.size() == 13
		and reinforced_bridge.effect_events.size() == 12
		and reinforced_bridge.sound_events == [504],
		"Demolish clears a reinforced span and the original forward-bank cell",
	)
	for x in range(80, 86):
		for y in range(80, 82):
			_check(special_city.building_id(x, y) == 0, "Reinforced demolition clears each span tile")
	_check(special_city.building_id(78, 80) == 0x49, "Reinforced demolition preserves the rear bank")
	_check(special_city.building_id(86, 80) == 0, "Reinforced demolition clears the forward bank")
	_check(special_city.land_altitude(86, 80) == 0, "Reinforced demolition lowers the forward bank")
	_check((special_city.tile_flags[86 * 128 + 80] & 0x04) != 0, "Reinforced demolition restores forward-bank water")
	_check(Demolish.undo(special_city, reinforced_bridge, demolition_random).ok, "Reinforced bridge demolition can be undone")

	_check(special_city.set_terrain_id(60, 60, 0x3d), "Water demolition fixture sets water terrain")
	_check(special_city.set_tile_flag(60, 60, 0x04, true), "Water demolition fixture sets its water flag")
	var water_tile := Demolish.apply_path(special_city, 0, 0, [Vector2i(60, 60)], demolition_random)
	_check(water_tile.ok and special_city.terrain_id(60, 60) == 0, "Demolish removes surface water terrain")
	_check((special_city.tile_flags[60 * 128 + 60] & 0x04) == 0, "Water demolition clears the water flag")
	_check(Demolish.undo(special_city, water_tile, demolition_random).ok, "Water demolition can be undone")


func _test_terrain_command(reference_root: String) -> void:
	_check(TerrainTools.supports_tool(0, 1), "Terrain command supports Level Terrain")
	_check(TerrainTools.supports_tool(0, 2), "Terrain command supports Raise Terrain")
	_check(TerrainTools.supports_tool(0, 3), "Terrain command supports Lower Terrain")
	_check(not TerrainTools.supports_tool(0, 0), "Terrain command rejects Demolish")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(size, 0)),
			"Terrain fixture clears %s" % chunk_id,
		)
	_check(document.set_misc_i32(0x14, 200), "Terrain fixture sets funds")
	_check(document.set_misc_u32(0x0e40, 0), "Terrain fixture sets sea level")
	_check(document.set_misc_u32(0x01f0, 16384), "Terrain fixture counts clear tiles")
	var city := CityModel.from_document(document)
	var raised := TerrainTools.apply_path(city, 0, 2, Vector2i(20, 20), [Vector2i(20, 20)])
	_check(raised.ok and city.land_altitude(20, 20) == 1, "Raise Terrain increases the selected altitude")
	_check(raised.cost == 25 and city.funds() == 175, "Raise Terrain charges each raised dependency")
	_check(city.terrain_id(20, 19) == 4 and city.terrain_id(21, 20) == 1, "Raise Terrain uses the recovered terrain shape table")
	_check(TerrainTools.undo(city, raised).ok, "Raise Terrain can be undone")
	_check(city.land_altitude(20, 20) == 0 and city.funds() == 200, "Raise undo restores altitude and funds")

	_check(city.set_land_altitude(20, 20, 1), "Lower Terrain fixture raises the selected tile")
	var lowered := TerrainTools.apply_path(city, 0, 3, Vector2i(20, 20), [Vector2i(20, 20)])
	_check(lowered.ok and city.land_altitude(20, 20) == 0, "Lower Terrain decreases the selected altitude")
	_check(lowered.cost == 25 and city.funds() == 175, "Lower Terrain charges the selected height change")
	_check(TerrainTools.undo(city, lowered).ok, "Lower Terrain can be undone")

	_check(city.set_land_altitude(30, 30, 5), "Level Terrain fixture sets the source height")
	_check(city.set_land_altitude(31, 30, 3), "Level Terrain fixture sets a lower path height")
	_check(city.set_land_altitude(31, 29, 3), "Level Terrain fixture sets the north dependency height")
	_check(city.set_land_altitude(32, 30, 3), "Level Terrain fixture sets the east dependency height")
	_check(city.set_land_altitude(31, 31, 3), "Level Terrain fixture sets the south dependency height")
	var leveled := TerrainTools.apply_path(
		city, 0, 1, Vector2i(30, 30), [Vector2i(30, 30), Vector2i(31, 30)]
	)
	_check(leveled.ok and leveled.target_altitude == 5, "Level Terrain captures the drag-start altitude")
	_check(city.land_altitude(31, 30) == 4, "Level Terrain moves a path tile one level toward its target")
	_check(TerrainTools.undo(city, leveled).ok, "Level Terrain can be undone")
	_check(city.set_land_altitude(50, 50, 1), "Lower propagation fixture sets the selected height")
	_check(city.set_land_altitude(51, 50, 3), "Lower propagation fixture sets a high neighbor")
	var propagated := TerrainTools.apply_path(city, 0, 3, Vector2i(50, 50), [Vector2i(50, 50)])
	_check(propagated.ok and city.land_altitude(50, 50) == 0, "Lower Terrain applies its selected change before propagation")
	_check(city.land_altitude(51, 50) == 2 and propagated.cost == 50, "Lower Terrain lowers a neighbor more than one level higher")
	_check(TerrainTools.undo(city, propagated).ok, "Propagated Lower Terrain can be undone")
	_check(city.set_building_id(40, 40, 0x1d), "Terrain conflict fixture places a road")
	var conflict := TerrainTools.apply_path(city, 0, 2, Vector2i(40, 40), [Vector2i(40, 40)])
	_check(not conflict.ok and conflict.error.contains("structure"), "Terrain command reports unimplemented structure conflicts")


func _test_dispatch_command(reference_root: String) -> void:
	_check(Dispatch.supports_tool(2, 0), "Dispatch command supports Police")
	_check(Dispatch.supports_tool(2, 1), "Dispatch command supports Fire")
	_check(Dispatch.supports_tool(2, 2), "Dispatch command supports Military")
	_check(not Dispatch.supports_tool(3, 0), "Dispatch command rejects another tool group")
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	for chunk_id in ["XBIT", "XTXT", "XTHG"]:
		var size := 480 if chunk_id == "XTHG" else 128 * 128
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(size, 0)),
			"Dispatch fixture clears %s" % chunk_id,
		)
	_check(document.set_misc_u32(0x01f0 + 0xd2 * 4, 9), "Dispatch fixture counts one police station")
	_check(document.set_misc_u32(0x01f0 + 0xd3 * 4, 18), "Dispatch fixture counts two fire stations")
	_check(document.set_misc_u32(0x0e4c, 4), "Dispatch fixture selects a navy base")
	var things: PackedByteArray = document.find_chunk("XTHG").decoded_payload.duplicate()
	things[5 * 12] = 7
	things[5 * 12 + 3] = 5
	things[5 * 12 + 4] = 5
	_check(document.find_chunk("XTHG").set_decoded_payload(things), "Dispatch fixture stores an old police unit")
	var text: PackedByteArray = document.find_chunk("XTXT").decoded_payload.duplicate()
	text[5 * 128 + 5] = 206
	_check(document.find_chunk("XTXT").set_decoded_payload(text), "Dispatch fixture labels the old police unit")
	var city := CityModel.from_document(document)
	var available := Dispatch.availability(city)
	_check(available.ok and available.police == 1, "Police availability is station tile count divided by eight")
	_check(available.fire == 2, "Fire availability is station tile count divided by eight")
	_check(available.military == 3, "A navy base supplies three military units")

	var police := Dispatch.apply(city, 2, 0, Vector2i(10, 10), 0, true)
	_check(police.ok and police.slot_index == 1 and police.thing_index == 1, "Police dispatch resets old units and uses the first record")
	_check(city.thing(1).type == 7 and city.thing(1).x == 10 and city.thing(1).y == 10, "Police dispatch stores the XTHG unit")
	_check(city.text_overlay_id(10, 10) == 202 and city.text_overlay_id(5, 5) == 0, "Police dispatch moves the XTXT unit marker")
	_check(IsometricRenderer.dispatch_sprite_id(city, 10, 10) == 1382, "Police dispatch selects the recovered large sprite")
	_check(
		IsometricRenderer.dispatch_sprite_id(
			city, 10, 10, IsometricRenderer.VIEW_MEDIUM
		) == 882,
		"Police dispatch selects the native medium sprite",
	)
	_check(
		IsometricRenderer.dispatch_sprite_id(
			city, 10, 10, IsometricRenderer.VIEW_SMALL
		) == 382,
		"Police dispatch selects the native small sprite",
	)
	_check(Dispatch.undo(city, police).ok, "Police dispatch can be undone")
	_check(city.thing(5).type == 7 and city.text_overlay_id(5, 5) == 206, "Dispatch undo restores units cleared at session start")
	police = Dispatch.apply(city, 2, 0, Vector2i(10, 10), 0, true)
	var moved_police := Dispatch.apply(city, 2, 0, Vector2i(11, 10), police.slot_index, false)
	_check(moved_police.ok and moved_police.slot_index == 1, "A second Police action wraps its one-unit cycle")
	_check(city.text_overlay_id(10, 10) == 0 and city.text_overlay_id(11, 10) == 202, "Wrapped Police dispatch relocates its unit")
	_check(Dispatch.undo(city, moved_police).ok, "Relocated Police dispatch can be undone")

	var fire := Dispatch.apply(city, 2, 1, Vector2i(20, 20), 0, false)
	_check(fire.ok and fire.available == 2 and city.thing(fire.thing_index).type == 8, "Fire dispatch adds an XTHG fire unit")
	var military := Dispatch.apply(city, 2, 2, Vector2i(21, 20), 0, false)
	_check(military.ok and military.available == 3 and city.thing(military.thing_index).type == 14, "Military dispatch adds an XTHG military unit")
	_check(Dispatch.undo(city, military).ok, "Military dispatch can be undone")
	_check(city.set_tile_flag(30, 30, 0x04, true), "Dispatch water fixture marks a water tile")
	var water := Dispatch.apply(city, 2, 1, Vector2i(30, 30), fire.slot_index, false)
	_check(not water.ok and water.error.contains("water"), "Dispatch rejects a water target")
	_check(document.set_misc_u32(0x01f0 + 0xd2 * 4, 0), "Dispatch unavailable fixture removes police capacity")
	var no_police := Dispatch.apply(city, 2, 0, Vector2i(31, 30), police.slot_index, false)
	_check(not no_police.ok and no_police.error.contains("available"), "Dispatch rejects an unavailable unit type")


func _test_city_rotation(reference_root: String) -> void:
	_check(
		CityRotation.rotate_point(Vector2i(10, 20), 128, true) == Vector2i(20, 117),
		"Counter-clockwise rotation transforms a full-map point",
	)
	_check(
		CityRotation.rotate_point(Vector2i(10, 20), 128, false) == Vector2i(107, 10),
		"Clockwise rotation transforms a full-map point",
	)
	_check(
		CityRotation.surface_tile_after_rotation(0x1f, true) == 0x22
		and CityRotation.surface_tile_after_rotation(0x1f, false) == 0x20,
		"Rotation uses the recovered surface-network lookup tables",
	)
	_check(
		CityRotation.terrain_tile_after_rotation(0x01, true) == 0x04
		and CityRotation.terrain_tile_after_rotation(0x01, false) == 0x02,
		"Rotation uses the recovered terrain lookup tables",
	)
	_check(
		CityRotation.underground_tile_after_rotation(0x03, true) == 0x06
		and CityRotation.underground_tile_after_rotation(0x03, false) == 0x04,
		"Rotation uses the recovered underground lookup tables",
	)

	var document := Sc2Document.load_path(reference_root.path_join("CITIES/STARTER.SC2"))
	var things: PackedByteArray = document.find_chunk("XTHG").decoded_payload.duplicate()
	things.fill(0)
	var airplane := 1 * CityModel.THING_RECORD_SIZE
	things[airplane] = 1
	things[airplane + 1] = 0
	things[airplane + 2] = 0x24
	things[airplane + 3] = 10
	things[airplane + 4] = 20
	things[airplane + 8] = 40
	things[airplane + 9] = 50
	var train := 2 * CityModel.THING_RECORD_SIZE
	things[train] = 10
	things[train + 1] = 0
	things[train + 3] = 30
	things[train + 4] = 40
	things[train + 6] = 60
	things[train + 7] = 70
	things[train + 8] = 0
	_check(document.find_chunk("XTHG").set_decoded_payload(things), "Rotation fixture stores moving things")
	var city := CityModel.from_document(document)
	_check(city.set_building_id(10, 10, 0x51), "Rotation fixture stores an unflipped bridge")
	_check(city.set_tile_flag(10, 10, 0x02, false), "Rotation fixture clears the first bridge flip")
	_check(city.set_building_id(11, 10, 0x51), "Rotation fixture stores a flipped bridge")
	_check(city.set_tile_flag(11, 10, 0x02, true), "Rotation fixture sets the second bridge flip")
	_check(city.set_building_id(12, 10, 0x5d), "Rotation fixture stores an unflipped on-ramp")
	_check(city.set_tile_flag(12, 10, 0x02, false), "Rotation fixture clears the first ramp flip")
	_check(city.set_building_id(13, 10, 0x5d), "Rotation fixture stores a flipped on-ramp")
	_check(city.set_tile_flag(13, 10, 0x02, true), "Rotation fixture sets the second ramp flip")
	_check(city.set_terrain_id(14, 10, 0x01), "Rotation fixture stores directional terrain")
	_check(city.set_underground_id(15, 10, 0x03), "Rotation fixture stores a directional subway")
	var old_payloads := {}
	for specification in CityRotation.REQUIRED_CHUNKS:
		var chunk_id: String = specification[0]
		old_payloads[chunk_id] = document.find_chunk(chunk_id).decoded_payload.duplicate()
	var old_compass := city.compass_rotation()
	var rotated := CityRotation.apply(city, true)
	_check(rotated.ok, "Counter-clockwise city rotation succeeds: %s" % rotated.error)
	_check(
		city.compass_rotation() == ((old_compass + 1) & 3),
		"Counter-clockwise rotation increments the saved compass",
	)
	_check(
		city.building_id(10, 117) == 0x51 and city.is_flipped(10, 117),
		"Counter-clockwise rotation toggles an unflipped bridge",
	)
	_check(
		city.building_id(10, 116) == 0x55 and not city.is_flipped(10, 116),
		"Counter-clockwise rotation retiles a flipped bridge",
	)
	_check(
		city.building_id(10, 115) == 0x5e and city.is_flipped(10, 115),
		"Counter-clockwise rotation retiles an unflipped on-ramp",
	)
	_check(
		city.building_id(10, 114) == 0x60 and not city.is_flipped(10, 114),
		"Counter-clockwise rotation retiles a flipped on-ramp",
	)
	_check(
		city.terrain_id(10, 113) == 0x04 and city.underground_id(10, 112) == 0x06,
		"Counter-clockwise rotation retiles terrain and underground networks",
	)
	var old_traffic: PackedByteArray = old_payloads.XTRF
	var rotated_traffic: PackedByteArray = document.find_chunk("XTRF").decoded_payload
	_check(
		rotated_traffic[7 * 64 + 58] == old_traffic[5 * 64 + 7],
		"Counter-clockwise rotation transforms a coarse-map coordinate",
	)
	var rotated_airplane := city.thing(1)
	_check(
		rotated_airplane.x == 20 and rotated_airplane.y == 117
		and rotated_airplane.direction == 6,
		"Counter-clockwise rotation transforms an airplane position and direction",
	)
	_check(
		rotated_airplane.dx == 50 and rotated_airplane.dy == 87
		and rotated_airplane.state == 0x04,
		"Counter-clockwise rotation transforms an airplane target and runway axis",
	)
	var rotated_train := city.thing(2)
	_check(
		rotated_train.x == 40 and rotated_train.y == 97
		and rotated_train.direction == 3,
		"Counter-clockwise rotation transforms a train position and direction",
	)
	_check(
		rotated_train.px == 70 and rotated_train.py == 67 and rotated_train.dx == 6,
		"Counter-clockwise rotation transforms a train route state",
	)
	var serialized := document.serialize()
	var reloaded_document := Sc2Document.new()
	_check(serialized.ok and reloaded_document.parse(serialized.data), "A rotated city serializes and reloads")
	var reloaded := CityModel.from_document(reloaded_document)
	_check(
		reloaded.is_valid() and reloaded.compass_rotation() == city.compass_rotation(),
		"A reloaded city retains its rotated compass",
	)
	var restored := CityRotation.apply(city, false)
	_check(restored.ok, "Inverse clockwise city rotation succeeds: %s" % restored.error)
	for specification in CityRotation.REQUIRED_CHUNKS:
		var chunk_id: String = specification[0]
		_check(
			document.find_chunk(chunk_id).decoded_payload == old_payloads[chunk_id],
			"Opposite rotations restore %s bytes" % chunk_id,
		)
	var engine := Simulation.new(city, 1, 1, 1)
	engine.ship_home = Vector2i(10, 20)
	engine.pending_disaster_type = 1
	engine.pending_disaster_point = Vector2i(30, 40)
	engine.rotate_runtime_coordinates(true)
	_check(
		engine.ship_home == Vector2i(20, 117)
		and engine.pending_disaster_point == Vector2i(40, 97),
		"Rotation transforms process-local simulation coordinates",
	)


func _files_with_extension(directory: String, extension: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension().to_upper() == extension:
			paths.append(directory.path_join(filename))
	paths.sort()
	return paths


func _filled_bytes(size: int, value: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(size)
	result.fill(value)
	return result


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: %s" % message)
