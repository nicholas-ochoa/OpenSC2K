extends SceneTree

@warning_ignore_start("integer_division")

const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const RleCodec = preload("res://src/formats/maxis_rle.gd")
const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityFileStore = preload("res://src/formats/city_file_store.gd")
const CityModel = preload("res://src/model/city_state.gd")
const ScenarioModel = preload("res://src/model/scenario_state.gd")
const Palette = preload("res://src/assets/sc2_palette.gd")
const IndexedBitmap = preload("res://src/assets/indexed_bmp.gd")
const ClipboardImage = preload("res://src/platform/image_clipboard.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const OriginalInstaller = preload("res://src/assets/original_game_installer.gd")
const ScurkTileSet = preload("res://src/assets/scurk_mif.gd")
const ScurkOutput = preload("res://src/assets/scurk_city_output.gd")
const ScurkEditor = preload("res://src/ui/scurk/scurk_editor_control.tscn")
const ScurkPlaceControl = preload("res://src/ui/scurk/scurk_place_print_control.tscn")
const ScurkPickCopy = preload("res://src/tools/scurk/scurk_pick_copy.gd")
const ScurkPlace = preload("res://src/tools/scurk/scurk_place_command.gd")
const ScurkHistory = preload("res://src/tools/scurk/scurk_edit_history.gd")
const ScurkWorkspace = preload("res://src/tools/scurk/scurk_drawing_workspace.gd")
const ScurkPixelEditor = preload("res://src/view/scurk_pixel_canvas.gd")
const ScurkViewWindow = preload("res://src/view/scurk_view_preview.gd")
const ScurkPalette = preload("res://src/view/scurk_palette_control.gd")
const Minimap = preload("res://src/view/city_minimap.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")
const PeBitmap = preload("res://src/assets/pe_bitmap_resource.gd")
const PeString = preload("res://src/assets/pe_string_resource.gd")
const TextUsa = preload("res://src/assets/text_usa_resource.gd")
const DataUsa = preload("res://src/assets/data_usa_resource.gd")
const MapControl = preload("res://src/view/city_map_control.gd")
const DynamicSpriteCanvas = preload("res://src/view/city_dynamic_sprite_canvas.gd")
const UndergroundView = preload("res://src/view/city_underground_view.gd")
const ViewFilter = preload("res://src/view/city_view_filter.gd")
const GraphView = preload("res://src/view/city_graph_control.gd")
const CityMapWindow = preload("res://src/view/city_map_window_control.gd")
const Clock = preload("res://src/simulation/core/simulation_clock.gd")
const Random = preload("res://src/simulation/random/sim_random.gd")
const LfsrRandom = preload("res://src/simulation/random/sim_lfsr_random.gd")
const Power = preload("res://src/simulation/infrastructure/power_phase.gd")
const Water = preload("res://src/simulation/infrastructure/water_phase.gd")
const Traffic = preload("res://src/simulation/infrastructure/traffic_phase.gd")
const Pollution = preload("res://src/simulation/data_maps/pollution_phase.gd")
const Graphs = preload("res://src/simulation/reports/graph_history.gd")
const RciDemand = preload("res://src/simulation/growth/rci_demand_phase.gd")
const RciAftermath = preload("res://src/simulation/growth/rci_aftermath_phase.gd")
const WeatherDisaster = preload("res://src/simulation/disasters/weather_disaster_phase.gd")
const NewsQueue = preload("res://src/simulation/reports/news_queue.gd")
const NewspaperTextGenerator = preload("res://src/simulation/reports/newspaper_text.gd")
const SimNation = preload("res://src/simulation/civic/simnation_phase.gd")
const Industries = preload("res://src/simulation/growth/industry_phase.gd")
const EducationHealth = preload("res://src/simulation/civic/education_health_phase.gd")
const MonthStart = preload("res://src/simulation/core/month_start_phase.gd")
const CityValue = preload("res://src/simulation/economy/city_value_phase.gd")
const Bonds = preload("res://src/simulation/economy/bond_command.gd")
const Budget = preload("res://src/simulation/economy/budget_phase.gd")
const Milestones = preload("res://src/simulation/civic/milestone_phase.gd")
const MilitaryProposal = preload("res://src/simulation/civic/military_proposal_phase.gd")
const DisasterStart = preload("res://src/simulation/disasters/disaster_start_phase.gd")
const DisasterMap = preload("res://src/simulation/disasters/map/constants.gd")
const ScenarioPhaseRunner = preload("res://src/simulation/civic/scenario_phase.gd")
const Bankruptcy = preload("res://src/simulation/economy/bankruptcy_phase.gd")
const AnnualMicrosims = preload("res://src/simulation/civic/microsim_annual_phase.gd")
const MayorApproval = preload("res://src/simulation/civic/mayor_approval_phase.gd")
const Transport = preload("res://src/simulation/infrastructure/transport_trip.gd")
const Growth = preload("res://src/simulation/growth/phase/constants.gd")
const MovingThings = preload("res://src/simulation/moving_things/moving_thing_spawner.gd")
const MovingThingTick = preload("res://src/simulation/moving_things/moving_thing_phase.gd")
const Simulation = preload("res://src/simulation/core/simulation_engine.gd")
const GameSpeed = preload("res://src/simulation/core/game_speed_controller.gd")
const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
const ToolEditState = preload("res://src/tools/shared/tool_edit_state.gd")
const Zones = preload("res://src/tools/city/zone_command.gd")
const Signs = preload("res://src/tools/city/sign_command.gd")
const Queries = preload("res://src/tools/city/query_info.gd")
const QueryFacilityActions = preload("res://src/tools/city/query_actions.gd")
const QueryPresentation = preload("res://src/view/query_presentation.gd")
const LibraryWindowLayout = preload("res://src/ui/city_windows/library_window_layout.gd")
const NewspaperTables = preload("res://src/model/newspaper_layout.gd")
const Landscapes = preload("res://src/tools/landscape/landscape_command.gd")
const Buildings = preload("res://src/tools/city/building_command.gd")
const GameRandom = preload("res://src/simulation/random/game_lcg_random.gd")
const Networks = preload("res://src/tools/city/network_command.gd")
const Hydro = preload("res://src/tools/city/hydro_command.gd")
const SubwayToRail = preload("res://src/tools/city/subway_to_rail_command.gd")
const Onramps = preload("res://src/tools/city/onramp_command.gd")
const Tunnels = preload("res://src/tools/city/tunnel_command.gd")
const Highways = preload("res://src/tools/city/highway_command.gd")
const Demolish = preload("res://src/tools/city/demolish_command.gd")
const TerrainTools = preload("res://src/tools/landscape/terrain_command.gd")
const Dispatch = preload("res://src/tools/city/dispatch_command.gd")
const CityRotation = preload("res://src/tools/city/city_rotation_command.gd")
const NewCity = preload("res://src/model/new_city_setup.gd")
const NewCityTerrain = preload("res://src/model/new_city_terrain.gd")
const NewCityTerrainSession = preload("res://src/model/new_city_terrain_session.gd")
const ThingAudio = preload("res://src/audio/moving_thing_audio.gd")
const AudioTests = preload("res://tests/suites/audio_test_suite.gd")
const InformationWindowTests = preload("res://tests/suites/information_window_test_suite.gd")
const UiShellTests = preload("res://tests/suites/ui_shell_test_suite.gd")
const TestRandoms = preload("res://tests/support/test_randoms.gd")
const ZeroRandom = TestRandoms.ZeroRandom
const ZeroLfsrRandom = TestRandoms.ZeroLfsrRandom
const NonzeroLfsrRandom = TestRandoms.NonzeroLfsrRandom
const MicrosimLfsrRandom = TestRandoms.MicrosimLfsrRandom
const SequenceLfsrRandom = TestRandoms.SequenceLfsrRandom
const SequenceRandom = TestRandoms.SequenceRandom
const SparseRandom = TestRandoms.SparseRandom
const CountingRandom = TestRandoms.CountingRandom
const SequenceGameModuloRandom = TestRandoms.SequenceGameModuloRandom
const ZeroGameRandom = TestRandoms.ZeroGameRandom
const NonzeroGameRandom = TestRandoms.NonzeroGameRandom
const SequenceGameRandom = TestRandoms.SequenceGameRandom

var fixture_documents: Dictionary = {}
var fixture_root := ""
var failures := 0
var checks := 0
var selected_domains := PackedStringArray()


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	var reference_root := ProjectSettings.globalize_path("res://../references/SIMCITY2000")

	if not arguments.is_empty():
		reference_root = arguments[0]

	fixture_root = reference_root

	for argument in arguments.slice(1):
		if argument not in ["formats", "simulation", "tools", "rendering", "scurk", "ui", "audio"]:
			push_error("Unknown core domain: " + argument)
			quit(1)
			return
		selected_domains.append(argument)

	var audio_tests := AudioTests.new(Callable(self, "_check"))
	var information_window_tests := InformationWindowTests.new(
		Callable(self, "_check")
	)
	var ui_shell_tests := UiShellTests.new(Callable(self, "_check"))

	if _selected("formats"):
		_test_rle()
	if _selected("formats"):
		_test_invalid_rle()
	if _selected("formats"):
		_test_original_game_installer(reference_root)
	if _selected("rendering"):
		_test_view_configurations()
		_test_palette_and_minimap(reference_root)
	if _selected("rendering"):
		_test_sprite_archives(reference_root)
	if _selected("scurk"):
		_test_scurk_mif(reference_root)
	if _selected("formats"):
		_test_reference_corpus(reference_root)
	if _selected("formats"):
		_test_city_options(reference_root)
	if _selected("audio"):
		audio_tests.test_music(reference_root)
	if _selected("ui"):
		ui_shell_tests.test_shell_controls()
	if _selected("ui"):
		ui_shell_tests.test_rci_status_control()
	if _selected("formats"):
		_test_scenarios(reference_root)
	if _selected("simulation"):
		_test_simulation_clock()
	if _selected("simulation"):
		_test_random_and_power(reference_root)
	if _selected("simulation"):
		_test_water(reference_root)
	if _selected("simulation"):
		_test_traffic(reference_root)
	if _selected("simulation"):
		_test_pollution(reference_root)
	if _selected("simulation"):
		_test_graph_history(reference_root)
	if _selected("simulation"):
		_test_rci_demand(reference_root)
	if _selected("simulation"):
		_test_news_queue(reference_root)
	if _selected("simulation"):
		_test_newspaper_text(reference_root)
	if _selected("simulation"):
		_test_rci_aftermath(reference_root)
	if _selected("simulation"):
		_test_weather_disaster_phase(reference_root)
	if _selected("simulation"):
		_test_simnation(reference_root)
	if _selected("simulation"):
		_test_industries(reference_root)
	if _selected("simulation"):
		_test_education_health(reference_root)
	if _selected("ui"):
		information_window_tests.run(reference_root)
	if _selected("simulation"):
		_test_month_start(reference_root)
	if _selected("simulation"):
		_test_city_value_phase(reference_root)
	if _selected("tools"):
		_test_bond_command(reference_root)
	if _selected("simulation"):
		_test_budget_phase(reference_root)
	if _selected("simulation"):
		_test_milestone_phase(reference_root)
	if _selected("simulation"):
		_test_military_proposal_phase(reference_root)
	if _selected("simulation"):
		_test_disaster_start_phase(reference_root)
	if _selected("simulation"):
		_test_disaster_map_phase(reference_root)
	if _selected("simulation"):
		_test_annual_microsim_phase(reference_root)
	if _selected("simulation"):
		_test_annual_service_microsim_phase(reference_root)
	if _selected("simulation"):
		_test_annual_special_microsim_phase(reference_root)
	if _selected("simulation"):
		_test_arcology_launch_phase(reference_root)
	if _selected("simulation"):
		_test_mayor_approval_phase(reference_root)
	if _selected("simulation"):
		_test_transport_trip(reference_root)
	if _selected("simulation"):
		_test_growth_phase(reference_root)
	if _selected("simulation"):
		_test_moving_thing_phase(reference_root)
	if _selected("simulation"):
		_test_simulation_engine(reference_root)
	if _selected("simulation"):
		_test_game_speed_controller(reference_root)
	if _selected("formats"):
		_test_modified_save(reference_root)
	if _selected("tools"):
		_test_new_city_terrain(reference_root)
	if _selected("tools"):
		_test_new_city_setup(reference_root)
	if _selected("tools"):
		_test_map_edits(reference_root)
	if _selected("tools"):
		_test_tool_catalog()
	if _selected("audio"):
		audio_tests.test_sound_rules()
	if _selected("tools"):
		_test_tool_availability(reference_root)
	if _selected("tools"):
		_test_zone_command(reference_root)
	if _selected("tools"):
		_test_sign_command(reference_root)
	if _selected("tools"):
		_test_query_info(reference_root)
	if _selected("tools"):
		_test_landscape_command(reference_root)
	if _selected("tools"):
		_test_building_command(reference_root)
	if _selected("tools"):
		_test_network_command(reference_root)
	if _selected("tools"):
		_test_hydro_command(reference_root)
	if _selected("tools"):
		_test_subway_to_rail_command(reference_root)
	if _selected("tools"):
		_test_onramp_command(reference_root)
	if _selected("tools"):
		_test_tunnel_command(reference_root)
	if _selected("tools"):
		_test_highway_command(reference_root)
	if _selected("tools"):
		_test_demolish_command(reference_root)
	if _selected("tools"):
		_test_terrain_command(reference_root)
	if _selected("tools"):
		_test_dispatch_command(reference_root)
	if _selected("tools"):
		_test_city_rotation(reference_root)

	if failures == 0:
		print("PASS: %d checks" % checks)
		quit(0)
	else:
		printerr("FAIL: %d of %d checks failed" % [failures, checks])
		quit(1)


func _selected(domain: String) -> bool:
	return selected_domains.is_empty() or domain in selected_domains


func _test_rle() -> void:
	var cases: Array[PackedByteArray] = [
		PackedByteArray(),
		PackedByteArray([1]),
		PackedByteArray([7, 7]),
		PackedByteArray([1, 2, 3, 4, 5]),
		_filled_bytes(128, 0xaa),
		_filled_bytes(300, 0x00),
		_filled_bytes(128, 0xaa) + PackedByteArray([1, 2, 3]) + _filled_bytes(3, 0x55),
	]

	for original in cases:
		var encoded := RleCodec.encode(original)
		var result := RleCodec.decode(encoded, original.size())
		_check(result.ok, "RLE round trip decodes")

		if result.ok:
			_check(result.data == original, "RLE round trip preserves bytes")

		var unsized := RleCodec.decode(encoded)
		_check(unsized.ok and unsized.data == original, "RLE decodes without an expected size")


func _test_invalid_rle() -> void:
	_check(not RleCodec.decode(PackedByteArray([0x80])).ok, "RLE rejects 0x80")
	_check(not RleCodec.decode(PackedByteArray([2, 1])).ok, "RLE rejects short literal")
	_check(not RleCodec.decode(PackedByteArray([0x81])).ok, "RLE rejects short run")
	_check(
		not RleCodec.decode(PackedByteArray([0x82, 4]), 2).ok,
		"RLE rejects output overflow"
	)


func _test_original_game_installer(reference_root: String) -> void:
	var reference_result := OriginalInstaller.validate_install_root(reference_root)
	_check(reference_result.ok, "Original game installer accepts the supplied install")

	var scratch_root := ProjectSettings.globalize_path(
		"user://test_original_installer_%d" % OS.get_process_id()
	)
	OriginalInstaller.remove_tree(scratch_root)
	var source_root := scratch_root.path_join("source")
	var source_data := source_root.path_join("DATA")
	var destination_root := scratch_root.path_join("installed")
	var make_error := DirAccess.make_dir_recursive_absolute(source_data)
	_check(make_error == OK, "Original game installer test directory is created")

	if make_error != OK:
		return

	var executable_path := source_root.path_join("simcity.exe")
	var executable_file := FileAccess.open(executable_path, FileAccess.WRITE)
	_check(executable_file != null, "Original game installer test executable opens")

	if executable_file == null:
		OriginalInstaller.remove_tree(scratch_root)

		return

	executable_file.store_buffer(PackedByteArray([0x53, 0x43, 0x32, 0x4b]))
	executable_file.close()
	var data_path := source_data.path_join("EXTRA.DAT")
	var data_file := FileAccess.open(data_path, FileAccess.WRITE)
	_check(data_file != null, "Original game installer test data opens")

	if data_file == null:
		OriginalInstaller.remove_tree(scratch_root)

		return

	data_file.store_buffer(PackedByteArray([1, 2, 3, 4]))
	data_file.close()
	var expected_hash := FileAccess.get_sha256(executable_path)
	var wrong_hash_result := OriginalInstaller.validate_executable(
		executable_path, "0".repeat(64)
	)
	_check(not wrong_hash_result.ok, "Original game installer rejects a wrong hash")
	DirAccess.make_dir_recursive_absolute(destination_root)
	var old_file := FileAccess.open(destination_root.path_join("OLD.DAT"), FileAccess.WRITE)

	if old_file != null:
		old_file.store_8(0x7f)
		old_file.close()

	var install_result := OriginalInstaller.install_from_executable(
		executable_path,
		destination_root,
		expected_hash,
		["DATA/EXTRA.DAT"],
	)
	_check(install_result.ok, "Original game installer copies a complete test install")

	if install_result.ok:
		_check(
			not str(install_result.previous_root).is_empty()
			and FileAccess.file_exists(
				str(install_result.previous_root).path_join("OLD.DAT")
			),
			"Original game installer preserves an existing app data copy",
		)
		_check(
			FileAccess.file_exists(destination_root.path_join("SIMCITY.EXE")),
			"Original game installer gives the copied executable its canonical name",
		)
		_check(
			FileAccess.get_file_as_bytes(destination_root.path_join("DATA/EXTRA.DAT"))
			== PackedByteArray([1, 2, 3, 4]),
			"Original game installer copies nested support files",
		)
		var installed_result := OriginalInstaller.validate_install_root(
			destination_root, expected_hash, ["DATA/EXTRA.DAT"]
		)
		_check(installed_result.ok, "Original game installer validates its installed copy")

	var cleanup_error := OriginalInstaller.remove_tree(scratch_root)
	_check(cleanup_error == OK, "Original game installer test data is removed")




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
			_check(city.microsim(149) != null, "%s has 150 microsim records" % path.get_file())
			_check(city.thing(39) != null, "%s has 40 thing records" % path.get_file())
			var graph := city.graph_series(15)
			_check(graph.year.size() == 12, "%s graph has 12 monthly values" % path.get_file())
			_check(graph.decade.size() == 20, "%s graph has 20 decade values" % path.get_file())
			_check(graph.century.size() == 20, "%s graph has 20 century values" % path.get_file())
			var paper_records_valid := true
			var misc_chunk := document.find_chunk("MISC")

			for paper_index in NewsQueue.PAPER_COUNT:
				var paper := NewsQueue.paper_record(misc_chunk.decoded_payload, paper_index)
				paper_records_valid = paper_records_valid and (
					int(paper.name) in range(6)
					and int(paper.layout) in range(3)
					and int(paper.price) in range(3)
					and int(paper.opinion) in range(6)
					and int(paper.weather) in range(6)
				)

			_check(
				paper_records_valid,
				"%s newspaper configurations stay in their recovered ranges" % path.get_file(),
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


func _test_city_options(reference_root: String) -> void:
	var starter_document := _load_fixture(
		reference_root.path_join("CITIES/STARTER.SC2")
	).duplicate_document()
	var starter := CityModel.from_document(starter_document)
	_check(starter.is_valid(), "Starter city loads for saved-option tests")

	if not starter.is_valid():
		return

	_check(
		starter.auto_budget_enabled()
		and starter.auto_goto_enabled()
		and starter.sound_enabled()
		and starter.music_enabled()
		and starter.no_disasters_enabled(),
		"Starter city exposes all five enabled saved options",
	)
	_check(
		starter.set_auto_budget_enabled(false)
		and starter.set_auto_goto_enabled(false)
		and starter.set_sound_enabled(false)
		and starter.set_music_enabled(false)
		and starter.set_no_disasters_enabled(false),
		"Saved city options can be disabled",
	)
	_check(
		starter_document.misc_u32(CityState.MISC_AUTO_BUDGET_OPTION) == 0
		and starter_document.misc_u32(CityState.MISC_AUTO_GOTO_OPTION) == 0
		and starter_document.misc_u32(CityState.MISC_SOUND_OPTION) == 0
		and starter_document.misc_u32(CityState.MISC_MUSIC_OPTION) == 0
		and starter_document.misc_u32(CityState.MISC_NO_DISASTERS_OPTION) == 0,
		"Disabled options write zero to their original MISC fields",
	)
	_check(
		starter.set_auto_budget_enabled(true)
		and starter.set_auto_goto_enabled(true)
		and starter.set_sound_enabled(true)
		and starter.set_music_enabled(true)
		and starter.set_no_disasters_enabled(true),
		"Saved city options can be enabled",
	)
	_check(
		starter_document.misc_u32(CityState.MISC_AUTO_BUDGET_OPTION) == 1
		and starter_document.misc_u32(CityState.MISC_AUTO_GOTO_OPTION) == 1
		and starter_document.misc_u32(CityState.MISC_SOUND_OPTION) == 1
		and starter_document.misc_u32(CityState.MISC_MUSIC_OPTION) == 1
		and starter_document.misc_u32(CityState.MISC_NO_DISASTERS_OPTION) == 1,
		"Enabled options write one to their original MISC fields",
	)
	var scenario_document := _load_fixture(
		reference_root.path_join("SCENARIO/CHARLEST.SCN")
	)
	var scenario_city := CityModel.from_document(scenario_document)
	_check(
		scenario_city.is_valid()
		and scenario_document.misc_u32(CityState.MISC_AUTO_GOTO_OPTION) == 0xff
		and scenario_city.auto_goto_enabled(),
		"Saved option readers treat a nonzero legacy value as enabled",
	)




func _test_view_configurations() -> void:
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


func _view_configuration_values(configuration: CityViewConfiguration) -> Array[int]:
	return [configuration.view_size, configuration.divisor,
		configuration.tile_width, configuration.tile_height,
		configuration.half_width, configuration.half_height,
		configuration.altitude_step, configuration.top_margin,
		configuration.side_margin, configuration.sprite_base]


func _test_palette_and_minimap(reference_root: String) -> void:
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
	_check(
		CityMapWindow.MODE_STRING_IDS.structures == 327
		and CityMapWindow.MODE_STRING_IDS.colleges == 344,
		"City Map mode labels use the recovered executable string range",
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


func _test_sprite_archives(reference_root: String) -> void:
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
	var string_ids := PackedInt32Array([106, 236, 786, 790, 910, 982])
	var strings := PeString.load_ids(reference_root.path_join("SIMCITY.EXE"), string_ids)
	_check(strings.ok, "Windows string resources load: %s" % strings.error)

	if strings.ok:
		_check(strings.strings.size() == string_ids.size(), "Windows string loader returns each requested ID")
		_check(strings.strings[910] == "#T", "Windows string loader decodes UTF-16 placeholders")

	_check(
		not PeString.load_ids(
			reference_root.path_join("SIMCITY.EXE"), PackedInt32Array([0xffff])
		).ok,
		"Windows string loader rejects a missing resource block",
	)
	var newspaper_ids := PackedInt32Array()

	for resource_id in range(347, 392):
		newspaper_ids.append(resource_id)

	var newspaper_strings := PeString.load_ids(
		reference_root.path_join("SIMCITY.EXE"), newspaper_ids
	)
	var newspaper_strings_complete: bool = newspaper_strings.ok

	if newspaper_strings.ok:
		for resource_id in newspaper_ids:
			newspaper_strings_complete = (
				newspaper_strings_complete
				and not str(newspaper_strings.strings.get(resource_id, "")).is_empty()
			)

	_check(
		newspaper_strings_complete,
		"Windows resources provide all newspaper headings, names, and prices",
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
	# Pixel formats and local patches need only a small, populated drawing fixture.
	# Large-map patch extents are owned by large_render_patch_test.
	var render_fixture := CityModel.from_document(EmptyCityTemplate.create(16))
	for point in [Vector2i(4, 4), Vector2i(12, 12), Vector2i(10, 6)]:
		render_fixture.set_building_id(point.x, point.y, Tiles.SMALL_PARK)
	var indexed_city := IsometricRenderer.create_image(
		render_fixture, Palette.index_encoding(), small_medium,
		IsometricRenderer.VIEW_SMALL, 0, false, true
	)
	_check(
		indexed_city.ok and indexed_city.image.get_pixel(0, 0).a == 0.0,
		"Indexed city rendering keeps its outer canvas transparent",
	)
	_check(
		indexed_city.ok and indexed_city.image.get_format() == Image.FORMAT_LA8,
		"Transparent indexed city rendering uses two bytes per pixel",
	)
	var opaque_indexed_city := IsometricRenderer.create_image(
		render_fixture, Palette.index_encoding(), small_medium,
		IsometricRenderer.VIEW_SMALL, 0, false, false, false, false
	)
	_check(
		opaque_indexed_city.ok
		and opaque_indexed_city.image.get_format() == Image.FORMAT_L8,
		"Opaque indexed city rendering uses one byte per pixel",
	)
	_check(
		indexed_city.ok and indexed_city.image.get_used_rect().has_area(),
		"Indexed city rendering draws nontransparent map pixels",
	)
	var patch_document := render_fixture.document.duplicate_document()
	var patch_city := CityModel.from_document(patch_document)
	var patch_point := Vector2i(8, 8)
	var patch_index := patch_city.index_of(patch_point.x, patch_point.y)
	_check(
		patch_city.set_building_id(patch_point.x, patch_point.y, Tiles.SMALL_PARK),
		"Static region fixture places a small park",
	)
	var patch_result := IsometricRenderer.patch_static_image(
		indexed_city.image,
		patch_city,
		Palette.index_encoding(),
		small_medium,
		PackedInt32Array([patch_index]),
		IsometricRenderer.VIEW_SMALL,
		0
	)
	var patch_full := IsometricRenderer.create_image(
		patch_city, Palette.index_encoding(), small_medium,
		IsometricRenderer.VIEW_SMALL, 0, false, true, false, false
	)
	_check(
		patch_result.ok
		and patch_full.ok
		and patch_result.image.get_data() == patch_full.image.get_data(),
		"A regional static edit is byte-identical to a complete small-view render",
	)
	var scaled_before: Image = indexed_city.image.duplicate()
	scaled_before.resize(
		IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_LARGE, 16).x,
		IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_LARGE, 16).y,
		Image.INTERPOLATE_NEAREST
	)
	var scaled_patch := IsometricRenderer.patch_static_image(
		scaled_before,
		patch_city,
		Palette.index_encoding(),
		small_medium,
		PackedInt32Array([patch_index]),
		IsometricRenderer.VIEW_SMALL,
		0
	)
	var scaled_full: Image = patch_full.image.duplicate()
	scaled_full.resize(
		IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_LARGE, 16).x,
		IsometricRenderer.output_size_for_view(IsometricRenderer.VIEW_LARGE, 16).y,
		Image.INTERPOLATE_NEAREST
	)
	_check(
		scaled_patch.ok
		and scaled_patch.image.get_data() == scaled_full.get_data(),
		"A scaled regional edit is byte-identical to the complete display image",
	)
	var base_patch_occlusion := IsometricRenderer.static_occlusion_commands(
		render_fixture, small_medium, IsometricRenderer.VIEW_SMALL
	)
	var regional_patch_occlusion := (
		IsometricRenderer.patch_static_occlusion_commands(
			base_patch_occlusion,
			patch_city,
			small_medium,
			PackedInt32Array([patch_index]),
			IsometricRenderer.VIEW_SMALL
		)
	)
	var full_patch_occlusion := IsometricRenderer.static_occlusion_commands(
		patch_city, small_medium, IsometricRenderer.VIEW_SMALL
	)
	_check(
		_static_command_values(regional_patch_occlusion) == _static_command_values(full_patch_occlusion),
		"A regional edit keeps the complete static occlusion command order",
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
	var overlay_document := _load_fixture(reference_root.path_join("CITIES/STARTER.SC2"))
	var overlay_city := CityModel.from_document(overlay_document)
	var overlay_point := Vector2i(64, 64)
	var traffic_index := 32 * CityModel.COARSE_MAP_SIZE + 32
	var traffic_data: PackedByteArray = (
		overlay_document.find_chunk("XTRF").decoded_payload.duplicate()
	)
	_check(
		overlay_city.set_building_id(overlay_point.x, overlay_point.y, Tiles.ROAD_STRAIGHT_1),
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
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		) == null,
		"Normal road traffic does not draw at density 85",
	)
	traffic_data[traffic_index] = 86
	_check(
		overlay_document.find_chunk("XTRF").set_decoded_payload(traffic_data),
		"Traffic view fixture crosses the first threshold",
	)
	var low_traffic := IsometricStaticVisuals.traffic_overlay_visual(
		overlay_city, overlay_point.x, overlay_point.y
	)
	_check(
		low_traffic.sprite_id == 1400
		and low_traffic.variant == 1
		and not low_traffic.flip,
		"Normal road traffic selects the recovered low-density large sprite",
	)
	var traffic_base := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	traffic_base.set_pixel(0, 0, Color8(0xa1, 0xa1, 0xa1, 255))
	traffic_base.set_pixel(1, 0, Color8(0xa0, 0xa0, 0xa0, 255))
	var traffic_pixels := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	traffic_pixels.fill(Color8(0xc8, 0xc8, 0xc8, 255))
	var masked_traffic := IsometricPixelOperations._traffic_masked_image(
		traffic_pixels, traffic_base, Palette.index_encoding()
	)
	_check(
		masked_traffic.get_pixel(0, 0).a == 1.0
		and masked_traffic.get_pixel(1, 0).a == 0.0,
		"Traffic pixels replace only the recovered road-deck palette index",
	)
	_check(
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_MEDIUM
		).sprite_id == 900,
		"Medium traffic uses its native sprite set",
	)
	_check(
		IsometricStaticVisuals.traffic_overlay_visual(
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
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).sprite_id == 1427,
		"Normal road traffic selects the recovered high-density variant",
	)
	_check(
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_SMALL
		) == null,
		"Small view omits high-density variants absent from its source archive",
	)
	_check(
		overlay_city.set_building_id(overlay_point.x, overlay_point.y, Tiles.POWER_LINE_STRAIGHT_1),
		"Traffic exclusion fixture installs a power line",
	)
	_check(
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		) == null,
		"Busy traffic cells do not draw traffic sprites on power lines",
	)
	_check(
		overlay_city.set_building_id(overlay_point.x, overlay_point.y, Tiles.HIGHWAY_STRAIGHT_1),
		"Traffic view fixture installs a highway",
	)
	traffic_data[traffic_index] = 29
	_check(
		overlay_document.find_chunk("XTRF").set_decoded_payload(traffic_data),
		"Traffic view fixture crosses the highway threshold",
	)
	_check(
		IsometricStaticVisuals.traffic_overlay_visual(
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
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).sprite_id == 1437,
		"Highway traffic selects the recovered high-density lane sprite",
	)
	_check(
		overlay_city.set_building_id(overlay_point.x, overlay_point.y, Tiles.HIGHWAY_SLOPE_1),
		"Traffic view fixture installs an elevated highway",
	)
	traffic_data[traffic_index] = 29
	_check(
		overlay_document.find_chunk("XTRF").set_decoded_payload(traffic_data),
		"Traffic view fixture restores the first highway threshold",
	)
	_check(
		IsometricStaticVisuals.traffic_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		) != null,
		"Elevated highway traffic uses the recovered lower threshold",
	)
	_check(
		overlay_city.set_building_corners(overlay_point.x, overlay_point.y, 0),
		"Highway coverage fixture clears zone anchor bits",
	)
	_check(
		not IsometricStaticVisuals._should_draw_building(
			overlay_city, overlay_point.x, overlay_point.y, Tiles.HIGHWAY_SLOPE_1
		),
		"Elevated highway waits for its compass-selected anchor",
	)
	_check(
		IsometricStaticVisuals._should_draw_building(
			overlay_city, overlay_point.x, overlay_point.y, Tiles.RAIL_SUBWAY_ENTRANCE_1
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
		IsometricStaticVisuals._should_draw_building(
			overlay_city, overlay_point.x, overlay_point.y, Tiles.HIGHWAY_SLOPE_1
		),
		"Elevated highway draws from its compass-selected anchor",
	)
	var highway_ground := IsometricStaticVisuals.highway_ground_visuals(
		overlay_city, overlay_point.x, overlay_point.y
	)
	_check(
		highway_ground.size() == 4
		and highway_ground[0].source == Vector2i(64, 64)
		and highway_ground[1].source == Vector2i(64, 63)
		and highway_ground[2].source == Vector2i(65, 63)
		and highway_ground[3].source == Vector2i(65, 64)
		and highway_ground[3].offset == Vector2i(16, 8),
		"Elevated highway redraws the recovered four-cell ground diamond",
	)
	var small_highway_ground := IsometricStaticVisuals.highway_ground_visuals(
		overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_SMALL
	)
	_check(
		small_highway_ground.is_empty(),
		"Small elevated highways omit the large and medium ground-redraw pass",
	)
	_check(
		IsometricStaticVisuals.highway_ground_visuals(overlay_city, 127, 0).size() == 1
		and IsometricStaticVisuals.highway_ground_visuals(overlay_city, 64, 0).size() == 2
		and IsometricStaticVisuals.highway_ground_visuals(overlay_city, 127, 64).size() == 2,
		"Malformed edge highway anchors clip ground reads to valid map cells",
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
		not IsometricStaticVisuals.building_sprite_flip(
			overlay_city, overlay_point.x, overlay_point.y, 0x1d
		),
		"Compass rotation does not add a mirror to a network sprite",
	)
	_check(
		IsometricStaticVisuals.building_sprite_flip(
			overlay_city, overlay_point.x, overlay_point.y, 0x70
		),
		"Odd compass rotation adds the original mirror to a building sprite",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x02, true),
		"Network orientation fixture sets the saved mirror",
	)
	_check(
		IsometricStaticVisuals.building_sprite_flip(
			overlay_city, overlay_point.x, overlay_point.y, 0x2c
		)
		and not IsometricStaticVisuals.building_sprite_flip(
			overlay_city, overlay_point.x, overlay_point.y, 0x70
		),
		"Saved mirror stays direct for rail and combines with compass for buildings",
	)
	_check(
		IsometricRenderer.building_baseline_offset(Tiles.ROAD_STRAIGHT_1, 0x0d, 32) == -12
		and IsometricRenderer.building_baseline_offset(Tiles.ROAD_STRAIGHT_1, 0x00, 32) == 0,
		"A network on terrain shape 0x0d uses the recovered raised baseline",
	)
	_check(
		IsometricRenderer.building_baseline_offset(Tiles.LOWER_CLASS_HOMES_1X1_1, 0x00, 128) == 24
		and IsometricRenderer.building_baseline_offset(
			Tiles.LOWER_CLASS_HOMES_1X1_1, 0x00, 64, IsometricRenderer.VIEW_MEDIUM
		) == 12
		and IsometricRenderer.building_baseline_offset(
			Tiles.LOWER_CLASS_HOMES_1X1_1, 0x00, 32, IsometricRenderer.VIEW_SMALL
		) == 6,
		"Large footprints use the native quarter-width baseline at every zoom",
	)
	_check(
		overlay_city.set_building_id(overlay_point.x, overlay_point.y, Tiles.LOWER_CLASS_HOMES_1X1_1),
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
		IsometricStaticVisuals.power_marker_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).sprite_id == 1386,
		"Unpowered zone building selects the recovered large marker",
	)
	_check(
		IsometricStaticVisuals.power_marker_visual(
			overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_SMALL
		).sprite_id == 386,
		"Small view selects its native unpowered marker",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x40, true),
		"Power-marker fixture sets the powered flag",
	)
	_check(
		IsometricStaticVisuals.power_marker_visual(
			overlay_city, overlay_point.x, overlay_point.y
		) == null,
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
	var fire_visual := IsometricStaticVisuals.fire_overlay_visual(
		overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_LARGE, 3
	)
	_check(
		fire_visual.sprite_id >= 1396 and fire_visual.sprite_id <= 1399,
		"Fire view selects a native large frame from its visual phase",
	)
	var fire_command := IsometricDynamicCommands.special_overlay_draw_command(
		overlay_city,
		large,
		overlay_point,
		fire_visual,
		IsometricRenderer.view_configuration(IsometricRenderer.VIEW_LARGE),
	)
	_check(
		fire_command.static_occlusion,
		"Foreground buildings occlude dynamic fire markers",
	)
	var flipped_fire := IsometricStaticVisuals.fire_overlay_visual(
		overlay_city, overlay_point.x, overlay_point.y, IsometricRenderer.VIEW_LARGE, 4
	)
	_check(
		flipped_fire.sprite_id == 1396 + (int(fire_visual.sprite_id) - 1396 + 1) % 4,
		"Fire advances to the next native frame",
	)
	var fire_frames := {}
	var fire_differences := {}
	var previous_frame := -1

	for fire_x in range(32, 64):
		var original_overlay := overlay_city.text_overlay_id(fire_x, overlay_point.y)
		var original_water := overlay_city.is_water(fire_x, overlay_point.y)
		overlay_city.set_text_overlay_id(fire_x, overlay_point.y, 0xff)
		overlay_city.set_tile_flag(fire_x, overlay_point.y, 0x04, false)
		var visual := IsometricStaticVisuals.fire_overlay_visual(overlay_city, fire_x, overlay_point.y)
		fire_frames[visual.sprite_id] = true
		var repeated := IsometricStaticVisuals.fire_overlay_visual(overlay_city, fire_x, overlay_point.y)
		_check(visual.sprite_id == repeated.sprite_id and visual.flip == repeated.flip and visual.overlay == repeated.overlay,
			"Fire animation is stable for the same tile and display time")
		overlay_city.set_text_overlay_id(fire_x, overlay_point.y, original_overlay)
		overlay_city.set_tile_flag(fire_x, overlay_point.y, 0x04, original_water)

		if previous_frame >= 0:
			fire_differences[(int(visual.sprite_id) - previous_frame + 4) % 4] = true

		previous_frame = int(visual.sprite_id)

	_check(fire_frames.size() == 4 and fire_differences.size() == 4,
		"Adjacent fires use varied phases instead of a constant wave step")
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x04, true),
		"Fire view fixture changes to a water tile",
	)
	_check(
		IsometricStaticVisuals.fire_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		) == null,
		"Fire does not draw on a saved water tile",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xfb),
		"Special-overlay fixture installs marker 0xfb",
	)
	_check(
		IsometricStaticVisuals.special_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		).sprite_id == 1496,
		"Special marker 0xfb uses its recovered large sprite on water",
	)
	_check(
		overlay_city.set_text_overlay_id(overlay_point.x, overlay_point.y, 0xfc),
		"Special-overlay fixture installs marker 0xfc",
	)
	_check(
		IsometricStaticVisuals.special_overlay_visual(
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
		IsometricStaticVisuals.special_overlay_visual(
			overlay_city, overlay_point.x, overlay_point.y
		) == null,
		"Special marker 0xfd does not draw on a saved water tile",
	)
	_check(
		overlay_city.set_tile_flag(overlay_point.x, overlay_point.y, 0x04, false),
		"Special-overlay fixture changes back to dry land",
	)
	var launch_effect := IsometricStaticVisuals.special_overlay_visual(
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
		IsometricStaticVisuals.special_overlay_visual(
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
	var land_edges := IsometricStaticVisuals.edge_stack_visuals(
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
	var water_edges := IsometricStaticVisuals.edge_stack_visuals(
		overlay_city, edge_point.x, edge_point.y
	)
	_check(
		water_edges.size() == 5
		and water_edges[3].sprite_id == 1284
		and water_edges[3].elevation == 36
		and water_edges[4].sprite_id == 1284,
		"Large map edge adds water-side sprites above the land stack",
	)
	var small_edges := IsometricStaticVisuals.edge_stack_visuals(
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
		IsometricStaticVisuals.edge_stack_visuals(
			overlay_city, 126, 64, IsometricRenderer.VIEW_LARGE
		).is_empty(),
		"Interior tiles do not draw map-edge stacks",
	)
	# All archives decode above; representative city/view asset checks cover mapping.
	# Corpus parsing and byte-exact rebuilds belong to _test_reference_corpus.

	var plane_visual := IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
		"type": 1, "direction": 4, "state": 2,
	}))
	_check(
		plane_visual.sprite_id == 1362 and plane_visual.flip,
		"Airplane view uses the recovered direction offset and mirror",
	)
	var medium_plane := IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
		"type": 1, "direction": 4, "state": 2,
	}), IsometricRenderer.VIEW_MEDIUM)
	_check(
		medium_plane.sprite_id == 862 and medium_plane.flip,
		"Airplane view selects the native medium direction sprite",
	)
	var small_plane := IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
		"type": 1, "direction": 4, "state": 2,
	}), IsometricRenderer.VIEW_SMALL)
	_check(
		small_plane.sprite_id == 362 and small_plane.flip,
		"Airplane view selects the native small direction sprite",
	)
	var ship_visual := IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
		"type": 3, "direction": 7, "state": 0,
	}))
	_check(
		ship_visual.sprite_id == 1369 and not ship_visual.flip,
		"Cargo-ship view uses the recovered north-west sprite",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 3, "direction": 7, "state": 0,
		}), IsometricRenderer.VIEW_SMALL).sprite_id == 369,
		"Cargo-ship view selects the native small sprite",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 4, "direction": 2, "state": 0,
		}), IsometricRenderer.VIEW_MEDIUM).sprite_id == 891,
		"Bulldozer view selects the native medium direction sprite",
	)
	var sail_visual := IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
		"type": 9, "direction": 2, "state": 0,
	}))
	_check(
		sail_visual.sprite_id == 1381 and sail_visual.flip,
		"Sailboat view uses the recovered cardinal offset and mirror",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 9, "direction": 2, "state": 1,
		})).sprite_id == 1379,
		"A distressed sailboat uses the Nessie sprite",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 6, "direction": 2, "state": 0,
		})).sprite_id == 1389,
		"Explosion frame two uses the third recovered sprite",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 6, "direction": 2, "state": 0,
		}), IsometricRenderer.VIEW_MEDIUM).sprite_id == 889,
		"Explosion view selects the native medium frame",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 6, "direction": 2, "state": 0,
		}), IsometricRenderer.VIEW_SMALL) == null,
		"Explosion stays hidden below its recovered minimum view",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 2, "direction": 2, "state": 0,
		}), IsometricRenderer.VIEW_MEDIUM) == null,
		"Helicopter stays hidden below its recovered minimum view",
	)
	_check(
		IsometricRenderer.moving_thing_sprite(ThingRecord.from_fields({
			"type": 10, "direction": 0, "state": 0,
		})) == null,
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
	_check(starter.set_building_id(64, 64, Tiles.EMPTY), "Moving overlay fixture clears its tile")
	_check(starter.set_tile_flag(64, 64, 0x04, false), "Moving overlay fixture uses dry land")
	var plane_entry := large.find_sprite(plane_visual.sprite_id)
	var plane_commands_visual := IsometricMovingVisuals.Visual.new()
	plane_commands_visual.sprite_id = plane_visual.sprite_id
	plane_commands_visual.flip = plane_visual.flip
	plane_commands_visual.type = 1
	plane_commands_visual.x = 64
	plane_commands_visual.y = 64
	plane_commands_visual.z = 2
	plane_commands_visual.px = 8
	plane_commands_visual.py = 8
	plane_commands_visual.train = false
	plane_commands_visual.tornado = false
	plane_commands_visual.monster = false
	var plane_commands := IsometricRenderer.moving_thing_draw_commands_for_visual(
		starter, large, plane_commands_visual, IsometricRenderer.view_configuration(IsometricRenderer.VIEW_LARGE)
	)
	var expected_plane_position := Vector2i(
		2096 - int(plane_entry.width / 2), 1545 - plane_entry.height
	)
	_check(
		plane_commands.size() == 2
		and plane_commands[0].shadow
		and plane_commands[0].position == expected_plane_position
		and not plane_commands[1].shadow
		and plane_commands[1].position == expected_plane_position,
		"Moving overlay commands use the recovered baseline and shadow positions",
	)
	var moving_fixture := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	moving_fixture.fill(Color.WHITE)
	var occluder_fixture := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	occluder_fixture.fill(Color.TRANSPARENT)
	occluder_fixture.set_pixel(1, 1, Color.WHITE)
	var occluded := IsometricRenderer.occlude_dynamic_with_mask(
		moving_fixture, occluder_fixture, Vector2i(1, 1)
	)
	_check(
		occluded.occluded_pixels == 1
		and occluded.image.get_pixel(1, 1).a == 0.0,
		"Dynamic occlusion hides a pixel painted by a later map sprite",
	)
	var unobscured := IsometricRenderer.occlude_dynamic_with_mask(
		moving_fixture, null, Vector2i(1, 1)
	)
	_check(
		unobscured.occluded_pixels == 0 and unobscured.image == moving_fixture,
		"Dynamic occlusion keeps pixels without a later map sprite",
	)
	var index_fixture := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	index_fixture.fill(Color8(0xa1, 0xa1, 0xa1, 255))
	index_fixture.set_pixel(2, 2, Color8(0, 0, 0, 255))
	var wire_occluded := IsometricRenderer.occlude_dynamic_with_mask(
		moving_fixture, null, Vector2i(1, 1), index_fixture,
		PackedInt32Array([0x00, 0x2a])
	)
	_check(
		wire_occluded.occluded_pixels == 1
		and wire_occluded.image.get_pixel(1, 1).a == 0.0,
		"Same-tile wire masking keeps rail crossover cables in front",
	)
	var static_occluders := IsometricRenderer.static_occlusion_commands(starter, large)
	_check(
		static_occluders.size() >= CityState.TILE_COUNT
		and int(static_occluders[0].depth_order) <= int(static_occluders[-1].depth_order),
		"Static occlusion commands keep the isometric map order",
	)
	var occlusion_grid := IsometricRenderer.build_occlusion_grid(static_occluders, 1)
	var occlusion_target_index := int(static_occluders.size() / 2)
	var occlusion_target: CityStaticCommand = static_occluders[occlusion_target_index]
	var occlusion_target_bounds := Rect2i(
		Vector2i(occlusion_target.position), Vector2i(occlusion_target.size)
	)
	var occlusion_candidates := IsometricRenderer.occlusion_candidate_indices(
		occlusion_grid, occlusion_target_bounds
	)
	var occlusion_candidates_complete := true

	for occluder_index in static_occluders.size():
		var candidate: CityStaticCommand = static_occluders[occluder_index]
		var candidate_bounds := Rect2i(
			Vector2i(candidate.position), Vector2i(candidate.size)
		)

		if (
			occlusion_target_bounds.intersects(candidate_bounds)
			and not occlusion_candidates.has(occluder_index)
		):
			occlusion_candidates_complete = false
			break

	_check(
		occlusion_candidates_complete
		and occlusion_candidates.has(occlusion_target_index)
		and occlusion_candidates.size() < static_occluders.size(),
		"The occlusion grid keeps all local overlaps and rejects distant sprites",
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
		IsometricRenderer.static_visual_signature(starter) == static_signature,
		"A dynamic special marker does not invalidate the static city image",
	)
	var signature_flag_index := starter.index_of(64, 64)
	var original_signature_flags := starter.tile_flags[signature_flag_index]
	starter.set_tile_flag(64, 64, 0x08, (starter.tile_flags[signature_flag_index] & 0x08) == 0)
	_check(
		IsometricRenderer.static_visual_signature(starter) == static_signature,
		"A simulation-only tile flag does not invalidate the static city image",
	)
	var underground_signature := UndergroundView.visual_signature(
		starter, IsometricRenderer.VIEW_LARGE
	)
	starter.set_tile_flag(64, 64, 0x08, (starter.tile_flags[signature_flag_index] & 0x08) == 0)
	_check(
		UndergroundView.visual_signature(starter, IsometricRenderer.VIEW_LARGE)
		== underground_signature,
		"A simulation-only tile flag does not invalidate the underground image",
	)
	starter.set_tile_flag(64, 64, 0x10, (starter.tile_flags[signature_flag_index] & 0x10) == 0)
	_check(
		UndergroundView.visual_signature(starter, IsometricRenderer.VIEW_LARGE)
		!= underground_signature,
		"A water-network tile flag invalidates the underground image",
	)
	starter.set_tile_flag(64, 64, 0xff, false)
	starter.set_tile_flag(64, 64, original_signature_flags, true)
	starter.set_tile_flag(64, 64, 0x04, (starter.tile_flags[signature_flag_index] & 0x04) == 0)
	_check(
		IsometricRenderer.static_visual_signature(starter) != static_signature,
		"A visible water tile flag invalidates the static city image",
	)
	starter.set_tile_flag(64, 64, 0xff, false)
	starter.set_tile_flag(64, 64, original_signature_flags, true)
	var dynamic_specials := IsometricRenderer.dynamic_draw_commands(
		starter, large, IsometricRenderer.VIEW_LARGE, 0
	)
	var found_dynamic_special := false

	for command in dynamic_specials:
		if int(command.overlay) == 0xfb:
			found_dynamic_special = true
			break

	_check(found_dynamic_special, "The dynamic city layer draws a special map marker")
	_check(starter.set_text_overlay_id(64, 64, 0), "Static-signature fixture clears its marker")

	for expected in [Vector2i.ZERO, Vector2i(24, 93), Vector2i(64, 64), Vector2i(127, 127)]:
		var polygon := IsometricRenderer.tile_polygon(starter, expected.x, expected.y)
		var center := (polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.25
		_check(
			IsometricRenderer.screen_to_tile(starter, center) == expected,
			"Isometric screen lookup finds tile %s" % expected,
		)

	var surface_city := CityModel.from_document(starter.document.duplicate_document())
	var surface_point := Vector2i(64, 64)
	_check(
		surface_city.set_terrain_id(surface_point.x, surface_point.y, 0x09),
		"Selection surface fixture installs a one-corner slope",
	)
	var flat_polygon := IsometricRenderer.tile_polygon(
		surface_city, surface_point.x, surface_point.y
	)
	var slope_polygon := IsometricRenderer.terrain_surface_polygon(
		surface_city, surface_point.x, surface_point.y
	)
	_check(
		slope_polygon[0] == flat_polygon[0] + Vector2(0, -12)
		and slope_polygon[1] == flat_polygon[1]
		and slope_polygon[2] == flat_polygon[2]
		and slope_polygon[3] == flat_polygon[3],
		"Selection surface follows the raised corner of a terrain slope",
	)
	_check(
		surface_city.set_terrain_id(surface_point.x, surface_point.y, 0x0d),
		"Selection surface fixture installs a raised flat shape",
	)
	var raised_polygon := IsometricRenderer.terrain_surface_polygon(
		surface_city, surface_point.x, surface_point.y
	)
	var raised_surface_matches := true

	for corner in 4:
		if raised_polygon[corner] != flat_polygon[corner] + Vector2(0, -12):
			raised_surface_matches = false
			break

	_check(
		raised_surface_matches,
		"Selection surface follows all corners of a raised flat terrain shape",
	)
	var capeques := CityModel.from_document(
		_load_fixture(reference_root.path_join("CITIES/CAPEQUES.SC2"))
	)
	var capeques_dynamic := IsometricRenderer.dynamic_draw_commands(
		capeques, large, IsometricRenderer.VIEW_LARGE, 0
	)
	var capeques_dynamic_moving: Array[CityDynamicCommand] = []

	for command in capeques_dynamic:
		if command.overlay < 0:
			capeques_dynamic_moving.append(command)

	_check(
		_dynamic_command_values(capeques_dynamic_moving) == _dynamic_command_values(IsometricDynamicCommands.moving_thing_draw_commands(
			capeques, large, IsometricRenderer.VIEW_LARGE, 0
		)),
		"Indexed dynamic lookup preserves Capeques moving-object draw order",
	)

	for expected in [
		Vector2i(0, 0), Vector2i(18, 44), Vector2i(47, 93),
		Vector2i(64, 64), Vector2i(96, 31), Vector2i(127, 127),
	]:
		var polygon := IsometricRenderer.tile_polygon(capeques, expected.x, expected.y)

		for offset in [Vector2.ZERO, Vector2(5, 2), Vector2(-5, -2)]:
			var screen_point: Vector2 = (
				(polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.25 + offset
			)
			_check(
				IsometricRenderer.screen_to_tile(capeques, screen_point)
				== _brute_force_screen_to_tile(capeques, screen_point),
				"Fast isometric lookup matches the full Capeques scan at %s" % screen_point,
			)

	var map_control := MapControl.new()
	map_control.city = starter
	_check(map_control.zoom_percent() == 100, "City view starts at native large-sprite scale")
	_check(map_control.zoom_in(), "City view accepts a fixed zoom-in step")
	_check(map_control.zoom_percent() == 200, "City view zoom-in doubles source pixels")
	_check(map_control.zoom_in() and map_control.zoom_percent() == 300,
		"City view supports the intermediate 300 percent zoom")
	_check(map_control.zoom_in() and map_control.zoom_percent() == 400,
		"City view supports the additional 400 percent closer zoom")
	_check(not map_control.zoom_in(), "City view rejects zoom above the largest fixed level")
	_check(map_control.zoom_out() and map_control.zoom_percent() == 300,
		"City view zoom-out restores the 300 percent level")
	_check(map_control.zoom_out() and map_control.zoom_percent() == 200,
		"City view zoom-out restores the 200 percent level")
	_check(map_control.zoom_out(), "City view accepts a fixed zoom-out step")
	_check(map_control.zoom_percent() == 100, "City view zoom-out restores native scale")
	_check(
		map_control.camera.wheel_zoom(1, Vector2.INF, 1000)
		and map_control.zoom_percent() == 200,
		"Mouse wheel accepts one zoom level at the start of its debounce interval",
	)
	_check(
		not map_control.camera.wheel_zoom(-1, Vector2.INF, 1249)
		and map_control.zoom_percent() == 200,
		"Mouse wheel rejects another zoom level before 250 milliseconds",
	)
	_check(
		not map_control.camera.wheel_zoom(1, Vector2.INF, 1450)
		and map_control.zoom_percent() == 200,
		"Mouse wheel events in one continuing gesture extend the debounce interval",
	)
	_check(
		not map_control.camera.wheel_zoom(-1, Vector2.INF, 1499)
		and map_control.zoom_percent() == 200,
		"Mouse wheel extends the interval up to 500 milliseconds after a zoom",
	)
	_check(
		map_control.camera.wheel_zoom(-1, Vector2.INF, 1500)
		and map_control.zoom_percent() == 100,
		"A continuing gesture changes the next level 500 milliseconds after a zoom",
	)
	_check(
		not map_control.camera.wheel_zoom(1, Vector2.INF, 1749)
		and map_control.zoom_percent() == 100,
		"Mouse wheel rejects a level in the next 250 milliseconds",
	)
	_check(
		map_control.camera.wheel_zoom(1, Vector2.INF, 1999)
		and map_control.zoom_percent() == 200,
		"Mouse wheel accepts the next level after a 250 millisecond pause",
	)
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
	var scroll_control := MapControl.new()
	scroll_control.size = Vector2(400, 300)
	var scroll_image := Image.create_empty(1000, 800, false, Image.FORMAT_RGBA8)
	scroll_control.set_city_view(starter, CityMapSource.whole(ImageTexture.create_from_image(scroll_image)))
	var initial_scroll := scroll_control.camera.scroll_state()
	_check(
		initial_scroll.content == Vector2(1960, 800)
		and initial_scroll.page == Vector2(400, 300)
		and initial_scroll.value == Vector2(780, 250),
		"City scroll state includes horizontal padding, visible page, and centered offsets",
	)
	_check(
		scroll_control.camera.set_scroll_value(0, 600)
		and scroll_control.camera.set_scroll_value(1, 500)
		and scroll_control.source_center == Vector2(320, 650)
		and scroll_control.camera.scroll_state().value == Vector2(600, 500),
		"City scroll values move the source center on both axes",
	)
	_check(
		scroll_control.camera.set_scroll_value(0, 9999)
		and scroll_control.camera.scroll_state().value.x == 1560
		and not scroll_control.camera.set_scroll_value(2, 0),
		"City scroll values clamp to the last visible page and reject an invalid axis",
	)
	scroll_control.size = Vector2(2200, 900)
	scroll_control.camera._on_resized()
	var fitted_scroll := scroll_control.camera.scroll_state()
	_check(
		fitted_scroll.page == Vector2(1960, 800)
		and fitted_scroll.value == Vector2.ZERO
		and scroll_control.source_center == Vector2(500, 400),
		"A viewport larger than the city centers the texture and fills each scroll page",
	)
	scroll_control.free()
	var small_sign := CityMapSigns.sign_layout(
		Vector2(100, 80), 40.0, IsometricRenderer.VIEW_SMALL
	)
	var medium_sign := CityMapSigns.sign_layout(
		Vector2(100, 80), 40.0, IsometricRenderer.VIEW_MEDIUM
	)
	var large_sign := CityMapSigns.sign_layout(
		Vector2(100, 80), 40.0, IsometricRenderer.VIEW_LARGE
	)
	var doubled_sign := CityMapSigns.sign_layout(
		Vector2(200, 160), 80.0, IsometricRenderer.VIEW_LARGE, 2.0
	)
	_check(
		small_sign.panel == Rect2(72, 43, 56, 17)
		and small_sign.post == Rect2(98, 60, 4, 20),
		"Small-view sign uses the recovered panel and post geometry",
	)
	_check(
		medium_sign.panel == Rect2(72, 26, 56, 19)
		and medium_sign.post == Rect2(98, 45, 4, 35),
		"Medium-view sign uses the recovered panel and post geometry",
	)
	_check(
		large_sign.panel == Rect2(72, 9, 56, 21)
		and large_sign.post == Rect2(98, 30, 4, 50),
		"Large-view sign uses the recovered panel and post geometry",
	)
	_check(
		doubled_sign.panel == Rect2(144, 18, 112, 42)
		and doubled_sign.post == Rect2(196, 60, 8, 100),
		"Extra-large sign doubles the native large-view geometry",
	)
	_check(
		CityMapSigns.sign_view_index(0.25) == IsometricRenderer.VIEW_SMALL
		and CityMapSigns.sign_view_index(0.5) == IsometricRenderer.VIEW_MEDIUM
		and CityMapSigns.sign_view_index(1.0) == IsometricRenderer.VIEW_LARGE
		and CityMapSigns.sign_view_index(2.0) == IsometricRenderer.VIEW_LARGE
		and CityMapSigns.sign_view_index(4.0) == IsometricRenderer.VIEW_LARGE
		and CityMapSigns.sign_display_multiplier(2.0) == 2.0
		and CityMapSigns.sign_display_multiplier(4.0) == 4.0,
		"Sign view selection follows all six city zoom levels",
	)
	var sign_city := CityModel.from_document(starter.document.duplicate_document())
	var sign_result := Signs.set_sign(sign_city, center_tile, "Depth Test")
	_check(sign_result.ok, "Sign bounds fixture creates a user sign")
	map_control.city = sign_city

	for zoom_fixture in [
		[0.25, 148], [0.5, 108], [1.0, 71], [2.0, 71], [3.0, 71], [4.0, 71],
	]:
		map_control.zoom_factor = zoom_fixture[0]
		var sign_entries := map_control.sign_source_entries()
		_check(
			sign_entries.size() == 1
			and sign_entries[0].bounds.size.y == zoom_fixture[1]
			and sign_entries[0].draw_order == 16448,
			"Sign source bounds match zoom %.2f" % zoom_fixture[0],
		)

	var sign_cache_builds := map_control._sign_cache_build_count
	map_control.sign_source_entries()
	_check(
		map_control._sign_cache_build_count == sign_cache_builds,
		"Repeated sign drawing reuses the zoom-specific city-sign scan",
	)
	map_control.set_sign_occlusion_visuals({sign_city.index_of(64, 64): CitySignVisual.new()})
	_check(
		map_control.sign_occlusion_visuals.size() == 1,
		"Map control accepts one localized sign-occlusion layer",
	)
	map_control.set_sign_occlusion_visuals({})
	var sign_candidates: Array[CityDynamicVisual] = []

	for fixture in [
		[Vector2(100, 100), 9, false], [Vector2(100, 100), 10, false],
		[Vector2(150, 150), 12, false], [Vector2(100, 100), 13, true],
		[Vector2(105, 105), 14, false],
	]:
		var visual := CityDynamicVisual.new(null, fixture[0], Vector2(20, 20))
		visual.depth_order = fixture[1]
		visual.shadow = fixture[2]
		sign_candidates.append(visual)

	var later_sign_visuals := CityMapSigns.later_sign_occluder_visuals(
		sign_candidates, Rect2i(100, 100, 20, 20), 10
	)
	_check(
		later_sign_visuals.size() == 1
		and later_sign_visuals[0].depth_order == 14,
		"Only a later overlapping moving sprite occludes a city sign",
	)
	map_control.city = starter
	map_control.zoom_factor = 1.0
	map_control.set_signs_visible(false)
	_check(not map_control.signs_visible, "Data views can hide surface signs")
	map_control.set_signs_visible(true)
	map_control.selection_start = center_tile
	_check(map_control.is_left_drag_active(), "Map control reports an active left drag")
	map_control.selection_end = center_tile + Vector2i(2, 1)
	map_control.edit_enabled = true
	map_control.selection_mode = "rectangle"
	map_control.selection._rebuild_selection_path()
	_check(
		map_control.selection.selection_tiles().size() == 6,
		"Rectangle selection contains every tile while it grows",
	)
	map_control.city = surface_city
	map_control.selection_start = surface_point
	map_control.selection_end = surface_point + Vector2i(1, 0)
	map_control.selection._rebuild_selection_path()
	var terrain_selection_polygons := map_control.selection._selection_source_polygons()
	_check(
		terrain_selection_polygons.size() == 2
		and terrain_selection_polygons[0] == raised_polygon
		and terrain_selection_polygons[1] == IsometricRenderer.terrain_surface_polygon(
			surface_city, surface_point.x + 1, surface_point.y
		),
		"A multi-tile mouse selection follows each tile surface",
	)
	map_control.city = starter
	map_control.selection_start = center_tile
	map_control.selection_end = center_tile + Vector2i(2, 1)
	map_control.selection._rebuild_selection_path()
	map_control.selection_end = center_tile + Vector2i(1, 0)
	map_control.selection._rebuild_selection_path()
	_check(
		map_control.selection.selection_tiles() == [center_tile, center_tile + Vector2i(1, 0)],
		"Rectangle selection shrinks from its fixed start",
	)
	map_control.selection_mode = "point"
	map_control.point_footprint_area = 4
	_check(
		map_control.selection.point_preview_tiles(center_tile)
		== [
			Vector2i(63, 63), Vector2i(63, 64), Vector2i(63, 65), Vector2i(63, 66),
			Vector2i(64, 63), Vector2i(64, 64), Vector2i(64, 65), Vector2i(64, 66),
			Vector2i(65, 63), Vector2i(65, 64), Vector2i(65, 65), Vector2i(65, 66),
			Vector2i(66, 63), Vector2i(66, 64), Vector2i(66, 65), Vector2i(66, 66),
		],
		"Point preview shows the complete asymmetric four-tile building footprint",
	)
	map_control.point_footprint_area = 2
	_check(
		map_control.selection.point_preview_tiles(center_tile)
		== [center_tile, Vector2i(64, 65), Vector2i(65, 64), Vector2i(65, 65)],
		"Point preview starts a two-tile building footprint at the pointer",
	)
	map_control.set_edit_enabled(true, "path")
	map_control.selection_start = Vector2i(-1, -1)
	map_control.selection_end = Vector2i(-1, -1)
	map_control.hover_tile = center_tile
	_check(
		map_control.selection._selection_source_polygons() == [
			IsometricRenderer.terrain_surface_polygon(starter, center_tile.x, center_tile.y)
		],
		"An idle network tool highlights the exact hovered terrain tile",
	)
	map_control.highway_preview = true
	map_control.hover_tile = center_tile + Vector2i.ONE
	_check(map_control.selection._selection_source_polygons().size() == 4,
		"Highway hover highlights its snapped two-by-two section")
	map_control.highway_preview = false
	map_control.show_selection_preview = false
	_check(map_control.selection._selection_source_polygons().is_empty(),
		"Center can suppress all tile previews")
	map_control.show_selection_preview = true
	map_control.set_edit_enabled(false)
	_check(map_control.selection._selection_source_polygons().is_empty(),
		"Disabling network input clears its hover highlight")
	map_control.set_edit_enabled(true, "path")
	map_control.selection_start = center_tile
	map_control.selection_end = center_tile + Vector2i(3, 2)
	map_control.selection._rebuild_selection_path()
	var preview_path := map_control.selection.selection_tiles()
	_check(
		preview_path == [
			center_tile,
			center_tile + Vector2i(1, 0),
			center_tile + Vector2i(1, 1),
			center_tile + Vector2i(2, 1),
			center_tile + Vector2i(2, 2),
			center_tile + Vector2i(3, 2),
		],
		"Path selection follows a contiguous diagonal route",
	)
	var selection_cancel_signals := [0]
	var selection_complete_signals := [0]
	var selection_start_signals := [0]
	var selection_finish_signals := [0]
	var selection_complete_drags: Array[bool] = []
	var query_signal_points: Array[Vector2i] = []
	map_control.selection_canceled.connect(func() -> void:
		selection_cancel_signals[0] += 1
	)
	map_control.selection_completed.connect(func(
		_start: Vector2i,
		_finish: Vector2i,
		_path: Array[Vector2i],
		dragged: bool
	) -> void:
		selection_complete_signals[0] += 1
		selection_complete_drags.append(dragged)
	)
	map_control.selection_started.connect(func() -> void:
		selection_start_signals[0] += 1
	)
	map_control.selection_finished.connect(func() -> void:
		selection_finish_signals[0] += 1
	)
	map_control.query_requested.connect(func(point: Vector2i) -> void:
		query_signal_points.append(point)
	)
	map_control.edit_enabled = true
	map_control.city_source = CityMapSource.whole(ImageTexture.create_from_image(
		Image.create(1, 1, false, Image.FORMAT_RGBA8)
	))
	map_control.set_selection_price(12345, false)
	_check(
		map_control.selection.selection_price_text() == "$12,345"
		and not map_control.selection_price_affordable,
		"Map control formats an unaffordable selection price",
	)
	var cancel_event := InputEventMouseButton.new()
	cancel_event.button_index = MOUSE_BUTTON_RIGHT
	cancel_event.pressed = true
	map_control.interaction._handle_mouse_button(cancel_event)
	_check(
		selection_cancel_signals[0] == 1 and selection_finish_signals[0] == 1,
		"Mouse button 2 emits canceled and finished selection signals",
	)
	_check(
		not map_control.is_left_drag_active()
		and map_control.selection.selection_tiles().is_empty()
		and map_control.selection.selection_price_text().is_empty(),
		"Canceled selection cannot commit any preview tiles",
	)
	var release_event := InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.position = Vector2.ZERO
	map_control.interaction._handle_mouse_button(release_event)
	_check(
		selection_complete_signals[0] == 0 and selection_complete_drags.is_empty(),
		"Left-button release cannot commit a mouse-button-2 cancellation",
	)
	map_control.size = Vector2(800, 600)
	var drag_start_event := InputEventMouseButton.new()
	drag_start_event.button_index = MOUSE_BUTTON_LEFT
	drag_start_event.pressed = true
	drag_start_event.position = map_control.size * 0.5
	map_control.interaction._handle_mouse_button(drag_start_event)
	_check(
		selection_start_signals[0] == 1 and selection_finish_signals[0] == 1,
		"A valid left press emits one selection-started signal",
	)
	var drag_target := center_tile + Vector2i(2, 0)
	var drag_target_polygon := IsometricRenderer.tile_polygon(
		starter, drag_target.x, drag_target.y
	)
	var drag_motion_event := InputEventMouseMotion.new()
	drag_motion_event.position = map_control.camera._draw_offset(map_control.camera._view_scale()) + (
		drag_target_polygon[0]
		+ drag_target_polygon[1]
		+ drag_target_polygon[2]
		+ drag_target_polygon[3]
	) * 0.25 * map_control.camera._view_scale()
	map_control.interaction._handle_mouse_motion(drag_motion_event)
	_check(
		map_control.selection.selection_was_dragged()
		and map_control.selection_end == drag_target,
		"Active map selection follows local pointer motion",
	)
	var drag_release_event := InputEventMouseButton.new()
	drag_release_event.button_index = MOUSE_BUTTON_LEFT
	drag_release_event.pressed = false
	drag_release_event.position = drag_motion_event.position
	map_control.interaction._handle_mouse_button(drag_release_event)
	_check(
		selection_complete_signals[0] == 1
		and selection_complete_drags == [true]
		and selection_finish_signals[0] == 2,
		"Map selection reports its moved action and finished state",
	)
	map_control.shift_query_enabled = true
	var shift_query_event := InputEventMouseButton.new()
	shift_query_event.button_index = MOUSE_BUTTON_LEFT
	shift_query_event.pressed = true
	shift_query_event.shift_pressed = true
	shift_query_event.position = map_control.size * 0.5
	map_control.interaction._handle_mouse_button(shift_query_event)
	_check(
		query_signal_points == [center_tile],
		"Shift-click emits Query for the selected landscape tile",
	)
	_check(
		not map_control.is_left_drag_active()
		and selection_complete_signals[0] == 1,
		"Shift-click does not start or commit a landscape selection",
	)
	map_control.set_dynamic_sprites([CityDynamicVisual.new(null, Vector2(10, 20))])
	_check(map_control.dynamic_sprites.size() == 1, "Map control accepts a dynamic sprite layer")
	map_control.layers._ensure_base_layer()
	var many_dynamic_sprites: Array[CityDynamicVisual] = []

	for index in 1500:
		many_dynamic_sprites.append(CityDynamicVisual.new(null, Vector2(index, index)))

	map_control.set_dynamic_sprites(many_dynamic_sprites)
	_check(
		map_control.dynamic_sprites.size() == 1500
		and map_control.presentation.dynamic_render_node_count() == 1
		and map_control._dynamic_canvas is Node2D,
		"Map control batches 1,500 dynamic sprites in one render node",
	)
	var center_requests: Array[Vector2i] = []
	map_control.center_requested.connect(func(point: Vector2i) -> void:
		center_requests.append(point))
	var center_click := InputEventMouseButton.new()
	center_click.button_index = MOUSE_BUTTON_MIDDLE
	center_click.position = map_control.size * 0.5
	center_click.pressed = true
	map_control.interaction._handle_mouse_button(center_click)
	_check(center_requests.is_empty(), "Middle-button press waits for release before Center")
	center_click.pressed = false
	map_control.interaction._handle_mouse_button(center_click)
	_check(center_requests == [center_tile] and selection_complete_signals[0] == 1,
		"Middle click requests Center without applying the selected build tool")
	var visual_revision := map_control._dynamic_canvas.visual_revision
	var dynamic_position := map_control._dynamic_canvas.position
	var middle_press := InputEventMouseButton.new()
	middle_press.button_index = MOUSE_BUTTON_MIDDLE
	middle_press.pressed = true
	map_control.interaction._handle_mouse_button(middle_press)
	var pan_motion := InputEventMouseMotion.new()
	pan_motion.relative = Vector2(12, 8)
	pan_motion.position = Vector2(12, 8)
	pan_motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	map_control.interaction._handle_mouse_motion(pan_motion)
	_check(
		map_control.is_panning()
		and map_control._dynamic_canvas.visual_revision == visual_revision
		and map_control._dynamic_canvas.position != dynamic_position,
		"Middle-button panning moves the cached dynamic canvas without rebuilding it",
	)
	var middle_release := InputEventMouseButton.new()
	middle_release.button_index = MOUSE_BUTTON_MIDDLE
	middle_release.position = pan_motion.position
	map_control.interaction._handle_mouse_button(middle_release)
	_check(center_requests.size() == 1, "Middle drag release does not invoke Center")
	map_control.interaction._handle_mouse_button(middle_press)
	pan_motion.button_mask = 0
	map_control.interaction._handle_mouse_motion(pan_motion)
	_check(
		not map_control.is_panning(),
		"Map panning stops if the pointer no longer reports a pressed pan button",
	)
	map_control.set_dynamic_sprites([])
	_check(map_control.dynamic_sprites.is_empty(), "Map control clears its dynamic sprite layer")
	var marker_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	marker_image.fill(Color8(10, 10, 10, 255))
	var marker_texture := ImageTexture.create_from_image(marker_image)
	var batch_input: Array[CityDynamicVisual] = []

	for index in 1500:
		var visual := CityDynamicVisual.new(marker_texture, Vector2(index % 100, int(index / 100)), Vector2(4, 4))
		visual.image = marker_image
		visual.special_overlay = true
		visual.batch_cache_key = "marker:%d" % index
		batch_input.append(visual)

	var separator := CityDynamicVisual.new()
	separator.texture = marker_texture
	separator.image = marker_image
	separator.position = Vector2.ZERO
	separator.size = Vector2(4, 4)
	batch_input.insert(750, separator)
	var marker_batch_cache: Dictionary[String, CityDynamicVisual] = {}
	var batches := DynamicSpriteCanvas.batch_special_visuals(
		batch_input, marker_batch_cache
	)
	_check(
		batches.size() < 10
		and batches[3] == separator
		and batches[0].special_batch,
		"Dynamic marker batching keeps moving-object order and reduces 1,500 markers",
	)
	var cached_batches := DynamicSpriteCanvas.batch_special_visuals(
		batch_input, marker_batch_cache
	)
	_check(
		not marker_batch_cache.is_empty()
		and cached_batches[0].texture == batches[0].texture,
		"Dynamic marker batching reuses unchanged batch textures",
	)
	map_control.free()
	var underground_city := CityModel.from_document(starter.document.duplicate_document())
	_check(
		UndergroundView.terrain_wireframe_offset(0x00) == 0x131
		and UndergroundView.terrain_wireframe_offset(0x0e) == 0x13e
		and UndergroundView.terrain_wireframe_offset(0x10) == 0x131
		and UndergroundView.terrain_wireframe_offset(0x2e) == 0x13e
		and UndergroundView.terrain_wireframe_offset(0x45) == 0x131,
		"Underground terrain uses the recovered wireframe lookup table",
	)

	for fixture in [
		[Vector2i(20, 20), 0x01, 1319],
		[Vector2i(21, 20), 0x0f, 1333],
		[Vector2i(22, 20), 0x10, 1334],
		[Vector2i(23, 20), 0x1e, 1348],
		[Vector2i(24, 20), 0x1f, 1349],
		[Vector2i(25, 20), 0x20, 1350],
		[Vector2i(26, 20), 0x22, 1352],
		[Vector2i(27, 20), 0x23, 1353],
	]:
		var point: Vector2i = fixture[0]
		_check(
			underground_city.set_underground_id(point.x, point.y, fixture[1]),
			"Underground view fixture stores tile 0x%02X" % fixture[1],
		)
		_check(
			UndergroundView.tile_sprite_ids(underground_city, point.x, point.y)[0]
			== fixture[2],
			"Underground tile 0x%02X selects native sprite %d" % [fixture[1], fixture[2]],
		)

	var wet_pipe := Vector2i(22, 20)
	_check(
		underground_city.set_tile_flag(wet_pipe.x, wet_pipe.y, 0x20, true)
		and underground_city.set_tile_flag(wet_pipe.x, wet_pipe.y, 0x10, true),
		"Underground fixture marks a pipe as active and watered",
	)
	_check(
		UndergroundView.tile_sprite_ids(underground_city, wet_pipe.x, wet_pipe.y)[0]
		== 1450,
		"Watered pipe selects the recovered blue native sprite",
	)
	var piped_subway := Vector2i(20, 20)
	_check(
		underground_city.set_tile_flag(piped_subway.x, piped_subway.y, 0x20, true),
		"Underground fixture marks the subway tile as piped",
	)
	_check(
		UndergroundView.tile_sprite_ids(
			underground_city, piped_subway.x, piped_subway.y
		) == PackedInt32Array([1319, 1351]),
		"A piped subway adds the recovered underground service overlay",
	)
	_check(
		UndergroundView.tile_sprite_ids(
			underground_city, wet_pipe.x, wet_pipe.y,
			IsometricRenderer.VIEW_LARGE, true, true, false
		) == PackedInt32Array([1305]),
		"Hidden water mains leave the terrain wireframe visible",
	)
	_check(
		UndergroundView.tile_sprite_ids(
			underground_city, 24, 20, IsometricRenderer.VIEW_LARGE, true, true, false
		) == PackedInt32Array([1319]),
		"Hidden water mains replace the first pipe-subway crossover with subway LR",
	)
	_check(
		UndergroundView.tile_sprite_ids(
			underground_city, 25, 20, IsometricRenderer.VIEW_LARGE, true, true, false
		) == PackedInt32Array([1320]),
		"Hidden water mains replace the second pipe-subway crossover with subway TB",
	)
	_check(
		UndergroundView.tile_sprite_ids(
			underground_city, piped_subway.x, piped_subway.y,
			IsometricRenderer.VIEW_LARGE, false
		) == PackedInt32Array([1319]),
		"Hidden pipes keep a subway and remove its pipe overlay",
	)
	_check(
		underground_city.set_building_id(20, 20, Tiles.LLAMA_DOME),
		"Underground fixture adds a surface building",
	)
	_check(
		UndergroundView.tile_sprite_ids(underground_city, 20, 20)
		== PackedInt32Array([1319, 1351]),
		"Surface buildings do not change underground drawing",
	)
	var underground_errors := UndergroundView.validate_assets(
		underground_city, large, IsometricRenderer.VIEW_LARGE
	)
	_check(
		underground_errors.is_empty(),
		"Underground view has every required large sprite: %s" % underground_errors,
	)
	var underground_image := UndergroundView.create_image(
		underground_city,
		Palette.index_encoding(),
		small_medium,
		IsometricRenderer.VIEW_SMALL,
		true,
	)
	_check(underground_image.ok, "Underground view renders: %s" % underground_image.error)

	if underground_image.ok:
		_check(
			underground_image.image.get_pixel(0, 0).to_rgba32()
			== Color8(255, 255, 255, 255).to_rgba32(),
			"Underground view uses the recovered white background",
		)
		_check(
			underground_image.image.get_format() == Image.FORMAT_L8,
			"Opaque indexed underground rendering uses one byte per pixel",
		)

	var filtered_source := CityModel.from_document(starter.document.duplicate_document())
	_check(filtered_source.set_building_id(10, 10, Tiles.SMALL_OFFICE_BUILDING_1X1), "View filter adds a building")
	_check(filtered_source.set_building_id(11, 10, Tiles.RAIL_SLOPE_1), "View filter adds a network")
	_check(filtered_source.set_building_id(12, 10, Tiles.TREES_1), "View filter adds a tree")
	_check(filtered_source.set_zone_id(13, 10, 2), "View filter adds a zone")
	_check(filtered_source.set_terrain_id(14, 10, 0x10), "View filter adds water terrain")
	_check(filtered_source.set_tile_flag(14, 10, 0x04, true), "View filter marks water")
	_check(filtered_source.set_terrain_id(15, 10, 0x2d), "View filter adds shoreline terrain")
	_check(filtered_source.set_tile_flag(15, 10, 0x04, true), "View filter marks shoreline water")
	_check(filtered_source.set_land_altitude(15, 10, 2), "View filter sets shoreline land altitude")
	_check(filtered_source.set_water_altitude(15, 10, 7), "View filter sets shoreline water altitude")
	_check(filtered_source.set_building_id(15, 10, Tiles.MARINA), "View filter adds a partial-water structure")
	var filtered := ViewFilter.surface_copy(filtered_source, {
		"buildings": false,
		"networks": false,
		"water": false,
		"trees": false,
		"zones": false,
	})
	_check(
		filtered.building_id(10, 10) == 0
		and filtered.building_id(11, 10) == 0
		and filtered.building_id(12, 10) == 0
		and filtered.zone_id(13, 10) == 0
		and filtered.terrain_id(14, 10) == 0
		and filtered.terrain_id(15, 10) == 0x0d
		and not filtered.is_water(14, 10),
		"Surface visibility filters each requested display layer",
	)
	_check(
		filtered.land_altitude(15, 10) == 2
		and filtered.object_altitude(15, 10) == 7,
		"Hidden shoreline water draws dry slope terrain but keeps structure altitude",
	)
	_check(
		filtered_source.building_id(10, 10) == 0x80
		and filtered_source.building_id(11, 10) == 0x2e
		and filtered_source.building_id(12, 10) == 0x06
		and filtered_source.zone_id(13, 10) == 2
		and filtered_source.terrain_id(14, 10) == 0x10
		and filtered_source.is_water(14, 10),
		"Surface visibility filtering does not change saved city state",
	)
	_check(starter.set_building_id(64, 64, Tiles.RAIL_SLOPE_1), "Train drawing fixture adds a rail tile")
	var straight_train := IsometricRenderer.train_sprite(starter, 64, 64, ThingRecord.from_fields({
		"type": 10, "dx": 0,
	}))
	_check(
		straight_train.sprite_id == 1377 and straight_train.flip,
		"Train view maps a rail tile to its recovered sprite variant",
	)
	var train_entry := large.find_sprite(straight_train.sprite_id)
	var train_commands_visual := IsometricMovingVisuals.Visual.new()
	train_commands_visual.sprite_id = straight_train.sprite_id
	train_commands_visual.flip = straight_train.flip
	train_commands_visual.type = 10
	train_commands_visual.x = 64
	train_commands_visual.y = 64
	train_commands_visual.z = 0
	train_commands_visual.px = 0
	train_commands_visual.py = 0
	train_commands_visual.train = true
	train_commands_visual.screen_x = straight_train.screen_x
	train_commands_visual.screen_y = straight_train.screen_y
	train_commands_visual.elevation = straight_train.elevation
	train_commands_visual.tornado = false
	train_commands_visual.monster = false
	var train_commands := IsometricRenderer.moving_thing_draw_commands_for_visual(
		starter, large, train_commands_visual, IsometricRenderer.view_configuration(IsometricRenderer.VIEW_LARGE)
	)
	_check(
		train_commands.size() == 1
		and train_commands[0].position == Vector2i(
			2096 - int(train_entry.width / 2), 1553 - train_entry.height
		),
		"Surface train uses the same recovered baseline as its rail tile",
	)
	_check(starter.set_building_id(64, 64, Tiles.RAIL_POWER_CROSSING_2), "Train wire fixture adds a rail-power crossover")
	var crossing_train := IsometricRenderer.train_sprite(starter, 64, 64, ThingRecord.from_fields({
		"type": 10, "dx": 0,
	}))
	var crossing_commands_visual := IsometricMovingVisuals.Visual.new()
	crossing_commands_visual.sprite_id = crossing_train.sprite_id
	crossing_commands_visual.flip = crossing_train.flip
	crossing_commands_visual.type = 10
	crossing_commands_visual.x = 64
	crossing_commands_visual.y = 64
	crossing_commands_visual.z = 0
	crossing_commands_visual.px = 0
	crossing_commands_visual.py = 0
	crossing_commands_visual.train = true
	crossing_commands_visual.screen_x = crossing_train.screen_x
	crossing_commands_visual.screen_y = crossing_train.screen_y
	crossing_commands_visual.elevation = crossing_train.elevation
	crossing_commands_visual.tornado = false
	crossing_commands_visual.monster = false
	var crossing_commands := IsometricRenderer.moving_thing_draw_commands_for_visual(
		starter, large, crossing_commands_visual, IsometricRenderer.view_configuration(IsometricRenderer.VIEW_LARGE)
	)
	_check(
		crossing_commands.size() == 1
		and crossing_commands[0].train
		and crossing_commands[0].same_tile_foreground_indices.is_empty(),
		"Train commands request the dedicated power-line foreground mask",
	)
	_check(
		IsometricStaticOcclusion.train_power_foreground_reference_sprite_id(0x0e) == -1
		and IsometricStaticOcclusion.train_power_foreground_reference_sprite_id(0x48) == 1045
		and IsometricStaticOcclusion.train_power_foreground_reference_sprite_id(0x2d) == 0,
		"Power lines and crossovers select their train foreground source",
	)
	var crossing_foreground_command: CityStaticCommand
	var crossing_depth := (64 + 64) * CityState.MAP_SIZE + 64

	for command in IsometricRenderer.static_occlusion_commands(starter, large):
		if int(command.sprite_id) == 1072 and int(command.depth_order) == crossing_depth:
			crossing_foreground_command = command
			break

	_check(
		crossing_foreground_command != null
		and crossing_foreground_command.train_foreground_reference_sprite_id
			== 1045,
		"Static rail-power crossover commands retain the rail-only reference",
	)
	var index_palette := Palette.index_encoding()
	var crossing_terrain: Image = large.find_sprite(1256).create_image(index_palette).image
	var crossing_surface: Image = large.find_sprite(1072).create_image(index_palette).image
	var crossing_rail: Image = large.find_sprite(1045).create_image(index_palette).image
	var crossing_foreground := IsometricRenderer.foreground_difference_mask(
		crossing_surface, crossing_rail
	)
	var crossing_train_image: Image = (
		large.find_sprite(crossing_train.sprite_id).create_image(index_palette).image.duplicate()
	)

	if crossing_train.flip:
		crossing_train_image.flip_x()

	var crossing_height := maxi(
		crossing_terrain.get_height(),
		maxi(crossing_surface.get_height(), crossing_train_image.get_height()),
	)
	var crossing_fixture := Image.create(
		32, crossing_height, false, Image.FORMAT_RGBA8
	)
	crossing_fixture.fill(Color.TRANSPARENT)
	crossing_fixture.blend_rect(
		crossing_terrain,
		Rect2i(Vector2i.ZERO, crossing_terrain.get_size()),
		Vector2i(0, crossing_height - crossing_terrain.get_height()),
	)
	crossing_fixture.blend_rect(
		crossing_surface,
		Rect2i(Vector2i.ZERO, crossing_surface.get_size()),
		Vector2i(0, crossing_height - crossing_surface.get_height()),
	)
	var crossing_train_position := Vector2i(
		16 + crossing_train.screen_x - int(crossing_train_image.get_width() / 2),
		crossing_height + crossing_train.screen_y - crossing_train_image.get_height(),
	)
	var crossing_surface_position := Vector2i(
		0, crossing_height - crossing_surface.get_height()
	)
	var crossing_train_foreground := Image.create(
		crossing_train_image.get_width(), crossing_train_image.get_height(),
		false, Image.FORMAT_RGBA8
	)
	crossing_train_foreground.fill(Color.TRANSPARENT)
	crossing_train_foreground.blend_rect(
		crossing_foreground,
		Rect2i(Vector2i.ZERO, crossing_foreground.get_size()),
		crossing_surface_position - crossing_train_position,
	)
	var actual_crossing_mask := IsometricRenderer.occlude_dynamic_with_mask(
		crossing_train_image,
		crossing_train_foreground,
		crossing_train_position,
	)
	var crossing_composite: Image = crossing_fixture.duplicate()
	crossing_composite.blend_rect(
		actual_crossing_mask.image,
		Rect2i(Vector2i.ZERO, actual_crossing_mask.image.get_size()),
		crossing_train_position,
	)
	var foreground_overlap := 0
	var foreground_preserved := 0
	var rail_deck_replaced := 0

	for train_y in crossing_train_image.get_height():
		for train_x in crossing_train_image.get_width():
			if crossing_train_image.get_pixel(train_x, train_y).a == 0.0:
				continue

			var map_point := crossing_train_position + Vector2i(train_x, train_y)

			if not Rect2i(Vector2i.ZERO, crossing_fixture.get_size()).has_point(map_point):
				continue

			var static_index := roundi(crossing_fixture.get_pixelv(map_point).r * 255.0)

			if crossing_train_foreground.get_pixel(train_x, train_y).a > 0.0:
				foreground_overlap += 1

				if (
					crossing_composite.get_pixelv(map_point).to_rgba32()
					== crossing_fixture.get_pixelv(map_point).to_rgba32()
				):
					foreground_preserved += 1
			elif (
				static_index in [0xa0, 0x7c]
				and crossing_composite.get_pixelv(map_point).to_rgba32()
				!= crossing_fixture.get_pixelv(map_point).to_rgba32()
			):
				rail_deck_replaced += 1

	_check(
		foreground_overlap > 0
		and foreground_preserved == foreground_overlap
		and rail_deck_replaced > 0
		and actual_crossing_mask.occluded_pixels == foreground_overlap,
		"The train draws over the rail deck but stays behind the full power-line foreground",
	)
	_check(starter.set_building_id(64, 64, Tiles.RAIL_JUNCTION_1), "Train drawing fixture adds a turn tile")
	var turning_train := IsometricRenderer.train_sprite(starter, 64, 64, ThingRecord.from_fields({
		"type": 11, "dx": 1,
	}))
	_check(
		turning_train.variant == 17 and turning_train.sprite_id == 1375,
		"Train view uses the saved transition on a turn tile",
	)
	_check(
		turning_train.screen_y == 6 and not turning_train.flip,
		"Train view applies the recovered turn position and mirror",
	)
	_check(starter.set_building_id(64, 64, Tiles.RAIL_BRIDGE), "Train drawing fixture adds a tunnel tile")
	_check(starter.set_tile_flag(64, 64, 0x02, true), "Train drawing fixture mirrors the tunnel")
	var tunnel_train := IsometricRenderer.train_sprite(starter, 64, 64, ThingRecord.from_fields({
		"type": 10, "dx": 0,
	}))
	_check(
		tunnel_train.variant == 1 and tunnel_train.elevation == 12,
		"Tunnel train view uses the water level, raised track, and flip flag",
	)
	var tornado_visual := IsometricRenderer.tornado_sprite(starter, 64, 64, ThingRecord.from_fields({
		"type": 15, "px": 8, "py": 8,
	}), 1)
	_check(
		tornado_visual.sprite_id == 1498
		and tornado_visual.flip
		and tornado_visual.tornado,
		"Tornado view selects a stable recovered frame and mirror",
	)
	var small_tornado := IsometricRenderer.tornado_sprite(starter, 64, 64, ThingRecord.from_fields({
		"type": 15, "px": 8, "py": 8,
	}), 1, IsometricRenderer.VIEW_SMALL)
	_check(
		small_tornado.sprite_id == 498
		and small_tornado.elevation == 0
		and small_tornado.flip,
		"Tornado view selects its native small frame and altitude scale",
	)
	_check(
		IsometricGeometry.bridge_effect_position(starter, EffectEvent.new(Vector2i(64, 64), 0, Vector2i(16, -8)), 10) == Vector2i(2096, 1518),
		"Bridge debris view uses water altitude and the recovered screen offset",
	)
	var default_effect_position := IsometricRenderer.transient_effect_position(
		starter, EffectEvent.new(Vector2i(64, 64)), 10
	)
	var raised_effect_position := IsometricRenderer.transient_effect_position(
		starter,
		EffectEvent.new(Vector2i(64, 64), 0, Vector2i.ZERO, false, 0,
			starter.water_altitude(64, 64) + 2),
		10
	)
	_check(
		raised_effect_position == default_effect_position + Vector2i(0, -24),
		"Transient effects can preserve their pre-demolition altitude",
	)
	_check(
		IsometricRenderer.effect_sprite_id(1392, IsometricRenderer.VIEW_SMALL) == 392
		and IsometricRenderer.effect_sprite_id(1392, IsometricRenderer.VIEW_MEDIUM) == 892
		and IsometricRenderer.effect_sprite_id(1392, IsometricRenderer.VIEW_LARGE) == 1392,
		"Bridge debris selects its native sprite at each zoom",
	)
	var small_debris := small_medium.find_sprite(392)
	var small_debris_height := small_debris.height if small_debris != null else -1
	var small_debris_position := IsometricGeometry.bridge_effect_position(
		starter,
		EffectEvent.new(Vector2i(64, 64), 0, Vector2i(16, -8)),
		small_debris_height,
		IsometricRenderer.VIEW_SMALL
	)
	_check(
		small_debris != null
		and small_debris_position == Vector2i(524, 382 - small_debris.height),
		"Small bridge debris scales its tile anchor and recovered offset",
	)
	var medium_debris := small_medium.find_sprite(892)
	var medium_debris_height := medium_debris.height if medium_debris != null else -1
	var medium_debris_position := IsometricGeometry.bridge_effect_position(
		starter,
		EffectEvent.new(Vector2i(64, 64), 0, Vector2i(16, -8)),
		medium_debris_height,
		IsometricRenderer.VIEW_MEDIUM
	)
	_check(
		medium_debris != null
		and medium_debris_position == Vector2i(1048, 764 - medium_debris.height),
		"Medium bridge debris scales its tile anchor and recovered offset",
	)
	var monster_layers := IsometricMovingVisuals.monster_layers(starter, 64, 64, ThingRecord.from_fields({
		"type": 5,
		"z": 10,
		"px": 8,
		"py": 8,
		"dx": 0xa5,
		"dy": 0x9b,
	}), 1)
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
	var ordinary_monster := ThingRecord.from_fields({
		"type": 5, "z": 10, "dx": 0x25, "dy": 0x1b,
	})
	for view_size in [IsometricRenderer.VIEW_SMALL, IsometricRenderer.VIEW_MEDIUM, IsometricRenderer.VIEW_LARGE]:
		var head_base: int = 490 + view_size * 500
		for phase in [0, 19, 20, 39, 40]:
			var eye_layers := IsometricMovingVisuals.monster_layers(
				starter, 64, 64, ordinary_monster, 1, view_size, phase
			)
			var expected_head := head_base + (1 if phase >= 20 and phase < 40 else 0)
			_check(
				eye_layers[6].sprite_id == expected_head
				and eye_layers[7].sprite_id == expected_head
				and not eye_layers[6].flip and eye_layers[7].flip,
				"Monster eye opens and closes at every source size without the unused DY flag",
			)
	_check(ordinary_monster.dx == 0x25 and ordinary_monster.dy == 0x1b,
		"Monster eye animation preserves saved pose bytes")
	var small_monster_layers := IsometricMovingVisuals.monster_layers(starter, 64, 64, ThingRecord.from_fields({
		"type": 5,
		"z": 10,
		"px": 8,
		"py": 8,
		"dx": 0xa5,
		"dy": 0x9b,
	}), 1, IsometricRenderer.VIEW_SMALL)
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


func _test_scurk_mif(reference_root: String) -> void:
	_test_indexed_bmp()
	_test_scurk_place_command(reference_root)
	var scurk_directory := reference_root.path_join("SCURKART")
	var mif_files := PackedStringArray()

	for filename in DirAccess.get_files_at(scurk_directory):
		if filename.get_extension().to_lower() == "mif":
			mif_files.append(filename)

	mif_files.sort()
	_check(mif_files.size() == 31, "All 31 supplied SCURK tile sets are present")

	for filename in mif_files:
		var mif_path := scurk_directory.path_join(filename)
		var tile_set := ScurkTileSet.load_path(mif_path)
		_check(tile_set.is_valid(), "%s parses: %s" % [filename, tile_set.parse_error])

		if tile_set.is_valid():
			var serialized := tile_set.to_bytes()
			_check(
				serialized.ok and serialized.bytes == FileAccess.get_file_as_bytes(mif_path),
				"%s has a byte-identical no-change write" % filename,
			)

	var original := ScurkTileSet.load_path(scurk_directory.path_join("ORIGINAL.MIF"))
	_check(original.is_valid(), "ORIGINAL.MIF parses: %s" % original.parse_error)

	if original.is_valid():
		var editable_ids := ScurkEditorControl.editable_large_sprite_ids(original)
		var grouped_ids := ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_ALL)
		var grouped_unique := {}

		for grouped_id in grouped_ids:
			grouped_unique[grouped_id] = true

		_check(
			original.piece_count == 558
			and original.shapes.size() == 558
			and original.overrides.entries.size() == 558
			and original.names.is_empty(),
			"ORIGINAL.MIF contains 558 visible SHAP records",
		)
		_check(
			editable_ids.size() == 186
			and ScurkEditorControl.view_sprite_id(editable_ids[0], ScurkEditorControl.VIEW_LARGE)
				== editable_ids[0]
			and ScurkEditorControl.view_sprite_id(editable_ids[0], ScurkEditorControl.VIEW_MEDIUM)
				== editable_ids[0] - 500
			and ScurkEditorControl.view_sprite_id(editable_ids[0], ScurkEditorControl.VIEW_SMALL)
				== editable_ids[0] - 1000,
			"SCURK editor exposes 186 objects with direct three-view sprite IDs",
		)
		_check(
			ScurkPickCopy.GROUP_NAMES.size() == 11
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_RESIDENTIAL).size() == 24
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_COMMERCIAL).size() == 28
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_INDUSTRIAL).size() == 18
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_SPECIAL).size() == 26
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_POWER).size() == 10
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_TRANSPORTATION).size() == 22
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_MISC).size() == 12
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_ANIMATING_I).size() == 15
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_ANIMATING_II).size() == 15
			and ScurkPickCopy.group_large_ids(ScurkPickCopy.GROUP_CONSTRUCTION).size() == 16
			and grouped_ids.size() == 186
			and grouped_unique.size() == 186,
			"SCURK Pick & Copy catalog contains all eleven original object groups",
		)
		var editor_palette := Palette.load_bmp(
			reference_root.path_join("BITMAPS/PAL_MSTR.BMP")
		)
		var editor_large := SpriteArchive.load_path(
			reference_root.path_join("DATA/LARGE.DAT")
		)
		var editor_small_medium := SpriteArchive.load_path(
			reference_root.path_join("DATA/SMALLMED.DAT")
		)
		var editor_special := SpriteArchive.load_path(
			reference_root.path_join("DATA/SPECIAL.DAT")
		)
		editor_small_medium = SpriteArchive.combine([
			editor_small_medium, editor_special,
		])
		var complete_editor_ids := ScurkEditorControl.editable_large_sprite_ids(
			original, editor_large
		)
		_check(
			complete_editor_ids.size() == 499
			and complete_editor_ids[0] == 1001
			and complete_editor_ids[complete_editor_ids.size() - 1] == 1499,
			"SCURK editor catalog exposes every original large sprite family",
		)
		var one_tile_mask := ScurkWorkspace.clip_mask(32)
		var four_tile_mask := ScurkWorkspace.clip_mask(128)
		_check(
			one_tile_mask.size() == 128 * 256
			and one_tile_mask[255 * 128 + 62] == 0
			and one_tile_mask[255 * 128 + 63] == 1
			and one_tile_mask[255 * 128 + 64] == 0
			and one_tile_mask[254 * 128 + 61] == 1
			and one_tile_mask[254 * 128 + 65] == 1
			and one_tile_mask[254 * 128 + 66] == 0
			and one_tile_mask[0 * 128 + 47] == 1
			and one_tile_mask[0 * 128 + 80] == 0
			and four_tile_mask[224 * 128 + 0] == 0
			and four_tile_mask[223 * 128 + 0] == 1,
			"SCURK clip mask follows the executable's bottom-up widening region",
		)
		var blank_workspace := PackedInt32Array()
		blank_workspace.resize(ScurkWorkspace.WIDTH * ScurkWorkspace.HEIGHT)
		blank_workspace.fill(-1)
		var blank_large := ScurkWorkspace.shape_from_workspace(blank_workspace, 32, 0)
		var blank_medium := ScurkWorkspace.shape_from_workspace(blank_workspace, 32, 1)
		var blank_small := ScurkWorkspace.shape_from_workspace(blank_workspace, 32, 2)
		_check(
			blank_large.ok and blank_large.width == 32 and blank_large.height == 1
			and blank_medium.ok and blank_medium.width == 16 and blank_medium.height == 1
			and blank_small.ok and blank_small.width == 8 and blank_small.height == 1,
			"SCURK Clear Object keeps each fixed base width and one transparent row",
		)
		var sample_shape := PackedInt32Array()
		sample_shape.resize(96 * 3)
		sample_shape.fill(-1)
		sample_shape[48] = 7
		sample_shape[96 + 47] = 8
		sample_shape[2 * 96 + 47] = 9
		var sample_workspace := ScurkWorkspace.from_shape(
			96, 3, sample_shape, ScurkEditorControl.VIEW_LARGE, 96
		)
		var sample_round_trip := ScurkWorkspace.shape_from_workspace(
			sample_workspace, 96, ScurkEditorControl.VIEW_LARGE
		)
		_check(
			sample_round_trip.ok
			and sample_round_trip.width == 96
			and sample_round_trip.height == 3
			and sample_round_trip.pixels == sample_shape,
			"SCURK drawing workspace preserves pixels inside the clip region",
		)
		var pick_working := ScurkTileSet.load_path(
			scurk_directory.path_join("ORIGINAL.MIF")
		)
		var pick_source := ScurkTileSet.load_path(
			scurk_directory.path_join("FUTURE.MIF")
		)
		var pick_target := ScurkPickCopy.group_large_ids(
			ScurkPickCopy.GROUP_RESIDENTIAL
		)[0]
		var pick_result := ScurkPickCopy.copy_objects(
			pick_working,
			pick_source,
			PackedInt32Array([pick_target]),
			editor_large,
			editor_small_medium
		)
		var copied_views_match := true

		for pick_view in 3:
			var pick_sprite_id := pick_target - pick_view * 500
			var source_entry := ScurkPickCopy.resolved_entry(
				pick_source, pick_sprite_id, editor_large, editor_small_medium
			)
			var working_entry := pick_working.overrides.find_sprite(pick_sprite_id)
			copied_views_match = (
				copied_views_match
				and source_entry != null
				and working_entry != null
				and source_entry.decode_indices().pixels
					== working_entry.decode_indices().pixels
			)

		_check(
			pick_result.ok
			and pick_result.object_count == 1
			and pick_result.shape_count == 3
			and copied_views_match,
			"SCURK Pick & Copy replaces all three equivalent object views",
		)
		var invalid_pick_bytes: PackedByteArray = pick_working.to_bytes().bytes
		var invalid_pick := ScurkPickCopy.copy_objects(
			pick_working,
			pick_source,
			PackedInt32Array([999]),
			editor_large,
			editor_small_medium
		)
		_check(
			not invalid_pick.ok
			and pick_working.to_bytes().bytes == invalid_pick_bytes,
			"SCURK Pick & Copy rejects an invalid object without another edit",
		)
		var scurk_editor := ScurkEditor.instantiate() as ScurkEditorControl
		scurk_editor._ready()
		scurk_editor.configure(
			editor_palette, editor_large, editor_small_medium, reference_root,
			GraphicsPack.load_root("res://../ext/graphics").scurk_graphics
		)

		# This control is built manually outside a SceneTree in this test.
		if scurk_editor.pick_copy_control.source_list == null:
			scurk_editor.pick_copy_control._ready()

		var editor_load := scurk_editor.load_path(
			scurk_directory.path_join("ORIGINAL.MIF")
		)
		_check(
			editor_load.ok
			and scurk_editor.object_list.item_count == 499
			and scurk_editor.pixel_canvas.sprite_width == ScurkWorkspace.WIDTH
			and scurk_editor.pixel_canvas.sprite_height == ScurkWorkspace.HEIGHT
			and scurk_editor.active_workspace,
			"SCURK editor loads all tile, terrain, network, and support sprites",
		)
		_check(
			scurk_editor.tool_buttons.size() == 12
			and scurk_editor.palette_panel.texture_control.patterns.size()
				== ScurkPixelEditor.TEXTURE_NAMES.size()
			and scurk_editor.brush_size_selector.item_count == 6
			and scurk_editor.revert_button != null
			and scurk_editor.revert_name_button != null
			and scurk_editor.paste_tool_button.disabled
			and scurk_editor.clipboard_action_buttons.size() == 3
			and not scurk_editor.pixel_canvas.original_textures_loaded
			and scurk_editor.pixel_canvas.texture_patterns.size() == 42
			and scurk_editor.cycle_colors_check.button_pressed
			and scurk_editor.increment_cycle_button.disabled
			and scurk_editor.import_bmp_dialog != null
			and scurk_editor.export_bmp_dialog != null
			and scurk_editor.copy_object_button != null
			and scurk_editor.paste_image_button != null
			and scurk_editor.clear_object_button != null
			and scurk_editor.clip_region_check != null
			and scurk_editor.snap_to_grid_check != null
			and scurk_editor.grid_width_selector.min_value == 1
			and scurk_editor.grid_width_selector.max_value == 65
			and scurk_editor.grid_height_selector.min_value == 1
			and scurk_editor.grid_height_selector.max_value == 65
			and scurk_editor.view_previews.size() == 3
			and scurk_editor.view_previews[0].preview_width == 128
			and scurk_editor.view_previews[0].preview_height == 256
			and scurk_editor.view_previews[1].preview_width == 64
			and scurk_editor.view_previews[1].preview_height == 128
			and scurk_editor.view_previews[2].preview_width == 32
			and scurk_editor.view_previews[2].preview_height == 64
			and scurk_editor.pixel_canvas.clear_background_pixels.size()
			== ScurkWorkspace.WIDTH * ScurkWorkspace.HEIGHT
			and scurk_editor.pixel_canvas.clip_background_pixels.size() == 4
			and scurk_editor.pick_copy_control != null,
			"SCURK editor exposes the recovered paint, clip, and brush controls",
		)
		scurk_editor.grid_width_selector.value = 8
		scurk_editor.grid_height_selector.value = 6
		scurk_editor.snap_to_grid_check.button_pressed = true
		scurk_editor._apply_grid_settings()
		_check(
			scurk_editor.pixel_canvas.grid_width == 8
			and scurk_editor.pixel_canvas.grid_height == 6
			and scurk_editor.pixel_canvas.snap_to_grid,
			"SCURK Grid Settings apply independent 1-through-65 dimensions",
		)
		scurk_editor.request_pick_copy()
		var same_source := scurk_editor.pick_copy_control.load_source_path(
			scurk_directory.path_join("ORIGINAL.MIF")
		)
		var future_source := scurk_editor.pick_copy_control.load_source_path(
			scurk_directory.path_join("FUTURE.MIF")
		)
		_check(
			scurk_editor.pick_copy_control.visible
			and not same_source.ok
			and not same_source.error.is_empty()
			and future_source.ok
			and scurk_editor.pick_copy_control.source_list.item_count == 24
			and scurk_editor.pick_copy_control.working_list.item_count == 24,
			"SCURK Pick & Copy keeps distinct source and working object sets",
		)
		scurk_editor.pick_copy_control._select_group(
			ScurkPickCopy.GROUP_COMMERCIAL
		)
		_check(
			scurk_editor.pick_copy_control.source_list.item_count == 28
			and scurk_editor.pick_copy_control.working_list.item_count == 28,
			"SCURK Pick & Copy filters both object sets by group",
		)
		var pick_editor_before: PackedByteArray = scurk_editor.tile_set.to_bytes().bytes
		var pick_editor_id := ScurkPickCopy.group_large_ids(
			ScurkPickCopy.GROUP_COMMERCIAL
		)[0]
		scurk_editor._copy_pick_objects(
			scurk_editor.pick_copy_control.source_set,
			PackedInt32Array([pick_editor_id]),
			"Test copy"
		)
		var pick_editor_views_match := true

		for pick_editor_view in 3:
			var pick_editor_sprite := pick_editor_id - pick_editor_view * 500
			var pick_editor_source_entry := ScurkPickCopy.resolved_entry(
				scurk_editor.pick_copy_control.source_set,
				pick_editor_sprite,
				editor_large,
				editor_small_medium
			)
			pick_editor_views_match = (
				pick_editor_views_match
				and pick_editor_source_entry.decode_indices().pixels
					== scurk_editor.tile_set.overrides.find_sprite(
						pick_editor_sprite
					).decode_indices().pixels
			)

		_check(
			scurk_editor.dirty
			and scurk_editor.undo_stack.size() == 1
			and pick_editor_views_match,
			"SCURK Pick & Copy is one three-view editor transaction",
		)
		scurk_editor.undo()
		_check(
			scurk_editor.tile_set.to_bytes().bytes == pick_editor_before,
			"SCURK Undo restores a Pick & Copy transaction",
		)
		scurk_editor.pick_copy_control.request_close()
		scurk_editor._set_cycle_colors(false)
		var cycle_before := scurk_editor.pixel_canvas.palette_cycle_ticks
		scurk_editor._increment_cycle()
		_check(
			not scurk_editor.increment_cycle_button.disabled
			and scurk_editor.pixel_canvas.palette_cycle_ticks
				== cycle_before + Palette.SCURK_INCREMENT_TIMER_TICKS
			and scurk_editor.pixel_canvas.display_palette_index(Palette.FAST_CYCLE_START)
				== editor_palette.scurk_animation_index_map(
					cycle_before + Palette.SCURK_INCREMENT_TIMER_TICKS
				)[Palette.FAST_CYCLE_START],
			"SCURK Increment Cycle works only while automatic cycling is off",
		)
		scurk_editor._set_cycle_colors(true)
		scurk_editor._select_tool(ScurkPixelEditor.TOOL_COPY)
		var editor_copy_press := InputEventMouseButton.new()
		editor_copy_press.button_index = MOUSE_BUTTON_LEFT
		editor_copy_press.pressed = true
		editor_copy_press.position = Vector2(1, 1)
		scurk_editor.pixel_canvas._gui_input(editor_copy_press)
		var editor_copy_release := InputEventMouseButton.new()
		editor_copy_release.button_index = MOUSE_BUTTON_LEFT
		editor_copy_release.pressed = false
		editor_copy_release.position = Vector2(17, 17)
		scurk_editor.pixel_canvas._gui_input(editor_copy_release)
		_check(
			not scurk_editor.paste_tool_button.disabled
			and not scurk_editor.clipboard_action_buttons[0].disabled,
			"SCURK Copy enables Paste and clipboard transforms",
		)
		scurk_editor._select_tool(ScurkPixelEditor.TOOL_PENCIL)
		var original_editor_bytes: PackedByteArray = scurk_editor.tile_set.to_bytes().bytes
		var edited_pixels := scurk_editor.pixel_canvas.pixels.duplicate()
		var editable_pixel := 100 * ScurkWorkspace.WIDTH + 64
		edited_pixels[editable_pixel] = (
			1 if edited_pixels[editable_pixel] != 1 else 2
		)
		scurk_editor._capture_edit_start()
		scurk_editor._commit_pixels(edited_pixels)
		var changed_editor_bytes: PackedByteArray = scurk_editor.tile_set.to_bytes().bytes
		_check(
			scurk_editor.dirty
			and changed_editor_bytes != original_editor_bytes
			and scurk_editor.undo_stack.size() == 1,
			"SCURK pixel edits update the MIF document and enter undo history",
		)
		scurk_editor.undo()
		_check(
			not scurk_editor.dirty
			and scurk_editor.tile_set.to_bytes().bytes == original_editor_bytes,
			"SCURK Undo restores the byte-identical loaded MIF document",
		)
		scurk_editor.redo()
		_check(
			scurk_editor.dirty
			and scurk_editor.tile_set.to_bytes().bytes == changed_editor_bytes,
			"SCURK Redo restores the edited MIF document",
		)
		scurk_editor.undo()
		var object_edit_pixels := scurk_editor.pixel_canvas.pixels.duplicate()
		object_edit_pixels[editable_pixel] = (
			3 if object_edit_pixels[editable_pixel] != 3 else 4
		)
		scurk_editor._capture_edit_start()
		scurk_editor._commit_pixels(object_edit_pixels)
		var object_edit_bytes: PackedByteArray = scurk_editor.tile_set.to_bytes().bytes
		scurk_editor.revert_object()
		_check(
			scurk_editor.tile_set.to_bytes().bytes == original_editor_bytes,
			"SCURK Revert restores the exact object-selection document state",
		)
		scurk_editor.undo()
		_check(
			scurk_editor.tile_set.to_bytes().bytes == object_edit_bytes,
			"SCURK Revert enters exact-byte Undo history",
		)
		scurk_editor.redo()
		var current_tile_id := ScurkEditorControl.object_tile_id(scurk_editor.current_large_id)
		scurk_editor.name_edit.text = "Temporary Query Name"
		scurk_editor._commit_name()
		_check(
			scurk_editor.tile_set.names.get(current_tile_id, "") == "Temporary Query Name",
			"SCURK Rename writes a custom query name",
		)
		scurk_editor.revert_name()
		_check(
			not scurk_editor.tile_set.names.has(current_tile_id),
			"SCURK Revert Name removes the custom NAME piece",
		)
		scurk_editor.undo()
		_check(
			scurk_editor.tile_set.names.get(current_tile_id, "") == "Temporary Query Name",
			"SCURK Revert Name enters Undo history",
		)
		scurk_editor.redo()
		var reference_save := scurk_editor.save_path(
			scurk_directory.path_join("DO_NOT_WRITE.MIF")
		)
		_check(
			not reference_save.ok and not reference_save.error.is_empty(),
			"SCURK editor refuses to write inside the reference directory",
		)
		var scratch_path := ProjectSettings.globalize_path(
			"user://test-scurk-editor-output.MIF"
		)
		var editor_save := scurk_editor.save_path(scratch_path)
		_check(
			editor_save.ok
			and FileAccess.get_file_as_bytes(scratch_path)
				== FileAccess.get_file_as_bytes(scurk_directory.path_join("ORIGINAL.MIF")),
			"SCURK editor saves an unchanged MIF byte-identically",
		)
		var added_sprite_id := 1256
		var added_before: PackedByteArray = scurk_editor.tile_set.to_bytes().bytes
		scurk_editor.current_large_id = added_sprite_id
		scurk_editor.current_view = ScurkEditorControl.VIEW_LARGE
		scurk_editor._capture_object_start()
		scurk_editor._refresh_sprite()
		var added_pixels := scurk_editor.pixel_canvas.pixels.duplicate()
		var added_editable_pixel := 100 * ScurkWorkspace.WIDTH + 64
		added_pixels[added_editable_pixel] = (
			7 if added_pixels[added_editable_pixel] != 7 else 8
		)
		scurk_editor._capture_edit_start()
		scurk_editor._commit_pixels(added_pixels)
		_check(
			scurk_editor.tile_set.overrides.find_sprite(added_sprite_id) != null,
			"SCURK editor appends a previously absent terrain sprite to MIF",
		)
		scurk_editor.undo()
		_check(
			scurk_editor.tile_set.to_bytes().bytes == added_before
			and scurk_editor.tile_set.overrides.find_sprite(added_sprite_id) == null,
			"SCURK Undo removes an appended full-catalog sprite exactly",
		)
		var scratch_bmp_path := ProjectSettings.globalize_path(
			"user://test-scurk-editor-output.BMP"
		)
		var editor_export := scurk_editor.export_bmp_path(scratch_bmp_path)
		var exported_bitmap := IndexedBitmap.decode(
			FileAccess.get_file_as_bytes(scratch_bmp_path)
		)
		var expected_export := scurk_editor._active_output_shape()
		var expected_export_pixels: PackedInt32Array = expected_export.pixels.duplicate()

		for pixel_index in expected_export_pixels.size():
			if expected_export_pixels[pixel_index] < 0:
				expected_export_pixels[pixel_index] = 0

		_check(
			editor_export.ok
			and exported_bitmap.ok
			and exported_bitmap.width == expected_export.width
			and exported_bitmap.height == expected_export.height
			and exported_bitmap.pixels == expected_export_pixels,
			"SCURK editor exports its clipped active object view as an indexed BMP",
		)
		var imported_pixels := PackedInt32Array([-1, 1, 2, 3, 4, 5])
		var import_fixture := IndexedBitmap.save_path(
			scratch_bmp_path, 3, 2, imported_pixels, editor_palette
		)
		var editor_import := scurk_editor.import_bmp_path(scratch_bmp_path)
		var imported_output := scurk_editor._active_output_shape()
		_check(
			import_fixture.ok
			and editor_import.ok
			and scurk_editor.pixel_canvas.sprite_width == ScurkWorkspace.WIDTH
			and scurk_editor.pixel_canvas.sprite_height == ScurkWorkspace.HEIGHT
			and imported_output.width == scurk_editor.active_base_width
			and imported_output.height == 2
			and imported_output.pixels.has(1)
			and imported_output.pixels.has(2)
			and imported_output.pixels.has(4)
			and not imported_output.pixels.has(3)
			and not imported_output.pixels.has(5)
			and scurk_editor.dirty,
			"SCURK editor centers and clips an imported bitmap without changing its base",
		)
		scurk_editor.current_large_id = editable_ids[0]
		scurk_editor.current_view = ScurkEditorControl.VIEW_LARGE
		scurk_editor._refresh_sprite()
		var before_clear: PackedByteArray = scurk_editor.tile_set.to_bytes().bytes
		scurk_editor.clear_object()
		var cleared_views_are_blank := true
		var clear_mismatch := ""

		for clear_view in range(3):
			var clear_entry := scurk_editor.tile_set.archive.find_sprite(
				editable_ids[0] - clear_view * 500
			)
			var clear_decoded := clear_entry.decode_indices() if clear_entry != null else IndexedImageResult.new()
			var clear_view_is_blank: bool = (
				clear_entry != null
				and clear_entry.width
					== int(scurk_editor.active_base_width / ScurkWorkspace.view_divisor(clear_view))
				and clear_entry.height == 1
				and clear_decoded.ok
				and not clear_decoded.pixels.has(0)
			)

			if not clear_view_is_blank and clear_mismatch.is_empty():
				clear_mismatch = "view %d: %s" % [clear_view, str(clear_decoded)]

			cleared_views_are_blank = cleared_views_are_blank and clear_view_is_blank

		_check(
			cleared_views_are_blank and scurk_editor.undo_stack.size() > 0,
			"SCURK Clear Object clears all three views with their fixed base widths: %s"
				% clear_mismatch,
		)
		scurk_editor.undo()
		_check(
			scurk_editor.tile_set.to_bytes().bytes == before_clear,
			"SCURK Clear Object has exact-byte Undo",
		)

		if FileAccess.file_exists(scratch_path):
			DirAccess.remove_absolute(scratch_path)

		if FileAccess.file_exists(scratch_bmp_path):
			DirAccess.remove_absolute(scratch_bmp_path)

		scurk_editor.free()

	var fill_source := PackedInt32Array([
		1, 1, -1,
		1, 2, -1,
	])
	var filled := ScurkPixelEditor.flood_fill(fill_source, 3, 2, Vector2i(0, 0), 9)
	_check(
		filled == PackedInt32Array([9, 9, -1, 9, 2, -1])
		and fill_source == PackedInt32Array([1, 1, -1, 1, 2, -1]),
		"SCURK fill edits only the connected palette region",
	)
	var checker_fill := ScurkPixelEditor.flood_fill_pattern(
		PackedInt32Array([1, 1, 1, 2, 2, 2]), 3, 2, Vector2i(0, 0),
		7, 8, ScurkPixelEditor.TEXTURE_ROWS[1]
	)
	_check(
		checker_fill == PackedInt32Array([7, 8, 7, 2, 2, 2]),
		"SCURK texture fill uses foreground and background colors",
	)
	_check(
		ScurkPixelEditor.resolve_texture_value(0xff, 7, 8) == 7
		and ScurkPixelEditor.resolve_texture_value(0xf5, 7, 8) == 8
		and ScurkPixelEditor.resolve_texture_value(0x00, 7, 8) == 8
		and ScurkPixelEditor.resolve_texture_value(0x9b, 7, 8) == 0x9b,
		"SCURK textures map sentinels and keep literal palette indices",
	)
	var hollow_box := ScurkPixelEditor.shape_points(
		ScurkPixelEditor.TOOL_RECTANGLE, Vector2i(1, 2), Vector2i(4, 4), false
	)
	var filled_box := ScurkPixelEditor.shape_points(
		ScurkPixelEditor.TOOL_RECTANGLE, Vector2i(1, 2), Vector2i(4, 4), true
	)
	_check(
		hollow_box.size() == 10
		and filled_box.size() == 12
		and hollow_box.has(Vector2i(1, 2))
		and not hollow_box.has(Vector2i(2, 3))
		and filled_box.has(Vector2i(2, 3)),
		"SCURK box tool supports hollow and filled previews",
	)
	_check(
		ScurkPixelEditor.line_points(Vector2i(0, 0), Vector2i(4, 2))
			== [
				Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 1),
				Vector2i(3, 2), Vector2i(4, 2),
			]
		and not ScurkPixelEditor.shape_points(
			ScurkPixelEditor.TOOL_DIAMOND, Vector2i(0, 0), Vector2i(6, 4), false
		).is_empty()
		and not ScurkPixelEditor.shape_points(
			ScurkPixelEditor.TOOL_LEFT_WALL, Vector2i(0, 0), Vector2i(6, 8), true
		).is_empty()
		and not ScurkPixelEditor.shape_points(
			ScurkPixelEditor.TOOL_ELLIPSE, Vector2i(0, 0), Vector2i(6, 4), false
		).is_empty(),
		"SCURK line, diamond, wall, and ellipse tools produce pixel paths",
	)
	_check(
		ScurkPixelEditor.snapped_shape_point(
			Vector2i(1, 2), 4, 6, true
		) == Vector2i(0, 0)
		and ScurkPixelEditor.snapped_shape_point(
			Vector2i(2, 3), 4, 6, true
		) == Vector2i(4, 6)
		and ScurkPixelEditor.snapped_shape_point(
			Vector2i(6, 9), 4, 6, true
		) == Vector2i(8, 12)
		and ScurkPixelEditor.snapped_shape_point(
			Vector2i(6, 9), 4, 6, false
		) == Vector2i(6, 9),
		"SCURK shape snapping rounds half steps forward on each grid axis",
	)
	var view_window := ScurkViewWindow.new()
	var preview_background := PackedInt32Array()
	preview_background.resize(ScurkWorkspace.WIDTH * ScurkWorkspace.HEIGHT)
	preview_background.fill(5)
	view_window.set_preview(
		2, 1, 1, PackedInt32Array([7]), 32,
		Palette.index_encoding(), preview_background
	)
	_check(
		view_window.preview_width == 32
		and view_window.preview_height == 64
		and view_window.preview_indices[63 * 32 + 15] == 7
		and view_window.preview_indices[0] == 5
		and view_window.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"SCURK Small View Window shows the complete sampled Drawing Area and is read-only",
	)
	view_window.free()
	var snap_canvas := ScurkPixelEditor.new()
	var snap_pixels := PackedInt32Array()
	snap_pixels.resize(16 * 16)
	snap_pixels.fill(-1)
	snap_canvas.set_sprite_data(16, 16, snap_pixels, Palette.index_encoding())
	snap_canvas.set_zoom(1)
	snap_canvas.set_tool(ScurkPixelEditor.TOOL_LINE)
	snap_canvas.set_paint_indices(7, 0)
	snap_canvas.set_grid_settings(4, 6, true)
	var snap_press := InputEventMouseButton.new()
	snap_press.button_index = MOUSE_BUTTON_LEFT
	snap_press.pressed = true
	snap_press.position = Vector2(3.2, 4.2)
	snap_canvas._gui_input(snap_press)
	var snap_release := InputEventMouseButton.new()
	snap_release.button_index = MOUSE_BUTTON_LEFT
	snap_release.pressed = false
	snap_release.position = Vector2(9.2, 10.2)
	snap_canvas._gui_input(snap_release)
	_check(
		snap_canvas.pixel_at(Vector2i(4, 6)) == 7
		and snap_canvas.pixel_at(Vector2i(8, 12)) == 7
		and snap_canvas.pixel_at(Vector2i(3, 4)) == -1,
		"SCURK shape tools use snapped grid endpoints during the committed preview",
	)
	snap_canvas.free()
	var stroke_canvas := ScurkPixelEditor.new()
	stroke_canvas.set_sprite_data(
		5, 1, PackedInt32Array([-1, -1, -1, -1, -1]), Palette.index_encoding()
	)
	stroke_canvas.set_paint_indices(7, 0)
	var stroke_press := InputEventMouseButton.new()
	stroke_press.button_index = MOUSE_BUTTON_LEFT
	stroke_press.pressed = true
	stroke_press.position = Vector2(1, 1)
	stroke_canvas._gui_input(stroke_press)
	var stroke_motion := InputEventMouseMotion.new()
	stroke_motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	stroke_motion.position = Vector2(17, 1)
	stroke_canvas._gui_input(stroke_motion)
	var stroke_release := InputEventMouseButton.new()
	stroke_release.button_index = MOUSE_BUTTON_LEFT
	stroke_release.pressed = false
	stroke_release.position = Vector2(17, 1)
	stroke_canvas._gui_input(stroke_release)
	_check(
		stroke_canvas.pixels == PackedInt32Array([7, 7, 7, 7, 7]),
		"SCURK pencil strokes fill every crossed pixel without gaps",
	)
	stroke_canvas.free()
	var clip_canvas := ScurkPixelEditor.new()
	var clip_pixels := PackedInt32Array()
	clip_pixels.resize(ScurkWorkspace.WIDTH * ScurkWorkspace.HEIGHT)
	clip_pixels.fill(7)
	clip_canvas.set_sprite_data(
		ScurkWorkspace.WIDTH, ScurkWorkspace.HEIGHT, clip_pixels, Palette.index_encoding()
	)
	clip_canvas.set_edit_region(ScurkWorkspace.clip_mask(32), 1)
	_check(
		clip_canvas.pixels[255 * 128 + 62] == -1
		and clip_canvas.pixels[255 * 128 + 63] == 7
		and clip_canvas.pixels[255 * 128 + 64] == -1
		and clip_canvas.pixels[0 * 128 + 48] == 7,
		"SCURK drawing tools erase pixels outside the active object base",
	)
	clip_canvas.free()
	var clipboard_source := PackedInt32Array([1, 2, 3, 4, 5, 6])
	var copied_region := ScurkPixelEditor.copy_region(
		clipboard_source, 3, 2, Vector2i(1, 0), Vector2i(2, 1)
	)
	_check(
		copied_region.width == 2
		and copied_region.height == 2
		and copied_region.pixels == PackedInt32Array([2, 3, 5, 6]),
		"SCURK Copy extracts an inclusive rectangular pixel region",
	)
	_check(
		ScurkPixelEditor.rotate_counterclockwise(clipboard_source, 3, 2)
			== PackedInt32Array([3, 6, 2, 5, 1, 4])
		and ScurkPixelEditor.flip_horizontal(clipboard_source, 3, 2)
			== PackedInt32Array([3, 2, 1, 6, 5, 4])
		and ScurkPixelEditor.flip_vertical(clipboard_source, 3, 2)
			== PackedInt32Array([4, 5, 6, 1, 2, 3]),
		"SCURK clipboard rotate and flip operations preserve palette indices",
	)
	var paste_target := PackedInt32Array()
	paste_target.resize(12)
	paste_target.fill(0)
	_check(
		ScurkPixelEditor.paste_region(
			paste_target, 4, 3, Vector2i(2, 2),
			clipboard_source, 3, 2
		) == PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2]),
		"SCURK Paste clips copied pixels at the object boundary",
	)
	var clipboard_canvas := ScurkPixelEditor.new()
	clipboard_canvas.set_sprite_data(
		5, 5, PackedInt32Array([
			1, 2, 3, 4, 5,
			6, 7, 8, 9, 10,
			11, 12, 13, 14, 15,
			16, 17, 18, 19, 20,
			21, 22, 23, 24, 25,
		]), Palette.index_encoding()
	)
	clipboard_canvas.set_zoom(4)
	clipboard_canvas.set_tool(ScurkPixelEditor.TOOL_COPY)
	var copy_press := InputEventMouseButton.new()
	copy_press.button_index = MOUSE_BUTTON_LEFT
	copy_press.pressed = true
	copy_press.position = Vector2(1, 1)
	clipboard_canvas._gui_input(copy_press)
	var copy_release := InputEventMouseButton.new()
	copy_release.button_index = MOUSE_BUTTON_LEFT
	copy_release.pressed = false
	copy_release.position = Vector2(17, 17)
	clipboard_canvas._gui_input(copy_release)
	_check(
		clipboard_canvas.clipboard_width == 5
		and clipboard_canvas.clipboard_height == 5
		and clipboard_canvas.clipboard_pixels[0] == 1
		and clipboard_canvas.clipboard_pixels[24] == 25,
		"SCURK Copy drag stores a source-sized region in its private clipboard",
	)
	var accepted_clipboard := clipboard_canvas.clipboard_pixels.duplicate()
	copy_press.position = Vector2(1, 1)
	clipboard_canvas._gui_input(copy_press)
	copy_release.position = Vector2(13, 13)
	clipboard_canvas._gui_input(copy_release)
	_check(
		clipboard_canvas.clipboard_pixels == accepted_clipboard,
		"SCURK Copy rejects endpoint spans shorter than four pixels",
	)
	clipboard_canvas.free()
	var palette_grid := ScurkPalette.new()
	_check(
		palette_grid.index_at(Vector2(0, 0)) == 0
		and palette_grid.index_at(Vector2(17, 17)) == 0
		and palette_grid.index_at(Vector2(18, 0)) == 1
		and palette_grid.index_at(Vector2(287, 287)) == 255
		and palette_grid.index_at(Vector2(288, 0)) == -1,
		"SCURK palette maps all 256 visible color cells",
	)
	palette_grid.free()

	var city_hall := ScurkTileSet.load_path(scurk_directory.path_join("CITYHAL.MIF"))
	_check(city_hall.is_valid(), "CITYHAL.MIF parses: %s" % city_hall.parse_error)

	if city_hall.is_valid():
		_check(
			city_hall.piece_count == 552
			and city_hall.shapes.size() == 552
			and city_hall.overrides.entries.size() == 3,
			"CITYHAL.MIF keeps only its three visible overrides",
		)

		for expected in [[1208, 96, 85], [708, 48, 43], [208, 24, 22]]:
			var entry := city_hall.overrides.find_sprite(expected[0])
			_check(
				entry != null and entry.width == expected[1] and entry.height == expected[2],
				"CITYHAL.MIF sprite %d has its native dimensions" % expected[0],
			)

		var base_large := SpriteArchive.load_path(
			reference_root.path_join("DATA/LARGE.DAT")
		)
		var combined_large := SpriteArchive.combine([base_large, city_hall.overrides])
		_check(
			combined_large.is_valid()
			and combined_large.find_sprite(1208)
			== city_hall.overrides.find_sprite(1208)
			and combined_large.find_sprite(1207) == base_large.find_sprite(1207),
			"A partial MIF replaces visible sprites and keeps blank base sprites",
		)

	var tile_set_one := ScurkTileSet.load_path(scurk_directory.path_join("TILESET1.MIF"))
	_check(tile_set_one.is_valid(), "TILESET1.MIF parses: %s" % tile_set_one.parse_error)

	if tile_set_one.is_valid():
		_check(
			tile_set_one.piece_count == 572
			and tile_set_one.shapes.size() == 552
			and tile_set_one.names.size() == 20,
			"TILESET1.MIF contains 552 shapes and 20 names",
		)
		_check(
			tile_set_one.names.get(0xb5, "") == "Theater",
			"SCURK NAME records decode their full ID and terminal-null text",
		)
		var original_info := tile_set_one.info_payload.duplicate()
		var edited_pixels := PackedInt32Array([
			-1, 7, -1,
			8, 9, 10,
		])
		var edited_shape := tile_set_one.set_shape_indices(1208, 3, 2, edited_pixels)
		var edited_name := tile_set_one.set_name(Tiles.THEATER_SQUARE_3X3, "Edited Theater")
		var edited_bytes := tile_set_one.to_bytes()
		var reparsed := ScurkTileSet.new()
		_check(
			edited_shape.ok and edited_name.ok and edited_bytes.ok
			and reparsed.parse(edited_bytes.bytes),
			"SCURK writes edited SHAP and NAME records",
		)

		if reparsed.is_valid():
			var edited_entry := reparsed.archive.find_sprite(1208)
			var edited_decode := edited_entry.decode_indices() if edited_entry != null else IndexedImageResult.new()
			_check(
				reparsed.info_payload == original_info
				and reparsed.names.get(0xb5, "") == "Edited Theater"
				and edited_entry != null
				and edited_entry.width == 3
				and edited_entry.height == 2
				and edited_decode.ok
				and edited_decode.pixels == edited_pixels,
				"SCURK edit writes preserve INFO and decode to the edited values",
			)

		var removed_name := tile_set_one.remove_name(Tiles.THEATER_SQUARE_3X3)
		var removed_bytes := tile_set_one.to_bytes()
		var reparsed_removed := ScurkTileSet.new()
		_check(
			removed_name.ok
			and removed_bytes.ok
			and reparsed_removed.parse(removed_bytes.bytes)
			and not reparsed_removed.names.has(0xb5)
			and reparsed_removed.piece_count == 571,
			"SCURK can remove a custom NAME piece without changing other pieces",
		)

	var unpadded := Sc2SpriteArchive.SpriteEntry.new()
	unpadded.sprite_id = 7
	unpadded.width = 1
	unpadded.height = 1
	unpadded.encoded_pixels = PackedByteArray([3, 1, 1, 4, 7, 0, 2])
	_check(
		not unpadded.decode_indices().ok,
		"Normal DAT sprites reject an unpadded odd pixel run",
	)
	unpadded.allow_unpadded_odd_runs = true
	var decoded_unpadded := unpadded.decode_indices()
	_check(
		decoded_unpadded.ok and decoded_unpadded.pixels[0] == 7,
		"SCURK sprites accept an odd pixel run that ends at the row boundary",
	)

	var city_hall_bytes := FileAccess.get_file_as_bytes(
		scurk_directory.path_join("CITYHAL.MIF")
	)
	var bad_header := city_hall_bytes.duplicate()
	bad_header[0] = 0
	var bad_header_result := ScurkTileSet.new()
	_check(
		not bad_header_result.parse(bad_header)
		and not bad_header_result.parse_error.is_empty(),
		"SCURK parser rejects an invalid form header",
	)
	var bad_pixel_length := city_hall_bytes.duplicate()
	bad_pixel_length[161] = (bad_pixel_length[161] + 1) & 0xff
	var bad_pixel_result := ScurkTileSet.new()
	_check(
		not bad_pixel_result.parse(bad_pixel_length)
		and not bad_pixel_result.parse_error.is_empty(),
		"SCURK parser rejects a SHAP pixel-length mismatch",
	)


func _test_scurk_place_command(reference_root: String) -> void:
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


func _test_indexed_bmp() -> void:
	var index_palette := Palette.index_encoding()
	var source_pixels := PackedInt32Array([
		-1, 1, 2,
		3, 4, 5,
	])
	var encoded := IndexedBitmap.encode(3, 2, source_pixels, index_palette)
	_check(encoded.ok, "SCURK indexed BMP encoder accepts valid pixels")

	if not encoded.ok:
		return

	var bytes: PackedByteArray = encoded.bytes
	_check(
		bytes.size() == 1086
		and bytes[0] == 0x42
		and bytes[1] == 0x4d
		and bytes[10] == 0x36
		and bytes[11] == 0x04
		and bytes[1078] == 3
		and bytes[1079] == 4
		and bytes[1080] == 5
		and bytes[1081] == 0
		and bytes[1082] == 0
		and bytes[1083] == 1
		and bytes[1084] == 2
		and bytes[1085] == 0,
		"SCURK BMP output has a 256-color header and padded bottom-up rows",
	)
	var decoded := IndexedBitmap.decode(bytes)
	_check(
		decoded.ok
		and decoded.width == 3
		and decoded.height == 2
		and not decoded.top_down
		and decoded.pixels == PackedInt32Array([0, 1, 2, 3, 4, 5]),
		"SCURK BMP decoder restores indexed rows in display order",
	)
	var mapped := IndexedBitmap.map_to_palette(decoded, index_palette)
	_check(
		mapped.ok
		and mapped.remapped_color_count == 0
		and mapped.pixels == source_pixels,
		"SCURK BMP import maps palette index zero to transparent pixels",
	)
	var compressed := bytes.duplicate()
	compressed[30] = 1
	_check(
		not IndexedBitmap.decode(compressed).ok,
		"SCURK BMP import rejects compressed indexed data",
	)
	var short_palette := bytes.duplicate()
	short_palette[46] = 16
	short_palette[47] = 0
	_check(
		not IndexedBitmap.decode(short_palette).ok,
		"SCURK BMP import rejects a palette with fewer than 256 colors",
	)
	var encoded_dib := IndexedBitmap.encode_dib(
		3, 2, source_pixels, index_palette
	)
	_check(
		encoded_dib.ok
		and encoded_dib.bytes.size() == bytes.size() - 14
		and encoded_dib.bytes[0] == 40
		and encoded_dib.bytes[14] == 8,
		"SCURK clipboard encoder produces a headerless 8-bit CF_DIB payload",
	)
	var decoded_dib := IndexedBitmap.decode_dib(encoded_dib.bytes)
	_check(
		decoded_dib.ok
		and decoded_dib.width == 3
		and decoded_dib.height == 2
		and decoded_dib.pixels == PackedInt32Array([0, 1, 2, 3, 4, 5]),
		"SCURK clipboard decoder restores native CF_DIB indexed rows",
	)
	var wrapped_dib := IndexedBitmap.dib_to_bmp(encoded_dib.bytes)
	_check(
		wrapped_dib.ok and wrapped_dib.bytes == bytes,
		"SCURK CF_DIB wrapper restores the exact indexed BMP bytes",
	)
	var true_color_dib: PackedByteArray = encoded_dib.bytes.duplicate()
	true_color_dib[14] = 24
	_check(
		not IndexedBitmap.decode_dib(true_color_dib).ok,
		"SCURK native clipboard rejects a non-indexed DIB",
	)
	var windows_copy_command := ClipboardImage._copy_command(
		"Windows", "C:\\Temp\\scurk's tile.dib"
	)
	var windows_copy_script: String = windows_copy_command.arguments[4]
	_check(
		windows_copy_command.ok
		and windows_copy_command.arguments.has("-STA")
		and windows_copy_script.contains("DataFormats]::Dib")
		and windows_copy_script.contains("scurk''s tile.dib")
		and not windows_copy_script.contains("SetImage"),
		"SCURK Windows copy publishes the indexed CF_DIB payload on an STA thread",
	)
	var windows_paste_command := ClipboardImage._paste_command(
		"Windows", "C:\\Temp\\scurk-paste.dib"
	)
	var windows_paste_script: String = windows_paste_command.arguments[4]
	_check(
		windows_paste_command.ok
		and windows_paste_script.contains("DataFormats]::Dib")
		and windows_paste_script.contains("WriteAllBytes"),
		"SCURK Windows paste retrieves native indexed CF_DIB bytes",
	)
	var linux_copy_command := ClipboardImage._copy_command(
		"Linux", "/tmp/scurk-copy.bmp", "/usr/bin/xclip"
	)
	_check(
		linux_copy_command.ok
		and linux_copy_command.arguments.has("image/bmp")
		and not linux_copy_command.arguments.has("image/png"),
		"SCURK Linux copy offers the indexed BMP clipboard target",
	)
	var linux_paste_command := ClipboardImage._paste_command(
		"Linux", "/tmp/scurk paste.bmp", "/usr/bin/xclip"
	)
	_check(
		linux_paste_command.ok
		and linux_paste_command.executable == "/bin/sh"
		and String(linux_paste_command.arguments[1]).contains("image/bmp")
		and String(linux_paste_command.arguments[1]).contains("'/tmp/scurk paste.bmp'"),
		"SCURK Linux paste retrieves the indexed BMP clipboard target safely",
	)
	var clipboard_pixels := PackedInt32Array([-1, 0, 1, 255])
	var clipboard_image := ClipboardImage.indexed_to_image(
		2, 2, clipboard_pixels, index_palette
	)
	_check(
		clipboard_image.ok
		and clipboard_image.image.get_pixel(0, 0).a == 0.0
		and clipboard_image.image.get_pixel(1, 0).a == 1.0,
		"SCURK system clipboard image keeps transparent and visible black pixels distinct",
	)
	var clipboard_round_trip := ClipboardImage.image_to_indexed(
		clipboard_image.image, index_palette
	)
	_check(
		clipboard_round_trip.ok
		and clipboard_round_trip.pixels == clipboard_pixels
		and clipboard_round_trip.remapped_color_count == 0,
		"SCURK system clipboard image preserves master-palette pixels",
	)
	var off_palette_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	off_palette_image.set_pixel(0, 0, Color8(17, 18, 19, 255))
	var mapped_clipboard := ClipboardImage.image_to_indexed(
		off_palette_image, index_palette
	)
	_check(
		mapped_clipboard.ok and mapped_clipboard.remapped_color_count == 1,
		"SCURK system clipboard image maps colors outside the master palette",
	)


func _test_simulation_clock() -> void:
	var clock := Clock.new(0)
	var phases: Array[SimulationSchedule] = []

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
	var scenario_palette := Palette.load_bmp(reference_root.path_join("BITMAPS/PAL_MAC.BMP"))
	_check(scenario_palette.is_valid(), "Scenario palette loads: %s" % scenario_palette.load_error)
	var legacy_count := 0
	var extended_count := 0
	var template_count := 0
	var template_without_chunk_count := 0
	var first_template_fields: Array = []

	for path in paths:
		var document := _load_fixture(path)
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
			var rendered_picture := scenario.picture_image(scenario_palette)
			_check(
				rendered_picture.ok,
				"%s picture renders with PAL_MAC: %s" % [path.get_file(), rendered_picture.error],
			)

			if rendered_picture.ok:
				var image: Image = rendered_picture.image
				_check(
					image.get_width() == picture.width and image.get_height() == picture.height,
					"%s rendered picture keeps its dimensions" % path.get_file(),
				)
				_check(
					image.get_pixel(0, 0).is_equal_approx(
						scenario_palette.color(picture.pixels[0])
					),
					"%s first stored picture row renders at the top" % path.get_file(),
				)
				var last_index: int = picture.pixels.size() - 1
				_check(
					image.get_pixel(picture.width - 1, picture.height - 1).is_equal_approx(
						scenario_palette.color(picture.pixels[last_index])
					),
					"%s last stored picture row renders at the bottom" % path.get_file(),
				)

		var template := scenario.template_fields()
		_check(template.ok, "%s template parses: %s" % [path.get_file(), template.error])

		if template.ok and template.present:
			template_count += 1
			_check(template.fields.size() == 17, "%s template has 17 fields" % path.get_file())
			_check(
				template.scenario_size == ScenarioModel.LEGACY_SIZE,
				"%s template describes the complete legacy SCEN record" % path.get_file(),
			)
			_check(
				template.fields[0].name == "Disaster Type"
				and template.fields[0].type_code == "DWRD"
				and template.fields[0].size == 2
				and template.fields[0].scenario_offset == 4,
				"%s template starts with the disaster type" % path.get_file(),
			)
			_check(
				template.fields[-1].name == "Item Two Tiles"
				and template.fields[-1].type_code == "DWRD"
				and template.fields[-1].size == 2
				and template.fields[-1].scenario_offset == 50,
				"%s template ends with the second tile count" % path.get_file(),
			)

			var field_values: Array = []

			for field in template.fields:
				field_values.append([field.name, field.type_code, field.size, field.scenario_offset])

			if first_template_fields.is_empty():
				first_template_fields = field_values
			else:
				_check(
					field_values == first_template_fields,
					"%s uses the common supplied template" % path.get_file(),
				)
		elif template.ok:
			template_without_chunk_count += 1

	_check(legacy_count == 15, "Fifteen supplied scenarios use the 52-byte SCEN layout")
	_check(extended_count == 3, "Three supplied scenarios use the 56-byte SCEN layout")
	_check(template_count == 5, "Five supplied scenarios contain a TMPL chunk")
	_check(template_without_chunk_count == 13, "Thirteen supplied scenarios omit the optional TMPL chunk")

	var malformed_template_document := _load_fixture(
		reference_root.path_join("SCENARIO/CHARLEST.SCN")
	).duplicate_document()
	var malformed_template_chunk := malformed_template_document.find_chunk("TMPL")
	var malformed_template_data := malformed_template_chunk.decoded_payload.duplicate()
	malformed_template_data.resize(malformed_template_data.size() - 1)
	_check(
		malformed_template_chunk.set_decoded_payload(malformed_template_data),
		"Scenario fixture truncates TMPL",
	)
	_check(
		not ScenarioModel.from_document(malformed_template_document).template_fields().ok,
		"TMPL reader rejects a truncated field",
	)
	var unknown_template_document := _load_fixture(
		reference_root.path_join("SCENARIO/CHARLEST.SCN")
	).duplicate_document()
	var unknown_template_chunk := unknown_template_document.find_chunk("TMPL")
	var unknown_template_data := unknown_template_chunk.decoded_payload.duplicate()

	for index in range(18, 22):
		unknown_template_data[index] = 0x58

	_check(
		unknown_template_chunk.set_decoded_payload(unknown_template_data),
		"Scenario fixture changes a TMPL type",
	)
	_check(
		not ScenarioModel.from_document(unknown_template_document).template_fields().ok,
		"TMPL reader rejects an unknown field type",
	)

	var city_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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

	var scenario_document := _load_fixture(paths[0])
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

	var victory_document := _load_fixture(paths[0])
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
		and bankrupt.game_over_events[0].type == "bankruptcy"
		and bankrupt.game_over_events[0].funds == -100001,
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

	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_building_id(10, 10, Tiles.HYDRO_POWER_1), "Power test places a hydro plant")
	_check(city.set_building_id(10, 11, Tiles.POWER_LINE_STRAIGHT_1), "Power test places a power line")
	_check(city.set_building_id(10, 12, Tiles.LOWER_CLASS_HOMES_1X1_1), "Power test places a consumer")
	_check(city.set_building_id(20, 20, Tiles.LOWER_CLASS_HOMES_1X1_1), "Power test places a disconnected consumer")

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
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_building_id(30, 30, Tiles.WATER_PUMP), "Water test places a pump")
	_check(city.set_building_id(30, 31, Tiles.EMPTY), "Water test clears a pipe tile")
	_check(city.set_building_id(30, 32, Tiles.LOWER_CLASS_HOMES_1X1_1), "Water test places a consumer")
	_check(city.set_building_id(40, 40, Tiles.LOWER_CLASS_HOMES_1X1_1), "Water test places a disconnected consumer")

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
		_check(
			result.treatment_capacity == 0
			and not result.treatment_sufficient
			and document.misc_u32(0x104c) == 0,
			"Untreated served demand clears the saved treatment state",
		)
		_check(city.is_watered(30, 30), "Powered pump is marked watered")
		_check(city.is_watered(30, 31), "Connected pipe is marked watered")
		_check(city.is_watered(30, 32), "Connected consumer is marked watered")
		_check(not city.is_watered(40, 40), "Disconnected consumer is not watered")
		_check(
			document.set_misc_u32(0x01f0 + 0xf4 * 4, 4),
			"Water test records one complete treatment plant",
		)
		var treated := Water.run(city)
		_check(
			treated.ok
			and treated.treatment_capacity == 2000
			and treated.treatment_sufficient
			and document.misc_u32(0x104c) == 1,
			"One treatment plant covers 2,000 served demand units",
		)


func _test_simulation_engine(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_age_in_days(0), "Simulation engine test resets the city day")
	_check(document.set_misc_u32(0x001c, 1), "Simulation engine fixture selects Easy")
	_check(document.set_misc_u32(0x1000, 1), "Simulation engine fixture disables random disasters")
	var engine := Simulation.new(city, 1, 7)
	engine.midi_playback_active = true
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
	_check(
		SimulationDaySchedule.scanned_data_maps_only(day_two)
		and not SimulationDaySchedule.scanned_data_maps_only(day_one),
		"Only the data-map scan day reports data-map work alone",
	)
	var day_three := engine.advance_day()
	_check(day_three.ok, "Simulation engine advances the first growth day")
	_check(day_three.phase_results.has("growth"), "Simulation engine runs the RCI growth core")
	_check(
		day_three.applied == PackedStringArray(["growth"]) and day_three.pending.is_empty(),
		"Simulation engine completes the full growth partition",
	)
	_check(engine.lfsr_random.state != 7, "Growth continues the engine LFSR sequence")
	_check(
		not SimulationDaySchedule.scanned_data_maps_only(day_three),
		"A growth day does not report data-map work alone",
	)
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
	_check(
		latest.phase_results.has("rci_aftermath")
		and latest.phase_results.rci_aftermath.weather_trend >= 0,
		"Simulation engine runs monthly ecology, news, inventions, and weather after demand",
	)
	_check(
		latest.phase_results.has("music")
		and latest.phase_results.music.playback_was_active
		and not latest.phase_results.music.selection_attempted
		and latest.phase_results.music.music_track_requests.is_empty(),
		"Active MIDI skips the monthly random gate without a track request",
	)
	_check(
		latest.phase_results.has("simnation")
		and latest.phase_results.simnation.national_population >= 0,
		"Simulation engine runs SimNation before demographics",
	)
	_check(
		latest.phase_results.has("industries")
		and latest.phase_results.industries.mix_bonus >= 0,
		"Simulation engine runs individual industries before demographics",
	)
	_check(latest.pending.is_empty(), "Day 21 has no unimplemented scheduled phase")
	latest = engine.advance_day()
	_check(latest.phase_results.has("milestones"), "Simulation engine runs milestones on day 22")
	_check(
		latest.applied == PackedStringArray(["milestones", "scenario", "bankruptcy"])
		and latest.pending.is_empty(),
		"Simulation engine applies all normal day-22 checks",
	)
	latest = engine.advance_day()
	_check(
		latest.day == 23
		and latest.applied == PackedStringArray(["statistics_windows"])
		and latest.pending.is_empty()
		and latest.phase_results.statistics_windows.refresh_requests
		== ["population", "industries", "graphs"],
		"Simulation engine completes the day-23 statistics refresh",
	)
	latest = engine.advance_day()
	_check(
		latest.day == 24
		and latest.applied == PackedStringArray(["map", "simnation", "weather_disaster"])
		and latest.pending.is_empty()
		and latest.phase_results.weather_disaster.status_index >= -1
		and latest.phase_results.weather_disaster.disaster_type == WeatherDisaster.DISASTER_NONE,
		"Simulation engine completes the map, SimNation, status, and disaster work on day 24",
	)
	latest = engine.advance_day()
	_check(
		latest.applied == PackedStringArray(["budget", "month_start"]),
		"Simulation engine applies budget before month start on day 25",
	)
	_check(latest.pending.is_empty(), "Normal month-start budget work is complete")
	_check(latest.phase_results.has("budget"), "Simulation engine exposes the budget result")

	var silent_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var silent_city := CityModel.from_document(silent_document)
	_check(
		silent_city.set_age_in_days(20)
		and silent_city.set_simulation_speed(GameSpeed.Speed.TURTLE)
		and silent_city.set_music_enabled(false),
		"Monthly MIDI fixture selects day 21 with music disabled",
	)
	var silent_engine := Simulation.new(silent_city, 3, 7, 13)
	var silent_day := silent_engine.advance_day()
	_check(
		silent_day.ok
		and silent_day.phase_results.music.selection_attempted
		and not silent_day.phase_results.music.playback_was_active
		and silent_day.phase_results.music.music_track_requests
		== PackedInt32Array([10014])
		and not silent_engine.midi_playback_active,
		"Inactive monthly MIDI consumes the process RNG and requests the selected track",
	)

	var annual_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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

	var military_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(_clear_news_records(military_document), "Military engine fixture clears story records")
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
	var milestone_story := NewsQueue.story_record(
		military_document.find_chunk("MISC").decoded_payload, 0
	)
	_check(
		military_request.phase_results.milestones.news_queue_updated
		and milestone_story.type == 3
		and milestone_story.priority == 1000
		and milestone_story.argument == 3,
		"The engine stores milestone news before its military interaction",
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

	var monster_scenario_document := _load_fixture(reference_root.path_join("SCENARIO/ATLANTA.SCN"))
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

	var crash_scenario_document := _load_fixture(reference_root.path_join("SCENARIO/CHARLEST.SCN"))
	var crash_scenario_data: PackedByteArray = (
		crash_scenario_document.find_chunk("SCEN").decoded_payload.duplicate()
	)
	crash_scenario_data[0x04] = 0
	crash_scenario_data[0x05] = DisasterStart.DISASTER_HELICOPTER_CRASH
	_check(
		crash_scenario_document.find_chunk("SCEN").set_decoded_payload(
			crash_scenario_data
		),
		"Crash scenario fixture selects the helicopter crash wrapper",
	)
	var crash_scenario_city := CityModel.from_document(crash_scenario_document)
	_check(crash_scenario_city.set_age_in_days(0), "Crash scenario fixture resets the day")
	var crash_scenario_engine := Simulation.new(crash_scenario_city, 1, 7, 13)
	var crash_start := crash_scenario_engine.advance_day()
	_check(
		crash_start.ok
		and crash_start.applied.has("disaster_start")
		and crash_scenario_engine.active_disaster_type
		== DisasterStart.DISASTER_HELICOPTER_CRASH
		and crash_scenario_city.city_mode() == 2,
		"A scheduled no-op crash wrapper enters disaster mode",
	)
	var crash_end := crash_scenario_engine.advance_disaster_tick()
	_check(
		crash_end.ok
		and crash_end.complete
		and crash_scenario_engine.active_disaster_type == 0
		and crash_scenario_city.city_mode() == 1,
		"A no-op crash wrapper ends on the next eligible disaster tick",
	)


func _test_game_speed_controller(reference_root: String) -> void:
	var paused_document := _load_fixture(reference_root.path_join("CITIES/STARTER.SC2"))
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

	var llama_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
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

	var cheetah_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
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

	var swallow_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
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

	var island_city := CityModel.from_document(
		_load_fixture(reference_root.path_join("CITIES/ISLAND.SC2"))
	)
	var island_start_day := island_city.age_in_days()
	_check(island_city.set_simulation_speed(4), "Island unpause fixture selects Cheetah")
	var island_controller := GameSpeed.new(Simulation.new(island_city, 1, 7, 13))
	var island_ticks_ok := true

	for tick in 25:
		var island_tick := island_controller.advance_time(200.0, (tick + 1) * 200)

		if not island_tick.ok:
			island_ticks_ok = false
			break

	_check(
		island_ticks_ok and island_city.age_in_days() >= island_start_day + 25,
		"Island runs 25 Cheetah ticks after unpause without a script or simulation error",
	)

	var refresh_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
	_check(refresh_city.set_age_in_days(22), "Controller refresh fixture selects day 22")
	_check(refresh_city.set_simulation_speed(4), "Controller refresh fixture stores Cheetah speed")
	_check(refresh_city.document.set_misc_u32(0x001c, 1), "Controller refresh fixture selects Easy")
	_check(refresh_city.document.set_misc_u32(0x1000, 1), "Controller refresh fixture disables disasters")
	var refresh_controller := GameSpeed.new(Simulation.new(refresh_city, 1, 7, 13))
	var statistics_refresh := refresh_controller.advance_time(200.0, 200)
	_check(
		statistics_refresh.ok
		and statistics_refresh.refresh_requests == ["population", "industries", "graphs"],
		"Controller forwards the day-23 statistics refresh requests",
	)
	var map_refresh := refresh_controller.advance_time(200.0, 400)
	_check(
		map_refresh.ok
		and map_refresh.refresh_requests == ["toolbar", "map", "simnation", "weather_disaster"],
		"Controller deduplicates and forwards the day-24 refresh requests",
	)

	var music_city := CityModel.from_document(
		_load_fixture(reference_root.path_join("DEFAULT.SC2"))
	)
	_check(
		music_city.set_age_in_days(20)
		and music_city.set_simulation_speed(GameSpeed.Speed.TURTLE)
		and music_city.set_music_enabled(false),
		"Controller MIDI fixture selects an inactive day-21 gate",
	)
	var music_controller := GameSpeed.new(Simulation.new(music_city, 3, 7, 13))
	music_controller.simulation_ready = true
	var music_tick := music_controller.advance_time(0.0, 0)
	_check(
		music_tick.ok
		and music_tick.day_results.size() == 1
		and music_tick.music_track_requests == PackedInt32Array([10014]),
		"Controller forwards a monthly MIDI track request",
	)

	var budget_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
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

	var annual_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
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

	var military_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
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

	var monster_city := CityModel.from_document(_load_fixture(reference_root.path_join("SCENARIO/ATLANTA.SCN")))
	_check(monster_city.set_age_in_days(0), "Controller monster scenario fixture resets the day")
	_check(monster_city.set_simulation_speed(4), "Controller monster scenario fixture stores Cheetah speed")
	var monster_controller := GameSpeed.new(Simulation.new(monster_city, 1, 7, 13))
	var monster_start := monster_controller.advance_time(200.0, 200)
	_check(
		monster_start.ok
		and monster_start.day_results.size() == 1
		and (SoundEvent.count_plain(monster_start.sound_events, DisasterStart.SOUND_SIREN) > 0)
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

	var terminal_city := CityModel.from_document(_load_fixture(reference_root.path_join("DEFAULT.SC2")))
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
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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


func _test_city_value_phase(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)

	for tile_id in 256:
		_check(
			document.set_misc_i32(0x01f0 + tile_id * 4, 0),
			"City-value fixture clears tile count 0x%02X" % tile_id,
		)

	_check(document.set_misc_u32(0x0fe8, 3), "City-value fixture sets subway count")

	for entry in [
		[0x0e, 2], [0x1d, 3], [0x2c, 4], [0x3f, 5], [0x51, 6],
		[0x61, 7], [0x6c, 8], [0xc6, 2], [0xc9, 32], [0xd1, 18],
		[0xd4, 9], [0xd5, 9], [0xd7, 16], [0xdc, 3], [0xdd, 2],
		[0xdf, 2], [0xe9, 2], [0xeb, 8], [0xec, 8], [0xed, 8],
		[0xf4, 9], [0xf5, 8], [0xf8, 9], [0xfa, 9], [0xfb, 16],
	]:
		_check(
			document.set_misc_u32(0x01f0 + int(entry[0]) * 4, int(entry[1])),
			"City-value fixture sets tile count 0x%02X" % int(entry[0]),
		)

	_check(document.set_misc_u32(0x01f0 + 0x0d * 4, 99), "City-value fixture sets small parks")
	_check(document.set_misc_u32(0x01f0 + 0xd0 * 4, 99), "City-value fixture sets city halls")
	var before := document.misc_i32(0x0024)
	var calculated := CityValue.calculate(city)
	_check(calculated.ok and calculated.city_value == 136956, "City value uses all recovered rules")
	_check(document.misc_i32(0x0024) == before, "City-value calculation is read-only")
	var result := CityValue.run(city)
	_check(result.ok and result.city_value == 136956, "City-value phase completes")
	_check(document.misc_i32(0x0024) == 136956, "City-value phase stores MISC city value")

	_check(document.set_misc_u32(0x01f0 + 0x0e * 4, 0xffff), "City-value fixture sets signed count")
	_check(document.set_misc_u32(0x0fe8, 0xffff), "City-value fixture sets signed subway count")
	var signed_result := CityValue.calculate(city)
	_check(
		signed_result.ok and signed_result.city_value == 136954,
		"City value sign-extends the supplied runtime counters",
	)


func _test_bond_command(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)

	for tile_id in 256:
		_check(
			document.set_misc_i32(0x01f0 + tile_id * 4, 0),
			"Bond fixture clears tile count 0x%02X" % tile_id,
		)

	_check(document.set_misc_u32(0x0fe8, 0), "Bond fixture clears subway count")
	_check(city.set_funds(2000), "Bond fixture sets funds")
	_check(document.set_misc_u32(0x0018, 0), "Bond fixture clears bond count")
	_check(document.set_misc_i32(0x0024, 12345), "Bond fixture sets stale city value")
	_check(document.set_misc_u32(0x0058, 3), "Bond fixture sets federal rate")

	for rate_index in 50:
		_check(
			document.set_misc_u32(0x0610 + rate_index * 4, 0x77770000),
			"Bond fixture clears rate %d" % rate_index,
		)

	var invalid_before: PackedByteArray = document.find_chunk("MISC").decoded_payload.duplicate()
	var invalid := Bonds.issue(city, 2)
	_check(not invalid.ok, "Bond issue rejects an invalid confirmation choice")
	_check(
		document.find_chunk("MISC").decoded_payload == invalid_before,
		"Rejected bond confirmation preserves MISC",
	)

	var request := Bonds.issue(city)
	_check(
		request.ok and request.status == "confirmation_required"
		and request.confirmation_required and request.rate == 4,
		"Bond issue requests confirmation at federal rate plus one",
	)
	_check(document.misc_i32(0x0024) == 0, "Bond issue first rebuilds the city value")
	_check(city.funds() == 2000 and document.misc_u32(0x0018) == 0, "Bond prompt does not issue")
	var cancel_before: PackedByteArray = document.find_chunk("MISC").decoded_payload.duplicate()
	var cancelled := Bonds.issue(city, Bonds.CONFIRMATION_CANCELLED)
	_check(cancelled.ok and cancelled.status == "cancelled", "Bond issue can be declined")
	_check(
		document.find_chunk("MISC").decoded_payload == cancel_before,
		"Declined bond issue preserves the post-valuation MISC data",
	)

	var first := Bonds.issue(city, Bonds.CONFIRMATION_CONFIRMED)
	_check(first.ok and first.status == "issued" and first.changed, "Bond issue completes")
	_check(city.funds() == 12000 and document.misc_u32(0x0018) == 1, "Bond issue adds $10,000")
	_check(document.misc_u32(0x0610) == 4, "Bond issue appends the offered rate")
	_check(document.misc_i32(0x092c) == 1, "Bond issue updates the budget bond count")
	_check(document.misc_i32(0x0930) == 40000, "Bond issue updates the average rate")
	_check(document.misc_u32(0x0614) == 0, "Bond issue normalizes saved rate fields")

	_check(document.set_misc_u32(0x0058, 5), "Bond fixture changes federal rate")
	_check(document.set_misc_u32(0x01f0 + 0x1d * 4, 100), "Bond fixture improves city value")
	var second := Bonds.issue(city, Bonds.CONFIRMATION_CONFIRMED)
	_check(second.ok and second.rate == 6, "A second bond uses the current rate")
	_check(city.funds() == 22000 and document.misc_u32(0x0018) == 2, "Second bond is stored")
	_check(document.misc_u32(0x0614) == 6, "Second bond uses the next saved rate slot")
	_check(document.misc_i32(0x0930) == 50000, "Two bond rates use their integer average")

	var repay_before: PackedByteArray = document.find_chunk("MISC").decoded_payload.duplicate()
	var repay_request := Bonds.repay(city)
	_check(
		repay_request.ok and repay_request.status == "confirmation_required"
		and repay_request.rate == 4,
		"Bond repayment offers the oldest bond",
	)
	_check(
		document.find_chunk("MISC").decoded_payload == repay_before,
		"Bond repayment prompt preserves MISC",
	)
	var repay_cancel := Bonds.repay(city, Bonds.CONFIRMATION_CANCELLED)
	_check(repay_cancel.ok and repay_cancel.status == "cancelled", "Bond repayment can be declined")
	_check(
		document.find_chunk("MISC").decoded_payload == repay_before,
		"Declined bond repayment preserves MISC",
	)
	var repaid := Bonds.repay(city, Bonds.CONFIRMATION_CONFIRMED)
	_check(repaid.ok and repaid.status == "repaid" and repaid.rate == 4, "Oldest bond is repaid")
	_check(city.funds() == 12000 and document.misc_u32(0x0018) == 1, "Repayment removes $10,000")
	_check(document.misc_u32(0x0610) == 6, "Repayment shifts the remaining rate forward")
	_check(document.misc_u32(0x0614) == 6, "Repayment preserves the stale last active slot")
	_check(document.misc_i32(0x092c) == 1 and document.misc_i32(0x0930) == 60000, "Repayment updates the bond budget")
	var final_repay := Bonds.repay(city, Bonds.CONFIRMATION_CONFIRMED)
	_check(final_repay.ok and final_repay.bond_count == 0, "Last bond can be repaid")
	_check(city.funds() == 2000 and document.misc_i32(0x0930) == 0, "No bonds have zero average rate")
	_check(document.misc_u32(0x0610) == 6, "Last repayment does not clear its stale rate")
	var no_bonds_before: PackedByteArray = document.find_chunk("MISC").decoded_payload.duplicate()
	var no_bonds := Bonds.repay(city)
	_check(no_bonds.ok and no_bonds.status == "no_bonds", "Repayment reports no bonds")
	_check(document.find_chunk("MISC").decoded_payload == no_bonds_before, "No-bond repayment is read-only")

	var denied_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var denied_city := CityModel.from_document(denied_document)

	for tile_id in 256:
		denied_document.set_misc_i32(0x01f0 + tile_id * 4, 0)

	_check(denied_document.set_misc_u32(0x01f0 + 0x1d * 4, 10), "Credit fixture sets roads")
	_check(denied_document.set_misc_u32(0x0018, 1), "Credit fixture sets one bond")
	_check(denied_document.set_misc_u32(0x0610, 4), "Credit fixture sets its rate")
	_check(denied_city.set_funds(9999), "Credit fixture sets insufficient repayment funds")
	var denied := Bonds.issue(denied_city)
	_check(
		denied.ok and denied.status == "credit_denied" and denied.credit_value == 24,
		"Supplied 2,500 credit formula can deny a bond",
	)
	_check(denied_document.misc_i32(0x0024) == 100, "Denied issue stores rebuilt city value")
	var insufficient := Bonds.repay(denied_city)
	_check(
		insufficient.ok and insufficient.status == "insufficient_funds",
		"Repayment requires $10,000 before it asks for confirmation",
	)

	var maximum_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var maximum_city := CityModel.from_document(maximum_document)

	for tile_id in 256:
		maximum_document.set_misc_i32(0x01f0 + tile_id * 4, 0)

	_check(maximum_document.set_misc_u32(0x0018, 50), "Maximum fixture sets fifty bonds")
	var maximum := Bonds.issue(maximum_city)
	_check(maximum.ok and maximum.status == "maximum_bonds", "Bond count is limited to fifty")


func _test_budget_phase(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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
	_check(result.current_costs[3] == -300, "Budget calculates active ordinance cost")
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

	var december_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var december_city := CityModel.from_document(december_document)
	_check(december_city.set_age_in_days(275), "December budget fixture selects month 12")
	_check(december_document.set_misc_u32(0x0e3c, 0), "December budget fixture clears year end")
	var december := Budget.run(december_city, SequenceRandom.new([1]))
	_check(december.ok and december.month == 11, "December budget phase completes")
	_check(december_document.misc_u32(0x0e3c) == 1, "December sets the year-end flag")

	var annual_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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

	var manual_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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

	var ordinance_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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

	var military_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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
	_check(
		military_document.set_misc_u32(
			ToolAvailability.MISC_INVENTION_YEARS + 12 * 4,
			0,
		),
		"Arcology milestone fixture releases one arcology",
	)
	_check(military_document.set_misc_u32(0x102c, 120001), "Arcology milestone fixture sets population")
	var arcology := Milestones.run(military_city)
	_check(arcology.ok and arcology.progression == 6, "The sixth milestone advances progression")
	_check(
		military_document.misc_u32(0x0078) == 31,
		"The sixth milestone enables the arcology chooser when one is released",
	)

	var final_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var final_city := CityModel.from_document(final_document)
	_check(final_document.set_misc_u32(0x0020, 9), "Final milestone fixture sets progression")
	_check(final_document.set_misc_u32(0x102c, 10000001), "Final milestone fixture sets population")
	var final := Milestones.run(final_city)
	_check(final.ok and final.progression == 10, "The last recovered threshold advances progression")
	var exhausted := Milestones.run(final_city)
	_check(exhausted.ok and not exhausted.advanced, "Progression stops after the recovered threshold table")


func _test_military_proposal_phase(reference_root: String) -> void:
	var declined_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var declined_city := CityModel.from_document(declined_document)
	var declined := MilitaryProposal.resolve(declined_city, false, null)
	_check(declined.ok and not declined.accepted, "The player can decline a military proposal")
	_check(
		declined.base_type == MilitaryProposal.BASE_DECLINED
		and declined_document.misc_u32(MilitaryProposal.MISC_BASE_TYPE) == MilitaryProposal.BASE_DECLINED,
		"A declined proposal stores the original base type",
	)
	_check(declined.changed_indices.is_empty(), "A declined proposal does not change map zones")

	var air_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
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
	var air_random := SequenceGameModuloRandom.new([10, 20])
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

	var army_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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
	var army := MilitaryProposal.resolve(army_city, true, SequenceGameModuloRandom.new([10, 20]))
	_check(
		army.ok
		and army.base_type == MilitaryProposal.BASE_ARMY
		and army.notice_id == MilitaryProposal.NOTICE_ARMY,
		"A suitable uneven candidate becomes an Army base",
	)

	var missile_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var missile_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.SMALL_PARK)
	var expected_sites: Array[Rect2i] = []

	for origin in [Vector2i(5, 5), Vector2i(15, 15), Vector2i(25, 25), Vector2i(35, 35), Vector2i(45, 45), Vector2i(55, 55)]:
		expected_sites.append(Rect2i(origin, Vector2i(3, 3)))

		for x in range(origin.x, origin.x + 3):
			for y in range(origin.y, origin.y + 3):
				missile_buildings[x * CityState.MAP_SIZE + y] = Tiles.EMPTY

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

	var missile_random := SequenceGameModuloRandom.new(missile_values)
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
	var monster_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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
		and SoundEvent.same_arrays(monster.sound_events, SoundEvent.from_ids([DisasterStart.SOUND_SIREN]))
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
	_check(DisasterStartObjectsState.has_active_object(monster_city, DisasterStart.DISASTER_MONSTER), "Monster activity is visible to the disaster controller")

	var fire_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var fire_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)
	var fire_point := Vector2i(60, 69)
	fire_buildings[fire_point.x * CityState.MAP_SIZE + fire_point.y] = Tiles.LOWER_CLASS_HOMES_1X1_1
	_check(
		fire_document.find_chunk("XBLD").set_decoded_payload(fire_buildings)
		and fire_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and fire_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and fire_document.find_chunk("XTRF").set_decoded_payload(_filled_bytes(64 * 64, 9))
		and fire_document.set_misc_u32(DisasterStart.MISC_CITY_CENTER_X, 60)
		and fire_document.set_misc_u32(DisasterStart.MISC_CITY_CENTER_Y, 70),
		"Fire start fixture installs a building north of the city center",
	)
	var fire_city := CityModel.from_document(fire_document)
	var fire_random := SequenceRandom.new([20, 20])
	var fire_lfsr := SequenceLfsrRandom.new([])
	var fire := DisasterStart.start(
		fire_city, DisasterStart.DISASTER_FIRE, Vector2i.ZERO, fire_random, fire_lfsr
	)
	_check(
		fire.ok
		and fire.started
		and fire.complete
		and fire.point == fire_point
		and SoundEvent.same_arrays(fire.sound_events, SoundEvent.from_ids([DisasterStart.SOUND_SIREN]))
		and fire.view_center_requests == [fire_point],
		"Fire starts at the first suitable point in the center spiral",
	)
	_check(
		fire_city.building_id(fire_point.x, fire_point.y) == 0x70
		and fire_city.text_overlay_id(fire_point.x, fire_point.y) == 0xff
		and fire_document.find_chunk("XTRF").decoded_payload[30 * 64 + 34] == 0,
		"Fire marks XTXT, clears coarse traffic, and preserves the source building",
	)
	_check(
		fire_random.position == 2 and fire_lfsr.position == 0,
		"A first-point fire consumes only the two process-random center offsets",
	)

	var flood_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var flood_terrain := _filled_bytes(CityState.TILE_COUNT, 0)
	var flood_source := Vector2i(20, 20)
	flood_terrain[flood_source.x * CityState.MAP_SIZE + flood_source.y] = 0x20
	_check(
		flood_document.find_chunk("XTER").set_decoded_payload(flood_terrain)
		and flood_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and flood_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		),
		"Flood start fixture installs one shoreline terrain cell",
	)
	var flood_city := CityModel.from_document(flood_document)
	var flood_lfsr := SequenceLfsrRandom.new([])
	var flood := DisasterStart.start(
		flood_city,
		DisasterStart.DISASTER_FLOOD,
		flood_source,
		SequenceRandom.new([]),
		flood_lfsr
	)
	_check(
		flood.ok
		and flood.started
		and flood.point == flood_source
		and flood.map_counter == 60
		and SoundEvent.same_arrays(flood.sound_events, SoundEvent.from_ids([DisasterStart.SOUND_FLOOD, DisasterStart.SOUND_SIREN]))
		and flood.view_center_requests == [flood_source],
		"Flood starts on the first shoreline terrain cell and reports its runtime state",
	)
	_check(
		flood_city.text_overlay_id(19, 20) == 0
		and flood_city.text_overlay_id(20, 19) == 0
		and flood_city.text_overlay_id(21, 20) == 0xfc
		and flood_city.text_overlay_id(20, 21) == 0xfc
		and flood_lfsr.position == 0,
		"A radius-zero flood preserves the supplied east-and-south seeding asymmetry",
	)

	var toxic_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(
		toxic_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		),
		"Toxic-spill start fixture clears XTXT",
	)
	var toxic_city := CityModel.from_document(toxic_document)
	var toxic_point := Vector2i(30, 31)
	var toxic_start := DisasterStart.start(
		toxic_city,
		DisasterStart.DISASTER_TOXIC_SPILL,
		toxic_point,
		SequenceRandom.new([]),
	)
	_check(
		toxic_start.ok
		and toxic_start.started
		and toxic_start.complete
		and toxic_start.point == toxic_point
		and SoundEvent.same_arrays(toxic_start.sound_events, SoundEvent.from_ids([DisasterStart.SOUND_SIREN]))
		and toxic_start.view_center_requests == [toxic_point]
		and toxic_city.text_overlay_id(toxic_point.x, toxic_point.y) == DisasterMap.TOXIC_OVERLAY,
		"Toxic Spill writes XTXT 0xFB directly at the requested point",
	)
	var outside_toxic := DisasterStart.start(
		toxic_city,
		DisasterStart.DISASTER_TOXIC_SPILL,
		Vector2i(-1, 31),
		SequenceRandom.new([]),
	)
	_check(
		outside_toxic.ok and not outside_toxic.started and outside_toxic.complete,
		"Toxic Spill rejects an out-of-map compatibility API point",
	)

	var pollution_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var pollution_text := _filled_bytes(CityState.TILE_COUNT, 0)
	var pollution_point := Vector2i(10, 10)
	pollution_text[pollution_point.x * CityState.MAP_SIZE + pollution_point.y] = 201
	_check(
		pollution_document.find_chunk("XTXT").set_decoded_payload(pollution_text)
		and pollution_document.set_misc_u32(DisasterStart.MISC_NORMAL_POPULATION, 30000),
		"Pollution start fixture sets its population and an occupied overlay",
	)
	var pollution_city := CityModel.from_document(pollution_document)
	var pollution_values: Array[int] = [
		4, 4, 7, 4, 0, 0, 4, 4,
		4, 4, 4, 4, 4, 4, 4, 4,
	]
	var pollution_random := SequenceRandom.new(pollution_values)
	var pollution_start := DisasterStart.start(
		pollution_city,
		DisasterStart.DISASTER_POLLUTION,
		pollution_point,
		pollution_random,
	)
	_check(
		pollution_start.ok
		and pollution_start.started
		and pollution_start.complete
		and pollution_start.counters.attempt_count == 8
		and pollution_start.counters.seed_writes == 8
		and SoundEvent.same_arrays(pollution_start.sound_events, SoundEvent.from_ids([DisasterStart.SOUND_SIREN]))
		and pollution_start.view_center_requests == [pollution_point],
		"Pollution uses normal population for its seed count and reports a start",
	)
	_check(
		pollution_city.text_overlay_id(10, 10) == DisasterMap.TOXIC_OVERLAY
		and pollution_city.text_overlay_id(13, 10) == DisasterMap.TOXIC_OVERLAY
		and pollution_city.text_overlay_id(6, 6) == DisasterMap.TOXIC_OVERLAY
		and pollution_random.position == 16,
		"Pollution consumes two random values per attempt and overwrites valid XTXT cells",
	)
	var missed_pollution_random := SequenceRandom.new([
		4, 4, 4, 4, 4, 4, 4, 4,
		4, 4, 4, 4, 4, 4, 4, 4,
	])
	var missed_pollution := DisasterStart.start(
		pollution_city,
		DisasterStart.DISASTER_POLLUTION,
		Vector2i(-10, -10),
		missed_pollution_random,
	)
	_check(
		missed_pollution.ok
		and not missed_pollution.started
		and missed_pollution.complete
		and missed_pollution.counters.attempt_count == 8
		and missed_pollution.counters.seed_writes == 0
		and missed_pollution.sound_events.is_empty()
		and missed_pollution_random.position == 16,
		"Pollution consumes all attempts but does not start when every seed is outside the map: %s pos=%d"
		% [missed_pollution, missed_pollution_random.position],
	)

	var riot_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var riot_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)

	for y in [19, 18, 17]:
		riot_buildings[20 * CityState.MAP_SIZE + y] = Tiles.ROAD_STRAIGHT_1

	_check(
		riot_document.find_chunk("XBLD").set_decoded_payload(riot_buildings)
		and riot_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and riot_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		),
		"Riot start fixture installs three northbound road cells",
	)
	var riot_city := CityModel.from_document(riot_document)
	var riot_random := SequenceRandom.new([0, 1, 0])
	var riot_start := DisasterStart.start(
		riot_city, DisasterStart.DISASTER_RIOT, Vector2i(20, 20), riot_random
	)
	_check(
		riot_start.ok
		and riot_start.started
		and riot_start.complete
		and riot_start.counters.seed_writes == 3
		and riot_start.seed_points == [Vector2i(20, 19), Vector2i(20, 18), Vector2i(20, 17)]
		and riot_start.point == Vector2i(20, 17)
		and riot_start.view_center_requests == [Vector2i(20, 17)],
		"Riot makes three spiral starts and keeps the last successful point",
	)
	_check(
		riot_city.text_overlay_id(20, 19) == DisasterStart.RIOT_OVERLAY_FORWARD
		and riot_city.text_overlay_id(20, 18) == DisasterStart.RIOT_OVERLAY_REVERSE
		and riot_city.text_overlay_id(20, 17) == DisasterStart.RIOT_OVERLAY_FORWARD
		and SoundEvent.same_arrays(riot_start.sound_events, SoundEvent.from_ids([
			DisasterStart.SOUND_RIOT,
			DisasterStart.SOUND_RIOT,
			DisasterStart.SOUND_RIOT,
			DisasterStart.SOUND_SIREN,
		]))
		and riot_random.position == 3,
		"Riot uses one orientation bit and sound request for each seeded marker",
	)

	var rejected_riot_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)
	var rejected_riot_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)
	rejected_riot_buildings[20 * CityState.MAP_SIZE + 20] = Tiles.ROAD_STRAIGHT_1
	rejected_riot_buildings[20 * CityState.MAP_SIZE + 19] = Tiles.POWER_LINE_CROSSROADS
	_check(
		rejected_riot_document.find_chunk("XBLD").set_decoded_payload(
			rejected_riot_buildings
		)
		and rejected_riot_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and rejected_riot_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		),
		"Rejected riot fixture keeps only the origin and a tile below the supported range",
	)
	var rejected_riot_random := SequenceRandom.new([1])
	var rejected_riot := DisasterStart.start(
		CityModel.from_document(rejected_riot_document),
		DisasterStart.DISASTER_RIOT,
		Vector2i(20, 20),
		rejected_riot_random,
	)
	_check(
		rejected_riot.ok
		and not rejected_riot.started
		and rejected_riot.complete
		and rejected_riot.counters.seed_writes == 0
		and rejected_riot_random.position == 0,
		"Riot excludes its origin and XBLD below 0x1D without consuming random state",
	)

	var mass_riot_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)
	_check(
		mass_riot_document.find_chunk("XBLD").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0x1d)
		)
		and mass_riot_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and mass_riot_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and mass_riot_document.set_misc_u32(DisasterStart.MISC_NORMAL_POPULATION, 20000),
		"Mass-riot fixture installs a dry road map and normal population",
	)
	var mass_riot_values: Array[int] = []

	for x_value in [16, 20, 24, 28, 0, 4, 8]:
		mass_riot_values.append_array([x_value, 16, x_value & 1])

	var mass_riot_random := SequenceRandom.new(mass_riot_values)
	var mass_riot_city := CityModel.from_document(mass_riot_document)
	var mass_riot_start := DisasterStart.start(
		mass_riot_city,
		DisasterStart.DISASTER_MASS_RIOTS,
		Vector2i(64, 64),
		mass_riot_random,
	)
	_check(
		mass_riot_start.ok
		and mass_riot_start.started
		and mass_riot_start.counters.attempt_count == 7
		and mass_riot_start.counters.seed_writes == 7
		and mass_riot_start.point == Vector2i(56, 63)
		and mass_riot_random.position == 21,
		"Mass Riots uses population plus five attempts and three random values per successful seed",
	)
	_check(
		mass_riot_city.text_overlay_id(64, 63) == DisasterStart.RIOT_OVERLAY_FORWARD
		and mass_riot_city.text_overlay_id(68, 63) == DisasterStart.RIOT_OVERLAY_FORWARD
		and mass_riot_city.text_overlay_id(56, 63) == DisasterStart.RIOT_OVERLAY_FORWARD
		and mass_riot_start.sound_events.size() == 8
		and mass_riot_start.sound_events[-1].equals(SoundEvent.new(DisasterStart.SOUND_SIREN)),
		"Mass Riots stores each marker and appends the common siren after riot sounds",
	)

	var earthquake_point := Vector2i(64, 64)
	var earthquake_damage_point := Vector2i(32, 32)
	var earthquake_fixture := _fire_map_fixture(
		reference_root, earthquake_damage_point, Tiles.ROAD_STRAIGHT_1
	)
	_check(
		earthquake_fixture.city != null
		and earthquake_fixture.city.set_text_overlay_id(
			earthquake_damage_point.x, earthquake_damage_point.y, 0
		),
		"Earthquake fixture installs one eligible tile at its first offset",
	)
	var earthquake_values: Array[int] = [0, 0]

	for _gate in 4224:
		earthquake_values.append(1)

	var earthquake_random := SequenceRandom.new(earthquake_values)
	var earthquake_start := DisasterStart.start(
		earthquake_fixture.city,
		DisasterStart.DISASTER_EARTHQUAKE,
		earthquake_point,
		earthquake_random,
		SequenceLfsrRandom.new([]),
	)
	_check(
		earthquake_start.ok
		and earthquake_start.started
		and earthquake_start.complete
		and earthquake_start.counters.gate_attempts == 4225
		and earthquake_start.counters.gate_hits == 1
		and earthquake_start.counters.eligible_targets == 1
		and earthquake_start.counters.fire_damage_attempts == 1
		and earthquake_start.counters.structure_damage_attempts == 0
		and earthquake_start.map_changed,
		"Earthquake scans all 65 by 65 offsets and selects fire damage with the next random value",
	)
	_check(
		earthquake_random.position == 4226
		and earthquake_fixture.city.text_overlay_id(
			earthquake_damage_point.x, earthquake_damage_point.y
		) == DisasterMap.FIRE_OVERLAY,
		"Earthquake consumes one gate per offset and starts fire on its selected cell",
	)
	_check(
		earthquake_start.effect_events.size() == 1
		and earthquake_start.effect_events[0].type == "earthquake"
		and earthquake_start.effect_events[0].frames == 24
		and earthquake_start.effect_events[0].frame_msec == 5
		and earthquake_start.effect_events[0].distance == 4
		and earthquake_start.sound_events.size() == 25
		and earthquake_start.sound_events[0].equals(SoundEvent.new(DisasterStart.SOUND_EARTHQUAKE))
		and earthquake_start.sound_events[23].equals(SoundEvent.new(DisasterStart.SOUND_EARTHQUAKE))
		and earthquake_start.sound_events[24].equals(SoundEvent.new(DisasterStart.SOUND_SIREN))
		and earthquake_start.view_center_requests == [earthquake_point],
		"Earthquake reports its 24 shake frames, repeated sound, siren, and view center",
	)

	var empty_earthquake_fixture := _fire_map_fixture(
		reference_root, Vector2i(20, 20), Tiles.EMPTY
	)
	_check(
		empty_earthquake_fixture.city.set_text_overlay_id(20, 20, 0),
		"Empty earthquake fixture clears its inherited fire marker",
	)
	var empty_earthquake_values: Array[int] = [0]

	for _gate in 4224:
		empty_earthquake_values.append(1)

	var empty_earthquake_random := SequenceRandom.new(empty_earthquake_values)
	var empty_earthquake := DisasterStart.start(
		empty_earthquake_fixture.city,
		DisasterStart.DISASTER_EARTHQUAKE,
		Vector2i.ZERO,
		empty_earthquake_random,
		SequenceLfsrRandom.new([]),
	)
	_check(
		empty_earthquake.ok
		and empty_earthquake.started
		and not empty_earthquake.map_changed
		and empty_earthquake.counters.gate_hits == 1
		and empty_earthquake.counters.eligible_targets == 0
		and empty_earthquake_random.position == 4225,
		"Earthquake consumes its random gate before it rejects an out-of-map offset",
	)

	var meltdown_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			meltdown_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Meltdown fixture clears %s" % chunk_id,
		)

	_check(
		meltdown_document.find_chunk("ALTM").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT * 2, 0)
		)
		and meltdown_document.find_chunk("XTRF").set_decoded_payload(
			_filled_bytes(64 * 64, 9)
		)
		and meltdown_document.find_chunk("XLAB").set_decoded_payload(
			_filled_bytes(CityState.LABEL_COUNT * CityState.LABEL_RECORD_SIZE, 0)
		)
		and meltdown_document.find_chunk("XMIC").set_decoded_payload(
			_filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
		),
		"Meltdown fixture clears linked map state",
	)
	var meltdown_buildings: PackedByteArray = (
		meltdown_document.find_chunk("XBLD").decoded_payload.duplicate()
	)
	var meltdown_zones: PackedByteArray = (
		meltdown_document.find_chunk("XZON").decoded_payload.duplicate()
	)
	var meltdown_flags: PackedByteArray = (
		meltdown_document.find_chunk("XBIT").decoded_payload.duplicate()
	)
	var military_target := Vector2i(32, 33)
	var fire_target := Vector2i(32, 34)
	var toxic_target := Vector2i(32, 35)
	meltdown_buildings[military_target.x * CityState.MAP_SIZE + military_target.y] = Tiles.RUNWAY
	meltdown_zones[military_target.x * CityState.MAP_SIZE + military_target.y] = 7
	meltdown_buildings[toxic_target.x * CityState.MAP_SIZE + toxic_target.y] = Tiles.SMALL_PARK
	meltdown_flags[toxic_target.x * CityState.MAP_SIZE + toxic_target.y] = 0x04
	_check(
		meltdown_document.find_chunk("XBLD").set_decoded_payload(meltdown_buildings)
		and meltdown_document.find_chunk("XZON").set_decoded_payload(meltdown_zones)
		and meltdown_document.find_chunk("XBIT").set_decoded_payload(meltdown_flags),
		"Meltdown fixture installs military, fire, and water-toxic targets",
	)
	var meltdown_misc: PackedByteArray = (
		meltdown_document.find_chunk("MISC").decoded_payload.duplicate()
	)

	for tile_id in 256:
		_write_u32_be(meltdown_misc, Buildings.MISC_TILE_COUNTS + tile_id * 4, 0)

	for military_index in 16:
		_write_u32_be(
			meltdown_misc,
			Growth.MISC_MILITARY_TILE_COUNTS + military_index * 4,
			0,
		)

	_write_u32_be(meltdown_misc, Buildings.MISC_TILE_COUNTS, CityState.TILE_COUNT - 2)
	_write_u32_be(meltdown_misc, Buildings.MISC_TILE_COUNTS + 0x0d * 4, 1)
	_write_u32_be(meltdown_misc, Growth.MISC_MILITARY_TILE_COUNTS + 4, 1)
	_write_u32_be(meltdown_misc, Buildings.MISC_FUNDS, 50000)
	_write_u32_be(
		meltdown_misc,
		ToolAvailability.MISC_INVENTION_YEARS + 4,
		0,
	)
	_check(
		meltdown_document.find_chunk("MISC").set_decoded_payload(meltdown_misc),
		"Meltdown fixture initializes normal and military tile counts",
	)
	var meltdown_city := CityModel.from_document(meltdown_document)
	var nuclear_placement := Buildings.apply(
		meltdown_city,
		3,
		6,
		Vector2i(64, 64),
		LfsrRandom.new(1),
		Random.new(1),
	)
	_check(
		nuclear_placement.ok
		and nuclear_placement.site == Rect2i(63, 63, 4, 4)
		and nuclear_placement.tile_id == DisasterStart.NUCLEAR_POWER_PLANT,
		"Meltdown fixture places one valid four-by-four nuclear power plant",
	)
	var meltdown_random := SparseRandom.new({
		144: 0,
		145: 1,
		147: 1,
		148: 0,
		149: 0,
		150: 0,
		151: 1,
		153: 1,
	})
	var meltdown_start := DisasterStart.start(
		meltdown_city,
		DisasterStart.DISASTER_MELTDOWN,
		Vector2i.ZERO,
		meltdown_random,
		SequenceLfsrRandom.new([]),
	)
	var meltdown_center := Vector2i(64, 65)
	_check(
		meltdown_start.ok
		and meltdown_start.started
		and meltdown_start.complete
		and meltdown_start.plant_point == Vector2i(63, 63)
		and meltdown_start.plant_site == Rect2i(63, 63, 4, 4)
		and meltdown_start.point == meltdown_center
		and meltdown_start.view_center_requests == [meltdown_center]
		and SoundEvent.same_arrays(meltdown_start.sound_events, SoundEvent.from_ids([
			DisasterStart.SOUND_EARTHQUAKE, DisasterStart.SOUND_SIREN,
		]))
		and meltdown_start.effect_events.size() == 64
		and meltdown_start.effect_events[0].frame == 0
		and meltdown_start.effect_events[16].frame == 1
		and meltdown_start.effect_events[63].frame == 3,
		"Meltdown finds the first nuclear plant, normalizes its center, and reports a start",
	)
	_check(
		meltdown_start.counters.gate_attempts == 4225
		and meltdown_start.counters.gate_hits == 3
		and meltdown_start.counters.fire_damage_attempts == 1
		and meltdown_start.counters.structure_damage_attempts == 2
		and meltdown_start.counters.radioactive_writes == 17
		and meltdown_start.counters.toxic_writes == 1
		and meltdown_start.map_changed
		and meltdown_random.position == 4392,
		"Meltdown preserves the 65-by-65 scan branches and exact process-random order: %s pos=%d"
		% [meltdown_start, meltdown_random.position],
	)
	_check(
		meltdown_city.building_id(military_target.x, military_target.y)
			== DisasterStart.RADIOACTIVITY_TILE
		and meltdown_city.text_overlay_id(fire_target.x, fire_target.y)
			== DisasterMap.FIRE_OVERLAY
		and meltdown_city.text_overlay_id(toxic_target.x, toxic_target.y)
			== DisasterMap.TOXIC_OVERLAY
		and meltdown_city.tile_flags[
			toxic_target.x * CityState.MAP_SIZE + toxic_target.y
		] & 0x04 != 0,
		"Meltdown writes radiation on dry land, fire on an open cell, and toxic waste on water: military=%d fire=%d toxic=%d flags=%d"
		% [
			meltdown_city.building_id(military_target.x, military_target.y),
			meltdown_city.text_overlay_id(fire_target.x, fire_target.y),
			meltdown_city.text_overlay_id(toxic_target.x, toxic_target.y),
			meltdown_city.tile_flags[toxic_target.x * CityState.MAP_SIZE + toxic_target.y],
		],
	)
	var stored_meltdown_misc: PackedByteArray = (
		meltdown_document.find_chunk("MISC").decoded_payload
	)
	_check(
		BuildingState.read_u32_be(
			stored_meltdown_misc, Buildings.MISC_TILE_COUNTS + 0xcb * 4
		) == 0
		and BuildingState.read_u32_be(
			stored_meltdown_misc, Buildings.MISC_TILE_COUNTS + 0x05 * 4
		) == 16
		and BuildingState.read_u32_be(
			stored_meltdown_misc, Growth.MISC_MILITARY_TILE_COUNTS
		) == 1
		and BuildingState.read_u32_be(
			stored_meltdown_misc, Growth.MISC_MILITARY_TILE_COUNTS + 4
		) == 0,
		"Meltdown moves normal and military tile counts to their radiation buckets: nuclear=%d normal=%d military0=%d military1=%d"
		% [
			BuildingState.read_u32_be(
				stored_meltdown_misc, Buildings.MISC_TILE_COUNTS + 0xcb * 4
			),
			BuildingState.read_u32_be(
				stored_meltdown_misc, Buildings.MISC_TILE_COUNTS + 0x05 * 4
			),
			BuildingState.read_u32_be(
				stored_meltdown_misc, Growth.MISC_MILITARY_TILE_COUNTS
			),
			BuildingState.read_u32_be(
				stored_meltdown_misc, Growth.MISC_MILITARY_TILE_COUNTS + 4
			),
		],
	)

	for x in range(63, 67):
		for y in range(63, 67):
			_check(
				meltdown_city.building_id(x, y) == DisasterStart.RADIOACTIVITY_TILE,
				"Meltdown radiation core covers plant tile %d,%d" % [x, y],
			)

	var no_plant_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(
		no_plant_document.find_chunk("XBLD").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		),
		"No-plant meltdown fixture clears all nuclear plants",
	)
	var no_plant_random := SparseRandom.new({})
	var no_plant_meltdown := DisasterStart.start(
		CityModel.from_document(no_plant_document),
		DisasterStart.DISASTER_MELTDOWN,
		Vector2i(20, 20),
		no_plant_random,
		SequenceLfsrRandom.new([]),
	)
	_check(
		no_plant_meltdown.ok
		and not no_plant_meltdown.started
		and no_plant_meltdown.complete
		and no_plant_meltdown.sound_events.is_empty()
		and no_plant_random.position == 0,
		"Meltdown does not start or consume random state when the city has no nuclear plant",
	)

	var microwave_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			microwave_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Microwave fixture clears %s" % chunk_id,
		)

	_check(
		microwave_document.find_chunk("ALTM").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT * 2, 0)
		)
		and microwave_document.find_chunk("XTRF").set_decoded_payload(
			_filled_bytes(64 * 64, 9)
		),
		"Microwave fixture clears altitude and fills traffic",
	)
	var microwave_plant := Vector2i(10, 10)
	var microwave_water := Vector2i(20, 10)
	var microwave_buildings: PackedByteArray = (
		microwave_document.find_chunk("XBLD").decoded_payload.duplicate()
	)
	var microwave_flags: PackedByteArray = (
		microwave_document.find_chunk("XBIT").decoded_payload.duplicate()
	)
	microwave_buildings[microwave_plant.x * CityState.MAP_SIZE + microwave_plant.y] = (
		DisasterStart.MICROWAVE_POWER_PLANT
	)
	microwave_flags[microwave_water.x * CityState.MAP_SIZE + microwave_water.y] = 0x04
	_check(
		microwave_document.find_chunk("XBLD").set_decoded_payload(microwave_buildings)
		and microwave_document.find_chunk("XBIT").set_decoded_payload(microwave_flags),
		"Microwave fixture places its plant and one water path cell",
	)
	var microwave_city := CityModel.from_document(microwave_document)
	var microwave_values: Array[int] = []

	for _step in 40:
		microwave_values.append(2)

	var microwave_random := SequenceRandom.new(microwave_values)
	var microwave_start := DisasterStart.start(
		microwave_city,
		DisasterStart.DISASTER_MICROWAVE,
		Vector2i(99, 99),
		microwave_random,
		SequenceLfsrRandom.new([]),
	)
	_check(
		microwave_start.ok
		and microwave_start.started
		and microwave_start.complete
		and microwave_start.plant_point == microwave_plant
		and microwave_start.point == microwave_plant
		and microwave_start.path_finish == Vector2i(49, 10)
		and microwave_start.counters.path_steps == 39
		and microwave_start.counters.damage_attempts == 38
		and microwave_start.counters.toxic_writes == 1
		and microwave_start.map_changed
		and microwave_random.position == 40,
		"Microwave ignores the requested point and follows 39 random eight-direction steps",
	)
	_check(
		microwave_start.view_center_requests == [
			Vector2i(10, 10),
			Vector2i(19, 10),
			Vector2i(29, 10),
			Vector2i(39, 10),
		]
		and microwave_start.sound_events.size() == 39
		and microwave_start.sound_events[0].equals(SoundEvent.new(DisasterStart.SOUND_MICROWAVE))
		and microwave_start.sound_events[-2].equals(SoundEvent.new(DisasterStart.SOUND_MICROWAVE))
		and microwave_start.sound_events[-1].equals(SoundEvent.new(DisasterStart.SOUND_SIREN)),
		"Microwave requests periodic view centers, one sound per damaged point, and the siren",
	)
	_check(
		microwave_city.building_id(microwave_plant.x, microwave_plant.y)
			== DisasterStart.MICROWAVE_POWER_PLANT
		and microwave_city.text_overlay_id(microwave_plant.x, microwave_plant.y) == 0
		and microwave_city.text_overlay_id(11, 10) == DisasterMap.FIRE_OVERLAY
		and microwave_city.text_overlay_id(microwave_water.x, microwave_water.y)
			== DisasterMap.TOXIC_OVERLAY
		and microwave_city.text_overlay_id(48, 10) == DisasterMap.FIRE_OVERLAY,
		"Microwave preserves its plant, burns dry path cells, and writes toxic waste on water",
	)
	var edge_microwave_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)
	var edge_microwave_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)
	edge_microwave_buildings[127 * CityState.MAP_SIZE + 10] = (
		DisasterStart.MICROWAVE_POWER_PLANT
	)
	_check(
		edge_microwave_document.find_chunk("XBLD").set_decoded_payload(
			edge_microwave_buildings
		),
		"Edge Microwave fixture places one plant at the east boundary",
	)
	var edge_microwave_random := SequenceRandom.new([2, 7])
	var edge_microwave := DisasterStart.start(
		CityModel.from_document(edge_microwave_document),
		DisasterStart.DISASTER_MICROWAVE,
		Vector2i.ZERO,
		edge_microwave_random,
		SequenceLfsrRandom.new([]),
	)
	_check(
		edge_microwave.ok
		and edge_microwave.started
		and edge_microwave.counters.path_steps == 1
		and edge_microwave.path_finish == Vector2i(128, 10)
		and edge_microwave.counters.damage_attempts == 0
		and not edge_microwave.map_changed
		and SoundEvent.same_arrays(edge_microwave.sound_events, SoundEvent.from_ids([DisasterStart.SOUND_SIREN]))
		and edge_microwave_random.position == 2,
		"Microwave stops after an out-of-map move and retains its final random read",
	)
	var no_microwave_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(
		no_microwave_document.find_chunk("XBLD").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		),
		"No-plant Microwave fixture clears every microwave plant",
	)
	var no_microwave_random := SparseRandom.new({})
	var no_microwave := DisasterStart.start(
		CityModel.from_document(no_microwave_document),
		DisasterStart.DISASTER_MICROWAVE,
		Vector2i.ZERO,
		no_microwave_random,
		SequenceLfsrRandom.new([]),
	)
	_check(
		no_microwave.ok
		and not no_microwave.started
		and no_microwave.complete
		and no_microwave.sound_events.is_empty()
		and no_microwave_random.position == 0,
		"Microwave does not start or consume random state when no microwave plant exists",
	)

	var volcano_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			volcano_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Volcano fixture clears %s" % chunk_id,
		)

	_check(
		volcano_document.find_chunk("ALTM").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT * 2, 0)
		)
		and volcano_document.set_misc_i32(0x14, 12345)
		and volcano_document.set_misc_u32(0x0e40, 0),
		"Volcano fixture clears altitude and sets city funds and sea level",
	)
	var volcano_city := CityModel.from_document(volcano_document)
	var volcano_random := SparseRandom.new({}, 0)
	var volcano := DisasterStart.start(
		volcano_city,
		DisasterStart.DISASTER_VOLCANO,
		Vector2i(64, 64),
		volcano_random,
	)
	_check(
		volcano.ok
		and volcano.started
		and volcano.complete
		and volcano.point == Vector2i(64, 64)
		and volcano.counters.successful_raises > 0
		and volcano.counters.rejected_raises == 0
		and volcano.counters.temporary_budget_spent == DisasterStart.VOLCANO_BUDGET
		and volcano.map_changed
		and volcano_city.funds() == 12345,
		"Volcano spends its separate terrain budget and preserves city funds",
	)
	_check(
		volcano_city.land_altitude(62, 62) > 0
		and volcano_city.text_overlay_id(62, 62) == DisasterMap.TOXIC_OVERLAY
		and volcano_city.text_overlay_id(48, 48) == DisasterMap.FIRE_OVERLAY
		and volcano.counters.near_toxic_writes == volcano.counters.iterations
		and volcano.counters.distant_fire_writes == volcano.counters.iterations,
		"Volcano raises its five-by-five core and writes the two recovered marker classes",
	)
	_check(
		volcano_random.position == volcano.counters.iterations * 6
		and SoundEvent.same_arrays(volcano.sound_events, SoundEvent.from_ids([
			DisasterStart.SOUND_VOLCANO,
			DisasterStart.SOUND_SIREN,
		]))
		and volcano.view_center_requests == [Vector2i(64, 64)],
		"Volcano preserves the per-iteration random order, sound gate, and view center",
	)

	var wet_volcano_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XTXT"]:
		_check(
			wet_volcano_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Wet Volcano fixture clears %s" % chunk_id,
		)

	_check(
		wet_volcano_document.find_chunk("ALTM").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT * 2, 0)
		)
		and wet_volcano_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0x04)
		),
		"Wet Volcano fixture clears altitude and marks every cell as water",
	)
	var wet_volcano_city := CityModel.from_document(wet_volcano_document)
	var wet_volcano_random := SparseRandom.new({}, 0)
	var wet_volcano := DisasterStart.start(
		wet_volcano_city,
		DisasterStart.DISASTER_VOLCANO,
		Vector2i(64, 64),
		wet_volcano_random,
	)
	_check(
		wet_volcano.ok
		and wet_volcano.started
		and wet_volcano.counters.iterations == 25
		and wet_volcano.counters.successful_raises == 0
		and wet_volcano.counters.rejected_raises == 25
		and wet_volcano.counters.temporary_budget_spent == DisasterStart.VOLCANO_BUDGET
		and wet_volcano_city.land_altitude(62, 62) == 0
		and wet_volcano_city.text_overlay_id(48, 48) == DisasterMap.TOXIC_OVERLAY
		and wet_volcano_random.position == 150,
		"Volcano charges 1,000 temporary dollars for each rejected water raise",
	)

	var firestorm_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			firestorm_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Firestorm fixture clears %s" % chunk_id,
		)

	_check(
		firestorm_document.find_chunk("ALTM").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT * 2, 0)
		)
		and firestorm_document.find_chunk("XTRF").set_decoded_payload(
			_filled_bytes(64 * 64, 9)
		),
		"Firestorm fixture clears altitude and fills traffic",
	)
	var firestorm_city := CityModel.from_document(firestorm_document)
	var firestorm_random := SparseRandom.new({})
	var firestorm_lfsr := SequenceLfsrRandom.new([])
	var firestorm := DisasterStart.start(
		firestorm_city,
		DisasterStart.DISASTER_FIRESTORM,
		Vector2i(64, 64),
		firestorm_random,
		firestorm_lfsr,
	)
	_check(
		firestorm.ok
		and firestorm.started
		and firestorm.complete
		and firestorm.counters.successful_cells == 65
		and firestorm.counters.remaining_cells == 0
		and firestorm.counters.scan_steps == 65
		and firestorm.counters.attempted_in_map == 65
		and firestorm.scan_finish == Vector2i(67, 68)
		and firestorm.map_changed,
		"Firestorm stops after 65 accepted cells on its clockwise square spiral",
	)
	_check(
		firestorm.accepted_points.size() == 65
		and firestorm.accepted_points[0] == Vector2i(64, 63)
		and firestorm.accepted_points[-1] == Vector2i(67, 68)
		and firestorm.result_codes.size() == 65
		and firestorm.result_codes.count(1) == 65
		and firestorm_city.text_overlay_id(64, 63) == DisasterMap.FIRE_OVERLAY
		and firestorm_city.text_overlay_id(67, 68) == DisasterMap.FIRE_OVERLAY,
		"Firestorm uses the shared small-tile damage option for every accepted cell",
	)
	_check(
		SoundEvent.same_arrays(firestorm.sound_events, SoundEvent.from_ids([DisasterStart.SOUND_SIREN]))
		and firestorm.view_center_requests == [Vector2i(67, 68)]
		and firestorm_random.position == 0
		and firestorm_lfsr.position == 0,
		"Clear Firestorm cells consume no random state and center the view on the last scan cell",
	)

	var blocked_firestorm_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)
	_check(
		blocked_firestorm_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0x04)
		),
		"Blocked Firestorm fixture marks every cell as water",
	)
	var blocked_firestorm := DisasterStart.start(
		CityModel.from_document(blocked_firestorm_document),
		DisasterStart.DISASTER_FIRESTORM,
		Vector2i(64, 64),
		SparseRandom.new({}),
		SequenceLfsrRandom.new([]),
	)
	_check(
		blocked_firestorm.ok
		and not blocked_firestorm.started
		and blocked_firestorm.complete
		and blocked_firestorm.counters.successful_cells == 0
		and blocked_firestorm.counters.scan_steps == 16256
		and blocked_firestorm.counters.attempted_in_map == 16255
		and blocked_firestorm.scan_finish == Vector2i(128, 0)
		and not blocked_firestorm.map_changed
		and blocked_firestorm.sound_events.is_empty()
		and blocked_firestorm.view_center_requests.is_empty(),
		"Firestorm reports failure after its full run-length-127 spiral finds no dry cell",
	)

	var mass_flood_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			mass_flood_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Mass Floods fixture clears %s" % chunk_id,
		)

	_check(
		mass_flood_document.find_chunk("ALTM").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT * 2, 0)
		)
		and mass_flood_document.find_chunk("XTRF").set_decoded_payload(
			_filled_bytes(64 * 64, 9)
		)
		and mass_flood_document.set_misc_u32(DisasterStart.MISC_NORMAL_POPULATION, 0),
		"Mass Floods fixture clears altitude and population and fills traffic",
	)
	var mass_flood_terrain := _filled_bytes(CityState.TILE_COUNT, 0)
	mass_flood_terrain[64 * CityState.MAP_SIZE + 64] = 0x20
	_check(
		mass_flood_document.find_chunk("XTER").set_decoded_payload(mass_flood_terrain),
		"Mass Floods fixture places one shoreline cell",
	)
	var mass_flood_city := CityModel.from_document(mass_flood_document)
	var mass_flood_random := SparseRandom.new({}, 16)
	var mass_flood_lfsr := SequenceLfsrRandom.new([])
	var mass_flood := DisasterStart.start(
		mass_flood_city,
		DisasterStart.DISASTER_MASS_FLOODS,
		Vector2i(64, 64),
		mass_flood_random,
		mass_flood_lfsr,
	)
	_check(
		mass_flood.ok
		and mass_flood.started
		and mass_flood.complete
		and mass_flood.counters.attempt_count == 5
		and mass_flood.counters.valid_candidates == 5
		and mass_flood.counters.seed_writes == 5
		and mass_flood.counters.delay_frames == 5
		and mass_flood.map_counter == 60
		and mass_flood.map_changed,
		"Mass Floods runs five ordinary Flood starts for a zero-population city",
	)
	_check(
		mass_flood.candidate_points.size() == 5
		and mass_flood.candidate_points.count(Vector2i(64, 64)) == 5
		and mass_flood.seed_points.size() == 5
		and mass_flood.seed_points.count(Vector2i(64, 64)) == 5
		and mass_flood_city.text_overlay_id(65, 64) == DisasterMap.FLOOD_OVERLAY
		and mass_flood_city.text_overlay_id(64, 65) == DisasterMap.FLOOD_OVERLAY,
		"Each valid Mass Floods candidate uses the ordinary shoreline and asymmetric seed rules",
	)
	_check(
		mass_flood.sound_events.size() == 6
		and SoundEvent.count_plain(mass_flood.sound_events, DisasterStart.SOUND_FLOOD) == 5
		and mass_flood.sound_events[-1].equals(SoundEvent.new(DisasterStart.SOUND_SIREN))
		and mass_flood.view_center_requests == [Vector2i(64, 64)]
		and mass_flood_random.position == 10
		and mass_flood_lfsr.position == 0,
		"Mass Floods preserves candidate random order, flood sounds, and the original view center",
	)

	var invalid_mass_flood_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)
	_check(
		invalid_mass_flood_document.set_misc_u32(
			DisasterStart.MISC_NORMAL_POPULATION, 0
		),
		"Invalid Mass Floods fixture clears normal population",
	)
	var invalid_mass_flood_random := SparseRandom.new({}, 0)
	var invalid_mass_flood_lfsr := SequenceLfsrRandom.new([])
	var invalid_mass_flood := DisasterStart.start(
		CityModel.from_document(invalid_mass_flood_document),
		DisasterStart.DISASTER_MASS_FLOODS,
		Vector2i.ZERO,
		invalid_mass_flood_random,
		invalid_mass_flood_lfsr,
	)
	_check(
		invalid_mass_flood.ok
		and not invalid_mass_flood.started
		and invalid_mass_flood.complete
		and invalid_mass_flood.counters.attempt_count == 5
		and invalid_mass_flood.counters.valid_candidates == 0
		and invalid_mass_flood.counters.seed_writes == 0
		and invalid_mass_flood.map_counter == 0
		and not invalid_mass_flood.map_changed
		and invalid_mass_flood.sound_events.is_empty()
		and invalid_mass_flood.view_center_requests.is_empty()
		and invalid_mass_flood_random.position == 10
		and invalid_mass_flood_lfsr.position == 0,
		"Mass Floods consumes point values but skips the Flood helper for invalid candidates",
	)

	var hurricane_cases := [
		{"rotation": 3, "direction": 0, "damage": 20, "flood": 50, "lfsr": 70},
		{"rotation": 0, "direction": 1, "damage": 20, "flood": 100, "lfsr": 120},
		{"rotation": 1, "direction": 2, "damage": 10, "flood": 100, "lfsr": 110},
		{"rotation": 2, "direction": 3, "damage": 20, "flood": 50, "lfsr": 70},
	]

	for hurricane_case in hurricane_cases:
		var hurricane_document := _load_fixture(
			reference_root.path_join("DEFAULT.SC2")
		)

		for chunk_id in ["XTER", "XZON", "XUND", "XBIT", "XTXT"]:
			_check(
				hurricane_document.find_chunk(chunk_id).set_decoded_payload(
					_filled_bytes(CityState.TILE_COUNT, 0)
				),
				"Hurricane direction %d clears %s" % [hurricane_case.direction, chunk_id],
			)

		_check(
			hurricane_document.find_chunk("XBLD").set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0x1d)
			)
			and hurricane_document.find_chunk("ALTM").set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT * 2, 0)
			)
			and hurricane_document.find_chunk("XTRF").set_decoded_payload(
				_filled_bytes(64 * 64, 9)
			)
			and hurricane_document.set_misc_u32(0x08, hurricane_case.rotation),
			"Hurricane direction %d installs a uniform edge target map"
			% hurricane_case.direction,
		)
		var hurricane_values: Array[int] = []

		for value in hurricane_case.lfsr:
			hurricane_values.append(value)

		var hurricane_lfsr := SequenceLfsrRandom.new(hurricane_values)
		var hurricane_random := SequenceRandom.new([])
		var hurricane_city := CityModel.from_document(hurricane_document)
		var hurricane := DisasterStart.start(
			hurricane_city,
			DisasterStart.DISASTER_HURRICANE,
			Vector2i(64, 64),
			hurricane_random,
			hurricane_lfsr,
		)
		_check(
			hurricane.ok
			and hurricane.started
			and hurricane.complete
			and hurricane.direction == hurricane_case.direction
			and hurricane.counters.damage_scans == hurricane_case.damage
			and hurricane.counters.damage_attempts == hurricane_case.damage
			and hurricane.counters.flood_attempts == hurricane_case.flood
			and hurricane.counters.flood_writes == hurricane_case.flood
			and hurricane.map_counter == 60
			and hurricane.hurricane_counter == 50
			and hurricane.map_changed,
			"Hurricane direction %d preserves its damage and flood budgets"
			% hurricane_case.direction,
		)
		_check(
			hurricane_lfsr.position == hurricane_case.lfsr
			and hurricane.view_center_requests.is_empty()
			and hurricane.sound_events[0].equals(SoundEvent.new(DisasterStart.SOUND_HURRICANE))
			and hurricane.sound_events[-2].equals(SoundEvent.new(DisasterStart.SOUND_HURRICANE))
			and hurricane.sound_events[-1].equals(SoundEvent.new(DisasterStart.SOUND_SIREN)),
			"Hurricane direction %d preserves random use, sound order, and no view center"
			% hurricane_case.direction,
		)
		var expected_effects: int = 20 if hurricane_case.direction in [0, 3] else 0
		var last_effect_frame := (
			int(hurricane.effect_events[-1].frame)
			if not hurricane.effect_events.is_empty()
			else -1
		)
		_check(
			hurricane.effect_events.size() == expected_effects
			and SoundEvent.count_plain(hurricane.sound_events, DisasterStart.SOUND_EARTHQUAKE)
			== expected_effects
			and last_effect_frame == expected_effects - 1,
			"Hurricane direction %d emits sequential source-enabled edge damage effects"
			% hurricane_case.direction,
		)

	var fallback_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var fallback_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)
	fallback_buildings[12 * CityState.MAP_SIZE + 13] = Tiles.TREES_1
	_check(
		fallback_document.find_chunk("XBLD").set_decoded_payload(fallback_buildings)
		and fallback_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and fallback_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and fallback_document.set_misc_u32(DisasterStart.MISC_CITY_CENTER_X, 64)
		and fallback_document.set_misc_u32(DisasterStart.MISC_CITY_CENTER_Y, 64),
		"Fire fallback fixture installs one non-building surface tile",
	)
	var fallback_city := CityModel.from_document(fallback_document)
	var fallback_lfsr := SequenceLfsrRandom.new([12, 13])
	var fallback := DisasterStart.start(
		fallback_city,
		DisasterStart.DISASTER_FIRE,
		Vector2i(99, 99),
		SequenceRandom.new([20, 20]),
		fallback_lfsr
	)
	_check(
		fallback.ok
		and fallback.started
		and fallback.point == Vector2i(12, 13)
		and fallback_city.text_overlay_id(12, 13) == 0xff
		and fallback_lfsr.position == 2,
		"Fire falls back to two game-LFSR coordinates after the spiral fails",
	)

	var tornado_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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

	var wrapper_before: PackedByteArray = tornado_document.find_chunk("XTHG").decoded_payload.duplicate()
	var air_wrapper := DisasterStart.start(
		tornado_city,
		DisasterStart.DISASTER_AIR_CRASH,
		Vector2i(10, 10),
		SequenceRandom.new([])
	)
	var helicopter_wrapper := DisasterStart.start(
		tornado_city,
		DisasterStart.DISASTER_HELICOPTER_CRASH,
		Vector2i(11, 11),
		SequenceRandom.new([])
	)
	_check(
		air_wrapper.ok
		and air_wrapper.started
		and air_wrapper.view_center_requests.is_empty()
		and helicopter_wrapper.ok
		and helicopter_wrapper.started
		and helicopter_wrapper.view_center_requests.is_empty(),
		"The two original no-op crash wrappers start without moving the view",
	)
	_check(
		tornado_document.find_chunk("XTHG").decoded_payload == wrapper_before,
		"The two crash wrappers preserve the supplied moving objects",
	)

	var plane_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var plane_things := _filled_bytes(CityState.THING_COUNT * CityState.THING_RECORD_SIZE, 0)
	plane_things[CityState.THING_RECORD_SIZE + 1] = 6
	plane_things[CityState.THING_RECORD_SIZE + 8] = 11
	plane_things[CityState.THING_RECORD_SIZE + 9] = 12
	plane_things[CityState.THING_RECORD_SIZE + 11] = 13
	var plane_text := _filled_bytes(CityState.TILE_COUNT, 0)
	plane_text[35 * CityState.MAP_SIZE + 36] = 50
	_check(
		plane_document.find_chunk("XTHG").set_decoded_payload(plane_things)
		and plane_document.find_chunk("XTXT").set_decoded_payload(plane_text),
		"Plane crash fixture installs one occupied random point and a stale free record",
	)
	var plane_city := CityModel.from_document(plane_document)
	var plane_lfsr := SequenceLfsrRandom.new([3, 4, 7, 8])
	var plane_crash := DisasterStart.start(
		plane_city,
		DisasterStart.DISASTER_PLANE_CRASH,
		Vector2i(99, 99),
		SequenceRandom.new([]),
		plane_lfsr
	)
	var crashing_plane := plane_city.thing(1)
	_check(
		plane_crash.ok
		and plane_crash.started
		and plane_crash.point == Vector2i(39, 40)
		and plane_crash.view_center_requests == [Vector2i(39, 40)]
		and plane_lfsr.position == 4,
		"Plane Crash retries an occupied central point and centers on the accepted point",
	)
	_check(
		crashing_plane.type == 1
		and crashing_plane.direction == 6
		and crashing_plane.state == 7
		and crashing_plane.x == 39
		and crashing_plane.y == 40
		and crashing_plane.z == 16
		and crashing_plane.px == 8
		and crashing_plane.py == 8
		and crashing_plane.dx == 11
		and crashing_plane.dy == 12
		and crashing_plane.label == 0
		and crashing_plane.goal == 13,
		"Plane Crash writes only the recovered XTHG fields and preserves stale free fields",
	)
	_check(
		plane_city.text_overlay_id(35, 36) == 50
		and plane_city.text_overlay_id(39, 40) == 202
		and DisasterStartObjectsState.has_active_object(plane_city, DisasterStart.DISASTER_PLANE_CRASH),
		"Plane Crash preserves the rejected label and links an active falling plane",
	)


func _test_disaster_map_phase(reference_root: String) -> void:
	var water := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1, true)
	var water_random := SequenceRandom.new([0])
	var water_lfsr := SequenceLfsrRandom.new([])
	var water_tick := DisasterMapFireFlood.run_fire(water.city, water_random, water_lfsr)
	_check(
		water_tick.ok
		and water_tick.active
		and water_tick.map_changed
		and water_tick.counters.water_extinctions == 1
		and water_tick.counters.remaining_fires == 0
		and SoundEvent.same_arrays(water_tick.sound_events, SoundEvent.from_ids([DisasterMap.SOUND_FIRE])),
		"A selected fire marker on water clears and keeps the disaster active for this scan",
	)
	_check(
		water.city.text_overlay_id(20, 20) == 0
		and water_random.position == 1
		and water_lfsr.position == 0,
		"Water extinction consumes only its process-random update gate",
	)
	var empty_tick := DisasterMapFireFlood.run_fire(
		water.city, SequenceRandom.new([]), SequenceLfsrRandom.new([])
	)
	_check(
		empty_tick.ok and not empty_tick.active and empty_tick.sound_events.is_empty(),
		"A later fire scan ends after no marker remains",
	)

	var spread := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(spread.city.set_building_id(19, 20, Tiles.TREES_1), "Fire spread fixture adds a west target")
	var spread_random := SequenceRandom.new([0, 0])
	var spread_tick := DisasterMapFireFlood.run_fire(
		spread.city, spread_random, SequenceLfsrRandom.new([])
	)
	_check(
		spread_tick.ok
		and spread_tick.counters.spread_attempts == 1
		and spread_tick.counters.spread_fires == 1
		and spread.city.text_overlay_id(19, 20) == 0xff
		and spread_random.position == 2,
		"Fire choice zero spreads west through the shared damage helper",
	)

	var linked_spread := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		linked_spread.city.set_building_id(19, 20, Tiles.LOWER_CLASS_HOMES_1X1_1)
		and linked_spread.city.set_text_overlay_id(19, 20, 51),
		"Linked fire spread fixture adds a west microsimulation building",
	)
	var linked_spread_random := SequenceRandom.new([0, 0, 2, 1])
	var linked_spread_tick := DisasterMapFireFlood.run_fire(
		linked_spread.city, linked_spread_random, SequenceLfsrRandom.new([])
	)
	_check(
		linked_spread_tick.ok
		and linked_spread_tick.counters.spread_fires == 1
		and linked_spread_tick.effect_events.size() == 1
		and linked_spread_tick.effect_events[0].point == Vector2i(19, 20)
		and linked_spread_tick.effect_events[0].sprite_id == 1394
		and linked_spread_tick.effect_events[0].flip
		and SoundEvent.same_arrays(linked_spread_tick.sound_events, SoundEvent.from_ids([
			DisasterMap.SOUND_EARTHQUAKE, DisasterMap.SOUND_FIRE,
		]))
		and linked_spread_random.position == 4,
		"Shared fire damage emits native dust and consumes its two visual random values",
	)

	var covered := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.LOWER_CLASS_HOMES_1X1_1)
	var covered_random := SequenceRandom.new([0, 4, 0, 2])
	var covered_lfsr := SequenceLfsrRandom.new([3])
	var covered_tick := DisasterMapFireFlood.run_fire(covered.city, covered_random, covered_lfsr)
	_check(
		covered_tick.ok
		and covered_tick.counters.coverage_extinctions == 1
		and covered_tick.counters.remaining_fires == 0
		and covered.city.text_overlay_id(20, 20) == 0
		and covered.city.building_id(20, 20) == 4,
		"Fire coverage plus eight extinguishes and replaces a burning structure with LFSR rubble",
	)
	_check(
		covered_random.position == 4 and covered_lfsr.position == 1,
		"Coverage extinction preserves the process and LFSR random order",
	)

	var collapsing := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.LOWER_CLASS_HOMES_1X1_1)
	var collapse_random := SequenceRandom.new([0, 5, 1])
	var collapse_lfsr := SequenceLfsrRandom.new([2, 0])
	var collapse_tick := DisasterMapFireFlood.run_fire(
		collapsing.city, collapse_random, collapse_lfsr
	)
	var explosion: ThingRecord = collapsing.city.thing(1)
	_check(
		collapse_tick.ok
		and collapse_tick.counters.structure_collapses == 1
		and collapse_tick.counters.created_explosions == 1
		and explosion.type == 6
		and explosion.x == 20
		and explosion.y == 20
		and explosion.z == 0
		and explosion.state == 0
		and explosion.goal == 1,
		"Fire choice five collapses a building and creates the gated explosion record",
	)
	_check(
		collapsing.city.text_overlay_id(20, 20) == 202
		and collapse_random.position == 3
		and collapse_lfsr.position == 2,
		"Fire collapse links its explosion and preserves the original random order",
	)
	var toxic := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.CHEMICAL_STORAGE_1X1)
	var toxic_tick := DisasterMapFireFlood.run_fire(
		toxic.city, SequenceRandom.new([0, 5, 1]), SequenceLfsrRandom.new([2, 1])
	)
	_check(
		toxic_tick.ok
		and toxic_tick.counters.structure_collapses == 1
		and toxic_tick.counters.created_explosions == 0
		and toxic_tick.counters.toxic_markers == 1
		and toxic.city.text_overlay_id(20, 20) == DisasterMap.TOXIC_OVERLAY,
		"A special burning structure can leave the recovered toxic marker",
	)

	var expired_toxic := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		expired_toxic.city.set_text_overlay_id(20, 20, DisasterMap.TOXIC_OVERLAY),
		"Toxic expiry fixture installs its marker",
	)
	var toxic_expiry_random := SequenceRandom.new([0])
	var toxic_expiry_lfsr := SequenceLfsrRandom.new([0])
	var toxic_expiry := DisasterMapMarkers.run_toxic(
		expired_toxic.city, toxic_expiry_random, toxic_expiry_lfsr
	)
	_check(
		toxic_expiry.ok
		and toxic_expiry.active
		and toxic_expiry.counters.lfsr_expirations == 1
		and toxic_expiry.counters.remaining_toxic == 0
		and expired_toxic.city.text_overlay_id(20, 20) == 0,
		"A selected toxic marker expires on the one-in-64 LFSR gate",
	)
	_check(
		toxic_expiry_random.position == 1 and toxic_expiry_lfsr.position == 1,
		"Toxic LFSR expiry consumes no later process-random value",
	)

	var water_toxic := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1, true)
	_check(
		water_toxic.city.set_text_overlay_id(20, 20, DisasterMap.TOXIC_OVERLAY),
		"Water toxic fixture installs its marker",
	)
	var water_toxic_random := SequenceRandom.new([0, 0])
	var water_toxic_lfsr := SequenceLfsrRandom.new([1])
	var water_toxic_tick := DisasterMapMarkers.run_toxic(
		water_toxic.city, water_toxic_random, water_toxic_lfsr
	)
	_check(
		water_toxic_tick.ok
		and water_toxic_tick.counters.water_expirations == 1
		and water_toxic_tick.counters.remaining_toxic == 0
		and water_toxic_random.position == 2
		and water_toxic_lfsr.position == 1,
		"A selected toxic marker on water has the recovered one-in-16 expiry gate",
	)

	var downhill_toxic := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		downhill_toxic.city.set_text_overlay_id(20, 20, DisasterMap.TOXIC_OVERLAY)
		and downhill_toxic.city.set_land_altitude(20, 20, 5)
		and downhill_toxic.city.set_land_altitude(19, 20, 3)
		and downhill_toxic.city.set_land_altitude(20, 19, 6)
		and downhill_toxic.city.set_land_altitude(21, 20, 6)
		and downhill_toxic.city.set_land_altitude(20, 21, 6),
		"Downhill toxic fixture sets one lower neighbor",
	)
	var downhill_random := SequenceRandom.new([0])
	var downhill_lfsr := SequenceLfsrRandom.new([1])
	var downhill_tick := DisasterMapMarkers.run_toxic(
		downhill_toxic.city, downhill_random, downhill_lfsr
	)
	_check(
		downhill_tick.ok
		and downhill_tick.counters.moved_markers == 1
		and downhill_tick.counters.remaining_toxic == 1
		and downhill_toxic.city.text_overlay_id(20, 20) == 0
		and downhill_toxic.city.text_overlay_id(19, 20) == DisasterMap.TOXIC_OVERLAY,
		"A toxic marker moves to its first strictly lower cardinal neighbor",
	)
	_check(
		downhill_random.position == 1 and downhill_lfsr.position == 1,
		"A downhill toxic move does not consume a fallback direction value",
	)

	var flat_toxic := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		flat_toxic.city.set_text_overlay_id(20, 20, DisasterMap.TOXIC_OVERLAY)
		and flat_toxic.city.set_land_altitude(20, 20, 5)
		and flat_toxic.city.set_land_altitude(19, 20, 5)
		and flat_toxic.city.set_land_altitude(20, 19, 5)
		and flat_toxic.city.set_land_altitude(21, 20, 5)
		and flat_toxic.city.set_land_altitude(20, 21, 5),
		"Flat toxic fixture levels all cardinal neighbors",
	)
	var flat_random := SequenceRandom.new([0, 2, 1])
	var flat_lfsr := SequenceLfsrRandom.new([1])
	var flat_tick := DisasterMapMarkers.run_toxic(flat_toxic.city, flat_random, flat_lfsr)
	_check(
		flat_tick.ok
		and flat_tick.counters.toxic_markers_scanned == 2
		and flat_tick.counters.toxic_updates == 1
		and flat_tick.counters.moved_markers == 1
		and flat_toxic.city.text_overlay_id(21, 20) == DisasterMap.TOXIC_OVERLAY,
		"A flat toxic marker uses the process-random cardinal direction",
	)
	_check(
		flat_random.position == 3 and flat_lfsr.position == 1,
		"A marker that moves later in scan order receives its native second scan gate",
	)

	var abandoned_toxic := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.LOWER_CLASS_HOMES_1X1_1)
	_check(
		abandoned_toxic.city.set_zone_id(20, 20, 1)
		and abandoned_toxic.city.set_building_corners(20, 20, 0xf0)
		and abandoned_toxic.city.set_text_overlay_id(20, 20, DisasterMap.TOXIC_OVERLAY)
		and abandoned_toxic.city.set_land_altitude(20, 20, 5)
		and abandoned_toxic.city.set_land_altitude(19, 20, 3)
		and abandoned_toxic.city.set_land_altitude(20, 19, 6)
		and abandoned_toxic.city.set_land_altitude(21, 20, 6)
		and abandoned_toxic.city.set_land_altitude(20, 21, 6),
		"Toxic abandonment fixture installs a normal residential building",
	)
	var abandon_random := SequenceRandom.new([0, 1])
	var abandon_tick := DisasterMapMarkers.run_toxic(
		abandoned_toxic.city, abandon_random, SequenceLfsrRandom.new([1])
	)
	_check(
		abandon_tick.ok
		and abandon_tick.counters.abandoned_structures == 1
		and abandoned_toxic.city.building_id(20, 20) == 0x8b
		and abandoned_toxic.city.zone_id(20, 20) == 1,
		"A toxic cloud changes a normal RCI building to its abandoned class before moving",
	)
	_check(
		abandon_random.position == 2,
		"Toxic abandonment consumes the normal building-selection random value",
	)

	var idle_riot := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		idle_riot.city.set_text_overlay_id(20, 20, DisasterMap.RIOT_OVERLAY_REVERSE),
		"Idle riot fixture installs its reverse marker",
	)
	var idle_riot_random := SequenceRandom.new([0, 1, 4, 0])
	var idle_riot_tick := DisasterMapMarkers.run_riot(
		idle_riot.city, idle_riot_random, SequenceLfsrRandom.new([])
	)
	_check(
		idle_riot_tick.ok
		and idle_riot_tick.active
		and idle_riot_tick.counters.riot_updates == 1
		and idle_riot_tick.counters.remaining_riots == 1
		and SoundEvent.same_arrays(idle_riot_tick.sound_events, SoundEvent.from_ids([DisasterMap.SOUND_RIOT]))
		and idle_riot.city.text_overlay_id(20, 20) == DisasterMap.RIOT_OVERLAY_FORWARD,
		"An unsupported reverse riot changes to the forward phase and can request sound",
	)
	_check(
		idle_riot_random.position == 4,
		"An unsupported riot consumes its two gates, damage choice, and final sound gate",
	)

	var water_riot := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1, true)
	_check(
		water_riot.city.set_text_overlay_id(20, 20, DisasterMap.RIOT_OVERLAY_FORWARD),
		"Water riot fixture installs its forward marker",
	)
	var water_riot_random := SequenceRandom.new([0, 1, 1])
	var water_riot_tick := DisasterMapMarkers.run_riot(
		water_riot.city, water_riot_random, SequenceLfsrRandom.new([])
	)
	_check(
		water_riot_tick.ok
		and water_riot_tick.counters.expired_riots == 1
		and water_riot_tick.counters.remaining_riots == 0
		and water_riot_random.position == 3,
		"An updating riot expires on water after its second process-random gate",
	)

	var reverse_riot := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		reverse_riot.city.set_text_overlay_id(20, 20, DisasterMap.RIOT_OVERLAY_REVERSE)
		and reverse_riot.city.set_building_id(19, 20, Tiles.ROAD_STRAIGHT_2),
		"Reverse riot fixture adds a supported west road",
	)
	var reverse_riot_random := SequenceRandom.new([0, 1, 4, 1, 1])
	var reverse_riot_tick := DisasterMapMarkers.run_riot(
		reverse_riot.city, reverse_riot_random, SequenceLfsrRandom.new([])
	)
	_check(
		reverse_riot_tick.ok
		and reverse_riot_tick.counters.propagated_riots == 1
		and reverse_riot.city.text_overlay_id(20, 20) == 0
		and reverse_riot.city.text_overlay_id(19, 20) == DisasterMap.RIOT_OVERLAY_REVERSE,
		"A reverse riot propagates west along a supported network tile",
	)
	_check(
		reverse_riot_random.position == 5,
		"A one-connection reverse riot skips the connection-choice random value",
	)

	var forward_riot := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		forward_riot.city.set_text_overlay_id(20, 20, DisasterMap.RIOT_OVERLAY_FORWARD)
		and forward_riot.city.set_building_id(21, 20, Tiles.TUNNEL_ENTRANCE_1),
		"Forward riot fixture adds a supported east rail tile",
	)
	var forward_riot_random := SequenceRandom.new([0, 1, 4, 1, 1, 1])
	var forward_riot_tick := DisasterMapMarkers.run_riot(
		forward_riot.city, forward_riot_random, SequenceLfsrRandom.new([])
	)
	_check(
		forward_riot_tick.ok
		and forward_riot_tick.counters.riot_markers_scanned == 2
		and forward_riot_tick.counters.riot_updates == 1
		and forward_riot_tick.counters.propagated_riots == 1
		and forward_riot.city.text_overlay_id(21, 20) == DisasterMap.RIOT_OVERLAY_FORWARD,
		"A forward riot propagates east and receives a second scan gate later in the pass",
	)
	_check(
		forward_riot_random.position == 6,
		"Forward riot reprocessing preserves the native in-place random order",
	)

	var damaging_riot := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		damaging_riot.city.set_text_overlay_id(20, 20, DisasterMap.RIOT_OVERLAY_REVERSE)
		and damaging_riot.city.set_building_id(19, 20, Tiles.TREES_1),
		"Riot damage fixture adds a combustible west target",
	)
	var damaging_riot_tick := DisasterMapMarkers.run_riot(
		damaging_riot.city,
		SequenceRandom.new([0, 1, 0, 1]),
		SequenceLfsrRandom.new([]),
	)
	_check(
		damaging_riot_tick.ok
		and damaging_riot_tick.counters.damage_attempts == 1
		and damaging_riot_tick.counters.started_fires == 1
		and damaging_riot.city.text_overlay_id(19, 20) == DisasterMap.FIRE_OVERLAY,
		"A low riot damage choice starts fire through the shared disaster helper",
	)

	var fire_dispatch := _dispatch_map_fixture(
		reference_root, Dispatch.TYPE_FIRE, Vector2i(20, 20)
	)
	_check(
		fire_dispatch.city.set_building_id(19, 20, Tiles.TREES_1)
		and fire_dispatch.city.set_text_overlay_id(19, 20, DisasterMap.FIRE_OVERLAY),
		"Fire dispatch fixture adds a burning west network tile",
	)
	var fire_dispatch_random := SequenceRandom.new([0, 1])
	var fire_dispatch_lfsr := SequenceLfsrRandom.new([2])
	var fire_dispatch_tick := DisasterMapScanDispatch.run_dispatch(
		fire_dispatch.city, fire_dispatch_random, fire_dispatch_lfsr
	)
	_check(
		fire_dispatch_tick.ok
		and fire_dispatch_tick.counters.dispatch_markers_scanned == 1
		and fire_dispatch_tick.counters.fire_suppression_attempts == 1
		and fire_dispatch_tick.counters.fire_extinctions == 1
		and fire_dispatch.city.text_overlay_id(19, 20) == 0
		and fire_dispatch.city.building_id(19, 20) == 3,
		"A fire unit extinguishes its selected neighbor and leaves LFSR-selected rubble",
	)
	_check(
		fire_dispatch_random.position == 2 and fire_dispatch_lfsr.position == 1,
		"Fire dispatch preserves direction, demolition, and rubble random order",
	)

	var rail_dispatch := _dispatch_map_fixture(
		reference_root, Dispatch.TYPE_FIRE, Vector2i(20, 20)
	)
	_check(
		rail_dispatch.city.set_building_id(19, 20, Tiles.TUNNEL_ENTRANCE_1)
		and rail_dispatch.city.set_text_overlay_id(19, 20, DisasterMap.FIRE_OVERLAY),
		"Rail dispatch fixture adds a burning west rail tile",
	)
	var rail_dispatch_tick := DisasterMapScanDispatch.run_dispatch(
		rail_dispatch.city, SequenceRandom.new([0]), SequenceLfsrRandom.new([])
	)
	_check(
		rail_dispatch_tick.ok
		and rail_dispatch_tick.counters.fire_extinctions == 1
		and rail_dispatch.city.text_overlay_id(19, 20) == 0
		and rail_dispatch.city.building_id(19, 20) == 0x3f,
		"Dispatch extinguishes rail values 0x3F through 0x42 without demolition",
	)

	var police_dispatch := _dispatch_map_fixture(
		reference_root, Dispatch.TYPE_POLICE, Vector2i(20, 20)
	)
	_check(
		police_dispatch.city.set_building_id(19, 20, Tiles.TUNNEL_ENTRANCE_1)
		and police_dispatch.city.set_text_overlay_id(19, 20, DisasterMap.FIRE_OVERLAY)
		and police_dispatch.city.set_text_overlay_id(21, 20, DisasterMap.RIOT_OVERLAY_FORWARD),
		"Police dispatch fixture adds west fire and east riot markers",
	)
	var police_dispatch_random := SequenceRandom.new([0, 2])
	var police_dispatch_lfsr := SequenceLfsrRandom.new([0])
	var police_dispatch_tick := DisasterMapScanDispatch.run_dispatch(
		police_dispatch.city, police_dispatch_random, police_dispatch_lfsr
	)
	_check(
		police_dispatch_tick.ok
		and police_dispatch_tick.counters.fire_extinctions == 1
		and police_dispatch_tick.counters.riot_suppressions == 1
		and police_dispatch.city.text_overlay_id(19, 20) == 0
		and police_dispatch.city.text_overlay_id(21, 20) == 0,
		"A police unit can pass its LFSR fire gate and always attempts riot suppression",
	)
	_check(
		police_dispatch_random.position == 2 and police_dispatch_lfsr.position == 1,
		"Police dispatch consumes its LFSR gate before two process-random directions",
	)

	var gated_police := _dispatch_map_fixture(
		reference_root, Dispatch.TYPE_POLICE, Vector2i(20, 20)
	)
	_check(
		gated_police.city.set_building_id(19, 20, Tiles.TUNNEL_ENTRANCE_1)
		and gated_police.city.set_text_overlay_id(19, 20, DisasterMap.FIRE_OVERLAY)
		and gated_police.city.set_text_overlay_id(21, 20, DisasterMap.RIOT_OVERLAY_REVERSE),
		"Gated police fixture adds west fire and east riot markers",
	)
	var gated_police_random := SequenceRandom.new([2])
	var gated_police_tick := DisasterMapScanDispatch.run_dispatch(
		gated_police.city, gated_police_random, SequenceLfsrRandom.new([1])
	)
	_check(
		gated_police_tick.ok
		and gated_police_tick.counters.fire_suppression_attempts == 0
		and gated_police_tick.counters.riot_suppressions == 1
		and gated_police.city.text_overlay_id(19, 20) == DisasterMap.FIRE_OVERLAY
		and gated_police.city.text_overlay_id(21, 20) == 0
		and gated_police_random.position == 1,
		"A failed police fire gate does not block its separate riot-suppression attempt",
	)

	var flood := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		flood.city.set_text_overlay_id(20, 20, 0xfc)
		and flood.city.set_building_id(19, 20, Tiles.TREES_1),
		"Flood tick fixture installs its source and west target",
	)
	var flood_random := SequenceRandom.new([0, 0])
	var flood_lfsr := SequenceLfsrRandom.new([])
	var flood_tick := DisasterMapFireFlood.run_flood(flood.city, flood_random, flood_lfsr, 60)
	_check(
		flood_tick.ok
		and flood_tick.active
		and flood_tick.map_counter == 59
		and flood_tick.counters.flood_updates == 1
		and flood_tick.counters.spread_floods == 1
		and flood_tick.counters.remaining_floods == 2
		and SoundEvent.same_arrays(flood_tick.sound_events, SoundEvent.from_ids([DisasterMap.SOUND_FLOOD]))
		and flood.city.text_overlay_id(19, 20) == 0xfc,
		"An early flood tick spreads west and can request the recovered flood sound",
	)
	_check(
		flood_random.position == 2 and flood_lfsr.position == 0,
		"An early flood spread preserves its process-random order",
	)

	var linked_flood := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		linked_flood.city.set_text_overlay_id(20, 20, 0xfc)
		and linked_flood.city.set_building_id(19, 20, Tiles.LOWER_CLASS_HOMES_1X1_1)
		and linked_flood.city.set_text_overlay_id(19, 20, 51),
		"Linked flood fixture installs a west microsimulation building",
	)
	var linked_flood_random := SequenceRandom.new([0, 2, 1, 1])
	var linked_flood_tick := DisasterMapFireFlood.run_flood(
		linked_flood.city,
		linked_flood_random,
		SequenceLfsrRandom.new([]),
		60,
	)
	_check(
		linked_flood_tick.ok
		and linked_flood_tick.counters.spread_floods == 1
		and linked_flood_tick.effect_events.size() == 1
		and linked_flood_tick.effect_events[0].point == Vector2i(19, 20)
		and linked_flood_tick.effect_events[0].sprite_id == 1394
		and linked_flood_tick.effect_events[0].flip
		and SoundEvent.same_arrays(linked_flood_tick.sound_events, SoundEvent.from_ids([DisasterMap.SOUND_EARTHQUAKE]))
		and linked_flood_random.position == 4,
		"Shared flood damage emits native dust and consumes its two visual random values",
	)

	var expired_flood := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		expired_flood.city.set_text_overlay_id(20, 20, 0xfc),
		"Expired flood fixture installs its marker",
	)
	var expired_random := SequenceRandom.new([1])
	var expired_lfsr := SequenceLfsrRandom.new([1])
	var expired_tick := DisasterMapFireFlood.run_flood(
		expired_flood.city, expired_random, expired_lfsr, 1
	)
	var no_flood_tick := DisasterMapFireFlood.run_flood(
		expired_flood.city, SequenceRandom.new([]), SequenceLfsrRandom.new([]), 0
	)
	_check(
		expired_tick.ok
		and expired_tick.active
		and expired_tick.map_counter == 0
		and expired_tick.counters.expired_floods == 1
		and expired_tick.counters.remaining_floods == 0
		and no_flood_tick.ok
		and not no_flood_tick.active,
		"A zero-counter LFSR bit clears flood and the next scan ends it",
	)
	_check(
		expired_random.position == 1 and expired_lfsr.position == 1,
		"Expired flood consumes its LFSR gate before the final sound gate",
	)

	var uphill := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		uphill.city.set_text_overlay_id(20, 20, 0xfc)
		and uphill.city.set_building_id(19, 20, Tiles.TREES_1)
		and uphill.city.set_land_altitude(20, 20, 0)
		and uphill.city.set_land_altitude(19, 20, 1),
		"Uphill flood fixture raises the west target",
	)
	var uphill_tick := DisasterMapFireFlood.run_flood(
		uphill.city, SequenceRandom.new([0, 1]), SequenceLfsrRandom.new([]), 60
	)
	_check(
		uphill_tick.ok
		and uphill_tick.counters.spread_attempts == 1
		and uphill_tick.counters.spread_floods == 0
		and uphill.city.text_overlay_id(19, 20) == 0,
		"Flood cannot spread to a higher low-five-bit altitude",
	)

	var manual_flood := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.EMPTY)
	var shoreline := _filled_bytes(CityState.TILE_COUNT, 0)
	shoreline[20 * CityState.MAP_SIZE + 20] = 0x20
	_check(
		manual_flood.city.set_text_overlay_id(20, 20, 0)
		and manual_flood.document.find_chunk("XTER").set_decoded_payload(shoreline),
		"Manual flood fixture installs a clear shoreline point",
	)
	var flood_engine := Simulation.new(manual_flood.city, 1, 7, 13)
	var manual_flood_start := flood_engine.start_disaster(
		DisasterStart.DISASTER_FLOOD, Vector2i(20, 20)
	)
	var manual_flood_tick := flood_engine.advance_disaster_tick()
	_check(
		manual_flood_start.ok
		and manual_flood_start.started
		and flood_engine.active_disaster_type == DisasterStart.DISASTER_FLOOD
		and manual_flood_tick.ok
		and manual_flood_tick.active
		and manual_flood_tick.map_counter == 59
		and flood_engine.disaster_map_counter == 59,
		"The engine keeps the flood lifetime counter from start through recurring ticks",
	)

	var engine_fixture := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1, true)
	_check(engine_fixture.document.set_misc_u32(0x0004, 2), "Fire engine fixture selects disaster mode")
	var engine := Simulation.new(engine_fixture.city, 3, 7, 13)
	engine.active_disaster_type = DisasterStart.DISASTER_FIRE
	var active_tick := engine.advance_disaster_tick()
	var ended_tick := engine.advance_disaster_tick()
	_check(
		active_tick.ok
		and active_tick.active
		and ended_tick.ok
		and ended_tick.complete
		and ended_tick.ended_type == DisasterStart.DISASTER_FIRE
		and engine.active_disaster_type == 0
		and engine_fixture.city.city_mode() == 1,
		"The engine runs fire-map ticks and restores city mode one scan after the last fire: %s %s %d %d"
		% [active_tick, ended_tick, engine.active_disaster_type, engine_fixture.city.city_mode()],
	)

	var dispatch_engine_fixture := _dispatch_map_fixture(
		reference_root, Dispatch.TYPE_FIRE, Vector2i(20, 20)
	)
	_check(
		dispatch_engine_fixture.city.set_building_id(19, 20, Tiles.TUNNEL_ENTRANCE_1)
		and dispatch_engine_fixture.city.set_text_overlay_id(
			19, 20, DisasterMap.FIRE_OVERLAY
		)
		and dispatch_engine_fixture.document.set_misc_u32(0x0004, 2),
		"Dispatch engine fixture adds a burning west rail tile",
	)
	var dispatch_engine := Simulation.new(dispatch_engine_fixture.city, 2, 1, 13)
	dispatch_engine.active_disaster_type = DisasterStart.DISASTER_FIRE
	var dispatch_engine_tick := dispatch_engine.advance_disaster_tick()
	_check(
		dispatch_engine_tick.ok
		and dispatch_engine_tick.active
		and dispatch_engine_tick.dispatch_map.counters.fire_extinctions == 1
		and dispatch_engine_fixture.city.text_overlay_id(19, 20) == 0
		and dispatch_engine_fixture.city.building_id(19, 20) == 0x3f,
		"The active disaster engine applies map-side dispatch suppression after its fire scan",
	)

	var mixed_map := _dispatch_map_fixture(
		reference_root, Dispatch.TYPE_FIRE, Vector2i(5, 5)
	)
	_check(
		mixed_map.city != null
		and mixed_map.city.set_text_overlay_id(
			10, 10, DisasterMap.RIOT_OVERLAY_REVERSE
		)
		and mixed_map.city.set_text_overlay_id(20, 20, DisasterMap.FIRE_OVERLAY)
		and mixed_map.city.set_tile_flag(20, 20, 0x04, true),
		"Mixed disaster fixture orders dispatch, riot, and fire markers by map position",
	)
	var mixed_random := SequenceRandom.new([3, 1, 0, 1])
	var mixed_tick := DisasterMapScanDispatch.run_all(
		mixed_map.city, mixed_random, SequenceLfsrRandom.new([]), 0
	)
	_check(
		mixed_tick.ok
		and mixed_tick.active
		and mixed_tick.dispatch_map.counters.fire_suppression_attempts == 1
		and mixed_tick.counters.riot_markers_scanned == 1
		and mixed_tick.counters.fire_markers_scanned == 1
		and mixed_tick.counters.water_extinctions == 1
		and SoundEvent.same_arrays(mixed_tick.sound_events, SoundEvent.from_ids([DisasterMap.SOUND_FIRE])),
		"The combined scan processes all marker classes and keeps original sound order",
	)
	_check(
		mixed_random.position == 4
		and mixed_map.city.text_overlay_id(10, 10) == DisasterMap.RIOT_OVERLAY_REVERSE
		and mixed_map.city.text_overlay_id(20, 20) == 0,
		"The combined scan consumes random state in X-before-Y marker order",
	)

	var hurricane_tick_fixture := _fire_map_fixture(
		reference_root, Vector2i(20, 21), Tiles.LOWER_CLASS_HOMES_1X1_2
	)
	_check(
		hurricane_tick_fixture.city.set_text_overlay_id(20, 21, 0),
		"Hurricane tick fixture clears its tall-building overlay",
	)
	var hurricane_tick_random := SequenceRandom.new([0, 0, 0, 0])
	var hurricane_tick_lfsr := SequenceLfsrRandom.new([0, 20, 21])
	var hurricane_tick := DisasterMapScanDispatch.run_all(
		hurricane_tick_fixture.city,
		hurricane_tick_random,
		hurricane_tick_lfsr,
		60,
		50,
	)
	_check(
		hurricane_tick.ok
		and hurricane_tick.hurricane_counter == 49
		and hurricane_tick.counters.hurricane_damage_attempts == 1
		and hurricane_tick.counters.hurricane_damaged_structures == 1
		and hurricane_tick_fixture.city.building_id(20, 21) < 5
		and hurricane_tick.view_center_requests == [Vector2i(20, 21)],
		"An active hurricane tick can damage and center a source-qualified tall building",
	)
	_check(
		SoundEvent.same_arrays(hurricane_tick.sound_events, SoundEvent.from_ids([
			DisasterMap.SOUND_HURRICANE, DisasterMap.SOUND_EARTHQUAKE,
		]))
		and hurricane_tick.effect_events.size() == 1
		and hurricane_tick_lfsr.position == 3
		and hurricane_tick_random.position == 4,
		"Hurricane recurring damage preserves its sound, effect, and random order",
	)

	var gated_hurricane_fixture := _fire_map_fixture(
		reference_root, Vector2i(20, 21), Tiles.LOWER_CLASS_HOMES_1X1_2
	)
	_check(
		gated_hurricane_fixture.city.set_text_overlay_id(20, 21, 0),
		"Gated hurricane fixture clears its overlay",
	)
	var gated_hurricane_random := SequenceRandom.new([1])
	var gated_hurricane_lfsr := SequenceLfsrRandom.new([1])
	var gated_hurricane_tick := DisasterMapScanDispatch.run_all(
		gated_hurricane_fixture.city,
		gated_hurricane_random,
		gated_hurricane_lfsr,
		60,
		50,
	)
	_check(
		gated_hurricane_tick.ok
		and gated_hurricane_tick.hurricane_counter == 49
		and gated_hurricane_tick.counters.hurricane_damage_attempts == 0
		and not gated_hurricane_tick.map_changed
		and gated_hurricane_tick.sound_events.is_empty()
		and gated_hurricane_random.position == 1
		and gated_hurricane_lfsr.position == 1,
		"A hurricane tick consumes only its sound and LFSR gates when both reject",
	)

	var toxic_engine_fixture := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.TREES_1)
	_check(
		toxic_engine_fixture.city.set_text_overlay_id(20, 20, DisasterMap.TOXIC_OVERLAY)
		and toxic_engine_fixture.document.set_misc_u32(0x0004, 2),
		"Toxic engine fixture selects disaster mode and installs its marker",
	)
	var toxic_engine := Simulation.new(toxic_engine_fixture.city, 0, 0, 13)
	toxic_engine.active_disaster_type = DisasterStart.DISASTER_FIRE
	var active_toxic_tick := toxic_engine.advance_disaster_tick()
	var ended_toxic_tick := toxic_engine.advance_disaster_tick()
	_check(
		active_toxic_tick.ok
		and active_toxic_tick.active
		and active_toxic_tick.counters.lfsr_expirations == 1
		and ended_toxic_tick.ok
		and ended_toxic_tick.complete
		and toxic_engine.active_disaster_type == 0
		and toxic_engine_fixture.city.city_mode() == 1,
		"The engine continues a map disaster through toxic residue and ends one scan later",
	)

	var toxic_spill_fixture := _fire_map_fixture(reference_root, Vector2i(24, 25), Tiles.EMPTY)
	_check(
		toxic_spill_fixture.city.set_text_overlay_id(24, 25, 0),
		"Toxic Spill engine fixture clears its target",
	)
	var toxic_spill_engine := Simulation.new(toxic_spill_fixture.city, 0, 0, 13)
	var toxic_spill_start := toxic_spill_engine.start_disaster(
		DisasterStart.DISASTER_TOXIC_SPILL, Vector2i(24, 25)
	)
	var toxic_spill_tick := toxic_spill_engine.advance_disaster_tick()
	var toxic_spill_end := toxic_spill_engine.advance_disaster_tick()
	_check(
		toxic_spill_start.ok
		and toxic_spill_start.started
		and toxic_spill_engine.active_disaster_type == 0
		and toxic_spill_tick.ok
		and toxic_spill_tick.active
		and toxic_spill_tick.counters.lfsr_expirations == 1
		and toxic_spill_end.ok
		and toxic_spill_end.complete
		and toxic_spill_fixture.city.city_mode() == 1,
		"Toxic Spill enters disaster mode, runs its map branch, and restores city mode",
	)

	var pollution_engine_fixture := _fire_map_fixture(
		reference_root, Vector2i(24, 25), Tiles.EMPTY
	)
	_check(
		pollution_engine_fixture.city.set_text_overlay_id(24, 25, 0)
		and pollution_engine_fixture.document.set_misc_u32(
			DisasterStart.MISC_NORMAL_POPULATION, 0
		),
		"Pollution engine fixture clears its target and population",
	)
	var pollution_engine := Simulation.new(pollution_engine_fixture.city, 0, 0, 13)
	var pollution_engine_start := pollution_engine.start_disaster(
		DisasterStart.DISASTER_POLLUTION, Vector2i(24, 25)
	)
	var pollution_ticks: Array[DisasterMapResult] = []

	while pollution_engine.active_disaster_type != 0 and pollution_ticks.size() < 128:
		var pollution_result := pollution_engine.advance_disaster_tick()
		pollution_ticks.append(pollution_result)

		if not pollution_result.ok:
			break

	var pollution_tick := pollution_ticks[0] if not pollution_ticks.is_empty() else DisasterMapResult.new()
	var pollution_end := pollution_ticks[-1] if not pollution_ticks.is_empty() else DisasterMapResult.new()
	_check(
		pollution_engine_start.ok
		and pollution_engine_start.started
		and pollution_tick.ok
		and pollution_tick.active
		and pollution_end.ok
		and pollution_end.complete
		and pollution_engine.active_disaster_type == 0
		and pollution_engine_fixture.city.city_mode() == 1,
		"Pollution enters disaster mode, runs toxic clouds, and restores city mode: %s %s %s active=%d mode=%d"
		% [pollution_engine_start, pollution_tick, pollution_end, pollution_engine.active_disaster_type, pollution_engine_fixture.city.city_mode()],
	)

	var riot_engine_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)
	_check(
		riot_engine_document.find_chunk("XBLD").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0x1d)
		)
		and riot_engine_document.find_chunk("XBIT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		)
		and riot_engine_document.find_chunk("XTXT").set_decoded_payload(
			_filled_bytes(CityState.TILE_COUNT, 0)
		),
		"Riot engine fixture installs a dry road map",
	)
	var riot_engine_city := CityModel.from_document(riot_engine_document)
	var riot_engine := Simulation.new(riot_engine_city, 1, 7, 13)
	var riot_engine_start := riot_engine.start_disaster(
		DisasterStart.DISASTER_RIOT, Vector2i(64, 64)
	)
	var riot_engine_tick := riot_engine.advance_disaster_tick()
	_check(
		riot_engine_start.ok
		and riot_engine_start.started
		and riot_engine_tick.ok
		and riot_engine_tick.active
		and riot_engine_tick.counters.riot_markers_scanned > 0
		and riot_engine.active_disaster_type == DisasterStart.DISASTER_RIOT
		and riot_engine_city.city_mode() == 2,
		"Riot enters disaster mode and runs its recurring map branch",
	)

	var manual := _fire_map_fixture(reference_root, Vector2i(20, 20), Tiles.EMPTY)
	_check(manual.city.set_text_overlay_id(20, 20, 0), "Manual disaster fixture clears fire")
	var manual_engine := Simulation.new(manual.city, 1, 7, 13)
	var manual_start := manual_engine.start_disaster(
		DisasterStart.DISASTER_TORNADO, Vector2i(22, 23)
	)
	var duplicate_start := manual_engine.start_disaster(
		DisasterStart.DISASTER_MONSTER, Vector2i(24, 25)
	)
	_check(
		manual_start.ok
		and manual_start.started
		and manual_engine.active_disaster_type == DisasterStart.DISASTER_TORNADO
		and manual.city.city_mode() == 2
		and manual.city.thing(1).type == 15
		and not duplicate_start.ok,
		"The public engine entry point starts one manual disaster and rejects a second",
	)


func _test_annual_microsim_phase(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	var service_tiles := [Tiles.HOSPITAL, Tiles.POLICE_STATION, Tiles.FIRE_STATION, Tiles.SCHOOL, Tiles.STADIUM, Tiles.PRISON, Tiles.COLLEGE]

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
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	var microsims := _filled_bytes(CityState.MICROSIM_COUNT * CityState.MICROSIM_RECORD_SIZE, 0)
	var special_tiles := [Tiles.GAS_POWER, Tiles.ZOO, Tiles.STATUE, Tiles.MAYOR_HOUSE, Tiles.WATER_TREATMENT, Tiles.MARINA, Tiles.PLYMOUTH_ARCOLOGY, Tiles.LAUNCH_ARCOLOGY, Tiles.LLAMA_DOME]

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
	var game_lcg := SequenceGameRandom.new([101, 202, 303, 404])
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

	var renewal_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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

	var expiry_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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
	_check(
		expiry_document.set_misc_u32(ToolAvailability.MISC_INVENTION_YEARS, 0),
		"Annual expiry fixture unlocks gas power",
	)
	var expiry_city := CityModel.from_document(expiry_document)
	var gas := Buildings.apply(
		expiry_city, 3, 5, Vector2i(20, 20), LfsrRandom.new(1), Random.new(1)
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
		expired.demolished_power_records.size() == 1 and expired.expired_power_records.is_empty()
		and expired.demolished_power_records[0].record == 10
		and expired.demolished_power_records[0].tile == 0xc9
		and expired.demolished_power_records[0].x == 19
		and expired.demolished_power_records[0].y == 19,
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
	_check(
		expired.effect_events.size() == 64
		and expired.effect_events[0].frame == 0
		and expired.effect_events[16].frame == 1
		and expired.effect_events[63].frame == 3,
		"Annual power demolition returns four ordered native dust frames",
	)
	_check(not NewsEvent.contains(expired.news_items, 0x1f8, 0), "Annual power demolition does not report sound as news")
	_check(SoundEvent.same_arrays(expired.sound_events, SoundEvent.from_ids([504])), "Annual power demolition reports the explosion sound")

	var aus_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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
		NewsEvent.same_arrays(favorable.news_items, [NewsEvent.new(0x201, 0)]),
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
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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
	_check(document.set_misc_u32(ToolAvailability.MISC_PROGRESSION, 6), "Arcology launch fixture sets metropolis progression")

	for invention_index in range(12, 16):
		_check(
			document.set_misc_u32(
				ToolAvailability.MISC_INVENTION_YEARS + invention_index * 4,
				0,
			),
			"Arcology launch fixture unlocks arcology %d" % invention_index,
		)

	var city := CityModel.from_document(document)
	var launch := Buildings.apply(
		city, 5, 8, Vector2i(20, 20), LfsrRandom.new(1), Random.new(1)
	)
	_check(launch.ok and launch.site == Rect2i(19, 19, 4, 4), "Arcology launch fixture builds a launch arcology")
	var text_overlays: PackedByteArray = document.find_chunk("XTXT").decoded_payload.duplicate()

	for index in launch.tile_indices:
		text_overlays[index] = 0xfe

	# Install the markers through the city so its XTXT mirror matches the chunk.
	# Writing the chunk alone leaves the mirror stale before the phase even runs.
	_check(city.replace_text_overlays(text_overlays), "Arcology launch fixture installs launch markers")
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
	_check(
		result.effect_events.size() == 64
		and result.effect_events[0].frame == 0
		and result.effect_events[63].frame == 3,
		"Arcology launch returns its four ordered native dust frames",
	)
	_check(lfsr.position == 100, "Arcology launch consumes one LFSR value per record")
	_check(
		NewsEvent.same_arrays(result.news_items, [
			NewsEvent.new(0x211, 0),
			NewsEvent.new(0x212, 0),
		]),
		"Arcology launch reports start and completion news: %s" % [result.news_items],
	)
	_check(SoundEvent.same_arrays(result.sound_events, SoundEvent.from_ids([504])), "Arcology launch reports one explosion sound: %s" % [result.sound_events])
	_check(result.complete, "Arcology launch completes the annual microsimulation action")


func _test_transport_trip(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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
		_check(city.set_building_id(point.x, point.y, Tiles.ROAD_STRAIGHT_1), "Transport fixture places a road")

	_check(city.set_zone_id(20, 20, 1), "Transport fixture sets the origin zone")
	_check(city.set_zone_id(20, 26, 3), "Transport fixture sets a job destination")
	var result := Transport.run(city, Vector2i(20, 20), 1, 2, Random.new(1))
	_check(result.ok and result.reached_destination, "Road trip reaches a compatible zone")
	_check(result.path_length == 3, "Road trip records the three-tile path")
	var traffic := document.find_chunk("XTRF").decoded_payload
	_check(traffic[10 * 64 + 10] == 2, "Road trip adds traffic to its first coarse cell")
	_check(traffic[10 * 64 + 11] == 4, "Road trip accumulates two tiles in one coarse cell")

	_check(city.set_zone_id(20, 26, 1), "Transport fixture changes the destination to residential")
	var before_failed_trip: PackedByteArray = document.find_chunk("XTRF").decoded_payload.duplicate()
	var failed := Transport.run(city, Vector2i(20, 20), 1, 2, Random.new(1))
	_check(failed.ok and not failed.reached_destination, "Trip rejects an incompatible destination")
	_check(document.find_chunk("XTRF").decoded_payload == before_failed_trip, "Failed trip preserves XTRF")

	_check(city.set_building_id(1, 0, Tiles.ROAD_STRAIGHT_1), "Connection fixture places an edge road")
	_check(city.set_text_overlay_id(1, 0, 0xfa), "Connection fixture marks a city connection")
	var connection := Transport.run(city, Vector2i(1, 1), 5, 1, Random.new(7))
	_check(connection.ok and connection.reached_destination, "Trip can leave through a city connection")
	_check(
		document.find_chunk("XTRF").decoded_payload[0] == 1,
		"Connection trip adds its density to the edge traffic cell",
	)


func _test_growth_phase(reference_root: String) -> void:
	var normal := _growth_fixture(reference_root, Tiles.LARGE_APARTMENT_BUILDING_3X3_1, 1, 2000)
	var normal_result := GrowthScan.run(normal.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(normal_result.ok, "Normal growth scan completes: %s" % normal_result.error)
	_check(normal_result.scanned_tiles == 1024, "Growth scan processes one sixteenth of the map")
	_check(normal_result.rci_tiles == 1, "Growth scan processes the controlled RCI anchor")
	_check(normal.document.misc_u32(0x05f4) == 36, "Density four adds 36 residential units")
	_check(normal_result.successful_trips == 1, "Developed zone completes its transport trip")
	_check(normal.city.building_id(20, 20) == 0xae, "Stable density-four zone keeps its building")

	var bare := _growth_fixture(reference_root, Tiles.EMPTY, 1, 2000)
	var bare_result := GrowthScan.run(bare.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(bare_result.ok, "Bare-zone growth scan completes: %s" % bare_result.error)
	_check(bare_result.started_construction == 1, "Bare powered zone starts construction")
	_check(bare.city.building_id(20, 20) == 0x88, "Bare zone gets the first construction tile")
	_check(bare.city.building_corners(20, 20) == 0xf0, "One-tile construction sets all corner bits")
	_check(
		bare.city.tile_flags[20 * 128 + 20] & 0xe0 == 0xe0,
		"Construction sets utility flags",
	)

	var declining := _growth_fixture(reference_root, Tiles.LOWER_CLASS_HOMES_1X1_1, 1, -2000)
	var decline_result := GrowthScan.run(declining.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(decline_result.ok, "Declining-zone scan completes: %s" % decline_result.error)
	_check(decline_result.abandoned_buildings == 1, "Low demand abandons the controlled building")
	_check(declining.city.building_id(20, 20) == 0x8a, "Density-one zone uses an abandoned tile")
	_check(declining.document.misc_u32(0x05f4) == 1, "Population is counted before abandonment")

	var abandoned := _growth_fixture(reference_root, Tiles.ABANDONED_1X1_1, 1, 2000)
	var recovery_result := GrowthScan.run(abandoned.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(recovery_result.ok, "Abandoned-zone scan completes: %s" % recovery_result.error)
	_check(recovery_result.recovered_buildings == 1, "High demand recovers an abandoned building")
	_check(abandoned.city.building_id(20, 20) == 0x70, "Recovered residence uses value group zero")
	_check(abandoned.document.misc_u32(0x060c) == 1, "Abandoned population is counted before recovery")

	var construction := _growth_fixture(reference_root, Tiles.CONSTRUCTION_1X1_1, 1, 2000)
	var construction_result := GrowthScan.run(
		construction.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(construction_result.ok, "Construction completion scan completes: %s" % construction_result.error)
	_check(construction_result.completed_construction == 1, "Construction completes on the controlled roll")
	_check(construction.city.building_id(20, 20) == 0x70, "Residential construction becomes occupied")

	var church := _growth_fixture(reference_root, Tiles.CONSTRUCTION_2X2_1, 1, 2000)

	for point in [Vector2i(20, 19), Vector2i(21, 19), Vector2i(21, 20)]:
		_check(church.city.set_building_id(point.x, point.y, Tiles.CONSTRUCTION_2X2_1), "Church fixture fills construction footprint")
		_check(church.city.set_zone_id(point.x, point.y, 1), "Church fixture zones construction footprint")

	_check(church.document.set_misc_u32(0x01f0 + 0xa6 * 4, 4), "Church fixture counts construction tiles")
	_check(church.document.set_misc_u32(0x01f0 + 0xf7 * 4, 0), "Church fixture clears church count")
	_check(church.document.set_misc_u32(0x102c, 1000), "Church fixture sets city population")
	var church_result := GrowthScan.run(church.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
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
	var airport_result := GrowthScan.run(
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
	var seaport_result := GrowthScan.run(
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
	var silo_result := GrowthScan.run(silos.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
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
	var army_result := GrowthScan.run(army.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new())
	_check(army_result.ok, "Army growth scan completes: %s" % army_result.error)
	_check(army_result.special_growth_attempts == 1, "Army growth attempts one controlled building")
	_check(army_result.special_tiles_placed == 4, "Military growth can develop its own zone")

	for x in range(20, 22):
		for y in range(20, 22):
			_check(army.city.building_id(x, y) == 0xef, "Military placement builds parking lots")
			_check(army.city.tile_flags[x * 128 + y] & 0xf0 == 0, "Win95 military placement clears utility flags")

	var air_force := _special_growth_fixture(reference_root)

	for x in range(21, 26):
		_check(air_force.city.set_zone_id(x, 21, 7), "Air Force fixture zones its runway strip")

	_check(air_force.city.set_building_id(10, 10, Tiles.RUNWAY), "Air Force fixture places one civilian runway")
	_check(air_force.city.set_building_id(23, 21, Tiles.ROAD_STRAIGHT_1), "Air Force fixture places a military road")
	_check(air_force.city.set_terrain_id(23, 21, 1), "Air Force fixture sets terrain under the road")
	_check(air_force.city.set_underground_id(23, 21, UnderTiles.SUBWAY_LR), "Air Force fixture sets a subway under the road")
	_check(air_force.document.set_misc_u32(0x0e4c, 3), "Air Force fixture selects an air base")
	_check(air_force.document.set_misc_u32(0x01f0, 16378), "Air Force fixture counts normal clear tiles")
	_check(air_force.document.set_misc_u32(0x01f0 + 0xdd * 4, 1), "Air Force fixture counts its civilian runway")
	_check(air_force.document.set_misc_u32(0x0fa8, 5), "Air Force fixture counts military other tiles")
	var air_force_result := GrowthScan.run(
		air_force.city, ZeroRandom.new(), 1, 1, NonzeroLfsrRandom.new()
	)
	_check(air_force_result.ok, "Air Force growth scan completes: %s" % air_force_result.error)
	_check(air_force_result.special_tiles_placed == 0, "Military runway cannot cross roads, slopes or subway")
	_check(air_force.city.building_id(23, 21) == 0x1d, "Military runway preserves the road")
	_check(air_force.city.terrain_id(23, 21) == 1, "Military runway preserves terrain")
	_check(air_force.city.underground_id(23, 21) == 1, "Military runway preserves subway")
	_check(air_force.document.misc_u32(0x01f0 + 0xdd * 4) == 1, "Military runways keep civilian counts separate")

	var aircraft := _special_growth_fixture(reference_root)
	_check(aircraft.city.set_zone_id(20, 20, 8), "Aircraft fixture sets an airport zone")
	_check(aircraft.city.set_building_id(20, 20, Tiles.RUNWAY), "Aircraft fixture places a runway")
	_check(aircraft.city.set_tile_flag(20, 20, 0x40, true), "Aircraft fixture powers its runway")
	_check(aircraft.document.set_misc_u32(0x01f0, 16383), "Aircraft fixture counts clear tiles")
	_check(aircraft.document.set_misc_u32(0x01f0 + 0xdd * 4, 1), "Aircraft fixture counts its runway")
	var aircraft_result := GrowthScan.run(
		aircraft.city, SequenceRandom.new([1, 0, 0]), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(aircraft_result.ok, "Aircraft growth scan completes: %s" % aircraft_result.error)
	_check(aircraft_result.spawned_helicopters == 1, "Powered airport runway spawns a helicopter")
	_check(aircraft.city.text_overlay_id(20, 20) == 202, "Helicopter attaches record one to its runway")
	var helicopter: ThingRecord = aircraft.city.thing(1)
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
	_check(airplane.city.set_building_id(20, 20, Tiles.RUNWAY), "Airplane fixture places a runway")
	_check(airplane.city.set_tile_flag(20, 20, 0x40, true), "Airplane fixture powers its runway")
	_check(airplane.document.set_misc_u32(0x01f0, 16383), "Airplane fixture counts clear tiles")
	_check(airplane.document.set_misc_u32(0x01f0 + 0xdd * 4, 1), "Airplane fixture counts its runway")
	var airplane_result := GrowthScan.run(
		airplane.city, SequenceRandom.new([1, 0, 4, 9]), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(airplane_result.ok and airplane_result.spawned_airplanes == 1, "Airport spawns an airplane")
	var plane: ThingRecord = airplane.city.thing(1)
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
	var maxis_things := _filled_bytes(CityState.THING_COUNT * CityState.THING_RECORD_SIZE, 0)
	var maxis_text := _filled_bytes(CityState.TILE_COUNT, 0)
	maxis_text[30 * CityState.MAP_SIZE + 20] = 0xff
	var spawned_maxis := MovingThings.spawn_maxis_man(
		maxis_things,
		maxis_text,
		Vector2i(18, 20),
		Vector2i(30, 20),
		241,
		7,
	)
	_check(
		spawned_maxis.spawned
		and spawned_maxis.record == 1
		and maxis_things[12] == MovingThings.TYPE_MAXIS_MAN
		and maxis_things[12 + 1] == 2
		and maxis_things[12 + 3] == 18
		and maxis_things[12 + 4] == 20
		and maxis_things[12 + 5] == 7
		and maxis_things[12 + 8] == 30
		and maxis_things[12 + 9] == 20
		and maxis_things[12 + 11] == 241
		and maxis_text[18 * CityState.MAP_SIZE + 20] == 202,
		"Debug Maxis Man dispatch stores a linked moving-object record and target",
	)
	_check(
		not MovingThings.spawn_maxis_man(
			maxis_things,
			maxis_text,
			Vector2i(17, 20),
			Vector2i(30, 20),
			241,
			7,
		).spawned,
		"Maxis Man dispatch keeps one active hero",
	)

	var ship_fixture := _special_growth_fixture(reference_root)
	_check(ship_fixture.city.set_zone_id(20, 20, 9), "Ship fixture sets a seaport zone")
	_check(ship_fixture.city.set_building_id(20, 20, Tiles.CRANE), "Ship fixture places a crane")
	_check(ship_fixture.city.set_terrain_id(2, 10, 0x10), "Ship fixture places edge water")
	var stale_ship_record: PackedByteArray = ship_fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	stale_ship_record[12 + 8] = 77
	stale_ship_record[12 + 9] = 88
	_check(
		ship_fixture.document.find_chunk("XTHG").set_decoded_payload(stale_ship_record),
		"Ship fixture sets stale target bytes",
	)
	var ship_result := GrowthScan.run(
		ship_fixture.city, SequenceRandom.new([1, 0, 0]), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(
		ship_result.ok
		and ship_result.spawned_ships == 1
		and ship_result.ship_home == Vector2i(2, 10)
		and ship_result.news_items.is_empty()
		and ship_result.sound_events.size() == 1
		and ship_result.sound_events[0].sound_id == 517
		and ship_result.sound_events[0].thing_type == 3,
		"Seaport crane spawns a cargo ship and requests its immediate sound",
	)
	var ship: ThingRecord = ship_fixture.city.thing(1)
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
	_check(station.city.set_building_id(20, 20, Tiles.RAIL_STATION), "Train fixture places a rail station")
	_check(station.city.set_tile_flag(20, 20, 0x40, true), "Train fixture powers its station")
	_check(station.city.set_building_id(20, 18, Tiles.RAIL_STRAIGHT_1), "Train fixture places its spawn rail")
	_check(station.city.set_building_id(19, 18, Tiles.RAIL_STRAIGHT_1), "Train fixture places its west route rail")
	_check(station.city.set_building_id(21, 18, Tiles.RAIL_STRAIGHT_1), "Train fixture places its east route rail")
	_check(station.document.set_misc_u32(0x01f0 + 0xed * 4, 4), "Train fixture sets the station count")
	var train_result := GrowthScan.run(
		station.city,
		ZeroRandom.new(),
		0,
		0,
		MicrosimLfsrRandom.new(),
		NonzeroGameRandom.new()
	)
	_check(train_result.ok and train_result.spawned_trains == 1, "Rail station spawns a train")
	_check(station.city.text_overlay_id(20, 18) == 202, "Train engine attaches to its rail tile")
	var engine: ThingRecord = station.city.thing(1)
	var first_car: ThingRecord = station.city.thing(2)
	var second_car: ThingRecord = station.city.thing(3)
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
	var full_buildings := _filled_bytes(128 * 128, Tiles.EMPTY)
	var full_things := _filled_bytes(40 * 12, 0)
	var full_text := _filled_bytes(128 * 128, 0)
	full_buildings[20 * 128 + 18] = Tiles.RAIL_STRAIGHT_1
	full_buildings[20 * 128 + 17] = Tiles.RAIL_STRAIGHT_1

	for record in range(1, 40):
		full_things[record * 12] = 7

	_check(
		MovingThings.spawn_train(
			full_buildings, full_things, full_text, Vector2i(20, 20),
			ZeroGameRandom.new(), ZeroLfsrRandom.new()
		),
		"Full-pool train creator keeps the supplied unchecked-allocation result",
	)
	_check(
		full_things[0] == 11 and full_text[20 * 128 + 18] == 201,
		"Full-pool train creator writes reserved record zero like the supplied executable",
	)

	var marina := _special_growth_fixture(reference_root)
	_check(marina.city.set_building_id(20, 20, Tiles.MARINA), "Sailboat fixture places a marina")
	_check(marina.city.set_tile_flag(20, 20, 0x40, true), "Sailboat fixture powers its marina")
	_check(marina.city.set_tile_flag(20, 19, 0x04, true), "Sailboat fixture marks north water")
	_check(marina.document.set_misc_u32(0x01f0 + 0xf8 * 4, 9), "Sailboat fixture sets the marina count")
	var sailboat_result := GrowthScan.run(
		marina.city, ZeroRandom.new(), 0, 0, MicrosimLfsrRandom.new()
	)
	_check(
		sailboat_result.ok and sailboat_result.spawned_sailboats == 1,
		"Marina spawns one sailboat on its valid adjacent water tile",
	)
	var sailboat: ThingRecord = marina.city.thing(1)
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
	_check(arcology.city.set_building_id(20, 20, Tiles.PLYMOUTH_ARCOLOGY), "Arcology fixture places an arcology tile")
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
	var arcology_result := GrowthScan.run(
		arcology.city, ZeroRandom.new(), 0, 0, NonzeroLfsrRandom.new()
	)
	_check(arcology_result.ok and arcology_result.arcologies_updated == 1, "Arcology updates its XMIC statistic")
	_check(arcology.city.microsim(10).stat_0 == 8, "Arcology rating uses land value, crime, pollution, power, and water")


func _test_moving_thing_phase(reference_root: String) -> void:
	var explosion := _special_growth_fixture(reference_root)
	_set_explosion(explosion, 1, Vector2i(20, 20), 5, 0, 0)
	_check(explosion.city.set_building_id(20, 20, Tiles.NICE_APARTMENTS_2X2_2), "Explosion fixture places its center building")
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
		and first_explosion_frame.news_items.is_empty()
		and first_explosion_frame.sound_events[0].sound_id == 0x1f8
		and first_explosion_frame.sound_events[0].thing_type == 6
		and second_explosion_frame.ok
		and final_explosion_frame.ok,
		"Explosion record requests sound and advances through two animation frames",
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

	for point in [Vector2i(21, 20), Vector2i(20, 21), Vector2i(19, 20)]:
		_check(
			spreading_explosion.city.set_building_id(point.x, point.y, Tiles.TREES_1),
			"Spreading explosion fixture makes the target combustible",
		)

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
		spread_result.ok
		and spread_result.spread_explosion_fires == 3
		and spread_result.disaster_start_requests.size() == 1
		and spread_result.disaster_start_requests[0].type == DisasterStart.DISASTER_AIR_CRASH
		and spread_result.disaster_start_requests[0].point == Vector2i(20, 20)
		and spreading_explosion.city.disaster_type() == DisasterStart.DISASTER_AIR_CRASH,
		"A damaging airplane explosion stores its recovered Air Crash trigger",
	)
	_check(
		spreading_explosion.city.text_overlay_id(20, 20) == 0
		and spreading_explosion.city.text_overlay_id(21, 20) == 0xff
		and spreading_explosion.city.text_overlay_id(20, 21) == 0xff
		and spreading_explosion.city.text_overlay_id(19, 20) == 0xff,
		"Explosion damage rejects the cleared center and burns combustible neighbors",
	)
	_check(
		spreading_explosion.document.find_chunk("XTRF").decoded_payload[10 * 64 + 10] == 0,
		"Explosion fire clears coarse traffic",
	)

	var labeled_explosion := _special_growth_fixture(reference_root)
	_set_explosion(labeled_explosion, 1, Vector2i(20, 20), 5, 1, 2)
	_check(
		labeled_explosion.city.set_building_id(21, 20, Tiles.TREES_1),
		"Explosion fixture makes the labeled tile combustible",
	)
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
	_check(rubble_explosion.city.set_building_id(21, 20, Tiles.NICE_APARTMENTS_2X2_2), "Rubble explosion fixture places a building")
	_check(rubble_explosion.city.set_text_overlay_id(21, 20, 241), "Rubble explosion fixture places overlay 241")
	var rubble_result := MovingThingTick.run(
		rubble_explosion.city,
		SequenceRandom.new([1]),
		SequenceLfsrRandom.new([3, 2, 0, 3, 2, 0, 3, 2, 0, 3, 2, 0])
	)
	_check(
		rubble_result.ok
		and rubble_result.rubble_explosion_hits == 1
		and rubble_explosion.city.building_id(21, 20) == 1
		and rubble_explosion.city.text_overlay_id(21, 20) == 241,
		"Explosion overlay 241 through 249 changes a combustible tile to LFSR-selected rubble once: %s %d %d"
		% [rubble_result, rubble_explosion.city.building_id(21, 20), rubble_explosion.city.text_overlay_id(21, 20)],
	)

	var facility_explosion := _special_growth_fixture(reference_root)
	_set_explosion(facility_explosion, 1, Vector2i(20, 20), 5, 1, 2)
	_check(facility_explosion.city.set_building_id(21, 20, Tiles.ABANDONED_1X1_2), "Facility explosion fixture places a building")
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
	_check(connection_explosion.city.set_building_id(21, 20, Tiles.ROAD_STRAIGHT_1), "Connection blast fixture places a road")
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
	_check(tornado.city.set_building_id(20, 20, Tiles.ROAD_STRAIGHT_1), "Tornado fixture places a road")
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
		and attack_result.news_items.is_empty()
		and attack_result.sound_events[0].sound_id == 0x1f8
		and attack_result.sound_events[0].thing_type == 16
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
	_check(radioactive_monster.city.set_building_id(21, 21, Tiles.ABANDONED_1X1_2), "Monster damage fixture places a building")
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
		and radioactive_result.news_items.is_empty()
		and radioactive_result.sound_events[0].sound_id == 0x202
		and radioactive_result.sound_events[0].thing_type == 5,
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
	_check(airplane.city.set_building_id(20, 20, Tiles.RUNWAY), "Airplane takeoff fixture places a runway")
	_check(airplane.city.set_zone_id(20, 20, 8), "Airplane takeoff fixture sets the airport zone")
	var takeoff_plane_result := MovingThingTick.run(
		airplane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		takeoff_plane_result.ok
		and takeoff_plane_result.active_airplanes == 1
		and takeoff_plane_result.moved_airplanes == 1
		and takeoff_plane_result.news_items.is_empty()
		and takeoff_plane_result.sound_events[0].sound_id == 0x206
		and takeoff_plane_result.sound_events[0].thing_type == 1
		and airplane.city.thing(1).x == 21
		and airplane.city.thing(1).z == 1,
		"Airplane takeoff moves at sixteen sub-tiles, gains height, and requests sound",
	)

	var cruising_plane := _special_growth_fixture(reference_root)
	_set_airplane(cruising_plane, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 14)
	_check(cruising_plane.city.set_building_id(23, 20, Tiles.PLYMOUTH_ARCOLOGY), "Airplane obstacle fixture places an arcology")
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
	_check(landing_plane.city.set_building_id(21, 20, Tiles.RUNWAY), "Landing airplane fixture places its destination runway")
	var landing_plane_result := MovingThingTick.run(
		landing_plane.city, SequenceRandom.new([1]), NonzeroLfsrRandom.new()
	)
	_check(
		landing_plane_result.ok
		and landing_plane_result.landed_airplanes == 1
		and landing_plane_result.news_items.is_empty()
		and landing_plane_result.sound_events[0].sound_id == 0x207
		and landing_plane_result.sound_events[0].thing_type == 1
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
	_check(low_plane.city.set_building_id(20, 20, Tiles.CORPORATE_HEADQUARTERS_3X3), "Low airplane fixture places the tallest small-map building sprite")
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
	_check(arcology_plane.city.set_building_id(20, 20, Tiles.PLYMOUTH_ARCOLOGY), "Airplane crash fixture places an arcology")
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
		and falling_result.news_items.is_empty()
		and falling_result.sound_events[0].sound_id == 0x203
		and falling_result.sound_events[0].thing_type == 1
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
	_check(docking_ship.city.set_building_id(22, 20, Tiles.PIER), "Docking ship places a pier two cells away")
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
		and depart_result.news_items.is_empty()
		and depart_result.sound_events[0].sound_id == 0x205
		and depart_result.sound_events[0].thing_type == 3
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
		and first_traffic_news.news_items.is_empty()
		and first_traffic_news.sound_events[0].sound_id == 0x1fe
		and first_traffic_news.sound_events[0].thing_type == 2
		and first_traffic_news.traffic_news_deadline_msec == 6000
		and throttled_traffic_news.sound_events.is_empty()
		and resumed_traffic_news.sound_events.size() == 1,
		"Helicopter sound uses the recovered strict five-second deadline",
	)
	_check(
		ThingAudio.event_sound_id(
			first_traffic_news.sound_events[0], CityViewMode.Mode.CITY, IsometricRenderer.VIEW_MEDIUM
		) == -1
		and ThingAudio.event_sound_id(
			first_traffic_news.sound_events[0], CityViewMode.Mode.UNDERGROUND, IsometricRenderer.VIEW_LARGE
		) == -1
		and ThingAudio.event_sound_id(
			first_traffic_news.sound_events[0], CityViewMode.Mode.CITY, IsometricRenderer.VIEW_LARGE
		) == 510,
		"Moving-object sound follows the object's minimum zoom and surface view",
	)

	var avoiding := _special_growth_fixture(reference_root)
	_set_helicopter(avoiding, 1, Vector2i(20, 20), Vector2i(30, 20), 2, 2, 10)
	_check(avoiding.city.set_building_id(23, 20, Tiles.PLYMOUTH_ARCOLOGY), "Helicopter obstacle fixture places an arcology")
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
	_check(building_crash.city.set_building_id(20, 20, Tiles.PLYMOUTH_ARCOLOGY), "Helicopter crash fixture places an arcology")
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
	var moved_sailboat: ThingRecord = moving.city.thing(1)
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
		and distress_result.news_items.is_empty()
		and distress_result.sound_events[0].sound_id == 0x20f
		and distress_result.sound_events[0].thing_type == 9,
		"Sailboat distress sets its state and requests sound 0x20f",
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
	_check(marina.city.set_building_id(21, 20, Tiles.MARINA), "Sailboat destination fixture places a marina")
	var marina_result := MovingThingTick.run(
		marina.city, ZeroRandom.new(), SequenceLfsrRandom.new([1])
	)
	_check(marina_result.ok and marina_result.removed_sailboats == 1, "Sailboat disappears when it reaches a marina")
	_check(marina.city.thing(1).type == 0, "Marina arrival releases the sailboat record")
	_check(marina.city.text_overlay_id(20, 20) == 0, "Marina arrival clears the sailboat link")

	var train := _special_growth_fixture(reference_root)

	for x in range(20, 23):
		_check(train.city.set_building_id(x, 20, Tiles.RAIL_STRAIGHT_1), "Moving train fixture places surface rail")

	_set_train(train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var train_result := MovingThingTick.run(
		train.city, ZeroRandom.new(), SequenceLfsrRandom.new([0, 1]), ZeroGameRandom.new()
	)
	_check(train_result.ok and train_result.moved_trains == 1, "Train tick advances a clear consist")
	var moved_engine: ThingRecord = train.city.thing(1)
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
	_check(station.city.set_building_id(20, 20, Tiles.RAIL_STRAIGHT_1), "Pausing train fixture places current rail")
	_check(station.city.set_building_id(21, 20, Tiles.RAIL_STRAIGHT_1), "Pausing train fixture places destination rail")
	_check(station.city.set_building_id(20, 19, Tiles.RAIL_STATION), "Pausing train fixture places an adjacent station")
	_set_train(station, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var pause_result := MovingThingTick.run(
		station.city, ZeroRandom.new(), SequenceLfsrRandom.new([1]), ZeroGameRandom.new()
	)
	_check(pause_result.ok and pause_result.paused_trains == 1, "Surface train pauses beside a station")
	_check(
		station.city.thing(1).x == 20 and station.city.thing(1).px == 21,
		"Station pause keeps the train position and destination",
	)

	var turning_train := _special_growth_fixture(reference_root)
	_check(turning_train.city.set_building_id(20, 20, Tiles.RAIL_STRAIGHT_1), "Turning train fixture places current rail")
	_check(turning_train.city.set_building_id(21, 20, Tiles.RAIL_STRAIGHT_1), "Turning train fixture places destination rail")
	_check(turning_train.city.set_building_id(21, 19, Tiles.RAIL_STRAIGHT_1), "Turning train fixture places north rail")
	_set_train(turning_train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var train_turn_result := MovingThingTick.run(
		turning_train.city,
		SequenceRandom.new([0]),
		SequenceLfsrRandom.new([0, 0, 0]),
		ZeroGameRandom.new()
	)
	_check(
		train_turn_result.ok
		and train_turn_result.turned_trains == 1
		and train_turn_result.news_items.is_empty()
		and train_turn_result.sound_events[0].sound_id == 0x20c
		and train_turn_result.sound_events[0].thing_type == 10,
		"Train side turn returns the recovered random sound",
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
	_check(subway_train.city.set_building_id(20, 20, Tiles.RAIL_STRAIGHT_1), "Subway train fixture places current rail")
	_check(subway_train.city.set_building_id(21, 20, Tiles.RAIL_SUBWAY_ENTRANCE_1), "Subway train fixture places a transition tile")
	_check(subway_train.city.set_underground_id(22, 20, UnderTiles.SUBWAY_LR), "Subway train fixture places its next subway")
	_set_train(subway_train, Vector2i(20, 20), Vector2i(21, 20), 1, 10)
	var subway_train_result := MovingThingTick.run(
		subway_train.city,
		ZeroRandom.new(),
		SequenceLfsrRandom.new([0, 1]),
		ZeroGameRandom.new()
	)
	_check(subway_train_result.ok and subway_train_result.moved_trains == 1, "Train enters a subway transition")
	_check(
		subway_train.city.thing(1).type == 12
		and subway_train.city.thing(1).x == 21
		and subway_train.city.thing(1).px == 22,
		"Surface engine becomes a subway engine and plans an underground route",
	)

	var reversing_train := _special_growth_fixture(reference_root)
	_check(reversing_train.city.set_building_id(20, 20, Tiles.RAIL_STRAIGHT_1), "Reversing train fixture places its old rail")
	_check(reversing_train.city.set_building_id(21, 20, Tiles.RAIL_STRAIGHT_1), "Reversing train fixture places its current rail")
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
		ZeroGameRandom.new()
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
		ZeroGameRandom.new()
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
	var road := _maintenance_fixture(reference_root, Tiles.ROAD_STRAIGHT_1, UnderTiles.EMPTY)
	_check(road.city.set_tile_flag(20, 20, 0x80, true), "Road decay fixture sets powerable")
	_check(road.document.set_misc_i32(0x077c + 10 * 0x6c + 4, 0), "Road decay fixture removes funding")
	var road_result := GrowthScan.run(road.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(road_result.ok and road_result.decayed_roads == 1, "Unfunded road decays on the rare check")
	_check(road.city.building_id(20, 20) == 1, "Road decay makes process-selected rubble")
	_check(road.city.tile_flags[20 * 128 + 20] & 0x80 == 0, "Road decay clears powerable")

	var rail := _maintenance_fixture(reference_root, Tiles.RAIL_STRAIGHT_1, UnderTiles.EMPTY)
	_check(rail.city.set_tile_flag(20, 20, 0x80, true), "Rail decay fixture sets powerable")
	_check(rail.document.set_misc_i32(0x077c + 13 * 0x6c + 4, 0), "Rail decay fixture removes funding")
	var rail_result := GrowthScan.run(rail.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(rail_result.ok and rail_result.decayed_rails == 1, "Unfunded rail decays on the rare check")
	_check(rail.city.building_id(20, 20) == 1, "Rail decay makes process-selected rubble")
	_check(rail.city.tile_flags[20 * 128 + 20] & 0x80 == 0, "Rail decay clears powerable")

	var highway := _maintenance_fixture(reference_root, Tiles.HIGHWAY_STRAIGHT_1, UnderTiles.EMPTY)

	for point in [Vector2i(21, 20), Vector2i(20, 21), Vector2i(21, 21)]:
		_check(highway.city.set_building_id(point.x, point.y, Tiles.HIGHWAY_STRAIGHT_1), "Highway decay fixture fills its section")

	_check(highway.city.set_tile_flag(21, 20, 0x04, true), "Highway decay fixture sets one water tile")
	_check(highway.document.set_misc_u32(0x01f0 + 0x49 * 4, 4), "Highway decay fixture counts its tiles")
	_check(highway.document.set_misc_i32(0x077c + 11 * 0x6c + 4, 0), "Highway decay fixture removes funding")
	var highway_result := GrowthScan.run(highway.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(highway_result.ok and highway_result.decayed_highway_tiles == 4, "Unfunded highway decays as one section")
	_check(highway.city.building_id(21, 20) == 0, "Highway decay clears a water tile")

	for point in [Vector2i(20, 20), Vector2i(20, 21), Vector2i(21, 21)]:
		_check(highway.city.building_id(point.x, point.y) == 1, "Highway decay makes rubble on dry land")

	var subway := _maintenance_fixture(reference_root, Tiles.EMPTY, UnderTiles.SUBWAY_LR)
	_check(subway.document.set_misc_i32(0x077c + 14 * 0x6c + 4, 0), "Subway decay fixture removes funding")
	var subway_result := GrowthScan.run(subway.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(subway_result.ok and subway_result.decayed_subway_tiles == 1, "Unfunded subway decays on the rare check")
	_check(subway.city.underground_id(20, 20) == 0, "Subway decay clears a subway tile")
	_check(subway.document.misc_u32(0x0fe8) == 0, "Subway decay decrements the saved XUND count")

	var crossover := _maintenance_fixture(reference_root, Tiles.EMPTY, UnderTiles.PIPE_TB_SUBWAY_LR)
	_check(crossover.document.set_misc_i32(0x077c + 14 * 0x6c + 4, 0), "Crossover decay fixture removes funding")
	var crossover_result := GrowthScan.run(crossover.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(crossover_result.ok and crossover_result.decayed_subway_tiles == 1, "Subway crossover loses its rail layer")
	_check(crossover.city.underground_id(20, 20) == 0x11, "Subway crossover preserves its pipe layer")
	_check(crossover.document.misc_u32(0x0fe8) == 0, "Crossover decay decrements the saved XUND count")

	var station := _maintenance_fixture(reference_root, Tiles.SUBWAY_STATION, UnderTiles.SUBWAY_ENTRANCE)
	_check(station.city.set_text_overlay_id(20, 20, 54), "Station decay fixture sets its microsim label")
	_check(station.city.set_tile_flag(20, 20, 0xe2, true), "Station decay fixture sets utility and flip flags")
	_check(station.document.set_misc_i32(0x077c + 14 * 0x6c + 4, 0), "Station decay fixture removes funding")
	var station_result := GrowthScan.run(station.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
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

	var bridge := _maintenance_fixture(reference_root, Tiles.SUSPENSION_BRIDGE_1, UnderTiles.EMPTY)

	for x in range(18, 25):
		for y in range(19, 22):
			_check(bridge.city.set_land_altitude(x, y, 0), "Bridge decay fixture levels the waterbed")

	for x in range(20, 23):
		_check(bridge.city.set_building_id(x, 20, Tiles.SUSPENSION_BRIDGE_1), "Bridge decay fixture places a span tile")
		_check(bridge.city.set_terrain_id(x, 20, 0x30), "Bridge decay fixture places water terrain")
		_check(bridge.city.set_tile_flag(x, 20, 0x06, true), "Bridge decay fixture marks horizontal water")

	for x in [19, 23]:
		_check(bridge.city.set_building_id(x, 20, Tiles.ROAD_STRAIGHT_1), "Bridge decay fixture places a bank road")
		_check(bridge.city.set_land_altitude(x, 20, 1), "Bridge decay fixture raises a bank")

	_check(bridge.document.set_misc_u32(0x01f0, 16379), "Bridge decay fixture counts clear tiles")
	_check(bridge.document.set_misc_u32(0x01f0 + 0x51 * 4, 3), "Bridge decay fixture counts span tiles")
	_check(bridge.document.set_misc_u32(0x01f0 + 0x1d * 4, 2), "Bridge decay fixture counts bank roads")
	_check(bridge.document.set_misc_u32(0x0e40, 1), "Bridge decay fixture sets sea level")
	_check(bridge.document.set_misc_i32(0x077c + 12 * 0x6c + 4, 0), "Bridge decay fixture removes funding")
	var bridge_random := SequenceRandom.new([0, 2, 1, 3, 0, 1, 1])
	var bridge_result := GrowthScan.run(bridge.city, bridge_random, 0, 0, ZeroLfsrRandom.new())
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
		and SoundEvent.same_arrays(bridge_result.sound_events, SoundEvent.from_ids([504]))
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

	var reinforced := _maintenance_fixture(reference_root, Tiles.HIGHWAY_BRIDGE, UnderTiles.EMPTY)
	_check(reinforced.document.set_misc_i32(0x077c + 12 * 0x6c + 4, 0), "Reinforced bridge fixture removes funding")
	var reinforced_result := GrowthScan.run(
		reinforced.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new()
	)
	_check(reinforced_result.ok and reinforced_result.deferred_bridge_collapses == 1, "Reinforced bridge collapse stays explicit")
	_check(reinforced.city.building_id(20, 20) == 0x6a, "Malformed reinforced bridge stays unchanged")

	var reinforced_span := _maintenance_fixture(reference_root, Tiles.EMPTY, UnderTiles.EMPTY)

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

	_check(reinforced_span.city.set_building_id(26, 20, Tiles.HIGHWAY_STRAIGHT_1), "Reinforced collapse fixture places its forward bank")
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
	var reinforced_span_result := GrowthScan.run(
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

	var funded := _maintenance_fixture(reference_root, Tiles.ROAD_STRAIGHT_1, UnderTiles.EMPTY)
	var funded_result := GrowthScan.run(funded.city, ZeroRandom.new(), 0, 0, ZeroLfsrRandom.new())
	_check(funded_result.ok and funded_result.decayed_roads == 0, "Full road funding prevents decay")
	_check(funded.city.building_id(20, 20) == 0x1d, "Full road funding preserves the road")


func _maintenance_fixture(reference_root: String, surface_tile: int, underground_tile: int) -> Dictionary:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var buildings := _filled_bytes(128 * 128, Tiles.EMPTY)
	var zones := _filled_bytes(128 * 128, 0)
	var underground := _filled_bytes(128 * 128, UnderTiles.EMPTY)
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


func _fire_map_fixture(
	reference_root: String, point: Vector2i, tile: int, water := false
) -> Dictionary:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var index := point.x * CityState.MAP_SIZE + point.y
	var buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)
	var flags := _filled_bytes(CityState.TILE_COUNT, 0)
	var text := _filled_bytes(CityState.TILE_COUNT, 0)
	buildings[index] = tile
	flags[index] = 0x04 if water else 0
	text[index] = DisasterMap.FIRE_OVERLAY

	for entry in [
		["XBLD", buildings],
		["XZON", _filled_bytes(CityState.TILE_COUNT, 0)],
		["XUND", _filled_bytes(CityState.TILE_COUNT, UnderTiles.EMPTY)],
		["XBIT", flags],
		["XTXT", text],
		["XTER", _filled_bytes(CityState.TILE_COUNT, 0)],
		["XTRF", _filled_bytes(64 * 64, 0)],
		["XFIR", _filled_bytes(32 * 32, 0)],
		["XTHG", _filled_bytes(CityState.THING_COUNT * CityState.THING_RECORD_SIZE, 0)],
	]:
		if not document.find_chunk(entry[0]).set_decoded_payload(entry[1]):
			return {"document": document, "city": null}

	document.set_misc_u32(0x01f0, CityState.TILE_COUNT - int(tile != 0))

	if tile != 0:
		document.set_misc_u32(0x01f0 + tile * 4, 1)

	return {"document": document, "city": CityModel.from_document(document)}


func _dispatch_map_fixture(
	reference_root: String, thing_type: int, point: Vector2i
) -> Dictionary:
	var fixture := _fire_map_fixture(reference_root, point, Tiles.EMPTY)

	if fixture.city == null:
		return fixture

	var things: PackedByteArray = fixture.document.find_chunk("XTHG").decoded_payload.duplicate()
	var offset := CityState.THING_RECORD_SIZE
	things[offset] = thing_type
	things[offset + 3] = point.x
	things[offset + 4] = point.y

	if (
		not fixture.document.find_chunk("XTHG").set_decoded_payload(things)
		or not fixture.city.set_text_overlay_id(point.x, point.y, 202)
	):
		fixture.city = null

	return fixture


func _special_growth_fixture(reference_root: String) -> Dictionary:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for entry in [
		["XBLD", _filled_bytes(128 * 128, Tiles.EMPTY)],
		["XZON", _filled_bytes(128 * 128, 0)],
		["XUND", _filled_bytes(128 * 128, UnderTiles.EMPTY)],
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
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var buildings := _filled_bytes(128 * 128, Tiles.EMPTY)

	for point in [Vector2i(20, 21), Vector2i(20, 22), Vector2i(20, 23), Vector2i(20, 24)]:
		buildings[point.x * 128 + point.y] = Tiles.ROAD_STRAIGHT_1

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
		["XUND", _filled_bytes(128 * 128, UnderTiles.EMPTY)],
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
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for index in 8:
		_check(document.set_misc_i32(0x05f0 + index * 4, 0), "RCI fixture clears zone population")

	for entry in [[1, 100], [2, 50], [3, 40], [4, 10], [5, 20], [6, 5]]:
		_check(
			document.set_misc_i32(0x05f0 + entry[0] * 4, entry[1]),
			"RCI fixture sets zone population %d" % entry[0],
		)

	for offset in [0x0718, 0x071c, 0x0720, 0x0fa0, 0x1030]:
		_check(document.set_misc_i32(offset, 0), "RCI fixture clears MISC 0x%x" % offset)

	for tile_id in [Tiles.BIG_PARK, Tiles.STADIUM, Tiles.ZOO, Tiles.RUNWAY, Tiles.RUNWAY_CROSSING, Tiles.CRANE, Tiles.MARINA]:
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
	buildings[0] = Tiles.ROAD_STRAIGHT_1
	buildings[1] = Tiles.RAIL_STRAIGHT_1
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


func _test_news_queue(reference_root: String) -> void:
	var source_priorities := _load_indexed_u16_resource(reference_root, 1004)
	var source_decays := _load_indexed_u16_resource(reference_root, 1005)
	_check(
		source_priorities == PackedInt32Array(NewsQueue.STORY_PRIORITIES),
		"Newspaper priorities match DATA_USA resource 1004",
	)
	_check(
		source_decays == PackedInt32Array(NewsQueue.STORY_DECAYS),
		"Newspaper decays match DATA_USA resource 1005",
	)

	var paper_misc := _filled_bytes(NewsQueue.MISC_SIZE, 0)

	for field in NewsQueue.PAPER_FIELD_COUNT:
		_write_u32_be(paper_misc, NewsQueue.PAPER_OFFSET + field * 4, 0x100 + field)

	var paper := NewsQueue.paper_record(paper_misc, 0)
	_check(
		paper.name == 0 and paper.layout == 1 and paper.price == 2
		and paper.opinion == 3 and paper.weather == 4,
		"Newspaper paper records narrow all five saved fields",
	)
	_check(
		NewsQueue.paper_record(paper_misc, -1) == null
		and NewsQueue.paper_record(paper_misc, NewsQueue.PAPER_COUNT) == null,
		"Newspaper paper reader rejects invalid indices",
	)
	var session_misc := _filled_bytes(NewsQueue.MISC_SIZE, 0)
	var session_random := Random.new(1)
	var session_init := NewsQueue.initialize_session(session_misc, session_random)
	var paper_rows: Array[Array] = []

	for paper_index in NewsQueue.PAPER_COUNT:
		var session_paper := NewsQueue.paper_record(session_misc, paper_index)
		paper_rows.append([
			session_paper.name,
			session_paper.layout,
			session_paper.price,
			session_paper.opinion,
			session_paper.weather,
		])

	_check(
		session_init.ok
		and session_init.random_calls == 122
		and session_random.state == 3018468955
		and paper_rows == [
			[4, 1, 0, 4, 2],
			[1, 0, 1, 3, 1],
			[2, 0, 0, 5, 3],
			[5, 2, 2, 2, 0],
			[3, 1, 1, 0, 4],
			[0, 2, 2, 1, 5],
		],
		"Newspaper session initialization reproduces all 122 seed-one random calls",
	)
	var initial_story_records_valid := true

	for slot in NewsQueue.STORY_RECORD_COUNT:
		var initial_story := NewsQueue.story_record(session_misc, slot)
		initial_story_records_valid = initial_story_records_valid and (
			initial_story.type == 11 + slot
			and initial_story.priority == 0
			and initial_story.argument == 0
			and initial_story.auxiliary == PackedByteArray([0xff, 0xff, 0xff])
		)

	_check(
		initial_story_records_valid,
		"Newspaper session initialization resets all nine story records",
	)
	_check(
		NewspaperTables.PAGE_SIZE == Vector2i(640, 400)
		and NewspaperTables.section_rect(0, 3) == Rect2i(243, 76, 213, 100)
		and NewspaperTables.story_rect(1, 4) == Rect2i(512, 186, 128, 214)
		and NewspaperTables.story_rect(2, 0) == Rect2i(0, 30, 128, 370),
		"Newspaper page exposes the executable's three fixed layouts",
	)

	var misc := _filled_bytes(NewsQueue.MISC_SIZE, 0)
	var decay_types := PackedInt32Array([2, 6, 7, 46, 39, 42, 61])
	var decay_priorities := PackedInt32Array([900, 100, 40, 500, 250, 150, 100])

	for slot in NewsQueue.STORY_RECORD_COUNT:
		var offset := NewsQueue.STORY_OFFSET + slot * NewsQueue.STORY_RECORD_SIZE
		var story_type := decay_types[slot] if slot < NewsQueue.QUEUE_COUNT else 11 + slot
		var priority := decay_priorities[slot] if slot < NewsQueue.QUEUE_COUNT else 700 + slot
		_write_u32_be(misc, offset, story_type)
		_write_u32_be(misc, offset + 4, priority)
		_write_u32_be(misc, offset + 8, slot)
		_write_u32_be(misc, offset + 12, 0xa0 + slot)
		_write_u32_be(misc, offset + 16, 0xb0 + slot)
		_write_u32_be(misc, offset + 20, 0xc0 + slot)

	var decay := NewsQueue.decay_and_sort(misc)
	_check(decay.ok, "Newspaper queue decays and sorts: %s" % decay.error)
	var decayed_types := PackedInt32Array()
	var decayed_priorities := PackedInt32Array()

	for slot in NewsQueue.QUEUE_COUNT:
		var record := NewsQueue.story_record(misc, slot)
		decayed_types.append(record.type)
		decayed_priorities.append(record.priority)

	_check(
		decayed_types == PackedInt32Array([2, 39, 42, 6, 61, 46, 7]),
		"Newspaper decay sorts complete records by descending priority",
	)
	_check(
		decayed_priorities == PackedInt32Array([400, 200, 150, 90, 50, 0, 0]),
		"Newspaper decay subtracts each story-specific value and clamps at zero",
	)
	_check(
		NewsQueue.story_record(misc, 5).argument == 3
		and NewsQueue.story_record(misc, 5).auxiliary == PackedByteArray([0xa3, 0xb3, 0xc3]),
		"Newspaper sorting moves the argument and auxiliary bytes with a story",
	)
	_check(
		NewsQueue.story_record(misc, 7).type == 18
		and NewsQueue.story_record(misc, 7).priority == 707,
		"Monthly newspaper decay does not change display record eight",
	)

	var insert_types := PackedInt32Array([2, 46, 8, 7, 61, 6, 42])
	var insert_priorities := PackedInt32Array([1000, 500, 200, 200, 150, 100, 50])

	for slot in NewsQueue.QUEUE_COUNT:
		var offset := NewsQueue.STORY_OFFSET + slot * NewsQueue.STORY_RECORD_SIZE
		_write_u32_be(misc, offset, insert_types[slot])
		_write_u32_be(misc, offset + 4, insert_priorities[slot])
		_write_u32_be(misc, offset + 8, slot)
		_write_u32_be(misc, offset + 12, 0x80 + slot)
		_write_u32_be(misc, offset + 16, 0x90 + slot)
		_write_u32_be(misc, offset + 20, 0xa0 + slot)

	var inserted := NewsQueue.insert(misc, 17, 0x102)
	_check(
		inserted.ok and inserted.slot == 2 and inserted.priority == 200,
		"Newspaper inserts before older stories with equal priority",
	)
	var inserted_types := PackedInt32Array()

	for slot in NewsQueue.QUEUE_COUNT:
		inserted_types.append(NewsQueue.story_record(misc, slot).type)

	_check(
		inserted_types == PackedInt32Array([2, 46, 17, 8, 7, 61, 6]),
		"Newspaper insertion displaces the seventh story",
	)
	var inserted_record := NewsQueue.story_record(misc, 2)
	_check(
		inserted_record.argument == 2
		and inserted_record.auxiliary == PackedByteArray([0xff, 0xff, 0xff]),
		"Newspaper insertion narrows the argument and resets auxiliary fields",
	)
	_check(
		NewsQueue.story_record(misc, 3).argument == 2
		and NewsQueue.story_record(misc, 3).auxiliary == PackedByteArray([0x82, 0x92, 0xa2]),
		"Newspaper insertion preserves every field of a shifted story",
	)
	var before_invalid := misc.duplicate()
	var invalid := NewsQueue.insert(misc, 80, 0)
	_check(not invalid.ok and misc == before_invalid, "Newspaper rejects an invalid type without a write")
	var substitutions := NewsQueue.update_story_substitutions(
		misc, 0, 0x102, PackedByteArray([3, 4, 5])
	)
	var substituted_record := NewsQueue.story_record(misc, 0)
	_check(
		substitutions.ok
		and substituted_record.argument == 2
		and substituted_record.auxiliary == PackedByteArray([3, 4, 5]),
		"Newspaper stores narrowed generated substitutions in one saved record",
	)
	var mixed := NewsQueue.insert_items(
		misc,
		[NewsEvent.new(0x1f8, 0), NewsEvent.new(39, 4)],
	)
	_check(
		mixed.ok and mixed.inserted == 1 and NewsQueue.story_record(misc, 2).type == 39,
		"Newspaper insertion skips non-story runtime notifications",
	)

	var engine_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(_clear_news_records(engine_document), "Engine newspaper fixture clears story records")
	var engine_city := CityModel.from_document(engine_document)
	var engine := Simulation.new(engine_city, 1, 7, 13)
	var phase_result := PhaseResult.new()
	phase_result.ok = true
	phase_result.news_items = [
		NewsEvent.new(0x1fe, 0),
		NewsEvent.new(9, 4),
	]
	var persisted := engine._persist_news_result(phase_result)
	var persisted_record := NewsQueue.story_record(
		engine_document.find_chunk("MISC").decoded_payload, 0
	)
	_check(
		persisted.ok
		and persisted.inserted == 1
		and phase_result.news_queue_updated
		and phase_result.news_queue_inserted == 1
		and persisted_record.type == 9
		and persisted_record.priority == 200
		and persisted_record.argument == 4,
		"Simulation engine persists valid story events and skips runtime notifications",
	)
	var before_duplicate: PackedByteArray = engine_document.find_chunk("MISC").decoded_payload.duplicate()
	var already_updated := PhaseResult.new()
	already_updated.ok = true
	already_updated.news_queue_updated = true
	already_updated.news_items = [NewsEvent.new(3, 0)]
	var duplicate := engine._persist_news_result(already_updated)
	_check(
		duplicate.ok
		and duplicate.inserted == 0
		and engine_document.find_chunk("MISC").decoded_payload == before_duplicate,
		"Simulation engine does not insert a phase result twice",
	)


func _test_newspaper_text(reference_root: String) -> void:
	var data := DataUsa.load_path(
		reference_root.path_join("DATA/DATA_USA.DAT"),
		reference_root.path_join("DATA/DATA_USA.IDX"),
	)
	_check(data.is_valid(), "DATA_USA newspaper grammar loads: %s" % data.load_error)

	if not data.is_valid():
		return

	_check(
		data.bases.size() == 250 and data.counts.size() == 250,
		"Newspaper grammar has both 250-entry phrase tables",
	)
	_check(data.offsets.size() == 2500, "Newspaper grammar has 2,500 phrase offsets")
	_check(
		data.bases[0] == 92 and data.counts[0] == 1,
		"Newspaper grammar decodes the first base and count",
	)
	_check(
		not DataUsa.load_path("/missing/DATA_USA.DAT", "/missing/DATA_USA.IDX").is_valid(),
		"Newspaper grammar loader rejects missing files",
	)

	var executable_tokens := _load_pe_rva_bytes(
		reference_root.path_join("SIMCITY.EXE"), 0x000ea228, 512
	)
	var implemented_tokens := PackedByteArray()

	for token in 256:
		var phrase_id := NewspaperTextGenerator.token_phrase_id(token)
		implemented_tokens.append(phrase_id & 0xff)
		implemented_tokens.append((phrase_id >> 8) & 0xff)

	_check(
		implemented_tokens == executable_tokens,
		"Newspaper token map matches executable table 0x004ea228",
	)
	_check(
		NewspaperTextGenerator.published_seed(0x1234, 250, 2, 0)
		== 0x1234 + 10 + 1000 + 28,
		"Newspaper top-story seed uses session, month, paper, and section values",
	)
	_check(
		NewspaperTextGenerator.published_seed(0, 0, 0, 1) == 49
		and NewspaperTextGenerator.published_seed(0, 0, 0, 4) == 70
		and NewspaperTextGenerator.published_seed(0, 0, 0, 5) == -1,
		"Newspaper seed map covers only the published saved story slots",
	)

	var document := _load_fixture(reference_root.path_join("CITIES/STARTER.SC2"))
	var city := CityModel.from_document(document)
	var misc: PackedByteArray = document.find_chunk("MISC").decoded_payload
	var teams := PackedStringArray()

	for label_id in range(251, 256):
		teams.append(city.label(label_id))

	for slot in [0, 1, 2, 3, 4, 7, 8]:
		var record := NewsQueue.story_record(misc, slot)
		var seed := NewspaperTextGenerator.published_seed(
			0x1234, city.age_in_days(), 0, slot
		)
		var rendered := NewspaperTextGenerator.render_story(
			data, record, seed, city.city_name(), city.mayor_name(), teams
		)
		_check(rendered.ok, "Newspaper story slot %d renders: %s" % [slot, rendered.error])

		if not rendered.ok:
			continue

		_check(not rendered.headline.is_empty(), "Newspaper story slot %d has a headline" % slot)
		_check(not rendered.article.is_empty(), "Newspaper story slot %d has article text" % slot)
		_check(
			not rendered.headline.contains("�") and not rendered.article.contains("�"),
			"Newspaper story slot %d decodes each source character" % slot,
		)
		var repeated := NewspaperTextGenerator.render_story(
			data, record, seed, city.city_name(), city.mayor_name(), teams
		)
		_check(
			repeated.ok
			and repeated.headline == rendered.headline
			and repeated.article == rendered.article
			and repeated.auxiliary == rendered.auxiliary
			and repeated.random_state == rendered.random_state,
			"Newspaper story slot %d is deterministic for one display seed" % slot,
		)
		var headline_only := NewspaperTextGenerator.render_headline(
			data, record, seed, city.city_name(), city.mayor_name(), teams
		)
		_check(
			headline_only.ok and headline_only.headline == rendered.headline,
			"Newspaper story slot %d has the same standalone headline" % slot,
		)

	for story_type in 80:
		var rendered := NewspaperTextGenerator.render_story(
			data,
			NewsQueue.StoryRecord.new(story_type, 0, PackedByteArray([0xff, 0xff, 0xff])),
			0x4000 + story_type * 17,
			city.city_name(),
			city.mayor_name(),
			teams,
		)
		_check(rendered.ok, "Newspaper grammar type %d renders: %s" % [story_type, rendered.error])

		if rendered.ok:
			_check(not rendered.headline.is_empty(), "Newspaper grammar type %d has a headline" % story_type)
			_check(
				not rendered.headline.contains("�") and not rendered.article.contains("�"),
				"Newspaper grammar type %d decodes each source character" % story_type,
			)


func _test_rci_aftermath(reference_root: String) -> void:
	_check(
		RciAftermath.WEATHER_TRANSITIONS.size() == 384
		and RciAftermath.weather_transition(0, 0, 7) == 8
		and RciAftermath.weather_transition(8, 2, 7) == 11
		and RciAftermath.weather_transition(11, 3, 3) == 8,
		"Weather transitions use all 384 bytes of the supplied four-season table",
	)

	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var source := Vector2i(10, 20)
	var neighbor := Vector2i(11, 20)
	var source_index := source.x * CityModel.MAP_SIZE + source.y
	var neighbor_index := neighbor.x * CityModel.MAP_SIZE + neighbor.y
	var buildings: PackedByteArray = document.find_chunk("XBLD").decoded_payload.duplicate()
	var zones: PackedByteArray = document.find_chunk("XZON").decoded_payload.duplicate()
	var flags: PackedByteArray = document.find_chunk("XBIT").decoded_payload.duplicate()
	buildings[source_index] = Tiles.TREES_1
	buildings[neighbor_index] = Tiles.EMPTY
	zones[source_index] &= 0xf0
	zones[neighbor_index] &= 0xf0
	flags[source_index] &= ~0x04
	flags[neighbor_index] &= ~0x04
	_check(document.find_chunk("XBLD").set_decoded_payload(buildings), "RCI aftermath fixture stores a young tree")
	_check(document.find_chunk("XZON").set_decoded_payload(zones), "RCI aftermath fixture clears military zones")
	_check(document.find_chunk("XBIT").set_decoded_payload(flags), "RCI aftermath fixture clears water flags")

	for setting in [
		[0x01f0 + 0 * 4, 100],
		[0x01f0 + 6 * 4, 1],
		[0x01f0 + 7 * 4, 0],
		[0x01f0 + 0xd7 * 4, 0],
		[0x0048, 60],
		[0x004c, 80],
		[0x0060, 100],
		[0x0064, 20],
		[0x0068, 10],
		[0x006c, 0],
		[0x0fa4, 0],
	]:
		_check(document.set_misc_u32(setting[0], setting[1]), "RCI aftermath fixture sets MISC 0x%x" % setting[0])

	var graphs: PackedByteArray = document.find_chunk("XGRP").decoded_payload.duplicate()

	for series in [4, 5, 7]:
		_write_u32_be(graphs, series * CityModel.GRAPH_VALUE_COUNT * 4, 0)

	_check(document.find_chunk("XGRP").set_decoded_payload(graphs), "RCI aftermath fixture stores quiet graph values")
	var tree_random := SequenceRandom.new([
		10, 20, 0,
		1,
		127, 0, 127, 0, 127, 0,
		0, 0,
		0, 0,
		1,
		7,
	])
	var city := CityModel.from_document(document)
	var result := RciAftermath.run(city, tree_random, 0)
	_check(result.ok, "RCI aftermath phase completes: %s" % result.error)

	if result.ok:
		_check(
			city.building_id(source.x, source.y) == 7
			and city.building_id(neighbor.x, neighbor.y) == 6,
			"Monthly ecology matures one tree and seeds its selected neighbor",
		)
		_check(
			document.misc_u32(0x01f0) == 99
			and document.misc_u32(0x01f0 + 6 * 4) == 1
			and document.misc_u32(0x01f0 + 7 * 4) == 1,
			"Monthly ecology updates the saved tile counts",
		)
		_check(
			result.weather_trend == 8
			and result.heat == 137
			and result.wind == 40
			and result.rain == 20,
			"Weather uses the recovered transition and target averages",
		)
		_check(
			document.misc_u32(0x0060) == 137
			and document.misc_u32(0x0064) == 40
			and document.misc_u32(0x0068) == 20
			and document.misc_u32(0x006c) == 8,
			"Weather stores all four save-visible MISC fields",
		)
		_check(
			NewsEvent.same_arrays(result.news_items, [
				NewsEvent.new(RciAftermath.NEWS_JUNK, 0),
				NewsEvent.new(0x0b, 0),
			]),
			"The ordinary monthly news branch keeps its original order",
		)
		_check(tree_random.position == 16, "Tree, news, invention, and weather checks consume 16 random values")

	var news_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(news_document.set_misc_u32(0x000c, 1900), "News fixture sets the founding year")
	_check(news_document.set_misc_u32(0x0048, 50), "News fixture sets low health")
	_check(news_document.set_misc_u32(0x004c, 50), "News fixture sets low education")
	_check(news_document.set_misc_u32(0x005c, 2), "News fixture sets the national trend")
	_check(news_document.set_misc_u32(0x0060, 100), "News fixture sets heat")
	_check(news_document.set_misc_u32(0x0064, 10), "News fixture sets wind")
	_check(news_document.set_misc_u32(0x0068, 20), "News fixture sets rain")
	_check(news_document.set_misc_u32(0x006c, 1), "News fixture sets clear weather")
	_check(news_document.set_misc_u32(0x01f0 + 0xd7 * 4, 1), "News fixture counts a stadium")
	_check(news_document.set_misc_u32(0x0738 + 7 * 4, 1901), "News fixture schedules an innovation")
	_check(news_document.set_misc_u32(0x0fa4, 10), "News fixture sets unemployment")
	_check(news_document.set_misc_u32(0x1028, 1 << 2), "News fixture enables sports team 2")
	var news_flags: PackedByteArray = news_document.find_chunk("XBIT").decoded_payload.duplicate()
	var news_point := Vector2i(40, 40)
	news_flags[news_point.x * CityModel.MAP_SIZE + news_point.y] |= 0x04
	_check(news_document.find_chunk("XBIT").set_decoded_payload(news_flags), "News fixture makes the ecology point water")
	var news_graphs: PackedByteArray = news_document.find_chunk("XGRP").decoded_payload.duplicate()

	for series in [4, 5, 7]:
		_write_u32_be(news_graphs, series * CityModel.GRAPH_VALUE_COUNT * 4, 20)

	_check(news_document.find_chunk("XGRP").set_decoded_payload(news_graphs), "News fixture stores high graph values")
	var news_misc: PackedByteArray = news_document.find_chunk("MISC").decoded_payload.duplicate()

	for slot in NewsQueue.STORY_RECORD_COUNT:
		var offset := NewsQueue.STORY_OFFSET + slot * NewsQueue.STORY_RECORD_SIZE
		_write_u32_be(news_misc, offset, 11 + slot)
		_write_u32_be(news_misc, offset + 4, 0)
		_write_u32_be(news_misc, offset + 8, 0)

		for field in range(3, NewsQueue.STORY_FIELD_COUNT):
			_write_u32_be(news_misc, offset + field * 4, 0xff)

	_check(
		news_document.find_chunk("MISC").set_decoded_payload(news_misc),
		"News fixture clears the saved priority queue",
	)
	var news_city := CityModel.from_document(news_document)
	_check(news_city.set_age_in_days(300), "News fixture selects 1901")
	var news_random := SequenceRandom.new([
		40, 40,
		0, 0, 0,
		2,
		0, 15, 0, 15, 0, 15,
		0, 3,
		79, 59,
		0,
		0,
	])
	var news_result := RciAftermath.run(news_city, news_random, 2)
	_check(news_result.ok, "Controlled RCI news phase completes: %s" % news_result.error)

	if news_result.ok:
		var news_types := PackedInt32Array()

		for item in news_result.news_items:
			news_types.append(int(item.type))

		_check(
			news_types == PackedInt32Array([1, 6, 7, 8, 17, 18, 16, 21, 19, 20, 5]),
			"RCI news checks emit the recovered ordered story types: %s" % news_types,
		)
		_check(
			news_result.news_items[2].argument == 2
			and news_result.news_items[3].argument == 2,
			"Market and sports stories retain their native arguments",
		)
		_check(news_result.invention_index == 7, "The first due innovation is released")
		_check(news_document.misc_u32(0x0738 + 7 * 4) == 0, "A released innovation clears its saved year")
		_check(news_random.position == 18, "The full controlled news path consumes 18 random values")
		var queued_types := PackedInt32Array()
		var queued_priorities := PackedInt32Array()
		var saved_misc: PackedByteArray = news_document.find_chunk("MISC").decoded_payload

		for slot in NewsQueue.QUEUE_COUNT:
			var record := NewsQueue.story_record(saved_misc, slot)
			queued_types.append(record.type)
			queued_priorities.append(record.priority)

		_check(
			news_result.news_queue_updated
			and queued_types == PackedInt32Array([5, 6, 20, 19, 21, 16, 18]),
			"The monthly RCI phase stores its seven highest-priority stories",
		)
		_check(
			queued_priorities == PackedInt32Array([1000, 360, 200, 200, 200, 200, 200]),
			"The monthly RCI phase stores source-table priorities",
		)

	var arcology_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(arcology_document.set_misc_u32(ToolAvailability.MISC_PROGRESSION, 6), "Arcology release fixture sets metropolis progression")
	_check(arcology_document.set_misc_u32(ToolAvailability.MISC_GRANTED_REWARDS, 0), "Arcology release fixture clears rewards")
	_check(arcology_document.set_misc_u32(0x000c, 1900), "Arcology release fixture sets the founding year")
	_check(arcology_document.set_misc_u32(0x006c, 1), "Arcology release fixture sets valid weather")
	_check(arcology_document.set_misc_u32(0x01f0 + 0xd7 * 4, 0), "Arcology release fixture clears stadiums")

	for invention_index in ToolAvailability.INVENTION_COUNT:
		_check(
			arcology_document.set_misc_u32(
				ToolAvailability.MISC_INVENTION_YEARS + invention_index * 4,
				1902,
			),
			"Arcology release fixture schedules invention %d" % invention_index,
		)

	_check(
		arcology_document.set_misc_u32(
			ToolAvailability.MISC_INVENTION_YEARS + 12 * 4,
			1901,
		),
		"Arcology release fixture schedules its first arcology",
	)
	var arcology_flags: PackedByteArray = arcology_document.find_chunk("XBIT").decoded_payload.duplicate()
	arcology_flags[40 * CityState.MAP_SIZE + 40] |= 0x04
	_check(arcology_document.find_chunk("XBIT").set_decoded_payload(arcology_flags), "Arcology release fixture makes its ecology point water")
	var arcology_city := CityModel.from_document(arcology_document)
	_check(arcology_city.set_age_in_days(300), "Arcology release fixture selects 1901")
	var arcology_release := RciAftermath.run(
		arcology_city,
		SequenceRandom.new([
			40, 40,
			1,
			127, 0, 127, 0, 127, 0,
			0, 127,
			79, 59,
			0,
			0,
		]),
		0,
	)
	_check(
		arcology_release.ok
		and arcology_release.invention_index == 12
		and arcology_document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0x10,
		"A released arcology rebuild enables its saved chooser bit",
	)

	var radioactive_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var radioactive_buildings: PackedByteArray = radioactive_document.find_chunk("XBLD").decoded_payload.duplicate()
	var radioactive_flags: PackedByteArray = radioactive_document.find_chunk("XBIT").decoded_payload.duplicate()
	var radioactive_zones: PackedByteArray = radioactive_document.find_chunk("XZON").decoded_payload.duplicate()
	var radioactive_point := Vector2i(50, 50)
	var radioactive_neighbor := Vector2i(51, 50)
	var radioactive_index := radioactive_point.x * CityModel.MAP_SIZE + radioactive_point.y
	var radioactive_neighbor_index := radioactive_neighbor.x * CityModel.MAP_SIZE + radioactive_neighbor.y
	radioactive_buildings[radioactive_index] = Tiles.RADIOACTIVE_WASTE
	radioactive_buildings[radioactive_neighbor_index] = Tiles.EMPTY
	radioactive_flags[radioactive_index] &= ~0x04
	radioactive_flags[radioactive_neighbor_index] &= ~0x04
	radioactive_zones[radioactive_index] &= 0xf0
	radioactive_zones[radioactive_neighbor_index] &= 0xf0
	_check(radioactive_document.find_chunk("XBLD").set_decoded_payload(radioactive_buildings), "Ecology fixture stores radioactivity")
	_check(radioactive_document.find_chunk("XBIT").set_decoded_payload(radioactive_flags), "Ecology fixture stores dry land")
	_check(radioactive_document.find_chunk("XZON").set_decoded_payload(radioactive_zones), "Ecology fixture stores normal zones")
	_check(radioactive_document.set_misc_u32(0x006c, 0), "Ecology fixture sets valid weather")
	var radioactive_result := RciAftermath.run(
		CityModel.from_document(radioactive_document),
		SequenceRandom.new([50, 50, 0, 0, 0]),
		0
	)
	_check(radioactive_result.ok, "Radioactivity ecology path completes: %s" % radioactive_result.error)

	if radioactive_result.ok:
		_check(
			radioactive_document.find_chunk("XBLD").decoded_payload[radioactive_index] == 0
			and radioactive_document.find_chunk("XBLD").decoded_payload[radioactive_neighbor_index] == 6,
			"Radioactivity can decay before the independent tree-spread gate",
		)


func _test_weather_disaster_phase(reference_root: String) -> void:
	var power_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x001c, 1],
		[0x006c, 1],
		[0x1000, 1],
	]:
		_check(
			power_document.set_misc_u32(setting[0], setting[1]),
			"City-status fixture sets MISC 0x%x" % setting[0],
		)

	var power_random := SequenceRandom.new([])
	var power_result := WeatherDisaster.run(
		CityModel.from_document(power_document),
		power_random,
		ZeroLfsrRandom.new(),
		99,
		0,
		0,
		0,
	)
	_check(power_result.ok, "City-status phase completes: %s" % power_result.error)

	if power_result.ok:
		_check(
			power_result.status_index == WeatherDisaster.STATUS_POWER
			and power_result.status_news_type == 46
			and NewsEvent.same_arrays(power_result.news_items, [NewsEvent.new(46, 0)]),
			"A fully used power system requests more power with story type 46",
		)
		_check(
			power_result.disaster_type == WeatherDisaster.DISASTER_NONE
			and power_random.position == 0,
			"No Disasters suppresses the natural-disaster roll",
		)

	var stable_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x001c, 1],
		[0x006c, 1],
		[0x1000, 1],
		[0x1020, 0],
		[0x102c, 1000],
		[0x01f0 + WeatherDisaster.TILE_POLICE * 4, 9],
		[0x01f0 + WeatherDisaster.TILE_PRISON * 4, 0],
		[0x01f0 + WeatherDisaster.TILE_FIRE * 4, 9],
		[0x077c + WeatherDisaster.BUDGET_ROAD * 0x006c, 11],
	]:
		_check(
			stable_document.set_misc_u32(setting[0], setting[1]),
			"Stable city fixture sets MISC 0x%x" % setting[0],
		)

	var stable_result := WeatherDisaster.run(
		CityModel.from_document(stable_document),
		SequenceRandom.new([]),
		ZeroLfsrRandom.new(),
		0,
		0,
		0,
		0,
	)
	_check(
		stable_result.ok
		and stable_result.status_index == WeatherDisaster.STATUS_NONE
		and stable_result.news_items.is_empty(),
		"A supplied small city does not request an unnecessary service",
	)

	var hospital_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x001c, 1],
		[0x006c, 1],
		[0x1000, 1],
		[0x1020, 0],
		[0x102c, 25000],
		[0x01f0 + WeatherDisaster.TILE_POLICE * 4, 18],
		[0x01f0 + WeatherDisaster.TILE_PRISON * 4, 0],
		[0x01f0 + WeatherDisaster.TILE_FIRE * 4, 18],
		[0x01f0 + WeatherDisaster.TILE_HOSPITAL * 4, 0],
		[0x077c + WeatherDisaster.BUDGET_ROAD * 0x006c, 251],
	]:
		_check(
			hospital_document.set_misc_u32(setting[0], setting[1]),
			"Hospital-demand fixture sets MISC 0x%x" % setting[0],
		)

	var hospital_result := WeatherDisaster.run(
		CityModel.from_document(hospital_document),
		SequenceRandom.new([]),
		ZeroLfsrRandom.new(),
		0,
		0,
		0,
		0,
	)
	_check(
		hospital_result.ok
		and hospital_result.status_index == WeatherDisaster.STATUS_HOSPITAL
		and hospital_result.status_news_type == 51,
		"The recovered hierarchy requests a hospital after power, transit, police, fire, and water",
	)

	var wait_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(wait_document.set_misc_u32(0x001c, 1), "Disaster wait fixture selects Easy")
	_check(wait_document.set_misc_u32(0x006c, 9), "Disaster wait fixture selects severe weather text")
	_check(wait_document.set_misc_u32(0x1000, 0), "Disaster wait fixture enables disasters")
	var wait_city := CityModel.from_document(wait_document)
	_check(wait_city.set_age_in_days(99 * 25), "Disaster wait fixture selects month 99")
	var wait_random := SequenceRandom.new([])
	var wait_result := WeatherDisaster.run(
		wait_city, wait_random, ZeroLfsrRandom.new(), 0, 0, 0, 0
	)
	_check(
		wait_result.ok
		and wait_result.wait_months == 100
		and wait_result.disaster_type == WeatherDisaster.DISASTER_NONE
		and wait_random.position == 0,
		"Easy cities cannot receive a natural disaster before month 100",
	)

	var hurricane_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x001c, 3],
		[0x006c, 10],
		[0x0e44, 1],
		[0x1000, 0],
	]:
		_check(
			hurricane_document.set_misc_u32(setting[0], setting[1]),
			"Hurricane fixture sets MISC 0x%x" % setting[0],
		)

	var hurricane_city := CityModel.from_document(hurricane_document)
	_check(hurricane_city.set_age_in_days(30 * 25), "Hurricane fixture reaches Hard wait age")
	var hurricane_random := SequenceRandom.new([14])
	var hurricane_result := WeatherDisaster.run(
		hurricane_city, hurricane_random, ZeroLfsrRandom.new(), 0, 0, 0, 0
	)
	_check(
		hurricane_result.ok
		and hurricane_result.disaster_type == WeatherDisaster.DISASTER_HURRICANE
		and hurricane_result.disaster_roll == 14
		and hurricane_random.position == 1,
		"Ocean weather type 10 schedules a Hurricane on rolls below 15",
	)

	var tornado_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x001c, 3],
		[0x006c, 11],
		[0x1000, 0],
	]:
		_check(
			tornado_document.set_misc_u32(setting[0], setting[1]),
			"Tornado fixture sets MISC 0x%x" % setting[0],
		)

	var tornado_city := CityModel.from_document(tornado_document)
	_check(tornado_city.set_age_in_days(30 * 25), "Tornado fixture reaches Hard wait age")
	var tornado_random := SequenceRandom.new([14, 5, 7])
	var tornado_result := WeatherDisaster.run(
		tornado_city, tornado_random, ZeroLfsrRandom.new(), 0, 0, 0, 0
	)
	_check(
		tornado_result.ok
		and tornado_result.disaster_type == WeatherDisaster.DISASTER_TORNADO
		and tornado_result.disaster_point == Vector2i(8, 6)
		and tornado_random.position == 3,
		"Weather type 11 schedules a Tornado and keeps the original Y-then-X random order",
	)

	var fire_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x001c, 3],
		[0x0060, 255],
		[0x006c, 9],
		[0x1000, 0],
	]:
		_check(
			fire_document.set_misc_u32(setting[0], setting[1]),
			"Fire selector fixture sets MISC 0x%x" % setting[0],
		)

	var fire_city := CityModel.from_document(fire_document)
	_check(fire_city.set_age_in_days(30 * 25), "Fire selector fixture reaches Hard wait age")
	var fire_random := SequenceRandom.new([0, 1, 0, 4, 6])
	var fire_result := WeatherDisaster.run(
		fire_city, fire_random, ZeroLfsrRandom.new(), 0, 0, 0, 0
	)
	_check(
		fire_result.ok
		and fire_result.candidate_type == WeatherDisaster.DISASTER_FIRE
		and fire_result.disaster_type == WeatherDisaster.DISASTER_FIRE
		and fire_result.disaster_point == Vector2i(7, 5)
		and fire_random.position == 5,
		"A zero monthly roll can pass the Fire heat gate and select a map point",
	)

	var toxic_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x001c, 3],
		[0x006c, 9],
		[0x1000, 0],
	]:
		_check(
			toxic_document.set_misc_u32(setting[0], setting[1]),
			"Toxic selector fixture sets MISC 0x%x" % setting[0],
		)

	var pollution := PackedByteArray()
	pollution.resize(64 * 64)
	pollution.fill(0)
	pollution[10 * 64 + 20] = 200
	_check(
		toxic_document.find_chunk("XPLT").set_decoded_payload(pollution),
		"Toxic selector fixture stores one polluted coarse tile",
	)
	var toxic_city := CityModel.from_document(toxic_document)
	_check(toxic_city.set_age_in_days(30 * 25), "Toxic selector fixture reaches Hard wait age")
	var toxic_random := SequenceRandom.new([0, 4])
	var toxic_lfsr := SequenceLfsrRandom.new([0, 2, 3])
	var toxic_result := WeatherDisaster.run(
		toxic_city, toxic_random, toxic_lfsr, 0, 0, 0, 0
	)
	_check(
		toxic_result.ok
		and toxic_result.candidate_type == WeatherDisaster.DISASTER_TOXIC_SPILL
		and toxic_result.disaster_type == WeatherDisaster.DISASTER_TOXIC_SPILL
		and toxic_result.disaster_point == Vector2i(17, 38)
		and toxic_random.position == 2
		and toxic_lfsr.position == 3,
		"Toxic Spill selects a record-high polluted tile with the LFSR gates and jitter",
	)

	var invalid_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(invalid_document.set_misc_u32(0x001c, 0), "Invalid disaster fixture clears difficulty")
	_check(invalid_document.set_misc_u32(0x1000, 1), "Invalid disaster fixture first disables disasters")
	var invalid_suppressed := WeatherDisaster.run(
		CityModel.from_document(invalid_document),
		SequenceRandom.new([]),
		ZeroLfsrRandom.new(),
		0,
		0,
		0,
		0,
	)
	_check(
		invalid_suppressed.ok
		and invalid_suppressed.disaster_type == WeatherDisaster.DISASTER_NONE,
		"No Disasters returns before the original difficulty-table access",
	)
	_check(invalid_document.set_misc_u32(0x1000, 0), "Invalid disaster fixture enables disasters")
	var invalid_result := WeatherDisaster.run(
		CityModel.from_document(invalid_document),
		SequenceRandom.new([]),
		ZeroLfsrRandom.new(),
		0,
		0,
		0,
		0,
	)
	_check(
		not invalid_result.ok and not invalid_result.error.is_empty(),
		"The natural-disaster selector rejects an invalid saved difficulty",
	)


func _test_simnation(reference_root: String) -> void:
	_check(
		SimNation.economy_level(44) == 0
		and SimNation.economy_level(45) == 1
		and SimNation.economy_level(60) == 2
		and SimNation.economy_level(75) == 3,
		"SimNation uses the recovered national-value level boundaries",
	)

	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x0050, 1_200_000],
		[0x0054, 3_000_000],
		[0x0058, 4],
		[0x005c, 2],
		[0x06dc, 1_200_000],
		[0x06e0, 600_000],
		[0x06ec, 0],
		[0x06f0, 0],
		[0x06fc, 6_000_000],
		[0x0700, 4_000_000],
		[0x070c, 1],
		[0x0710, 0],
	]:
		_check(document.set_misc_u32(setting[0], setting[1]), "SimNation fixture sets MISC 0x%x" % setting[0])

	var random := SequenceRandom.new([1, 0, 0, 2, 4, 0, 1, 0, 1])
	var result := SimNation.run(CityModel.from_document(document), random)
	_check(result.ok, "SimNation phase completes: %s" % result.error)

	if result.ok:
		_check(
			result.national_population == 1_202_000
			and result.national_value == 3_000_000,
			"SimNation moves national population and value about their centers",
		)
		_check(
			result.neighbor_populations == PackedInt64Array([1_202_000, 0, 5_980_000, 2]),
			"SimNation updates each non-ocean neighbor population in compass order",
		)
		_check(
			result.neighbor_values == PackedInt64Array([597_500, 0, 4_006_666, 0]),
			"SimNation updates neighbor values with federal and local economy factors",
		)
		_check(result.news_items.is_empty(), "A quiet SimNation month emits no report")
		_check(random.position == 9, "The quiet neighbor update consumes nine process-random values")
		_check(
			document.misc_u32(0x0050) == 1_202_000
			and document.misc_u32(0x06e0) == 597_500
			and document.misc_u32(0x0700) == 4_006_666,
			"SimNation stores the national and neighbor fields in MISC",
		)

	var news_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x0050, 1_000_000],
		[0x0054, 800_000],
		[0x0058, 3],
		[0x005c, 0],
		[0x06dc, 0], [0x06ec, 0], [0x06fc, 0], [0x070c, 0],
	]:
		_check(news_document.set_misc_u32(setting[0], setting[1]), "SimNation news fixture sets MISC 0x%x" % setting[0])

	var news_random := SequenceRandom.new([0, 0, 0, 99, 0, 1])
	var news_result := SimNation.run(CityModel.from_document(news_document), news_random)
	_check(news_result.ok, "Controlled SimNation news phase completes: %s" % news_result.error)

	if news_result.ok:
		_check(
			NewsEvent.same_arrays(news_result.news_items, [
				NewsEvent.new(9, 4),
				NewsEvent.new(10, 3),
				NewsEvent.new(7, 3),
			]),
			"SimNation emits federal-rate and national-economy reports in native order",
		)
		_check(
			news_result.national_value == 804_000
			and news_result.federal_rate == 3
			and news_result.economy_trend == 3,
			"SimNation applies the controlled national-news update",
		)
		_check(news_random.position == 6, "The national-news path consumes six process-random values")

	var shock_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x0050, 1_000_000], [0x0054, 1_000_000], [0x0058, 3], [0x005c, 0],
		[0x06dc, 1200], [0x06e0, 1200],
		[0x06ec, 0], [0x06fc, 0], [0x070c, 0],
	]:
		_check(shock_document.set_misc_u32(setting[0], setting[1]), "Regional shock fixture sets MISC 0x%x" % setting[0])

	var shock_random := SequenceRandom.new([1, 0, 0, 0, 0, 0])
	var shock_result := SimNation.run(CityModel.from_document(shock_document), shock_random)
	_check(shock_result.ok, "Regional shock phase completes: %s" % shock_result.error)

	if shock_result.ok:
		_check(
			shock_result.shocked_neighbor == 0
			and shock_result.neighbor_populations[0] == 900
			and shock_result.neighbor_values[0] == 600,
			"The one-in-64 regional shock keeps 75 percent population and 50 percent value",
		)
		_check(shock_random.position == 6, "The regional-shock path consumes six process-random values")


func _test_industries(reference_root: String) -> void:
	_check(
		Industries.world_demands(1900, 25)
		== PackedInt32Array([25, 20, 25, 10, 17, 22, 10, 17, 12, 5, 15]),
		"Industry world demand interpolates between the executable's 50-year rows",
	)
	_check(
		Industries.world_demands(2100, 0)
		== PackedInt32Array([10, 20, 10, 10, 20, 20, 50, 30, 20, 80, 50]),
		"Industry world demand retains the final executable row after 2100",
	)

	var stable_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x000c, 1900], [0x0010, 0], [0x004c, 80], [0x0fa0, 0],
		[0x0604, 40], [0x0608, 60],
	]:
		_check(stable_document.set_misc_u32(setting[0], setting[1]), "Industry fixture sets MISC 0x%x" % setting[0])

	var stable_ratios := [30, 10, 10, 0, 0, 10, 0, 0, 0, 0, 40]
	var initial_demands := [20, 20, 10, 10, 15, 5, 0, 15, 8, 0, 10]

	for industry in 11:
		var base := 0x016c + industry * 0x0c
		_check(stable_document.set_misc_u32(base, initial_demands[industry]), "Industry fixture sets demand %d" % industry)
		_check(stable_document.set_misc_u32(base + 4, 0), "Industry fixture clears tax %d" % industry)
		_check(stable_document.set_misc_u32(base + 8, stable_ratios[industry]), "Industry fixture sets ratio %d" % industry)

	var stable_lfsr_values: Array[int] = []
	stable_lfsr_values.resize(44)
	stable_lfsr_values.fill(64)
	var stable_random := SequenceRandom.new([])
	var stable_lfsr := SequenceLfsrRandom.new(stable_lfsr_values)
	var stable_result := Industries.run(
		CityModel.from_document(stable_document), stable_random, stable_lfsr, 0
	)
	_check(stable_result.ok, "Stable industry phase completes: %s" % stable_result.error)

	if stable_result.ok:
		_check(
			stable_result.demands == PackedInt32Array(initial_demands),
			"Four midpoint LFSR values retain each matching world demand",
		)
		_check(
			stable_result.ratios == PackedInt64Array(stable_ratios)
			and stable_result.ratio_total_after == 100,
			"Matching industry population leaves all eleven ratios unchanged",
		)
		_check(
			stable_result.pollution_share == 59
			and stable_result.pollution_bonus == 1
			and stable_result.maximum_share == 39
			and stable_result.mix_bonus == 3,
			"Industry ratios produce both recovered industrial-mix bonuses",
		)
		_check(stable_lfsr.position == 44, "Industry demand consumes four LFSR values per industry")
		_check(stable_random.position == 0, "Balanced industry ratios consume no process-random values")
		_check(
			stable_document.misc_u32(0x1030) == 3
			and stable_document.misc_u32(0x1034) == 1,
			"Industry phase stores both industrial-mix bonuses",
		)

	var growth_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x000c, 1900], [0x0010, 0], [0x004c, 131], [0x0fa0, 0x00080000],
		[0x0604, 44], [0x0608, 44],
	]:
		_check(growth_document.set_misc_u32(setting[0], setting[1]), "Industry growth fixture sets MISC 0x%x" % setting[0])

	for industry in 11:
		var base := 0x016c + industry * 0x0c
		_check(growth_document.set_misc_u32(base, 100), "Industry growth fixture sets demand %d" % industry)
		_check(growth_document.set_misc_u32(base + 4, 70), "Industry growth fixture sets tax %d" % industry)
		_check(growth_document.set_misc_u32(base + 8, 0), "Industry growth fixture clears ratio %d" % industry)

	var growth_lfsr := SequenceLfsrRandom.new(stable_lfsr_values)
	var growth_random := SequenceRandom.new([1, 1, 1, 1, 1, 1, 1, 1, 1])
	var growth_result := Industries.run(
		CityModel.from_document(growth_document), growth_random, growth_lfsr, 1
	)
	_check(growth_result.ok, "Growing industry phase completes: %s" % growth_result.error)

	if growth_result.ok:
		_check(
			growth_result.demands == PackedInt32Array([80, 80, 77, 77, 78, 76, 75, 78, 77, 75, 77]),
			"Industry demand smooths the old and random world values",
		)
		_check(
			growth_result.adjusted_demands
			== PackedInt32Array([2, 2, 0, 7, 15, 0, 20, 8, 7, 20, 7]),
			"Clean Industry, population growth, workforce EQ, and taxes adjust exact sectors",
		)
		_check(
			growth_result.ratios
			== PackedInt64Array([2, 2, 0, 7, 15, 0, 20, 8, 7, 20, 7]),
			"Positive industry demand distributes the full population shortage",
		)
		_check(growth_random.position == 9, "Nine positive industries consume nine rounding values")
		_check(growth_lfsr.position == 44, "Growing industry demand preserves the LFSR call count")

	var excess_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for setting in [
		[0x000c, 1900], [0x0010, 0], [0x004c, 80], [0x0fa0, 0],
		[0x0604, 50], [0x0608, 50],
	]:
		_check(excess_document.set_misc_u32(setting[0], setting[1]), "Industry excess fixture sets MISC 0x%x" % setting[0])

	for industry in 11:
		var base := 0x016c + industry * 0x0c
		_check(excess_document.set_misc_u32(base, initial_demands[industry]), "Industry excess fixture sets demand %d" % industry)
		_check(excess_document.set_misc_u32(base + 4, 0), "Industry excess fixture clears tax %d" % industry)
		_check(excess_document.set_misc_u32(base + 8, 100), "Industry excess fixture sets ratio %d" % industry)

	var excess_lfsr := SequenceLfsrRandom.new(stable_lfsr_values)
	var excess_random := SequenceRandom.new([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	var excess_result := Industries.run(
		CityModel.from_document(excess_document), excess_random, excess_lfsr, 0
	)
	_check(excess_result.ok, "Excess industry phase completes: %s" % excess_result.error)

	if excess_result.ok:
		_check(
			excess_result.ratios == PackedInt64Array([9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9])
			and excess_result.ratio_total_after == 99,
			"Excess industry ratios use proportional removal and random rounding",
		)
		_check(excess_random.position == 11, "Excess removal consumes one rounding value per industry")


func _test_education_health(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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

	var empty_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(empty_document.set_misc_u32(0x102c, 0), "Empty demographic fixture clears city population")
	_check(empty_document.set_misc_u32(0x007c, 99), "Empty demographic fixture installs a stale cohort")
	var empty_result := EducationHealth.run(CityModel.from_document(empty_document), Random.new(1))
	_check(empty_result.ok and empty_result.empty_city, "Zero population takes the empty-city path")
	_check(empty_document.misc_u32(0x007c) == 0, "Empty-city path clears demographic tables")

	var mortality_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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

	var migration_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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
	var document := _load_fixture(reference_root.path_join("CITIES/STARTER.SC2"))
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
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var buildings := PackedByteArray()
	buildings.resize(CityModel.TILE_COUNT)
	buildings[20 * CityModel.MAP_SIZE + 20] = Tiles.GAS_POWER
	buildings[20 * CityModel.MAP_SIZE + 21] = Tiles.NUCLEAR_POWER
	buildings[21 * CityModel.MAP_SIZE + 20] = Tiles.RADIOACTIVE_WASTE
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
	_check(document.set_misc_u32(0x104c, 0), "Pollution test clears the treatment state")
	_check(document.set_misc_u32(0x1050, 99), "Pollution test installs ignored trailing data")
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
	_check(
		document.find_chunk("XPLT").set_decoded_payload(previous)
		and document.set_misc_u32(0x104c, 1),
		"Pollution test enables sufficient water treatment",
	)
	var treated_result := Pollution.run(city)
	_check(
		treated_result.ok
		and document.find_chunk("XPLT").decoded_payload[10 * 64 + 10] == 56
		and treated_result.pollution_total == 168,
		"Sufficient treatment increases the pollution smoothing divisor",
	)

	var clean_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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
	clean_buildings[40 * 128 + 40] = Tiles.ROAD_STRAIGHT_1
	_check(
		clean_document.find_chunk("XBLD").set_decoded_payload(clean_buildings),
		"Combined scan test places one road tile"
	)

	for offset in [0x0fa0, 0x1034, 0x103c, 0x104c]:
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
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	var data := PackedByteArray()
	data.resize(CityModel.GRAPH_COUNT * CityModel.GRAPH_VALUE_COUNT * 4)

	for series in CityModel.GRAPH_COUNT:
		for index in CityModel.GRAPH_VALUE_COUNT:
			_write_u32_be(data, (series * CityModel.GRAPH_VALUE_COUNT + index) * 4, series * 1000 + index)

	_check(document.find_chunk("XGRP").set_decoded_payload(data), "Graph test installs known history")
	_check(city.set_age_in_days(150), "Graph test selects July")
	var year_history := GraphView.history_for_scale(city, 2, GraphView.TIME_YEAR)
	var decade_history := GraphView.history_for_scale(city, 2, GraphView.TIME_DECADE)
	var century_history := GraphView.history_for_scale(city, 2, GraphView.TIME_CENTURY)
	_check(
		year_history.size() == 12
		and year_history[0] == 2011
		and year_history[-1] == 2000,
		"Graph window orders monthly history from oldest to newest",
	)
	_check(
		decade_history.size() == 20
		and decade_history[0] == 2031
		and decade_history[-1] == 2012,
		"Graph window orders half-year history from oldest to newest",
	)
	_check(
		century_history.size() == 20
		and century_history[0] == 2051
		and century_history[-1] == 2032,
		"Graph window orders five-year history from oldest to newest",
	)
	var display_maxima := GraphView.display_maxima(city)
	_check(
		display_maxima[0] == 51
		and display_maxima[1] == 51
		and display_maxima[3] == 51,
		"Graph window shares the City Size maximum with RCI series",
	)
	_check(
		display_maxima[4] == 7051 and display_maxima[7] == 7051,
		"Graph window shares the traffic through crime maximum",
	)
	_check(
		display_maxima[13] == 14051 and display_maxima[14] == 14051,
		"Graph window raises the GNP maximum to national population",
	)
	_check(
		GraphView.DEFAULT_SELECTED_MASK == 0x000f
		and GraphView.SERIES_MARKERS[15] == "%",
		"Graph window uses the recovered defaults and Federal Rate marker",
	)
	_check(
		GraphView.format_value(0, 9999) == "9999"
		and GraphView.format_value(0, 10000) == "10k"
		and GraphView.format_value(14, 999) == "999"
		and GraphView.format_value(14, 1000) == "1k"
		and GraphView.format_value(14, 1000000) == "1m",
		"Graph window uses the recovered compact number thresholds",
	)
	var month_labels := GraphView.time_labels(city, GraphView.TIME_YEAR)
	_check(
		month_labels.size() == 12
		and month_labels[0] == "Aug"
		and month_labels[-1] == "Jul",
		"Graph window aligns the one-year labels to the current month",
	)

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


func _load_indexed_u16_resource(reference_root: String, resource_id: int) -> PackedInt32Array:
	var index := FileAccess.get_file_as_bytes(reference_root.path_join("DATA/DATA_USA.IDX"))
	var data := FileAccess.get_file_as_bytes(reference_root.path_join("DATA/DATA_USA.DAT"))

	if index.is_empty() or data.is_empty() or index.size() % 8 != 0:
		return PackedInt32Array()

	var start := -1
	var end := -1

	for offset in range(0, index.size(), 8):
		var current_id := _read_u32_le(index, offset)
		var current_start := _read_u32_le(index, offset + 4)

		if start >= 0 and end < 0:
			end = current_start
			break

		if current_id == resource_id:
			start = current_start

	if start < 0:
		return PackedInt32Array()

	if end < 0:
		end = data.size()

	if start > end or end > data.size() or (end - start) % 2 != 0:
		return PackedInt32Array()

	var values := PackedInt32Array()

	for offset in range(start, end, 2):
		values.append((int(data[offset]) << 8) | int(data[offset + 1]))

	return values


func _read_u32_le(data: PackedByteArray, offset: int) -> int:
	return (
		int(data[offset])
		| (int(data[offset + 1]) << 8)
		| (int(data[offset + 2]) << 16)
		| (int(data[offset + 3]) << 24)
	)


func _read_u16_le(data: PackedByteArray, offset: int) -> int:
	return int(data[offset]) | (int(data[offset + 1]) << 8)


func _load_pe_rva_bytes(path: String, rva: int, size: int) -> PackedByteArray:
	var data := FileAccess.get_file_as_bytes(path)

	if data.size() < 0x40 or _read_u16_le(data, 0) != 0x5a4d:
		return PackedByteArray()

	var pe_offset := _read_u32_le(data, 0x3c)

	if pe_offset < 0 or pe_offset > data.size() - 24:
		return PackedByteArray()

	var section_count := _read_u16_le(data, pe_offset + 6)
	var optional_size := _read_u16_le(data, pe_offset + 20)
	var section_offset := pe_offset + 24 + optional_size

	if section_offset < 0 or section_offset > data.size() - section_count * 40:
		return PackedByteArray()

	for section_index in section_count:
		var header := section_offset + section_index * 40
		var virtual_size := _read_u32_le(data, header + 8)
		var virtual_address := _read_u32_le(data, header + 12)
		var raw_size := _read_u32_le(data, header + 16)
		var raw_offset := _read_u32_le(data, header + 20)
		var mapped_size := maxi(virtual_size, raw_size)

		if rva < virtual_address or rva + size > virtual_address + mapped_size:
			continue

		var file_offset := raw_offset + rva - virtual_address

		if file_offset < 0 or file_offset > data.size() - size:
			return PackedByteArray()

		return data.slice(file_offset, file_offset + size)

	return PackedByteArray()


func _clear_news_records(document) -> bool:
	var misc_chunk = document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != NewsQueue.MISC_SIZE:
		return false

	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()

	for slot in NewsQueue.STORY_RECORD_COUNT:
		var offset := NewsQueue.STORY_OFFSET + slot * NewsQueue.STORY_RECORD_SIZE
		_write_u32_be(misc, offset, 11 + slot)
		_write_u32_be(misc, offset + 4, 0)
		_write_u32_be(misc, offset + 8, 0)

		for field in range(3, NewsQueue.STORY_FIELD_COUNT):
			_write_u32_be(misc, offset + field * 4, 0xff)

	return misc_chunk.set_decoded_payload(misc)


func _test_modified_save(reference_root: String) -> void:
	var source_path := reference_root.path_join("DEFAULT.SC2")
	var document := _load_fixture(source_path)
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

	var original := _load_fixture(source_path)

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

	var save_base := ProjectSettings.globalize_path(
		"user://test_city_file_store_%d" % OS.get_process_id()
	)
	var saved_copy := CityFileStore.save_copy(document, save_base, reference_root)
	_check(
		saved_copy.ok
		and saved_copy.path == save_base + ".SC2"
		and FileAccess.get_file_as_bytes(saved_copy.path) == serialized.data,
		"City file store adds the SC2 extension and writes exact serialized bytes",
	)

	if saved_copy.ok and FileAccess.file_exists(saved_copy.path):
		DirAccess.remove_absolute(saved_copy.path)

	_check(
		CityFileStore.is_reference_path(
			ProjectSettings.globalize_path("user://original_game/DEFAULT.SC2"),
			ProjectSettings.globalize_path("user://original_game")
		),
		"The selected original support-data directory stays protected",
	)
	var protected_copy := CityFileStore.save_copy(
		document, reference_root.path_join("DO_NOT_WRITE.SC2"), reference_root
	)
	_check(
		not protected_copy.ok and not protected_copy.error.is_empty(),
		"City file store rejects every path inside the reference directory",
	)
	_check(
		not CityFileStore.save_copy(null, save_base, reference_root).ok,
		"City file store rejects a missing city document",
	)


func _test_new_city_terrain(reference_root: String) -> void:
	var source_path := reference_root.path_join("DEFAULT.SC2")
	var template := _load_fixture(source_path)
	var original_altitude := template.find_chunk("ALTM").decoded_payload.duplicate()
	var options := NewCityTerrain.Options.new()
	options.ocean = NewCityTerrain.DEFAULT_OCEAN
	options.river = NewCityTerrain.DEFAULT_RIVER
	options.hills = NewCityTerrain.DEFAULT_HILLS
	options.water = NewCityTerrain.DEFAULT_WATER
	options.trees = NewCityTerrain.DEFAULT_TREES
	var process_random := Random.new(1)
	var game_random := GameRandom.new(1)
	var generated := NewCity.create(
		template, "Terrain City", "Terrain Mayor", 1, 1900,
		process_random, game_random, options
	)
	_check(generated.ok, "Default new-city terrain generates: %s" % generated.error)

	if generated.ok:
		var document: Sc2File = generated.document
		var city := CityModel.from_document(document)
		var terrain_result: NewCityTerrain.Result = generated.terrain
		_check(
			terrain_result.water_level == 4
			and document.misc_u32(NewCityTerrain.MISC_WATER_LEVEL) == 4
			and document.misc_u32(NewCityTerrain.MISC_HAS_OCEAN) == 0
			and document.misc_u32(NewCityTerrain.MISC_HAS_RIVER) == 1,
			"Default terrain stores its recovered water, ocean, and river values",
		)
		var water_tiles := 0
		var tree_tiles := 0
		var cardinal_grade_is_valid := true

		for x in CityState.MAP_SIZE:
			for y in CityState.MAP_SIZE:
				var building := city.building_id(x, y)

				if city.is_water(x, y):
					water_tiles += 1

				if building >= 0x06 and building <= 0x0c:
					tree_tiles += 1

				if x < CityState.MAP_SIZE - 1:
					cardinal_grade_is_valid = cardinal_grade_is_valid and (
						absi(city.land_altitude(x, y) - city.land_altitude(x + 1, y)) <= 1
					)

				if y < CityState.MAP_SIZE - 1:
					cardinal_grade_is_valid = cardinal_grade_is_valid and (
						absi(city.land_altitude(x, y) - city.land_altitude(x, y + 1)) <= 1
					)

		var saved_count_total := 0

		for building_id in 256:
			saved_count_total += document.misc_u32(
				NewCityTerrain.MISC_TILE_COUNTS + building_id * 4
			)

		_check(
			water_tiles == terrain_result.water_tiles and water_tiles > 0,
			"Default terrain makes the recovered river and water paths",
		)
		_check(
			tree_tiles == terrain_result.tree_tiles and tree_tiles > 0,
			"Default terrain grows trees only on its dry tiles",
		)
		_check(
			cardinal_grade_is_valid,
			"Generated terrain keeps each cardinal height change to one level",
		)
		_check(
			saved_count_total == CityState.TILE_COUNT,
			"Generated terrain rebuilds all saved XBLD tile counts",
		)
		_check(
			terrain_result.water_tiles == 1456
			and terrain_result.tree_tiles == 2009
			and terrain_result.minimum_altitude == 2
			and terrain_result.maximum_altitude == 11
			and process_random.state == 3611152639
			and game_random.state == 1692766423,
			"Seed one preserves the recovered terrain pass and random-call order",
		)
		var serialized := document.serialize()
		var reparsed := Sc2Document.new()
		_check(
			serialized.ok and reparsed.parse(serialized.data),
			"Generated terrain serializes and reparses: %s" % reparsed.parse_error,
		)

	var repeated_process := Random.new(1)
	var repeated_game := GameRandom.new(1)
	var repeated := NewCity.create(
		template, "Terrain City", "Terrain Mayor", 1, 1900,
		repeated_process, repeated_game, options
	)
	_check(repeated.ok, "Repeated terrain generation succeeds: %s" % repeated.error)

	if generated.ok and repeated.ok:
		var same_maps := true

		for chunk_id in ["ALTM", "XTER", "XBLD", "XBIT"]:
			same_maps = same_maps and (
				generated.document.find_chunk(chunk_id).decoded_payload
				== repeated.document.find_chunk(chunk_id).decoded_payload
			)

		_check(
			same_maps
			and repeated_process.state == process_random.state
			and repeated_game.state == game_random.state,
			"Terrain generation is deterministic for both recovered random states",
		)

	var terrain_session := NewCityTerrainSession.new()
	terrain_session.begin(1, 1)
	var session_preview := terrain_session.generate_preview(
		source_path, options, false
	)
	_check(
		session_preview.ok
		and terrain_session.matches(options)
		and terrain_session.preview_process_start == 1
		and terrain_session.preview_game_start == 1
		and terrain_session.preview_process_cursor == 981240924
		and terrain_session.preview_game_cursor == 1692766423,
		"New City terrain session owns the preview seeds and current options (%d, %d)"
		% [
			terrain_session.preview_process_cursor,
			terrain_session.preview_game_cursor,
		],
	)
	var repeated_preview := terrain_session.generate_preview(
		source_path, options, false
	)
	var repeated_preview_matches: bool = (
		bool(session_preview.ok) and bool(repeated_preview.ok)
	)

	if repeated_preview_matches:
		for chunk_id in ["ALTM", "XTER", "XBLD", "XBIT"]:
			repeated_preview_matches = repeated_preview_matches and (
				session_preview.document.find_chunk(chunk_id).decoded_payload
				== repeated_preview.document.find_chunk(chunk_id).decoded_payload
			)

	_check(
		repeated_preview_matches
		and terrain_session.preview_process_start == 1
		and terrain_session.preview_game_start == 1,
		"New City option previews reuse their initial random states",
	)
	var previous_process_cursor := terrain_session.preview_process_cursor
	var previous_game_cursor := terrain_session.preview_game_cursor
	var advanced_preview := terrain_session.generate_preview(
		source_path, options, true
	)
	_check(
		advanced_preview.ok
		and terrain_session.preview_process_start == previous_process_cursor
		and terrain_session.preview_game_start == previous_game_cursor,
		"Make New Terrain advances both preview random states",
	)
	terrain_session.clear()
	_check(
		not terrain_session.matches(options),
		"Closing New City clears its preview document",
	)

	var ocean_options := NewCityTerrain.Options.new()
	ocean_options.ocean = true
	ocean_options.river = false
	ocean_options.hills = 12
	ocean_options.water = 5
	ocean_options.trees = 0
	var ocean := NewCity.create(
		template, "Ocean City", "Ocean Mayor", 1, 1900,
		Random.new(1), GameRandom.new(1),
		ocean_options
	)
	_check(ocean.ok, "Ocean-only terrain generates: %s" % ocean.error)

	if ocean.ok:
		var ocean_city := CityModel.from_document(ocean.document)
		var wet_east_edge := 0

		for y in CityState.MAP_SIZE:
			if ocean_city.is_water(CityState.MAP_SIZE - 1, y):
				wet_east_edge += 1

		_check(
			ocean.terrain.salt_water_tiles > 0
			and wet_east_edge > (CityState.MAP_SIZE >> 1),
			"Ocean terrain makes a salt-water edge",
		)

	var rejected_process := Random.new(123)
	var rejected_game := GameRandom.new(456)
	var rejected := NewCityTerrain.generate(
		template.duplicate_document(), false, true, 48, 5, 15,
		rejected_process, rejected_game
	)
	_check(
		not rejected.ok
		and rejected_process.state == 123
		and rejected_game.state == 456
		and template.find_chunk("ALTM").decoded_payload == original_altitude,
		"Invalid terrain settings preserve both random states and the template",
	)


func _test_new_city_setup(reference_root: String) -> void:
	var source_path := reference_root.path_join("DEFAULT.SC2")
	var template := _load_fixture(source_path)
	var original_name := template.city_name()
	var original_misc := template.find_chunk("MISC").decoded_payload.duplicate()
	var newspaper_session := _filled_bytes(NewsQueue.MISC_SIZE, 0)
	var newspaper_random := Random.new(1)
	_check(
		NewsQueue.initialize_session(newspaper_session, newspaper_random).ok,
		"New city fixture prepares the recovered newspaper session",
	)
	var easy_random := Random.new(1)
	var easy := NewCity.create(
		template,
		"  Test City  ",
		"  Test Mayor  ",
		1,
		1900,
		easy_random,
		null,
		null,
		newspaper_session,
	)
	_check(easy.ok, "Easy new city initializes: %s" % easy.error)

	if easy.ok:
		var document: Sc2File = easy.document
		var city := CityModel.from_document(document)
		_check(
			document.source_path.is_empty()
			and city.city_name() == "Test City"
			and city.mayor_name() == "Test Mayor",
			"New city trims and stores its names without a source path",
		)
		_check(
			city.city_mode() == 1
			and city.difficulty() == 1
			and city.founding_year() == 1900
			and city.funds() == 20000,
			"Easy new city stores its mode, difficulty, year, and funds",
		)
		_check(
			document.misc_u32(NewCity.MISC_BONDS) == 0
			and document.misc_u32(NewCity.MISC_NATIONAL_POPULATION) == 10000
			and document.misc_u32(NewCity.MISC_NATIONAL_FEDERAL_RATE) == 3
			and document.misc_u32(NewCity.MISC_NATIONAL_ECONOMY_TREND) == 0,
			"Easy new city stores its national settings without a bond",
		)
		_check(
			city.graph_series(NewCity.GRAPH_GNP).year[0] == 3
			and city.graph_series(NewCity.GRAPH_NATIONAL_POPULATION).year[0] == 10000,
			"New city seeds GNP and national-population history",
		)
		_check(
			easy.invention_years
			== PackedInt32Array([
				1941, 1957, 1994, 1970, 2029, 2054, 1938, 1938, 1912,
				1904, 1930, 1985, 1991, 2047, 2091, 2151, 2205,
			]),
			"New city uses the confirmed invention table and Microsoft random values",
		)
		var founding_story := NewsQueue.story_record(
			document.find_chunk("MISC").decoded_payload, 0
		)
		_check(
			founding_story.type == NewCity.FOUNDING_STORY_TYPE
			and founding_story.priority == 1000,
			"New city inserts the founding newspaper story",
		)
		var new_city_paper_state_valid := true

		for paper_index in NewsQueue.PAPER_COUNT:
			var actual_paper := NewsQueue.paper_record(document.find_chunk("MISC").decoded_payload, paper_index)
			var expected_paper := NewsQueue.paper_record(newspaper_session, paper_index)
			new_city_paper_state_valid = new_city_paper_state_valid and (
				actual_paper.name == expected_paper.name
				and actual_paper.layout == expected_paper.layout
				and actual_paper.price == expected_paper.price
				and actual_paper.opinion == expected_paper.opinion
				and actual_paper.weather == expected_paper.weather
			)

		var expected_story_types := PackedInt32Array([2, 11, 12, 13, 14, 15, 16, 18, 19])

		for slot in NewsQueue.STORY_RECORD_COUNT:
			new_city_paper_state_valid = new_city_paper_state_valid and (
				NewsQueue.story_record(
					document.find_chunk("MISC").decoded_payload, slot
				).type == expected_story_types[slot]
			)

		_check(
			new_city_paper_state_valid,
			"New city copies the session papers before it inserts the founding story",
		)
		var serialized := document.serialize()
		var reparsed := Sc2Document.new()
		_check(
			serialized.ok and reparsed.parse(serialized.data),
			"New city serializes and reparses: %s" % reparsed.parse_error,
		)

		if reparsed.is_valid():
			_check(
				reparsed.city_name() == "Test City"
				and reparsed.misc_u32(NewCity.MISC_START_YEAR) == 1900,
				"Reparsed new city preserves its identity and starting year",
			)

	var medium := NewCity.create(
		template, "123456789012345678901234567890EXTRA",
		"12345678901234567890123EXTRA", 2, 2000, Random.new(1)
	)
	_check(medium.ok, "Medium new city initializes: %s" % medium.error)

	if medium.ok:
		var medium_city := CityModel.from_document(medium.document)
		_check(
			medium_city.city_name() == "123456789012345678901234567890"
			and medium_city.mayor_name() == "12345678901234567890123",
			"New city applies the safe CNAM and XLAB limits",
		)
		_check(
			medium_city.difficulty() == 2
			and medium_city.funds() == 10000
			and medium.document.misc_u32(NewCity.MISC_NATIONAL_POPULATION) == 60000
			and medium.document.misc_u32(NewCity.MISC_NATIONAL_ECONOMY_TREND) == 1,
			"Medium year 2000 uses the recovered economy settings",
		)
		_check(
			medium.invention_years
			== PackedInt32Array([
				0, 0, 0, 0, 2029, 2054, 0, 0, 0, 0, 0, 0, 0,
				2047, 2091, 2151, 2205,
			]),
			"Year 2000 clears inventions that were already available",
		)

	var hard := NewCity.create(
		template, "", "", 3, 2050, Random.new(1)
	)
	_check(hard.ok, "Hard new city initializes: %s" % hard.error)

	if hard.ok:
		var hard_city := CityModel.from_document(hard.document)
		var bond_budget := (
			NewCity.MISC_BUDGETS + NewCity.BUDGET_BONDS * NewCity.BUDGET_RECORD_SIZE
		)
		_check(
			hard_city.city_name() == "New City"
			and hard_city.mayor_name() == "Mayor",
			"Blank new-city names use safe defaults",
		)
		_check(
			hard_city.difficulty() == 3
			and hard_city.funds() == 10000
			and hard.document.misc_u32(NewCity.MISC_BONDS) == 1
			and hard.document.misc_u32(NewCity.MISC_BOND_RATES) == 3,
			"Hard new city stores its 3 percent starting bond",
		)
		_check(
			hard.document.misc_i32(bond_budget + NewCity.BUDGET_CURRENT) == 1
			and hard.document.misc_i32(bond_budget + NewCity.BUDGET_FUNDING) == 30000
			and hard.document.misc_i32(bond_budget + NewCity.BUDGET_YEAR_TO_DATE) == 30000
			and hard.document.misc_i32(bond_budget + NewCity.BUDGET_COUNT_MONTH_0) == 1
			and hard.document.misc_i32(bond_budget + NewCity.BUDGET_FUND_MONTH_0) == 30000,
			"Hard new city initializes the saved Bonds budget record",
		)
		_check(
			hard.document.misc_u32(NewCity.MISC_NATIONAL_POPULATION) == 150000
			and hard.document.misc_u32(NewCity.MISC_NATIONAL_ECONOMY_TREND) == 2,
			"Hard year 2050 uses the recovered national settings",
		)

	var rejected_random := Random.new(123)
	_check(
		not NewCity.create(template, "X", "Y", 0, 1900, rejected_random).ok
		and rejected_random.state == 123,
		"New city rejects an invalid difficulty without consuming random state",
	)
	_check(
		not NewCity.create(template, "X", "Y", 1, 1975, Random.new(1)).ok,
		"New city rejects an unsupported starting year",
	)
	_check(
		template.city_name() == original_name
		and template.find_chunk("MISC").decoded_payload == original_misc,
		"New city setup never changes the supplied template",
	)


func _test_map_edits(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)
	_check(city.set_terrain_id(4, 5, 0x2a), "Terrain tile can change")
	_check(city.set_building_id(4, 5, Tiles.ABANDONED_1X1_1), "Building tile can change")
	_check(city.set_zone_id(4, 5, 0x05), "Zone can change")
	_check(city.set_building_corners(4, 5, 0xa0), "Building corners can change")
	_check(city.set_underground_id(4, 5, UnderTiles.MISSILE_SILO), "Underground tile can change")
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
	_check(Tools.all_tools().size() == 76, "Tool catalog retains original entries, Cancel Dispatch, five editor tools, and Trip Query")
	var coal := Tools.tool(3, 2)
	_check(coal.cost == 4000 and coal.area == 4, "Coal plant uses the executable cost and area")
	var coal_details := Tools.power_plant_details(2)
	_check(
		coal_details.output_mw == 200
		and coal_details.grid_capacity.contains("44")
		and coal_details.pollution == 50
		and coal_details.service_life.contains("50"),
		"Coal plant details expose output, grid capacity, pollution, and service life",
	)
	var hydro_details := Tools.power_plant_details(3)
	_check(
		hydro_details.output_mw == 20
		and hydro_details.grid_capacity.contains("40"),
		"Hydroelectric details expose its output and grid capacity",
	)
	var wind_details := Tools.power_plant_details(7)
	_check(
		wind_details.output_mw == 4,
		"Wind details expose its rated power output",
	)
	_check(
		Tools.power_plant_details(1) == null,
		"Power-plant details reject the retired chooser entry",
	)
	var road := Tools.tool(6, 0)
	_check(road.cost == 10 and road.area == 1, "Road uses the executable cost and area")
	var college := Tools.tool(12, 1)
	_check(college.cost == 1000 and college.area == 4, "College uses the executable cost and area")
	var prison := Tools.tool(13, 3)
	_check(prison.cost == 3000 and prison.area == 4, "Prison uses the executable cost and area")
	var marina := Tools.tool(14, 4)
	_check(marina.cost == 1000 and marina.area == 3, "Marina uses the executable cost and area")
	_check(Tools.tool(-1, 0) == null, "Tool catalog rejects an invalid group")
	_check(Tools.tool(0, 12) == null, "Tool catalog rejects an invalid subtool")


func _test_tool_availability(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(document.set_misc_u32(ToolAvailability.MISC_PROGRESSION, 0), "Tool availability fixture clears progression")
	_check(document.set_misc_u32(ToolAvailability.MISC_GRANTED_REWARDS, 0), "Tool availability fixture clears rewards")
	_check(document.set_misc_u32(ToolAvailability.MISC_ORDINANCES, 0), "Tool availability fixture clears ordinances")

	for invention_index in ToolAvailability.INVENTION_COUNT:
		_check(
			document.set_misc_u32(
				ToolAvailability.MISC_INVENTION_YEARS + invention_index * 4,
				2100,
			),
			"Tool availability fixture schedules invention %d" % invention_index,
		)

	var city := CityModel.from_document(document)
	var base := ToolAvailability.inspect(city)
	_check(base.ok, "Tool availability reads the saved MISC state: %s" % base.error)

	if not base.ok:
		return

	_check(
		base.group_masks == PackedInt32Array([
			0x1f, 0x03, 0x03, 0x03, 0x07, 0x00,
			0x05, 0x05, 0x01, 0x03, 0x03, 0x03,
			0x0f, 0x0f, 0x1f, 0x00, 0x00, 0x00,
		]),
		"Tool availability starts from the executable group-mask table",
	)
	_check(base.power_plant_mask == 0x07, "Coal, hydro, and oil are the initial power choices")
	_check(
		ToolAvailability.is_available(city, 3, 2)
		and ToolAvailability.is_available(city, 3, 3)
		and ToolAvailability.is_available(city, 3, 4)
		and not ToolAvailability.is_available(city, 3, 5),
		"Initial power availability includes only the first three plants",
	)
	_check(
		ToolAvailability.is_available(city, 6, 0)
		and ToolAvailability.is_available(city, 6, 2)
		and not ToolAvailability.is_available(city, 6, 1)
		and not ToolAvailability.is_available(city, 6, 4),
		"Initial road availability includes road and tunnel only",
	)
	_check(
		ToolAvailability.is_available(city, 2, 2),
		"Dispatch selection stays available because live capacity controls dispatch",
	)
	var zone_edit_state := ToolEditState.normal(city, CityViewMode.Mode.CITY, 9, 0)
	var road_edit_state := ToolEditState.normal(city, CityViewMode.Mode.CITY, 6, 0)
	var building_edit_state := ToolEditState.normal(city, CityViewMode.Mode.CITY, 13, 3)
	_check(
		zone_edit_state.enabled
		and zone_edit_state.selection == "rectangle"
		and road_edit_state.enabled
		and road_edit_state.selection == "path"
		and building_edit_state.enabled
		and building_edit_state.selection == "point"
		and building_edit_state.area == 4,
		"Tool edit state classifies zone, route, and building input",
	)
	var underground_pipe_state := ToolEditState.normal(city, CityViewMode.Mode.UNDERGROUND, 4, 0)
	var underground_zone_state := ToolEditState.normal(city, CityViewMode.Mode.UNDERGROUND, 9, 0)
	_check(
		underground_pipe_state.enabled
		and underground_pipe_state.selection == "path"
		and not underground_zone_state.enabled,
		"Tool edit state limits underground input to supported tools",
	)
	var scurk_object_state := ToolEditState.scurk_object(city, CityViewMode.Mode.CITY, 0xcf)
	var scurk_zone_state := ToolEditState.scurk_tool(
		city, ScurkEditTool.new("Light Residential", 9, 0, 1, "city")
	)
	_check(
		scurk_object_state.enabled
		and scurk_object_state.area == 4
		and scurk_zone_state.enabled
		and scurk_zone_state.selection == "rectangle",
		"Tool edit state classifies SCURK object and edit modes",
	)
	_check(
		not ToolEditState.is_tool_chooser(5, 4)
		and not ToolEditState.is_tool_variant(5, 5)
		and not ToolEditState.is_tool_variant(5, 4),
		"Tool edit state owns reward chooser and variant rules",
	)

	for invention_index in range(12):
		_check(
			document.set_misc_u32(
				ToolAvailability.MISC_INVENTION_YEARS + invention_index * 4,
				0,
			),
			"Tool availability fixture releases invention %d" % invention_index,
		)

	var released := ToolAvailability.inspect(city)
	_check(released.power_plant_mask == 0x1ff, "The first six inventions unlock all later power plants")
	_check(
		released.group_masks[8] == 0x03
		and released.group_masks[6] == 0x1f
		and released.group_masks[7] == 0x1f
		and released.group_masks[4] == 0x1f,
		"Transport and water inventions extend their exact executable masks",
	)
	_check(document.set_misc_u32(ToolAvailability.MISC_ORDINANCES, ToolAvailability.ORDINANCE_NUCLEAR_FREE), "Tool availability fixture enacts Nuclear-Free Zone")
	_check(
		not ToolAvailability.is_available(city, 3, 6),
		"Nuclear-Free Zone hides an invented nuclear power plant",
	)

	_check(document.set_misc_u32(ToolAvailability.MISC_GRANTED_REWARDS, 0x05), "Tool availability fixture grants mayor house and statue")
	_check(document.set_misc_u32(ToolAvailability.MISC_PROGRESSION, 5), "Tool availability fixture stays below arcology progression")
	_check(document.set_misc_u32(ToolAvailability.MISC_INVENTION_YEARS + 12 * 4, 0), "Tool availability fixture releases one arcology")
	_check(
		ToolAvailability.is_available(city, 5, 0)
		and not ToolAvailability.is_available(city, 5, 1)
		and ToolAvailability.is_available(city, 5, 2)
		and not ToolAvailability.is_available(city, 5, 4),
		"Saved reward bits control the four one-use rewards",
	)
	_check(document.set_misc_u32(ToolAvailability.MISC_PROGRESSION, 6), "Tool availability fixture reaches arcology progression")
	_check(
		ToolAvailability.is_available(city, 5, 4)
		and ToolAvailability.is_available(city, 5, 5)
		and not ToolAvailability.is_available(city, 5, 6),
		"One released arcology enables the chooser and its first entry",
	)
	_check(document.set_misc_u32(ToolAvailability.MISC_INVENTION_YEARS + 15 * 4, 0), "Tool availability fixture releases a second arcology slot")
	_check(
		ToolAvailability.is_available(city, 5, 5)
		and ToolAvailability.is_available(city, 5, 6)
		and not ToolAvailability.is_available(city, 5, 7),
		"Arcology availability uses the original released-count behavior",
	)
	var misc: PackedByteArray = document.find_chunk("MISC").decoded_payload.duplicate()
	_check(ToolAvailability.rebuild_reward_mask(misc) == 0x15, "Availability rebuild preserves rewards and enables arcologies")


func _test_zone_command(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Zone command test clears %s" % chunk_id
		)

	var buildings := document.find_chunk("XBLD").decoded_payload.duplicate()
	buildings[11 * 128 + 11] = Tiles.ROAD_STRAIGHT_1
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
	_check(
		city.set_terrain_id(12, 12, 0x10),
		"Zone test gives its water tile a saved water terrain shape",
	)
	var rectangle_preview := Zones.preview_rectangle(
		city, 9, 0, Vector2i(10, 10), Vector2i(12, 12), true
	)
	_check(
		rectangle_preview.ok
		and rectangle_preview.charged_tiles == 6
		and rectangle_preview.changed_tiles == 6
		and rectangle_preview.cost == 30,
		"Zone drag preview counts only eligible changed tiles",
	)
	_check(city.set_terrain_id(10, 10, 9), "Zone click preview installs a terrain slope")
	var slope_click_preview := Zones.preview_rectangle(
		city, 9, 0, Vector2i(10, 10), Vector2i(10, 10), false
	)
	_check(
		slope_click_preview.ok
		and slope_click_preview.charged_tiles == 1
		and slope_click_preview.changed_tiles == 0
		and slope_click_preview.terrain_surcharges == 1
		and slope_click_preview.cost == 30,
		"Zone click preview includes the recovered slope surcharge",
	)
	_check(city.set_terrain_id(10, 10, 0), "Zone click preview restores flat terrain")
	_check(
		not Zones.preview_rectangle(
			city, 9, 0, Vector2i(12, 12), Vector2i(10, 10), true
		).ok,
		"Zone selection cannot start on water",
	)
	_check(
		not Zones.preview_rectangle(
			city, 9, 0, Vector2i(12, 11), Vector2i(10, 10), true
		).ok,
		"Zone selection cannot start in a military zone",
	)
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
	var same_zone_preview := Zones.preview_rectangle(
		city, 9, 0, Vector2i(10, 10), Vector2i(10, 10), true
	)
	_check(
		same_zone_preview.ok and same_zone_preview.cost == 0,
		"Zone drag preview omits a tile that already has the selected zone",
	)
	var charged_click := Zones.apply_rectangle(
		city, 9, 0, Vector2i(10, 10), Vector2i(10, 10), false
	)
	_check(
		charged_click.ok
		and charged_click.cost == 5
		and charged_click.tile_indices.is_empty()
		and city.funds() == 65,
		"A true click keeps the executable's charge when the zone does not change",
	)
	_check(
		Zones.undo(city, charged_click).ok and city.funds() == 70,
		"Charge-only zone click can be undone",
	)
	var undo := Zones.undo(city, command)
	_check(undo.ok and undo.restored_tiles == 6, "Zone command undo restores all changed tiles")
	_check(city.funds() == 100, "Zone command undo restores funds")
	_check(city.zones[10 * 128 + 10] == 0xa0, "Zone command undo restores original XZON bytes")
	var later := Zones.apply_rectangle(city, 11, 1, Vector2i(10, 10), Vector2i(12, 12))
	_check(later.ok, "Later zoning command succeeds")
	_check(later.cost == 60, "Later zoning command uses changed-tile cost")
	var stale := Zones.undo(city, command)
	_check(not stale.ok, "Undo rejects a command after later zone changes")
	_check(city.set_building_id(10, 10, Tiles.RUBBLE_3), "De-zone test places rubble")
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
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
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
	var original_strings_result := PeString.load_ids(
		reference_root.path_join("SIMCITY.EXE"), QueryText.resource_string_ids()
	)
	_check(
		original_strings_result.ok,
		"Query source strings load: %s" % original_strings_result.error,
	)
	var original_strings: Dictionary = original_strings_result.strings
	_check(
		original_strings.size() == 259,
		"Query requests each reachable tile name, facility, action, and analysis string",
	)
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XTXT", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Query fixture clears %s" % chunk_id,
		)

	_check(
		document.find_chunk("XTHG").set_decoded_payload(
			_filled_bytes(CityState.THING_COUNT * CityState.THING_RECORD_SIZE, 0)
		),
		"Query fixture clears XTHG",
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
	_check(city.set_building_id(10, 10, Tiles.ROAD_STRAIGHT_1), "Query fixture places a road")
	_check(city.set_zone_id(10, 10, 1), "Query fixture zones the road")
	_check(city.set_land_altitude(10, 10, 6), "Query fixture sets altitude")
	_check(city.set_tile_flag(10, 10, 0x40, true), "Query fixture powers the road")
	_check(city.set_underground_id(10, 10, UnderTiles.PIPE_TB_SUBWAY_LR), "Query fixture adds a pipe and subway crossover")
	var info := Queries.inspect(city, Vector2i(10, 10))
	_check(info.ok and info.kind == "general", "General query succeeds: %s" % info.error)
	_check(info.sound_events.is_empty(), "General query does not request a sound")
	_check(
		info.things.is_empty(),
		"Query hides XTHG fields when no moving object occupies the tile",
	)
	var things_data := document.find_chunk("XTHG").decoded_payload.duplicate()
	var thing_offset := CityState.THING_RECORD_SIZE
	var thing_values := [2, 5, 3, 42, 42, 6, 7, 8, 50, 51, 12, 13]

	for field in CityState.THING_RECORD_SIZE:
		things_data[thing_offset + field] = thing_values[field]

	_check(
		document.find_chunk("XTHG").set_decoded_payload(things_data),
		"Query fixture stores an XTHG helicopter",
	)
	var thing_info := Queries.inspect(city, Vector2i(42, 42))
	_check(
		thing_info.things.size() == 1
		and thing_info.things[0].record == 1
		and thing_info.things[0].type_name == Queries.THING_NAMES[2]
		and thing_info.things[0].sprite_id == 1366
		and thing_info.things[0].sprite_flip,
		"Query exposes the matching XTHG record and its native sprite",
	)
	var queried_values := PackedInt32Array()
	for field in ["type", "direction", "state", "x", "y", "z", "px", "py", "dx", "dy", "label", "goal"]:
		queried_values.append(int(thing_info.things[0][field]))
	_check(
		queried_values == PackedInt32Array(thing_values),
		"Query exposes all saved XTHG fields without changing their values",
	)
	var named_info := Queries.inspect(city, Vector2i(10, 10), original_strings)
	_check(
		named_info.title
		== str(original_strings[Queries.GENERAL_NAME_RESOURCE_BASE + 6]),
		"General query loads the original road-range name",
	)
	_check(
		QueryText.general_name_resource_id(city, Vector2i(10, 10))
		== Queries.GENERAL_NAME_RESOURCE_BASE + 6,
		"General query applies the recovered road name indirection",
	)
	_check(info.zone_name == "Residential" and info.zone_density == "low-density", "Query reports zone type and density")
	_check(info.traffic == 4, "Query reproduces adjacent road traffic calculation")
	_check(info.altitude_feet == 250 and not info.altitude_is_depth, "Query reproduces clear-terrain altitude")
	_check(info.land_value == 10, "Query reports land value in thousands per acre")
	_check(info.crime_level == QueryDetails.level_name(61), "Query uses the recovered crime thresholds")
	_check(info.pollution_level == QueryDetails.level_name(181), "Query uses the recovered pollution thresholds")
	_check(info.shows_utilities and info.powered, "Query reports utility state")
	_check(
		info.tile_id == 0x1d
		and info.sprite_id == 1029
		and info.altitude_raw == 6
		and info.zone_raw == 1,
		"Advanced query reports raw tile, sprite, altitude, and zone values",
	)
	_check(
		info.flags_raw == 0x40
		and info.flag_names == PackedStringArray(["powered"])
		and info.underground_name == "Crossover (PIPESTB_SUBWAYLR)",
		"Advanced query decodes XBIT and XUND values",
	)
	_check(city.set_tile_flag(40, 41, 0x08, true), "Advanced Query fixture sets XBIT xvalmask")
	_check(city.set_tile_flag(40, 41, 0x02, true), "Advanced Query fixture sets XBIT rotated")
	var flag_info := Queries.inspect(city, Vector2i(40, 41))
	_check(
		flag_info.flag_names == PackedStringArray(["xvalmask", "rotated"])
		and flag_info.underground_name == "None",
		"Advanced Query uses the SC2KFix XBIT and empty-XUND names",
	)
	var advanced_general_text := QueryText.format_text(info)
	_check(
		advanced_general_text.contains("29 / 0x1D")
		and advanced_general_text.contains("61 / 0x3D"),
		"General query formats the SC2KFix advanced data section",
	)
	var bounds := [1, 60, 120, 180]
	for boundary in bounds:
		_check(
			QueryDetails.level_name(boundary) != QueryDetails.level_name(boundary + 1),
			"Query level changes at its recovered threshold",
		)
	for band in [[2, 60], [61, 120], [121, 180]]:
		_check(
			QueryDetails.level_name(band[0]) == QueryDetails.level_name(band[1]),
			"Query level stays constant within a threshold band",
		)
	_check(city.set_building_id(40, 40, Tiles.EMPTY), "Query name fixture clears a terrain tile")
	_check(city.set_tile_flag(40, 40, 0x04, false), "Query name fixture clears its water flag")
	_check(
		QueryText.general_name_resource_id(city, Vector2i(40, 40))
		== Queries.GENERAL_NAME_RESOURCE_BASE + Queries.GENERAL_CLEAR_NAME_INDEX,
		"General query selects the original clear-terrain name",
	)
	_check(city.set_tile_flag(40, 40, 0x04, true), "Query name fixture sets its water flag")
	_check(city.set_tile_flag(40, 40, 0x01, true), "Query name fixture sets its salt-water flag")
	_check(
		QueryText.general_name_resource_id(city, Vector2i(40, 40))
		== Queries.GENERAL_NAME_RESOURCE_BASE + Queries.GENERAL_SALT_WATER_NAME_INDEX,
		"General query selects the original salt-water name",
	)
	_check(city.set_tile_flag(40, 40, 0x01, false), "Query name fixture clears its salt-water flag")
	_check(
		QueryText.general_name_resource_id(city, Vector2i(40, 40))
		== Queries.GENERAL_NAME_RESOURCE_BASE + Queries.GENERAL_FRESH_WATER_NAME_INDEX,
		"General query selects the original fresh-water name",
	)
	_check(city.set_building_id(41, 40, Tiles.LLAMA_DOME), "Query name fixture places an exact-name tile")
	_check(
		QueryText.general_name_resource_id(city, Vector2i(41, 40))
		== Queries.GENERAL_NAME_RESOURCE_BASE + 153,
		"General query gives tile FF its individual original name",
	)
	_check(document.set_misc_u32(0x68, 8), "Query pump fixture sets rain")
	_check(city.set_building_id(20, 20, Tiles.WATER_PUMP), "Query pump fixture places a pump")
	_check(city.set_tile_flag(20, 20, 0x40, true), "Query pump fixture powers the pump")
	_check(city.set_tile_flag(19, 20, 0x04, true), "Query pump fixture places fresh water")
	var pump := Queries.inspect(city, Vector2i(20, 20))
	_check(pump.water_detail.contains("24480"), "Query reports recovered pump output")

	for tower_tile in [Vector2i(30, 30), Vector2i(31, 30), Vector2i(30, 29), Vector2i(31, 29)]:
		_check(city.set_building_id(tower_tile.x, tower_tile.y, Tiles.WATER_TOWER), "Query tower fixture places a tower tile")

	for watered_tile in [Vector2i(30, 30), Vector2i(31, 30), Vector2i(30, 29)]:
		_check(city.set_tile_flag(watered_tile.x, watered_tile.y, 0x10, true), "Query tower fixture stores water")

	var tower := Queries.inspect(city, Vector2i(31, 29))
	_check(tower.water_detail.contains("30000"), "Query counts stored tower water")

	var microsim_data := document.find_chunk("XMIC").decoded_payload.duplicate()
	microsim_data[0] = 0xd0
	microsim_data[1] = 7
	microsim_data[2] = 0x01
	microsim_data[3] = 0x02
	microsim_data[4] = 0x03
	microsim_data[5] = 0x04
	microsim_data[6] = 0x05
	microsim_data[7] = 0x06
	microsim_data[8] = 0
	microsim_data[9] = 9
	microsim_data[10] = 0x12
	microsim_data[11] = 0x34
	microsim_data[12] = 0x56
	microsim_data[13] = 0x78
	microsim_data[14] = 0x9a
	microsim_data[15] = 0xbc
	_check(document.find_chunk("XMIC").set_decoded_payload(microsim_data), "Query fixture sets microsim data")
	_check(city.set_label(52, "Dormant Link"), "Query fixture names a dormant microsim")
	_check(city.set_text_overlay_id(11, 10, 52), "Query fixture attaches a dormant microsim")
	var dormant := Queries.inspect(city, Vector2i(11, 10))
	var dormant_text := QueryText.format_text(dormant)
	_check(
		dormant.kind == "general"
		and dormant.microsim_id == 1
		and dormant.microsim.stat_3 == 0x9abc
		and dormant_text.contains(city.label(52))
		and dormant_text.contains("39612 / 0x9ABC"),
		"Advanced Query keeps XMIC details after the normal dialog falls back",
	)
	_check(city.set_label(51, "Civic Center"), "Query fixture names a microsim")
	_check(city.set_text_overlay_id(10, 10, 51), "Query fixture attaches a microsim")
	var specific := Queries.inspect(city, Vector2i(10, 10), original_strings)
	_check(specific.ok and specific.kind == "specific", "Specific query follows XTXT to XMIC")
	_check(specific.title == "Civic Center" and specific.microsim.stat_0 == 7, "Specific query reports its label and rating")
	_check(specific.microsim.stat_1 == 0x0102, "Specific query reads big-endian statistic one")
	_check(specific.microsim.stat_2 == 0x0304, "Specific query reads big-endian statistic two")
	_check(specific.microsim.stat_3 == 0x0506, "Specific query reads big-endian statistic three")
	_check(specific.microsim_type == 2, "Specific query maps City Hall to facility type two")
	_check(specific.sound_events == [513], "City Hall query requests original sound 513")
	_check(
		specific.sprite_id == 1208
		and QueryText.format_text(specific).contains("1286 / 0x0506"),
		"Specific query shows its full-size sprite and raw XMIC data",
	)
	var renamed := QueryFacilityActions.rename_facility(city, specific, "New Civic Center")
	_check(
		renamed.ok and city.label(51) == "New Civic Center",
		"Specific query can rename its linked facility",
	)
	_check(
		QueryFacilityActions.rename_facility(city, specific, "12345678901234567890123456789").new_value.length() == 23,
		"Query rename uses the saved XLAB length limit",
	)
	_check(city.set_label(51, "Civic Center"), "Query fixture restores the facility name")
	_check(
		specific.action == "city_analysis"
		and specific.action_resource_id == Queries.CITY_HALL_ACTION_RESOURCE,
		"City Hall query exposes its Analyze action",
	)

	if original_strings_result.ok:
		_check(
			specific.lines
			== PackedStringArray([
				str(original_strings[945]).replace("#1", "258"),
				str(original_strings[929]).replace("#2", "772"),
			]),
			"City Hall query expands its original resource rows",
		)

	var fallback := Queries.inspect(city, Vector2i(10, 10))
	_check(
		fallback.lines.size() == 4
		and fallback.lines[0].contains("7")
		and fallback.lines[3].contains("1286"),
		"Specific query keeps raw values when original text is unavailable",
	)

	microsim_data = document.find_chunk("XMIC").decoded_payload.duplicate()
	microsim_data[0] = 0xd7
	microsim_data[1] = 23
	microsim_data[2] = 0x46
	microsim_data[3] = 0x50
	microsim_data[4] = 0
	microsim_data[5] = 2
	microsim_data[6] = 0
	microsim_data[7] = 0xfd
	_check(document.find_chunk("XMIC").set_decoded_payload(microsim_data), "Query fixture sets Stadium data")
	_check(city.set_label(0xfd, "Camel City Flyers"), "Query fixture names a Stadium team")
	var stadium := Queries.inspect(city, Vector2i(10, 10), original_strings)
	_check(stadium.microsim_type == 7 and stadium.lines.size() == 5, "Stadium query uses all five original rows")

	if original_strings_result.ok:
		_check(
			stadium.lines
			== PackedStringArray([
				str(original_strings[936]),
				str(original_strings[924]).replace("#1", "18000"),
				str(original_strings[958]).replace("#S", str(original_strings[788])),
				"Camel City Flyers",
				str(original_strings[982]).replace("#W", "23-17"),
			]),
			"Stadium query separates its sport, editable name, and record",
		)

	microsim_data[0] = 0xd1
	microsim_data[1] = 12
	microsim_data[2] = 0x01
	microsim_data[3] = 0xf4
	microsim_data[4] = 0
	microsim_data[5] = 40
	microsim_data[6] = 0x07
	microsim_data[7] = 0xd0
	_check(document.find_chunk("XMIC").set_decoded_payload(microsim_data), "Query fixture sets Hospital data")
	var hospital := Queries.inspect(city, Vector2i(10, 10), original_strings)

	if original_strings_result.ok:
		_check(
			hospital.lines[3] == str(original_strings[952]).replace("#G", "A+"),
			"Specific query maps its rating byte to the original grade scale",
		)
		_check(
			hospital.lines[4] == str(original_strings[920]).replace("#3", "2000"),
			"Specific query expands statistic three",
		)
		var arcology := CityRecords.Microsim.new()
		arcology.tile_id = Tiles.PLYMOUTH_ARCOLOGY
		arcology.stat_1 = 7
		_check(
			QueryText.expand_specific_template(
				city, arcology, str(original_strings[942]), original_strings
			)
			== str(original_strings[942]).replace("#1", "7"),
			"Specific query preserves suffix digits after a numeric placeholder",
		)

	microsim_data[0] = 0xf5
	_check(document.find_chunk("XMIC").set_decoded_payload(microsim_data), "Query fixture sets Library data")
	var library := Queries.inspect(city, Vector2i(10, 10), original_strings)
	_check(
		library.action == "library_ruminate"
		and library.action_resource_id == Queries.LIBRARY_ACTION_RESOURCE,
		"Library query exposes its Ruminate action",
	)
	var arcology_info := Queries.inspect(city, Vector2i(10, 10), original_strings)
	arcology_info.microsim = city.microsim(library.microsim_id)
	arcology_info.microsim.tile_id = Tiles.PLYMOUTH_ARCOLOGY
	_check(
		QueryPresentation.sprite_id(city, arcology_info) == 1251,
		"Query uses a full-size arcology sprite as corrected by SC2KFix",
	)
	_check(
		QueryText.specific_sound_events(0xfb, 3) == [526, 512]
		and QueryText.specific_sound_events(0xfb, 4) == [526]
		and QueryText.specific_sound_events(0xfb, 10) == [526, 513],
		"Arcology query keeps all three original age-dependent sound branches",
	)
	_check(
		QueryText.specific_sound_events(0xc8, 0) == [514]
		and QueryText.specific_sound_events(0xd1, 0) == [506]
		and QueryText.specific_sound_events(0xd3, 0) == [509]
		and QueryText.specific_sound_events(0xd6, 0) == [523]
		and QueryText.specific_sound_events(0xd8, 0) == [522]
		and QueryText.specific_sound_events(0xda, 0) == [527]
		and QueryText.specific_sound_events(0xec, 0) == [521]
		and QueryText.specific_sound_events(0xed, 0) == [524]
		and QueryText.specific_sound_events(0xf8, 0) == [511]
		and QueryText.specific_sound_events(0xf5, 0).is_empty(),
		"Specific query maps each recovered facility sound class",
	)

	var analysis_misc := document.find_chunk("MISC").decoded_payload.duplicate()

	for tile_id in range(QueryFacilityActions.FIRST_BUILDING, 0x100):
		_write_u32_be(
			analysis_misc,
			QueryFacilityActions.MISC_TILE_COUNTS + tile_id * 4,
			0,
		)

	var category_examples := [
		0x1d,
		0x0e,
		0xdc,
		0x70,
		0x7c,
		0x84,
		0xdd,
		0xd4,
		0xd0,
		0x0d,
		0xfb,
	]

	for tile_id in category_examples:
		_write_u32_be(
			analysis_misc,
			QueryFacilityActions.MISC_TILE_COUNTS + tile_id * 4,
			1,
		)

	_write_u32_be(
		analysis_misc,
		QueryFacilityActions.MISC_TILE_COUNTS + 0x88 * 4,
		1,
	)
	_write_u32_be(
		analysis_misc,
		QueryFacilityActions.MISC_TILE_COUNTS + 0xff * 4,
		1,
	)
	_check(
		document.find_chunk("MISC").set_decoded_payload(analysis_misc),
		"City analysis fixture sets saved tile counts",
	)
	var analysis := QueryFacilityActions.city_analysis(city, original_strings)
	_check(analysis.ok, "City Hall analysis succeeds: %s" % analysis.error)
	_check(analysis.total == 11 and analysis.counts[0] == 1, "City Hall analysis excludes hidden and unmatched tiles from its total")

	for category_id in range(1, QueryFacilityActions.CATEGORY_COUNT):
		_check(
			analysis.counts[category_id] == 1
			and analysis.categories[category_id - 1].percent == 9,
			"City Hall analysis classifies category %d" % category_id,
		)

	if original_strings_result.ok:
		_check(
			analysis.header == str(original_strings[988])
			and analysis.categories[0].name == str(original_strings[989]).strip_edges(),
			"City Hall analysis uses the original table labels",
		)

	_check(
		QueryFacilityActions.format_city_analysis(analysis).contains("9%"),
		"City Hall analysis formats category percentages",
	)


func _test_landscape_command(reference_root: String) -> void:
	var tree_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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

	var water_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XTXT", "XBIT"]:
		_check(
			water_document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Water fixture clears %s" % chunk_id,
		)

	_check(water_document.set_misc_i32(0x14, 500), "Water fixture sets funds")
	_check(water_document.set_misc_u32(0x01f0, 16383), "Water fixture counts clear tiles")
	_check(water_document.set_misc_u32(0x01f0 + 6 * 4, 1), "Water fixture counts one tree")
	var water_city := CityModel.from_document(water_document)
	_check(water_city.set_building_id(10, 10, Tiles.TREES_1), "Water fixture places a tree")
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
	_check(not unaffordable_water.ok and not unaffordable_water.error.is_empty(), "Water tool reports insufficient funds")


func _test_building_command(reference_root: String) -> void:
	_check(BuildingSites.tile_for_tool(3, 2) == 0xcf, "Building table maps coal power")
	_check(BuildingSites.tile_for_tool(14, 4) == 0xf8, "Building table maps the marina")
	_check(Buildings.supports_tool(13, 0), "Building command supports police stations")
	_check(not Buildings.supports_tool(3, 3), "Hydroelectric power remains a special tool")
	_check(BuildingSites.footprint(Vector2i(20, 20), 1) == Rect2i(20, 20, 1, 1), "One-tile footprint starts at the pointer")
	_check(BuildingSites.footprint(Vector2i(20, 20), 2) == Rect2i(20, 20, 2, 2), "Two-tile footprint starts at the pointer")
	_check(BuildingSites.footprint(Vector2i(20, 20), 4) == Rect2i(19, 19, 4, 4), "Four-tile footprint starts one tile before the pointer")

	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Building fixture clears %s" % chunk_id,
		)

	_check(document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)), "Building fixture clears XLAB")
	_check(document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)), "Building fixture clears XMIC")
	_check(document.set_misc_i32(0x14, 20000), "Building fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Building fixture counts clear tiles")
	_check(document.set_misc_u32(0x0fe8, 0), "Building fixture clears subway count")
	_check(document.set_misc_u32(Buildings.MISC_STADIUM_TEAMS, 0), "Building fixture clears stadium teams")
	_check(document.set_misc_u32(Buildings.MISC_ARCOLOGY_POPULATION, 0), "Building fixture clears arcology population")
	_check(document.set_misc_u32(Buildings.MISC_NORMAL_POPULATION, 180000), "Building fixture sets normal population")
	_check(document.set_misc_u32(0x01f0 + 0xcf * 4, 0), "Building fixture clears coal count")
	_check(document.set_misc_u32(0x077c + 5 * 0x6c, 2), "Building fixture sets police count")
	_check(document.set_misc_u32(0x077c + 5 * 0x6c + 4, 80), "Building fixture funds police")
	_check(document.set_misc_u32(0x077c + 6 * 0x6c + 4, 80), "Building fixture funds fire")
	_check(document.set_misc_u32(ToolAvailability.MISC_PROGRESSION, 0), "Building fixture clears progression")
	_check(document.set_misc_u32(ToolAvailability.MISC_GRANTED_REWARDS, 0x0f), "Building fixture grants one-use rewards")

	for invention_index in ToolAvailability.INVENTION_COUNT:
		_check(
			document.set_misc_u32(
				ToolAvailability.MISC_INVENTION_YEARS + invention_index * 4,
				0,
			),
			"Building fixture unlocks invention %d" % invention_index,
		)

	var city := CityModel.from_document(document)
	var random := LfsrRandom.new(1)
	var process_random := Random.new(1)

	var utility_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			utility_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Immediate utility fixture clears %s" % chunk_id,
		)

	_check(
		utility_document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0)),
		"Immediate utility fixture clears XLAB",
	)
	_check(
		utility_document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)),
		"Immediate utility fixture clears XMIC",
	)
	_check(utility_document.set_misc_i32(0x14, 5000), "Immediate utility fixture sets funds")
	_check(
		utility_document.set_misc_u32(Buildings.MISC_NORMAL_POPULATION, 49999),
		"Immediate utility fixture sets population below the threshold",
	)
	_check(
		utility_document.set_misc_u32(Water.MISC_TREATMENT_SUFFICIENT, 0),
		"Immediate utility fixture clears treatment state",
	)
	var utility_city := CityModel.from_document(utility_document)
	_check(
		utility_city.set_tile_flag(10, 10, 0x40, true)
		and utility_city.set_tile_flag(10, 10, 0x10, true),
		"Immediate utility fixture stores stale utility flags",
	)
	var utility_random := LfsrRandom.new(0x2211)
	var utility_process_random := Random.new(0x3344)
	var low_population_station := Buildings.apply(
		utility_city,
		13,
		0,
		Vector2i(20, 20),
		utility_random,
		utility_process_random,
	)
	_check(
		low_population_station.ok
		and low_population_station.immediate_power_refresh
		and low_population_station.immediate_water_refresh,
		"A low-population building immediately refreshes power and water",
	)
	_check(
		not utility_city.is_powered(20, 20)
		and utility_city.is_powerable(20, 20)
		and utility_city.is_piped(20, 20),
		"Immediate power removes the new isolated building's initial powered flag",
	)
	_check(
		not utility_city.is_powered(10, 10)
		and not utility_city.is_watered(10, 10)
		and utility_document.misc_u32(Water.MISC_TREATMENT_SUFFICIENT) == 1,
		"Immediate utility phases update existing flags and saved treatment state",
	)
	_check(
		Buildings.undo(
			utility_city,
			low_population_station,
			utility_random,
			utility_process_random,
		).ok,
		"Immediate utility changes can be undone with their building",
	)
	_check(
		utility_city.is_powered(10, 10)
		and utility_city.is_watered(10, 10)
		and utility_document.misc_u32(Water.MISC_TREATMENT_SUFFICIENT) == 0,
		"Building undo restores the utility phase changes",
	)
	for population in [49_999, 50_000, 49_999_999, 50_000_000]:
		var expect_refresh: bool = population < 50_000_000

		_check(
			utility_document.set_misc_u32(Buildings.MISC_NORMAL_POPULATION, population),
			"Immediate utility fixture selects the strict threshold",
		)
		var threshold_station := Buildings.apply(
			utility_city,
			13,
			0,
			Vector2i(20, 20),
			utility_random,
			utility_process_random,
		)
		_check(
			threshold_station.ok
			and threshold_station.immediate_power_refresh == expect_refresh
			and threshold_station.immediate_water_refresh == expect_refresh
			and utility_city.is_powered(20, 20) != expect_refresh,
			"Building utility refresh at population %d" % population,
		)
		_check(
			Buildings.undo(
				utility_city,
				threshold_station,
				utility_random,
				utility_process_random,
			).ok,
			"Threshold building placement can be undone",
		)

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
	_check(not city.label(61).is_empty(), "Coal plant gets the original default label")
	_check(city.microsim(10).tile_id == 0xcf and city.microsim(10).stat_1 == 200, "Coal plant initializes its XMIC capacity")
	_check(document.misc_u32(0x01f0) == 16368, "Coal plant decrements clear tile count")
	_check(document.misc_u32(0x01f0 + 0xcf * 4) == 16, "Coal plant increments its tile count")
	_check(Buildings.undo(city, coal, random, process_random).ok, "Coal plant placement can be undone")
	_check(city.funds() == 20000 and city.building_id(19, 19) == 0, "Building undo restores funds and tiles")
	_check(city.text_overlay_id(19, 19) == 0 and city.microsim(10).tile_id == 0, "Building undo restores XTXT and XMIC")

	var police := Buildings.apply(city, 13, 0, Vector2i(30, 30), random, process_random)
	_check(police.ok, "Police station placement succeeds")
	_check(document.misc_u32(0x077c + 5 * 0x6c) == 3, "Police station increments the current budget count")
	_check(city.microsim(10).stat_1 == 160, "Police station starts with the funded population cap")
	_check(Buildings.undo(city, police, random, process_random).ok, "Police station placement can be undone")
	var fire := Buildings.apply(city, 13, 1, Vector2i(34, 30), random, process_random)
	_check(fire.ok, "Fire station placement succeeds")
	_check(
		city.microsim(10).stat_1 == 40 and city.microsim(10).stat_2 == 4,
		"Fire station starts with the funded population cap and four engines",
	)
	_check(Buildings.undo(city, fire, random, process_random).ok, "Fire station placement can be undone")
	var city_hall := Buildings.apply(city, 5, 1, Vector2i(38, 30), random, process_random)
	_check(city_hall.ok, "City Hall placement succeeds")
	_check(
		city.microsim(10).stat_1 == 200
		and city.microsim(10).stat_2 == city.current_year(),
		"City Hall starts with its population cap and construction year",
	)
	_check(Buildings.undo(city, city_hall, random, process_random).ok, "City Hall placement can be undone")
	var museum := Buildings.apply(city, 12, 3, Vector2i(42, 30), random, process_random)
	_check(museum.ok, "Museum placement succeeds")
	_check(city.microsim(7).stat_0 == 100, "Museum system starts with score byte 100")
	_check(Buildings.undo(city, museum, random, process_random).ok, "Museum placement can be undone")
	_check(city.set_building_id(40, 40, Tiles.POWER_LINE_STRAIGHT_1), "Small park rejection fixture places a power line")
	var blocked_park := Buildings.apply(
		city, 14, 0, Vector2i(40, 40), random, process_random
	)
	_check(
		not blocked_park.ok
		and not blocked_park.error.is_empty()
		and city.building_id(40, 40) == 0x0e,
		"Small park cannot replace a power line",
	)
	_check(city.set_building_id(40, 40, Tiles.EMPTY), "Small park rejection fixture clears its power line")
	var park := Buildings.apply(city, 14, 0, Vector2i(40, 40), random, process_random)
	_check(park.ok, "Small park placement succeeds")
	_check(city.tile_flags[40 * 128 + 40] & 0xe0 == 0x20, "Small park gets only the piped structure flag")
	_check(city.building_corners(40, 40) == 0xf0, "One-tile building gets all corner bits")
	_check(Buildings.undo(city, park, random, process_random).ok, "Small park placement can be undone")
	var first_bus := Buildings.apply(city, 6, 4, Vector2i(70, 70), random, process_random)
	var second_bus := Buildings.apply(city, 6, 4, Vector2i(73, 70), random, process_random)
	_check(first_bus.ok and second_bus.ok, "Bus depots use the shared placement command")
	_check(first_bus.overlay_id == 52 and second_bus.overlay_id == 52, "Bus depots share fixed microsim record one")
	_check(not city.label(52).is_empty(), "Fixed bus microsim gets its default system label")
	_check(city.microsim(1).tile_id == 0xec and city.microsim(1).stat_1 == 2, "Fixed bus microsim aggregates two depots")
	_check(Buildings.undo(city, second_bus, random, process_random).ok, "Fixed microsim aggregation can be undone")
	_check(city.microsim(1).stat_1 == 1, "Fixed microsim undo restores the prior aggregate")
	var mayor_random_before := process_random.state
	var mayor_house := Buildings.apply(city, 5, 0, Vector2i(80, 80), random, process_random)
	_check(mayor_house.ok and mayor_house.overlay_id == 61, "Mayor house allocates a dynamic microsim")
	_check(document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0x0e, "Mayor house placement consumes its saved reward bit")
	_check(not city.label(61).is_empty(), "Mayor house gets its default label")
	_check(city.microsim(10).stat_1 == city.current_year(), "Mayor house stores its construction year")
	_check(city.microsim(10).stat_2 >= 10 and city.microsim(10).stat_2 <= 39, "Mayor house initializes the recovered age statistic")
	_check(Buildings.undo(city, mayor_house, random, process_random).ok, "Mayor house placement can be undone")
	_check(document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0x0f, "Mayor house undo restores its reward bit")
	_check(process_random.state == mayor_random_before, "Building undo restores the process random state")
	var llama_random := Random.new(123)
	var expected_llama_random := Random.new(123)
	var expected_llama_stat := expected_llama_random.next_u15() & 0x3f
	var llama := Buildings.apply(city, 5, 3, Vector2i(84, 80), random, llama_random)
	_check(llama.ok, "Llama Dome placement succeeds")
	_check(
		city.microsim(10).stat_3 == expected_llama_stat,
		"US Llama Dome placement stores one masked process-random value",
	)
	_check(Buildings.undo(city, llama, random, llama_random).ok, "Llama Dome placement can be undone")
	var australian_random := Random.new(456)
	var australian_state := australian_random.state
	var australian_llama := Buildings.apply(
		city, 5, 3, Vector2i(84, 80), random, australian_random, true
	)
	_check(australian_llama.ok, "Australian Llama Dome placement succeeds")
	_check(
		city.microsim(10).stat_3 == city.current_year()
		and australian_random.state == australian_state,
		"Australian Llama Dome stores its construction year without random use",
	)
	_check(
		Buildings.undo(city, australian_llama, random, australian_random).ok,
		"Australian Llama Dome placement can be undone",
	)

	_check(city.set_underground_id(59, 60, UnderTiles.PIPE_LTBR), "Pump fixture places an adjacent isolated pipe")
	var pump := Buildings.apply(city, 4, 1, Vector2i(60, 60), random, process_random)
	_check(pump.ok, "Water pump placement succeeds")
	_check(city.underground_id(59, 60) == 0x11 and city.underground_id(60, 60) == 0x11, "Water pump reconnects its adjacent pipe")
	_check(city.is_piped(60, 60), "Water pump keeps the piped flag")
	_check(Buildings.undo(city, pump, random, process_random).ok, "Water pump underground changes can be undone")
	_check(city.underground_id(59, 60) == 0x1e and city.underground_id(60, 60) == 0, "Pump undo restores both underground tiles")

	_check(city.set_underground_id(64, 65, UnderTiles.SUBWAY_LTBR), "Subway fixture places an adjacent isolated subway")
	_check(document.set_misc_u32(0x0fe8, 1), "Subway fixture counts its adjacent subway")
	var subway_station := Buildings.apply(city, 7, 3, Vector2i(65, 65), random, process_random)
	_check(subway_station.ok, "Subway station placement succeeds")
	_check(city.underground_id(65, 65) == 0x23, "Subway station writes the underground entrance")
	_check(city.underground_id(64, 65) == 0x02, "Subway station reconnects its adjacent subway")
	_check(document.misc_u32(0x0fe8) == 2, "Subway station increments the saved subway count")
	_check(not city.is_piped(65, 65) and not city.is_powered(65, 65) and city.is_powerable(65, 65) and subway_station.immediate_power_refresh, "Subway station clears piped and refreshes its isolated power state")
	_check(Buildings.undo(city, subway_station, random, process_random).ok, "Subway station underground changes can be undone")
	_check(document.misc_u32(0x0fe8) == 1, "Subway station undo restores the saved subway count")

	var statue := Buildings.apply(city, 5, 2, Vector2i(68, 68), random, process_random)
	_check(statue.ok, "Statue placement succeeds")
	_check(document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0x0b, "Statue placement consumes its saved reward bit")
	_check(city.is_piped(68, 68) and city.is_powered(68, 68) and not city.is_powerable(68, 68), "Statue clears the powerable flag")
	_check(Buildings.undo(city, statue, random, process_random).ok, "Statue placement can be undone")
	_check(document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0x0f, "Statue undo restores its reward bit")
	_check(document.set_misc_u32(ToolAvailability.MISC_GRANTED_REWARDS, 0), "Building fixture removes one-use rewards")
	var locked_reward := Buildings.apply(city, 5, 0, Vector2i(75, 75), random, process_random)
	_check(
		not locked_reward.ok and not locked_reward.error.is_empty(),
		"Building command rejects a reward that the city has not granted",
	)
	_check(document.set_misc_u32(ToolAvailability.MISC_GRANTED_REWARDS, 0x0f), "Building fixture restores one-use rewards")

	_check(
		BuildingFacilities.stadium_team_choices(city) == PackedInt32Array([0, 1, 2, 3, 4]),
		"A city without teams offers all five stadium teams",
	)
	_check(
		BuildingFacilities.stadium_team_name(city, 2) == "Camels",
		"An empty sports label uses the supplied default team name",
	)
	var stadium := Buildings.apply(
		city, 14, 3, Vector2i(90, 90), random, process_random
	)
	_check(
		stadium.ok
		and stadium.stadium_team_selection_required
		and stadium.overlay_id >= 61,
		"Stadium placement requests a team when it gets an XMIC record",
	)
	var assigned_stadium := BuildingFacilities.assign_stadium_team(
		city, stadium, 2, "Camel City Flyers"
	)
	_check(
		assigned_stadium.ok,
		"Stadium team assignment succeeds: %s" % assigned_stadium.error,
	)

	if assigned_stadium.ok:
		var stadium_record_id := (
			int(stadium.overlay_id) - Buildings.MICROSIM_LABEL_BASE
		)
		var stadium_record := city.microsim(stadium_record_id)
		_check(
			document.misc_u32(Buildings.MISC_STADIUM_TEAMS) == 0x04,
			"Stadium assignment sets its saved team bit",
		)
		_check(
			stadium_record.stat_2 == 2 and stadium_record.stat_3 == 0xfd,
			"Stadium assignment stores the team index and sports-label ID in XMIC",
		)
		_check(
			city.label(0xfd) == "Camel City Flyers",
			"Stadium assignment stores the editable team name in XLAB",
		)
		_check(
			Buildings.undo(
				city, assigned_stadium, random, process_random
			).ok,
			"Assigned stadium placement can be undone as one transaction",
		)
		_check(
			document.misc_u32(Buildings.MISC_STADIUM_TEAMS) == 0
			and city.label(0xfd).is_empty()
			and city.building_id(89, 89) == 0,
			"Stadium undo restores the team bit, label, XMIC, and map",
		)

	_check(document.set_misc_u32(Buildings.MISC_STADIUM_TEAMS, 0x1b), "Stadium fixture uses four teams")
	_check(
		BuildingFacilities.stadium_team_choices(city) == PackedInt32Array([2]),
		"The Stadium dialog offers only unused teams",
	)
	_check(document.set_misc_u32(Buildings.MISC_STADIUM_TEAMS, 0x1f), "Stadium fixture uses all teams")
	_check(
		BuildingFacilities.stadium_team_choices(city) == PackedInt32Array([0, 1, 2, 3, 4]),
		"The Stadium dialog permits every team after all five are used",
	)
	_check(document.set_misc_u32(Buildings.MISC_STADIUM_TEAMS, 0), "Building fixture restores stadium teams")

	var edge := Buildings.apply(city, 3, 2, Vector2i(1, 1), random, process_random)
	_check(not edge.ok and not edge.error.is_empty(), "Four-tile building rejects the inner map edge")
	_check(city.set_building_id(20, 20, Tiles.ROAD_STRAIGHT_1), "Blocked-site fixture places a road")
	var blocked := Buildings.apply(city, 3, 2, Vector2i(20, 20), random, process_random)
	_check(not blocked.ok and not blocked.error.is_empty(), "Building placement rejects a road")
	_check(city.set_building_id(20, 20, Tiles.EMPTY), "Blocked-site fixture removes the road")
	_check(city.set_zone_id(20, 20, 7), "Military fixture sets a military zone")
	var military := Buildings.apply(city, 3, 2, Vector2i(20, 20), random, process_random)
	_check(not military.ok and not military.error.is_empty(), "Building placement rejects military zones")
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
	_check(not dry_marina.ok and not dry_marina.error.is_empty(), "Marina rejects an all-dry site")

	var nuisance_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		_check(
			nuisance_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(CityState.TILE_COUNT, 0)
			),
			"Nuisance fixture clears %s" % chunk_id,
		)

	_check(
		nuisance_document.find_chunk("XLAB").set_decoded_payload(_filled_bytes(6400, 0))
		and nuisance_document.find_chunk("XMIC").set_decoded_payload(_filled_bytes(1200, 0)),
		"Nuisance fixture clears labels and microsimulations",
	)
	_check(nuisance_document.set_misc_i32(0x14, 5000), "Nuisance fixture sets funds")
	_check(
		nuisance_document.set_misc_u32(Buildings.MISC_NORMAL_POPULATION, 50_000_000),
		"Nuisance fixture prevents an immediate utility refresh",
	)
	var nuisance_city := CityModel.from_document(nuisance_document)

	for residential_point in [Vector2i(12, 12), Vector2i(12, 13), Vector2i(12, 14)]:
		_check(
			nuisance_city.set_zone_id(residential_point.x, residential_point.y, 1),
			"Nuisance fixture stores one nearby residential tile",
		)

	var nuisance_lfsr := LfsrRandom.new(1)
	var nuisance_process := Random.new(123)
	var nuisance_process_before := nuisance_process.state
	var rejected_nuisance := Buildings.apply(
		nuisance_city,
		3,
		2,
		Vector2i(20, 20),
		nuisance_lfsr,
		nuisance_process,
	)
	var contrasting_lcg := GameRandom.new(1)
	_check(
		not rejected_nuisance.ok
		and not rejected_nuisance.error.is_empty()
		and rejected_nuisance.residential_tiles == 3
		and rejected_nuisance.resident_objection
		and rejected_nuisance.lfsr_advanced
		and rejected_nuisance.sound_events == [512]
		and rejected_nuisance.notice_bitmap_id == 403
		and rejected_nuisance.notice_string_id == 106
		and nuisance_lfsr.state == 2
		and contrasting_lcg.next_mod(200) == 38,
		"Building nuisance rejection exposes the original notice, sound, and LFSR result",
	)
	_check(
		nuisance_city.funds() == 5000
		and nuisance_process.state == nuisance_process_before
		and nuisance_city.building_id(19, 19) == 0,
		"Nuisance rejection changes only the original LFSR state",
	)

	for residential_point in [Vector2i(12, 12), Vector2i(12, 13), Vector2i(12, 14)]:
		_check(
			nuisance_city.set_zone_id(residential_point.x, residential_point.y, 0),
			"Nuisance fixture clears one nearby residential tile",
		)

	_check(nuisance_city.set_building_id(20, 20, Tiles.ROAD_STRAIGHT_1), "Nuisance fixture blocks a Coal plant site")
	var blocked_lfsr := LfsrRandom.new(1)
	var nuisance_blocked := Buildings.apply(
		nuisance_city,
		3,
		2,
		Vector2i(20, 20),
		blocked_lfsr,
		Random.new(123),
	)
	_check(
		not nuisance_blocked.ok
		and not nuisance_blocked.error.is_empty()
		and nuisance_blocked.lfsr_advanced
		and blocked_lfsr.state == 2,
		"A nuisance building consumes its LFSR value before the site test",
	)
	_check(nuisance_city.set_building_id(20, 20, Tiles.EMPTY), "Nuisance fixture clears the blocked site")
	var edge_lfsr := LfsrRandom.new(1)
	var nuisance_edge := Buildings.apply(
		nuisance_city,
		3,
		2,
		Vector2i(1, 1),
		edge_lfsr,
		Random.new(123),
	)
	_check(
		not nuisance_edge.ok
		and not nuisance_edge.error.is_empty()
		and nuisance_edge.lfsr_advanced
		and edge_lfsr.state == 2,
		"A nuisance building consumes its LFSR value before the footprint limit",
	)

	_check(city.set_funds(3999), "Building funds fixture sets insufficient funds")
	var insufficient_lfsr_before := random.state
	var unaffordable := Buildings.apply(city, 3, 2, Vector2i(60, 60), random, process_random)
	_check(
		not unaffordable.ok
		and not unaffordable.error.is_empty()
		and not unaffordable.lfsr_advanced
		and random.state == insufficient_lfsr_before,
		"Insufficient building funds stop before the nuisance LFSR call",
	)


func _test_network_command(reference_root: String) -> void:
	_check(Networks.supports_tool(6, 0), "Network command supports roads")
	_check(Networks.supports_tool(7, 1), "Network command supports subways")
	_check(not Networks.supports_tool(6, 1), "Highways remain a separate network tool")
	_check(
		NetworkRoutes.route(Vector2i(10, 10), Vector2i(13, 12))
		== [Vector2i(10, 10), Vector2i(11, 10), Vector2i(11, 11), Vector2i(12, 11), Vector2i(12, 12), Vector2i(13, 12)],
		"Network route follows the recovered dominant-axis rule",
	)

	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Network fixture clears %s" % chunk_id,
		)

	_check(document.set_misc_i32(0x14, 10000), "Network fixture sets funds")
	_check(document.set_misc_u32(0x01f0, 16384), "Network fixture counts clear tiles")
	_check(document.set_misc_u32(0x0fe8, 0), "Network fixture clears subway count")
	var city := CityModel.from_document(document)

	var road := Networks.apply(city, 6, 0, Vector2i(10, 10), Vector2i(14, 10))
	_check(road.ok and road.points.size() == 5, "Road drag builds five tiles")
	_check(road.cost == 50 and city.funds() == 9950, "Road drag charges ten dollars per route tile")

	for x in range(10, 15):
		_check(city.building_id(x, 10) == 0x1e, "Road drag stores a connected road shape")

	_check(Networks.undo(city, road).ok, "Road drag can be undone")
	_check(city.funds() == 10000 and city.building_id(12, 10) == 0, "Road undo restores funds and tiles")

	for group in [6, 7, 3]:
		var tile_cost := 2 if group == 3 else (10 if group == 6 else 25)
		var base := Networks.apply(city, group, 0, Vector2i(50, 48), Vector2i(50, 52))
		_check(base.ok, "Reuse fixture builds its existing network")
		var before: PackedByteArray = document.serialize().data

		for endpoints in [
			[Vector2i(50, 50), Vector2i(53, 50)],
			[Vector2i(47, 50), Vector2i(50, 50)],
			[Vector2i(48, 50), Vector2i(52, 50)],
			[Vector2i(50, 48), Vector2i(50, 52)],
			[Vector2i(50, 50), Vector2i(50, 50)],
		]:
			var command := Networks.apply(city, group, 0, endpoints[0], endpoints[1])
			var new_count := 0 if endpoints[0].x == endpoints[1].x else absi(endpoints[1].x - endpoints[0].x)
			_check(command.ok and not command.stopped_early,
				"Road, rail and power routes start, end, cross, retrace and click existing networks")
			_check(command.cost == new_count * tile_cost,
				"Existing network tiles have no repeat construction charge")

			if endpoints[0].x == 48:
				_check(city.building_id(50, 50) == (0x1c if group == 3 else (0x2b if group == 6 else 0x3a)),
					"Crossing the same network forms a four-way junction")

			_check(Networks.undo(city, command).ok and document.serialize().data == before,
				"Reused network route Undo restores exact bytes")

		_check(Networks.undo(city, base).ok, "Reuse fixture restores the original map")

	var road_connection_request := Networks.apply(
		city, 6, 0, Vector2i(124, 40), Vector2i(127, 40)
	)
	_check(
		not road_connection_request.ok
		and road_connection_request.connection_selection_required
		and road_connection_request.connection_anchor == Vector2i(127, 40)
		and road_connection_request.connection_cost == 1000
		and road_connection_request.dry_cost == 40
		and city.funds() == 10000
		and city.building_id(124, 40) == 0,
		"A road dragged out of the map requests its recovered neighbor connection",
	)
	var canceled_road_connection := Networks.apply(
		city,
		6,
		0,
		Vector2i(124, 40),
		Vector2i(127, 40),
		Networks.BRIDGE_UNSELECTED,
		Networks.CONNECTION_CANCELLED
	)
	_check(
		canceled_road_connection.ok
		and canceled_road_connection.connection_cancelled
		and not canceled_road_connection.connection_built
		and canceled_road_connection.cost == 40
		and city.funds() == 9960
		and city.text_overlay_id(127, 40) == 0,
		"Canceling a road connection keeps and charges the dry route",
	)
	_check(
		Networks.undo(city, canceled_road_connection).ok and city.funds() == 10000,
		"Canceled road connection route can be undone",
	)
	var confirmed_road_connection := Networks.apply(
		city,
		6,
		0,
		Vector2i(124, 40),
		Vector2i(127, 40),
		Networks.BRIDGE_UNSELECTED,
		Networks.CONNECTION_CONFIRMED
	)
	_check(
		confirmed_road_connection.ok
		and confirmed_road_connection.connection_built
		and confirmed_road_connection.cost == 1040
		and confirmed_road_connection.connection_cost == 1000
		and city.funds() == 8960
		and city.text_overlay_id(127, 40) == 0xfa
		and city.building_id(127, 40) == 0x1e,
		"A confirmed road connection stores XTXT 0xFA and faces out of the map",
	)
	_check(
		Networks.undo(city, confirmed_road_connection).ok
		and city.funds() == 10000
		and city.text_overlay_id(127, 40) == 0,
		"Road connection undo restores the route, label, and funds",
	)

	var rail_connection_request := Networks.apply(
		city, 7, 0, Vector2i(3, 42), Vector2i(0, 42)
	)
	_check(
		not rail_connection_request.ok
		and rail_connection_request.connection_selection_required
		and rail_connection_request.connection_anchor == Vector2i(0, 42)
		and rail_connection_request.connection_cost == 1500
		and rail_connection_request.dry_cost == 100,
		"A rail route requests the recovered 1,500-dollar neighbor connection",
	)
	var confirmed_rail_connection := Networks.apply(
		city,
		7,
		0,
		Vector2i(3, 42),
		Vector2i(0, 42),
		Networks.BRIDGE_UNSELECTED,
		Networks.CONNECTION_CONFIRMED
	)
	_check(
		confirmed_rail_connection.ok
		and confirmed_rail_connection.cost == 1600
		and city.funds() == 8400
		and city.text_overlay_id(0, 42) == 0xfa
		and city.building_id(0, 42) == 0x2d,
		"A confirmed rail connection stores its label and outward rail shape",
	)
	_check(
		Networks.undo(city, confirmed_rail_connection).ok and city.funds() == 10000,
		"Rail connection can be undone",
	)

	var tangent_edge_route := Networks.apply(
		city, 6, 0, Vector2i(20, 0), Vector2i(24, 0)
	)
	_check(
		tangent_edge_route.ok
		and not tangent_edge_route.connection_selection_required
		and tangent_edge_route.cost == 50
		and city.text_overlay_id(24, 0) == 0,
		"A multi-tile route tangent to the edge does not request a connection",
	)
	_check(Networks.undo(city, tangent_edge_route).ok, "Tangent edge route can be undone")

	var corner_connection_request := Networks.apply(
		city, 6, 0, Vector2i(0, 0), Vector2i(0, 0)
	)
	_check(
		not corner_connection_request.ok
		and corner_connection_request.connection_selection_required,
		"A single click at a corner requests a road connection",
	)
	var corner_connection := Networks.apply(
		city,
		6,
		0,
		Vector2i(0, 0),
		Vector2i(0, 0),
		Networks.BRIDGE_UNSELECTED,
		Networks.CONNECTION_CONFIRMED
	)
	_check(
		corner_connection.ok
		and city.text_overlay_id(0, 0) == 0xfa
		and city.building_id(0, 0) == 0x26,
		"A corner marker adds both recovered outside-map connection directions",
	)
	_check(Networks.undo(city, corner_connection).ok, "Corner road connection can be undone")

	_check(city.set_funds(1039), "Road connection fixture limits funds below its exact total")
	var unaffordable_road_connection := Networks.apply(
		city, 6, 0, Vector2i(124, 44), Vector2i(127, 44)
	)
	_check(
		unaffordable_road_connection.ok
		and not unaffordable_road_connection.connection_error.is_empty()
		and unaffordable_road_connection.cost == 40
		and city.funds() == 999
		and city.text_overlay_id(127, 44) == 0,
		"Funds below the connection total build only the charged road route",
	)
	_check(
		Networks.undo(city, unaffordable_road_connection).ok,
		"Unaffordable road connection route can be undone",
	)
	_check(city.set_funds(10000), "Road connection fixture restores funds")

	_check(city.set_building_id(20, 20, Tiles.ROAD_STRAIGHT_1), "Rail crossover fixture places a road")
	var rail_crossing := Networks.apply(city, 7, 0, Vector2i(20, 20), Vector2i(21, 20))
	_check(rail_crossing.ok and city.building_id(20, 20) == 0x45, "Rail tool creates the recovered road crossover")
	_check(Networks.undo(city, rail_crossing).ok, "Rail crossover can be undone")

	_check(city.set_terrain_id(30, 30, 1), "Road-grade fixture installs a north-south slope")
	var graded_road := Networks.apply(city, 6, 0, Vector2i(30, 30), Vector2i(30, 30))
	_check(
		graded_road.ok
		and graded_road.cost == 10
		and graded_road.graded_tiles == 0
		and city.building_id(30, 30) == 0x1f,
		"Road tool uses the recovered graded sprite on a simple slope",
	)
	_check(Networks.undo(city, graded_road).ok, "Graded road can be undone")
	_check(city.set_terrain_id(30, 30, 0), "Road-grade fixture restores flat terrain")
	_check(city.set_terrain_id(31, 30, 9), "Road-grade fixture installs a compound slope")
	var reshaped_road := Networks.apply(city, 6, 0, Vector2i(31, 30), Vector2i(32, 30))
	_check(
		reshaped_road.ok
		and reshaped_road.cost == 45
		and reshaped_road.graded_tiles == 1
		and city.terrain_id(31, 30) == 1
		and city.building_id(31, 30) == 0x1f,
		"Road tool grades a compound slope and charges the recovered extra cost",
	)
	_check(Networks.undo(city, reshaped_road).ok, "Reshaped road can be undone")

	var crossing_road := Networks.apply(city, 6, 0, Vector2i(60, 60), Vector2i(64, 60))
	_check(crossing_road.ok, "Power-crossing fixture builds a straight road")
	var road_power := Networks.apply(city, 3, 0, Vector2i(62, 58), Vector2i(62, 62))
	_check(
		road_power.ok
		and road_power.points.size() == 5
		and city.building_id(62, 60) == 0x44,
		"Power line crosses a perpendicular road",
	)
	_check(Networks.undo(city, road_power).ok, "Road power crossing can be undone")
	_check(Networks.undo(city, crossing_road).ok, "Power-crossing road can be undone")
	_check(city.set_building_id(65, 65, Tiles.ROAD_STRAIGHT_1), "Single power-crossing fixture places a road")
	var single_road_power := Networks.apply(city, 3, 0, Vector2i(65, 65), Vector2i(65, 65))
	_check(
		single_road_power.ok and city.building_id(65, 65) == 0x43,
		"A single click makes the perpendicular power and road crossing",
	)
	_check(Networks.undo(city, single_road_power).ok, "Single road power crossing can be undone")

	var crossing_rail := Networks.apply(city, 7, 0, Vector2i(70, 70), Vector2i(74, 70))
	_check(crossing_rail.ok, "Power-crossing fixture builds straight rail")
	var rail_power := Networks.apply(city, 3, 0, Vector2i(72, 68), Vector2i(72, 72))
	_check(
		rail_power.ok
		and rail_power.points.size() == 5
		and city.building_id(72, 70) == 0x48,
		"Power line crosses a perpendicular rail",
	)
	_check(Networks.undo(city, rail_power).ok, "Rail power crossing can be undone")
	_check(Networks.undo(city, crossing_rail).ok, "Power-crossing rail can be undone")
	_check(city.set_building_id(75, 75, Tiles.RAIL_STRAIGHT_1), "Single power-crossing fixture places rail")
	var single_rail_power := Networks.apply(city, 3, 0, Vector2i(75, 75), Vector2i(75, 75))
	_check(
		single_rail_power.ok and city.building_id(75, 75) == 0x47,
		"A single click makes the perpendicular power and rail crossing",
	)
	_check(Networks.undo(city, single_rail_power).ok, "Single rail power crossing can be undone")

	var pipes := Networks.apply(city, 4, 0, Vector2i(10, 30), Vector2i(12, 30))
	_check(pipes.ok and pipes.cost == 9, "Pipe drag charges three dollars per tile")

	for x in range(10, 13):
		_check(city.underground_id(x, 30) == 0x11, "Pipe drag stores connected pipe shapes")
		_check(city.is_piped(x, 30), "Pipe drag sets the piped flag")

	var pipes_before: PackedByteArray = document.serialize().data
	var pipe_extension := Networks.apply(city, 4, 0, Vector2i(11, 30), Vector2i(11, 33))
	_check(pipe_extension.ok and pipe_extension.cost == 9 and not pipe_extension.stopped_early,
		"Pipes can start on an existing pipe without charging it again")
	_check(Networks.undo(city, pipe_extension).ok and document.serialize().data == pipes_before,
		"Pipe extension Undo preserves exact bytes")
	var subway_over_pipe := Networks.apply(city, 7, 1, Vector2i(10, 30), Vector2i(12, 30))
	_check(subway_over_pipe.ok and subway_over_pipe.cost == 300 and not subway_over_pipe.stopped_early,
		"Subway can run under parallel pipe tiles")

	for x in range(10, 13):
		_check(city.is_piped(x, 30) and city.underground_id(x, 30) in [0x1f, 0x20],
			"Subway under a pipe keeps the dual-network cell and piped flag")

	_check(Networks.undo(city, subway_over_pipe).ok and document.serialize().data == pipes_before,
		"Subway under pipes has exact Undo")
	_check(Networks.undo(city, pipes).ok, "Pipe drag can be undone")

	var subway := Networks.apply(city, 7, 1, Vector2i(30, 30), Vector2i(30, 32))
	_check(subway.ok and subway.cost == 300, "Subway drag charges one hundred dollars per tile")

	for y in range(30, 33):
		_check(city.underground_id(30, y) == 0x01, "Subway drag stores connected subway shapes")

	_check(document.misc_u32(0x0fe8) == 3, "Subway drag increments the saved subway count")
	_check(Networks.undo(city, subway).ok, "Subway drag can be undone")
	_check(document.misc_u32(0x0fe8) == 0, "Subway undo restores the saved subway count")

	_check(city.set_building_id(42, 40, Tiles.SUSPENSION_BRIDGE_1), "Partial-route fixture places an obstruction")
	var partial := Networks.apply(city, 6, 0, Vector2i(40, 40), Vector2i(44, 40))
	_check(partial.ok and partial.stopped_early, "Road route stops at an obstruction")
	_check(partial.points == [Vector2i(40, 40), Vector2i(41, 40)], "Road route keeps the clear prefix")
	_check(partial.cost == 20, "Partial road route charges only its planned prefix")
	_check(Networks.undo(city, partial).ok, "Partial road route can be undone")

	for x in range(80, 89):
		_check(city.set_land_altitude(x, 20, 4), "Bridge fixture sets land altitude")
		_check(city.set_water_altitude(x, 20, 5), "Bridge fixture sets water altitude")
		_check(city.set_tile_flag(x, 20, 0x04, x < 88), "Bridge fixture sets surface water")
		_check(
			city.set_terrain_id(x, 20, 0x21 if x == 80 else (0x10 if x < 88 else 0)),
			"Bridge fixture sets shoreline and water terrain",
		)

	var bridge_request := Networks.apply(
		city, 6, 0, Vector2i(80, 20), Vector2i(88, 20)
	)
	_check(
		not bridge_request.ok
		and bridge_request.bridge_selection_required
		and bridge_request.bridge_span_length == 8
		and bridge_request.bridge_choices.size() == 3
		and bridge_request.bridge_choices[0].type == Networks.BRIDGE_ROAD_CAUSEWAY
		and bridge_request.bridge_choices[1].type == Networks.BRIDGE_ROAD_RAISING
		and bridge_request.bridge_choices[2].type == Networks.BRIDGE_ROAD_SUSPENSION,
		"Road bridge request offers all recovered choices for an eight-tile span",
	)
	_check(
		NetworkBridges.bridge_choices(4, Networks.MODE_ROAD).size() == 1
		and NetworkBridges.bridge_choices(5, Networks.MODE_ROAD).size() == 2
		and NetworkBridges.bridge_choices(7, Networks.MODE_ROAD).size() == 3
		and NetworkBridges.bridge_choices(12, Networks.MODE_ROAD).size() == 2,
		"Road bridge choices use the recovered length limits",
	)
	var direct_bridge_cancel := Networks.apply(
		city,
		6,
		0,
		Vector2i(80, 20),
		Vector2i(88, 20),
		Networks.BRIDGE_CANCELLED
	)
	_check(
		not direct_bridge_cancel.ok
		and direct_bridge_cancel.cancelled
		and city.funds() == 10000
		and city.building_id(80, 20) == 0,
		"Canceling a direct bridge does not change the city",
	)
	var prefix_bridge_cancel := Networks.apply(
		city,
		6,
		0,
		Vector2i(75, 20),
		Vector2i(88, 20),
		Networks.BRIDGE_CANCELLED
	)
	_check(
		prefix_bridge_cancel.ok
		and prefix_bridge_cancel.bridge_cancelled
		and prefix_bridge_cancel.dry_points.size() == 5
		and prefix_bridge_cancel.cost == 50
		and city.funds() == 9950
		and city.building_id(79, 20) != 0
		and city.building_id(80, 20) == 0,
		"Canceling a bridge keeps and charges its dry route prefix",
	)
	_check(
		Networks.undo(city, prefix_bridge_cancel).ok and city.funds() == 10000,
		"Canceled bridge prefix can be undone",
	)
	var causeway := Networks.apply(
		city,
		6,
		0,
		Vector2i(80, 20),
		Vector2i(88, 20),
		Networks.BRIDGE_ROAD_CAUSEWAY
	)
	_check(
		causeway.ok
		and causeway.bridge_built
		and causeway.bridge_span_length == 8
		and causeway.bridge_points.size() == 8
		and causeway.bridge_cost == 200
		and causeway.cost == 210
		and city.funds() == 9790
		and city.building_id(88, 20) != 0,
		"Causeway keeps its recovered span cost and continues to the dry endpoint",
	)
	_check(
		city.terrain_id(80, 20) == 3
		and city.terrain_id(87, 20) == 1
		and city.land_altitude(80, 20) == 5
		and city.land_altitude(87, 20) == 5
		and not city.is_water(80, 20)
		and not city.is_water(87, 20),
		"Causeway raises and reshapes both recovered bank tiles",
	)

	for x in range(81, 87):
		_check(
			city.building_id(x, 20) == 0x57
			and city.is_water(x, 20)
			and (city.tile_flags[x * 128 + 20] & 0x02) != 0,
			"Causeway stores horizontal span tiles with the recovered mirror flag",
		)

	_check(Networks.undo(city, causeway).ok, "Causeway placement can be undone")
	_check(
		city.funds() == 10000
		and city.terrain_id(80, 20) == 0x21
		and city.land_altitude(80, 20) == 4
		and city.is_water(80, 20),
		"Causeway undo restores funds, terrain, altitude, and water",
	)

	var raising_bridge := Networks.apply(
		city,
		6,
		0,
		Vector2i(80, 20),
		Vector2i(88, 20),
		Networks.BRIDGE_ROAD_RAISING
	)
	_check(
		raising_bridge.ok
		and raising_bridge.bridge_cost == 400
		and [
			city.building_id(81, 20), city.building_id(82, 20),
			city.building_id(83, 20), city.building_id(84, 20),
			city.building_id(85, 20), city.building_id(86, 20),
		] == [0x57, 0x56, 0x58, 0x58, 0x56, 0x57],
		"Raising bridge writes the recovered tower and raised-deck pattern",
	)
	_check(Networks.undo(city, raising_bridge).ok, "Raising bridge placement can be undone")

	var suspension_bridge := Networks.apply(
		city,
		6,
		0,
		Vector2i(80, 20),
		Vector2i(88, 20),
		Networks.BRIDGE_ROAD_SUSPENSION
	)
	_check(
		suspension_bridge.ok
		and suspension_bridge.bridge_cost == 600
		and [
			city.building_id(81, 20), city.building_id(82, 20),
			city.building_id(83, 20), city.building_id(84, 20),
			city.building_id(85, 20), city.building_id(86, 20),
		] == [0x55, 0x54, 0x53, 0x52, 0x51, 0x57],
		"Suspension bridge writes the recovered five-piece pattern",
	)
	_check(Networks.undo(city, suspension_bridge).ok, "Suspension bridge placement can be undone")

	var rail_bridge := Networks.apply(
		city, 7, 0, Vector2i(80, 20), Vector2i(88, 20)
	)
	_check(
		rail_bridge.ok
		and rail_bridge.bridge_type == Networks.BRIDGE_RAIL
		and rail_bridge.bridge_cost == 600
		and [
			city.building_id(81, 20), city.building_id(82, 20),
			city.building_id(83, 20), city.building_id(84, 20),
			city.building_id(85, 20), city.building_id(86, 20),
		] == [0x5a, 0x5b, 0x5b, 0x5a, 0x5b, 0x5b],
		"Rail bridge uses the recovered price and pylon pattern",
	)
	_check(Networks.undo(city, rail_bridge).ok, "Rail bridge placement can be undone")

	var wire_bridge := Networks.apply(
		city, 3, 0, Vector2i(80, 20), Vector2i(88, 20)
	)
	_check(
		wire_bridge.ok
		and wire_bridge.bridge_type == Networks.BRIDGE_WIRE
		and wire_bridge.bridge_cost == 80,
		"Raised wires use the recovered ten-dollar span price",
	)

	for x in range(81, 87):
		_check(
			city.building_id(x, 20) == 0x5c and city.is_powerable(x, 20),
			"Raised wires store powered bridge tiles",
		)

	_check(Networks.undo(city, wire_bridge).ok, "Raised-wire placement can be undone")

	_check(city.set_funds(100), "Bridge funds fixture limits available funds")
	var bridge_after_road := Networks.apply(
		city,
		6,
		0,
		Vector2i(75, 20),
		Vector2i(88, 20),
		Networks.BRIDGE_ROAD_CAUSEWAY
	)
	_check(
		bridge_after_road.ok
		and not bridge_after_road.bridge_built
		and not bridge_after_road.bridge_error.is_empty()
		and bridge_after_road.dry_points.size() == 5
		and bridge_after_road.cost == 50
		and city.funds() == 50,
		"An unaffordable bridge keeps and charges the recovered dry route prefix",
	)
	_check(Networks.undo(city, bridge_after_road).ok, "Unaffordable bridge prefix can be undone")
	_check(city.set_funds(10000), "Network fixture restores funds after bridge checks")

	_check(city.set_funds(1), "Network funds fixture sets insufficient funds")
	var unaffordable := Networks.apply(city, 3, 0, Vector2i(50, 50), Vector2i(51, 50))
	_check(not unaffordable.ok and not unaffordable.error.is_empty(), "Network command reports insufficient funds")


func _test_hydro_command(reference_root: String) -> void:
	_check(Hydro.supports_tool(3, 3), "Hydroelectric command supports the hydro tool")
	_check(not Hydro.supports_tool(3, 2), "Hydroelectric command rejects coal power")
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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
	_check(
		document.set_misc_u32(Buildings.MISC_NORMAL_POPULATION, 49999),
		"Hydroelectric fixture sets population below the utility threshold",
	)
	var city := CityModel.from_document(document)
	_check(city.set_terrain_id(20, 20, 0x2e), "Hydroelectric fixture places a waterfall")
	_check(city.set_land_altitude(20, 20, 5), "Hydroelectric fixture sets waterfall altitude")
	_check(city.set_land_altitude(20, 19, 6), "Hydroelectric fixture sets a higher north tile")
	var process_random := Random.new(33)
	var command := Hydro.apply(city, 3, 3, Vector2i(20, 20), process_random)
	_check(command.ok, "Hydroelectric placement succeeds: %s" % command.error)
	_check(command.tile_id == 0xc7 and city.building_id(20, 20) == 0xc7, "Hydroelectric tile follows the recovered slope orientation")
	_check(
		city.funds() == 600
		and city.is_powerable(20, 20)
		and city.is_powered(20, 20)
		and command.immediate_power_refresh,
		"Low-population hydroelectric placement charges cost and refreshes power",
	)
	_check(city.zones[20 * 128 + 20] == 0xf0, "Hydroelectric placement sets all corner bits")
	_check(command.overlay_id == 56 and not city.label(56).is_empty(), "Hydroelectric placement uses fixed XMIC record five")
	_check(city.microsim(5).stat_1 == 1 and city.microsim(5).stat_2 == 20, "Hydroelectric placement increments fixed XMIC totals")
	_check(Hydro.undo(city, command, process_random).ok, "Hydroelectric placement can be undone")
	_check(city.building_id(20, 20) == 0 and city.funds() == 1000, "Hydroelectric undo restores the tile and funds")
	for population in [49_999, 50_000, 49_999_999, 50_000_000]:
		var expect_refresh: bool = population < 50_000_000

		_check(
			document.set_misc_u32(Buildings.MISC_NORMAL_POPULATION, population),
			"Hydroelectric fixture sets the strict utility threshold",
		)
		var threshold_command := Hydro.apply(
			city, 3, 3, Vector2i(20, 20), process_random
		)
		_check(
			threshold_command.ok
			and threshold_command.immediate_power_refresh == expect_refresh
			and city.is_powerable(20, 20)
			and city.is_powered(20, 20) == expect_refresh,
			"Hydroelectric power refresh at population %d" % population,
		)
		_check(
			Hydro.undo(city, threshold_command, process_random).ok,
			"Threshold hydroelectric placement can be undone",
		)
	var wrong_terrain := Hydro.apply(city, 3, 3, Vector2i(21, 21), process_random)
	_check(not wrong_terrain.ok and not wrong_terrain.error.is_empty(), "Hydroelectric placement requires waterfall terrain")


func _test_subway_to_rail_command(reference_root: String) -> void:
	_check(SubwayToRail.supports_tool(7, 4), "Subway-to-rail command supports its catalog tool")
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["XBLD", "XTER", "XZON", "XUND", "XBIT"]:
		_check(
			document.find_chunk(chunk_id).set_decoded_payload(_filled_bytes(128 * 128, 0)),
			"Subway-to-rail fixture clears %s" % chunk_id,
		)

	_check(document.set_misc_i32(0x14, 0), "Subway-to-rail fixture clears funds")
	_check(document.set_misc_u32(0x01f0, 16383), "Subway-to-rail fixture counts clear tiles")
	_check(document.set_misc_u32(0x01f0 + 0x2c * 4, 1), "Subway-to-rail fixture counts rail")
	_check(document.set_misc_u32(0x0fe8, 0), "Subway-to-rail fixture clears subway count")
	var city := CityModel.from_document(document)
	_check(city.set_building_id(21, 20, Tiles.RAIL_STRAIGHT_1), "Subway-to-rail fixture places adjacent rail")
	_check(city.set_zone_id(20, 20, 3), "Subway-to-rail fixture places a commercial zone")
	var surface := SubwayToRail.apply(city, 7, 4, Vector2i(20, 20))
	_check(surface.ok, "Subway-to-rail placement beside surface rail succeeds: %s" % surface.error)
	_check(surface.tile_id == 0x6c and city.building_id(20, 20) == 0x6c, "East rail selects connector orientation zero")
	_check(city.underground_id(20, 20) == 0x23, "Subway-to-rail placement writes underground entrance 0x23")
	_check(document.misc_u32(0x0fe8) == 1, "Subway-to-rail increments the saved subway count")
	_check(city.zones[20 * 128 + 20] == 0xf3, "Subway-to-rail placement preserves the zone and sets all corners")
	_check(city.funds() == 0 and surface.cost == 0 and surface.listed_cost == 250, "Subway-to-rail reproduces the executable's missing cost deduction")
	_check(SubwayToRail.undo(city, surface).ok, "Subway-to-rail placement can be undone")
	_check(city.building_id(20, 20) == 0 and city.underground_id(20, 20) == 0, "Subway-to-rail undo restores surface and underground maps")
	_check(document.misc_u32(0x0fe8) == 0, "Subway-to-rail undo restores the saved subway count")

	_check(city.set_building_id(21, 20, Tiles.EMPTY), "Underground connection fixture removes surface rail")
	_check(city.set_underground_id(21, 20, UnderTiles.SUBWAY_LR), "Underground connection fixture places adjacent subway")
	var underground := SubwayToRail.apply(city, 7, 4, Vector2i(20, 20))
	_check(underground.ok and underground.tile_id == 0x6e, "East subway selects the opposite connector orientation")
	_check(SubwayToRail.undo(city, underground).ok, "Underground-oriented connector can be undone")
	_check(city.set_underground_id(21, 20, UnderTiles.EMPTY), "Missing-neighbor fixture removes adjacent subway")
	var no_neighbor := SubwayToRail.apply(city, 7, 4, Vector2i(20, 20))
	_check(not no_neighbor.ok and not no_neighbor.error.is_empty(), "Subway-to-rail placement requires an adjacent network")


func _test_onramp_command(reference_root: String) -> void:
	_check(Onramps.supports_tool(6, 3), "On-ramp command supports its catalog tool")
	_check(not Onramps.supports_tool(6, 1), "On-ramp command rejects the highway tool")
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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
	_check(city.set_building_id(21, 20, Tiles.HIGHWAY_STRAIGHT_1), "On-ramp fixture places east highway")
	_check(city.set_building_id(20, 19, Tiles.ROAD_STRAIGHT_1), "On-ramp fixture places north road")
	var north := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(north.ok, "North-road on-ramp succeeds: %s" % north.error)
	_check(north.tile_id == 0x5f and city.building_id(20, 20) == 0x5f, "East highway and north road select ramp 0x5f")
	_check(city.building_id(20, 19) == 0x2b, "On-ramp converts its adjacent road to tile 0x2b")
	_check((city.tile_flags[20 * 128 + 20] & 0x02) != 0, "North-road on-ramp sets the flipped flag")
	_check(city.funds() == 75 and north.cost == 25, "On-ramp charges the catalog cost")
	_check(Onramps.undo(city, north).ok, "On-ramp placement can be undone")
	_check(city.building_id(20, 20) == 0 and city.building_id(20, 19) == 0x1d, "On-ramp undo restores both surface tiles")
	_check(city.funds() == 100, "On-ramp undo restores funds")

	_check(city.set_building_id(21, 20, Tiles.EMPTY), "Second on-ramp fixture removes east highway")
	_check(city.set_building_id(20, 19, Tiles.EMPTY), "Second on-ramp fixture removes north road")
	_check(city.set_building_id(20, 19, Tiles.HIGHWAY_STRAIGHT_1), "Second on-ramp fixture places north highway")
	_check(city.set_building_id(21, 20, Tiles.ROAD_STRAIGHT_1), "Second on-ramp fixture places east road")
	var east := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(east.ok and east.tile_id == 0x5d, "North highway and east road select ramp 0x5d")
	_check(Onramps.undo(city, east).ok, "East-road on-ramp can be undone")
	_check(city.set_building_id(20, 19, Tiles.EMPTY), "Invalid arrangement fixture removes north highway")
	_check(city.set_building_id(21, 20, Tiles.EMPTY), "Invalid arrangement fixture removes east road")
	_check(city.set_building_id(21, 20, Tiles.HIGHWAY_STRAIGHT_1), "Invalid arrangement fixture places east highway")
	_check(city.set_building_id(19, 20, Tiles.ROAD_STRAIGHT_1), "Invalid arrangement fixture places west road")
	var parallel := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(not parallel.ok and not parallel.error.is_empty(), "On-ramp rejects a road parallel to the highway")
	_check(city.set_funds(24), "On-ramp funds fixture sets insufficient funds")
	_check(city.set_building_id(19, 20, Tiles.EMPTY), "On-ramp funds fixture removes west road")
	_check(city.set_building_id(20, 19, Tiles.ROAD_STRAIGHT_1), "On-ramp funds fixture places north road")
	var unaffordable := Onramps.apply(city, 6, 3, Vector2i(20, 20))
	_check(not unaffordable.ok and not unaffordable.error.is_empty(), "On-ramp command reports insufficient funds")
	_check(city.set_funds(0), "SCURK on-ramp fixture clears funds")
	var free_onramp := Onramps.apply(
		city, 6, 3, Vector2i(20, 20), true
	)
	_check(
		free_onramp.ok
		and free_onramp.cost == 0
		and free_onramp.listed_cost == 25
		and city.funds() == 0,
		"SCURK builds an on-ramp without changing city funds",
	)
	_check(
		Onramps.undo(city, free_onramp).ok and city.funds() == 0,
		"SCURK free on-ramp Undo preserves city funds",
	)


func _test_tunnel_command(reference_root: String) -> void:
	_check(Tunnels.supports_tool(6, 2), "Tunnel command supports its catalog tool")
	_check(not Tunnels.supports_tool(6, 1), "Tunnel command rejects the highway tool")
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
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
	_check(city.set_building_id(19, 20, Tiles.ROAD_STRAIGHT_1), "Tunnel fixture places an adjacent road")
	var planned := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(
		planned.confirmation_required
		and planned.finish == Vector2i(22, 20)
		and planned.points.size() == 3
		and planned.cost == 450,
		"Tunnel validates its path and cost before confirmation",
	)
	_check(
		city.building_id(20, 20) == 0
		and city.tunnel_levels(21, 20) == 0
		and city.funds() == 1000,
		"Tunnel confirmation request does not change the city",
	)
	var canceled := Tunnels.apply(
		city, 6, 2, Vector2i(20, 20), Tunnels.CONFIRMATION_CANCELLED
	)
	_check(
		canceled.cancelled
		and city.building_id(20, 20) == 0
		and city.tunnel_levels(21, 20) == 0
		and city.funds() == 1000,
		"Tunnel cancel does not change the city",
	)
	var invalid_choice := Tunnels.apply(city, 6, 2, Vector2i(20, 20), 2)
	_check(
		not invalid_choice.ok and not invalid_choice.error.is_empty(),
		"Tunnel rejects an unknown confirmation choice",
	)
	var command := Tunnels.apply(
		city, 6, 2, Vector2i(20, 20), Tunnels.CONFIRMATION_CONFIRMED
	)
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
	_check(not conflict.ok and not conflict.error.is_empty(), "Tunnel rejects an existing ALTM tunnel path")
	_check(city.set_tunnel_levels(21, 20, 0), "Tunnel conflict fixture removes existing tunnel")
	_check(city.set_underground_id(21, 20, UnderTiles.PIPE_LR), "Tunnel conflict fixture places a pipe at depth two")
	var pipe_conflict := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(not pipe_conflict.ok and not pipe_conflict.error.is_empty(), "Tunnel rejects a pipe at the matching depth")
	_check(city.set_underground_id(21, 20, UnderTiles.EMPTY), "Tunnel conflict fixture removes pipe")
	_check(city.set_terrain_id(22, 20, 2), "Tunnel exit fixture changes the opposite slope")
	var no_exit := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(not no_exit.ok and not no_exit.error.is_empty(), "Tunnel requires the recovered opposite exit slope")
	_check(city.set_terrain_id(22, 20, 1), "Tunnel funds fixture restores the exit slope")
	_check(city.set_funds(449), "Tunnel funds fixture sets insufficient funds")
	var unaffordable_plan := Tunnels.apply(city, 6, 2, Vector2i(20, 20))
	_check(
		unaffordable_plan.confirmation_required
		and unaffordable_plan.cost == 450,
		"Tunnel asks for confirmation before it checks funds",
	)
	var unaffordable := Tunnels.apply(
		city, 6, 2, Vector2i(20, 20), Tunnels.CONFIRMATION_CONFIRMED
	)
	_check(not unaffordable.ok and not unaffordable.error.is_empty(), "Tunnel command reports insufficient funds")
	_check(city.set_funds(0), "SCURK tunnel fixture clears funds")
	var free_tunnel := Tunnels.apply(
		city,
		6,
		2,
		Vector2i(20, 20),
		Tunnels.CONFIRMATION_CONFIRMED,
		true
	)
	_check(
		free_tunnel.ok
		and free_tunnel.cost == 0
		and free_tunnel.listed_cost == 450
		and city.funds() == 0,
		"SCURK builds a tunnel without changing city funds",
	)
	_check(
		Tunnels.undo(city, free_tunnel).ok and city.funds() == 0,
		"SCURK free tunnel Undo preserves city funds",
	)


func _test_highway_command(reference_root: String) -> void:
	_check(Highways.supports_tool(6, 1), "Highway command supports its catalog tool")
	_check(not Highways.supports_tool(6, 0), "Highway command rejects the road tool")
	_check(HighwayGeometry.snap_anchor(Vector2i(11, 13)) == Vector2i(10, 12), "Highway pointer snaps to even coordinates")
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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

	var highway_before: PackedByteArray = document.serialize().data

	for endpoints in [
		[Vector2i(14, 10), Vector2i(18, 10)],
		[Vector2i(6, 10), Vector2i(10, 10)],
		[Vector2i(10, 10), Vector2i(14, 10)],
	]:
		var reuse := Highways.apply(city, 6, 1, endpoints[0], endpoints[1])
		_check(reuse.ok and not reuse.stopped_early,
			"Highway routes can start, end and retrace existing highway sections")
		_check(reuse.cost == (0 if endpoints[0].x == 10 else 200),
			"Highway reuse charges only new sections")
		_check(Highways.undo(city, reuse).ok and document.serialize().data == highway_before,
			"Highway reuse Undo restores exact bytes")

	_check(Highways.undo(city, straight).ok, "Straight highway can be undone")
	_check(city.funds() == 1000 and city.building_id(12, 10) == 0, "Highway undo restores funds and tiles")

	var turn := Highways.apply(city, 6, 1, Vector2i(10, 10), Vector2i(12, 12))
	_check(turn.ok and turn.sections == [Vector2i(10, 10), Vector2i(10, 12), Vector2i(12, 12)], "Highway route follows the recovered dominant-axis rule")
	_check(city.building_id(10, 10) == 0x49, "Highway turn starts with a vertical section")
	_check(city.building_id(10, 12) == 0x65, "North-east highway turn uses shaped tile 0x65")
	_check(city.building_id(12, 12) == 0x4a, "Highway turn ends with a horizontal section")
	_check((city.zones[10 * 128 + 12] & 0xf0) != 0xf0, "Shaped highway stores a 2-by-2 corner mask")
	_check(Highways.undo(city, turn).ok, "Turning highway can be undone")

	_check(city.set_building_id(10, 10, Tiles.ROAD_STRAIGHT_2), "Highway crossing fixture places a horizontal road")
	_check(document.set_misc_u32(0x01f0, 16383), "Highway crossing fixture updates clear count")
	_check(document.set_misc_u32(0x01f0 + 0x1e * 4, 1), "Highway crossing fixture counts road")
	var crossing_city := CityModel.from_document(document)
	var crossing := Highways.apply(crossing_city, 6, 1, Vector2i(10, 10), Vector2i(10, 12))
	_check(crossing.ok, "Highway can cross a perpendicular road: %s" % crossing.error)
	_check(crossing_city.building_id(10, 10) == 0x4b, "Vertical highway and horizontal road use crossover 0x4b")
	_check(Highways.undo(crossing_city, crossing).ok, "Highway crossover can be undone")
	_check(crossing_city.set_building_id(10, 10, Tiles.EMPTY), "Highway obstruction fixture removes road")
	_check(crossing_city.set_building_id(14, 10, Tiles.CITY_HALL), "Highway obstruction fixture places a building")
	var partial := Highways.apply(crossing_city, 6, 1, Vector2i(10, 10), Vector2i(16, 10))
	_check(partial.ok and partial.stopped_early, "Highway route stops at an obstruction")
	_check(partial.sections == [Vector2i(10, 10), Vector2i(12, 10)], "Highway route keeps its clear prefix")
	_check(partial.cost == 200, "Partial highway charges only its clear sections")
	_check(Highways.undo(crossing_city, partial).ok, "Partial highway can be undone")
	_check(crossing_city.set_tile_flag(10, 10, 0x04, true), "Highway water fixture sets water")
	var water := Highways.apply(crossing_city, 6, 1, Vector2i(10, 10), Vector2i(10, 10))
	_check(
		not water.ok and not water.error.is_empty(),
		"Highway bridge start requires a valid 2-by-2 shoreline",
	)

	var bridge_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			bridge_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(size, 0)
			),
			"Highway bridge fixture clears %s" % chunk_id,
		)

	_check(bridge_document.set_misc_i32(0x14, 5000), "Highway bridge fixture sets funds")
	_check(
		bridge_document.set_misc_u32(0x01f0, CityState.TILE_COUNT),
		"Highway bridge fixture counts clear tiles",
	)
	var bridge_city := CityModel.from_document(bridge_document)

	for x in range(76, 88):
		for y in range(20, 22):
			var water_cell := x >= 80 and x < 86
			_check(
				bridge_city.set_land_altitude(x, y, 4 if water_cell else 6)
				and bridge_city.set_water_altitude(x, y, 5)
				and bridge_city.set_tile_flag(x, y, 0x04, water_cell)
				and bridge_city.set_terrain_id(x, y, 0x10 if water_cell else 0),
				"Highway bridge fixture writes its banks and water sections",
			)

	var bridge_request := Highways.apply(
		bridge_city, 6, 1, Vector2i(76, 20), Vector2i(84, 20)
	)
	_check(
		not bridge_request.ok
		and bridge_request.bridge_selection_required
		and bridge_request.sections == [Vector2i(76, 20), Vector2i(78, 20)]
		and bridge_request.bridge_span_length == 3
		and bridge_request.bridge_choices.size() == 2
		and bridge_request.bridge_choices[0].type == Highways.BRIDGE_HIGHWAY
		and bridge_request.bridge_choices[0].cost == 600
		and bridge_request.bridge_choices[1].type == Highways.BRIDGE_REINFORCED
		and bridge_request.bridge_choices[1].cost == 900
		and bridge_city.funds() == 5000,
		"Highway water route offers the normal and reinforced bridge types",
	)
	var canceled_bridge := Highways.apply(
		bridge_city,
		6,
		1,
		Vector2i(76, 20),
		Vector2i(84, 20),
		Highways.CONNECTION_UNSELECTED,
		Highways.BRIDGE_CANCELLED
	)
	_check(
		canceled_bridge.ok
		and canceled_bridge.bridge_cancelled
		and not canceled_bridge.bridge_built
		and canceled_bridge.sections.size() == 2
		and canceled_bridge.cost == 200
		and bridge_city.funds() == 4800
		and bridge_city.building_id(78, 20) == 0x4a
		and bridge_city.building_id(80, 20) == 0,
		"Canceling a highway bridge keeps and charges the dry prefix",
	)
	_check(
		Highways.undo(bridge_city, canceled_bridge).ok and bridge_city.funds() == 5000,
		"Canceled highway bridge prefix can be undone",
	)
	var normal_bridge := Highways.apply(
		bridge_city,
		6,
		1,
		Vector2i(76, 20),
		Vector2i(84, 20),
		Highways.CONNECTION_UNSELECTED,
		Highways.BRIDGE_HIGHWAY
	)
	_check(
		normal_bridge.ok
		and normal_bridge.bridge_built
		and normal_bridge.bridge_span_length == 3
		and normal_bridge.bridge_sections.size() == 3
		and normal_bridge.bridge_cost == 600
		and normal_bridge.cost == 800
		and bridge_city.funds() == 4200,
		"Normal highway bridge charges 200 dollars for each 2-by-2 section",
	)

	for x in range(80, 86):
		for y in range(20, 22):
			_check(
				bridge_city.building_id(x, y) == 0x4a
				and bridge_city.is_water(x, y)
				and (bridge_city.zones[x * 128 + y] & 0xf0) == 0xf0,
				"Normal highway bridge stores straight highway over water",
			)

	_check(
		bridge_city.building_id(86, 20) == 0,
		"Normal highway bridge does not construct a far-bank section",
	)
	_check(Highways.undo(bridge_city, normal_bridge).ok, "Normal highway bridge can be undone")
	_check(
		bridge_city.funds() == 5000 and bridge_city.building_id(80, 20) == 0,
		"Normal highway bridge undo restores funds and water sections",
	)

	var reinforced_bridge := Highways.apply(
		bridge_city,
		6,
		1,
		Vector2i(76, 20),
		Vector2i(84, 20),
		Highways.CONNECTION_UNSELECTED,
		Highways.BRIDGE_REINFORCED
	)
	_check(
		reinforced_bridge.ok
		and reinforced_bridge.bridge_built
		and reinforced_bridge.bridge_cost == 900
		and reinforced_bridge.cost == 1100
		and reinforced_bridge.bridge_endpoint_sections
		== [Vector2i(78, 20), Vector2i(86, 20)]
		and bridge_city.funds() == 3900,
		"Reinforced highway bridge charges 300 dollars per section and writes both banks",
	)
	_check(
		[
			bridge_city.building_id(80, 20),
			bridge_city.building_id(82, 20),
			bridge_city.building_id(84, 20),
		] == [0x6b, 0x6a, 0x6b]
		and bridge_city.building_id(78, 20) == 0x4a
		and bridge_city.building_id(86, 20) == 0x4a,
		"Reinforced highway bridge alternates deck and pylon sections",
	)

	for x in range(80, 86):
		for y in range(20, 22):
			_check(
				bridge_city.is_water(x, y)
				and (bridge_city.tile_flags[x * 128 + y] & 0x02) != 0,
				"Horizontal reinforced bridge stores its recovered mirror bit",
			)

	_check(
		Highways.undo(bridge_city, reinforced_bridge).ok
		and bridge_city.funds() == 5000
		and bridge_city.building_id(86, 20) == 0,
		"Reinforced highway bridge undo restores the far bank and funds",
	)

	_check(bridge_city.set_funds(1000), "Highway bridge funds fixture limits funds")
	var unaffordable_bridge := Highways.apply(
		bridge_city,
		6,
		1,
		Vector2i(76, 20),
		Vector2i(84, 20),
		Highways.CONNECTION_UNSELECTED,
		Highways.BRIDGE_REINFORCED
	)
	_check(
		unaffordable_bridge.ok
		and not unaffordable_bridge.bridge_built
		and not unaffordable_bridge.bridge_error.is_empty()
		and unaffordable_bridge.cost == 200
		and bridge_city.funds() == 800
		and bridge_city.building_id(78, 20) == 0x4a
		and bridge_city.building_id(80, 20) == 0,
		"Unaffordable reinforced bridge keeps the charged dry prefix",
	)
	_check(Highways.undo(bridge_city, unaffordable_bridge).ok, "Unaffordable bridge prefix can be undone")
	_check(bridge_city.set_funds(5000), "Highway bridge fixture restores funds")

	for entry in [
		[Vector2i(80, 20), 0, false],
		[Vector2i(81, 20), 0x10, true],
		[Vector2i(81, 21), 0, false],
		[Vector2i(80, 21), 0x10, true],
	]:
		_check(
			bridge_city.set_terrain_id(entry[0].x, entry[0].y, entry[1])
			and bridge_city.set_tile_flag(entry[0].x, entry[0].y, 0x04, entry[2]),
			"Direct highway bridge fixture writes its shoreline mask",
		)

	var direct_plan := HighwayBridges.plan_bridge_from_start(
		bridge_document.find_chunk("XBLD").decoded_payload,
		bridge_document.find_chunk("XTER").decoded_payload,
		bridge_document.find_chunk("ALTM").decoded_payload,
		Vector2i(80, 20),
		0
	)
	_check(
		HighwayBridges.bridge_terrain_code(
			bridge_document.find_chunk("XTER").decoded_payload, Vector2i(80, 20)
		) == 0x9060
		and direct_plan.ok
		and direct_plan.direction == 1
		and direct_plan.span_length == 3,
		"Direct highway bridge uses the recovered 2-by-2 shoreline direction table",
	)

	var connection_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			connection_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(size, 0)
			),
			"Highway connection fixture clears %s" % chunk_id,
		)

	_check(connection_document.set_misc_i32(0x14, 5000), "Highway connection fixture sets funds")
	_check(connection_document.set_misc_u32(0x01f0, 16384), "Highway connection fixture counts clear tiles")
	var connection_city := CityModel.from_document(connection_document)
	var connection_request := Highways.apply(
		connection_city, 6, 1, Vector2i(120, 10), Vector2i(126, 10)
	)
	_check(
		not connection_request.ok
		and connection_request.connection_selection_required
		and connection_request.connection_anchor == Vector2i(126, 10)
		and connection_request.connection_cost == 1500
		and connection_request.route_cost == 400
		and connection_city.funds() == 5000
		and connection_city.building_id(120, 10) == 0,
		"Highway exit requests the recovered neighbor connection before changing the city",
	)
	var canceled_connection := Highways.apply(
		connection_city,
		6,
		1,
		Vector2i(120, 10),
		Vector2i(126, 10),
		Highways.CONNECTION_CANCELLED
	)
	_check(
		canceled_connection.ok
		and canceled_connection.connection_cancelled
		and not canceled_connection.connection_built
		and canceled_connection.cost == 400
		and connection_city.funds() == 4600
		and connection_city.text_overlay_id(126, 10) == 0,
		"Canceling a neighbor connection still builds and charges the highway route",
	)
	_check(
		Highways.undo(connection_city, canceled_connection).ok
		and connection_city.funds() == 5000,
		"Canceled highway connection route can be undone",
	)
	var confirmed_connection := Highways.apply(
		connection_city,
		6,
		1,
		Vector2i(120, 10),
		Vector2i(126, 10),
		Highways.CONNECTION_CONFIRMED
	)
	_check(
		confirmed_connection.ok
		and confirmed_connection.connection_built
		and confirmed_connection.cost == 1900
		and confirmed_connection.connection_cost == 1500
		and connection_city.funds() == 3100
		and connection_city.text_overlay_id(126, 10) == 0xfa
		and connection_city.building_id(126, 10) == 0x4a,
		"Confirmed highway connection stores XTXT 0xFA and charges the recovered cost",
	)
	_check(
		Highways.undo(connection_city, confirmed_connection).ok
		and connection_city.funds() == 5000
		and connection_city.text_overlay_id(126, 10) == 0,
		"Highway connection undo restores the route, label, and funds",
	)

	var grade_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			grade_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(size, 0)
			),
			"Graded highway fixture clears %s" % chunk_id,
		)

	_check(grade_document.set_misc_i32(0x14, 5000), "Graded highway fixture sets funds")
	_check(
		grade_document.set_misc_u32(0x01f0, 16384),
		"Graded highway fixture counts clear tiles",
	)
	var grade_city := CityModel.from_document(grade_document)
	var north_slope := [
		[Vector2i(20, 20), 1],
		[Vector2i(21, 20), 1],
		[Vector2i(21, 21), 0],
		[Vector2i(20, 21), 0],
	]

	for entry in north_slope:
		_check(
			grade_city.set_terrain_id(entry[0].x, entry[0].y, entry[1]),
			"Graded highway fixture writes the north slope",
		)

	var north_grade := Highways.apply(
		grade_city, 6, 1, Vector2i(20, 20), Vector2i(20, 20)
	)
	_check(
		north_grade.ok
		and north_grade.graded_sections == 1
		and north_grade.cost == 100
		and grade_city.funds() == 4900,
		"A north slope builds one graded highway section for one hundred dollars",
	)

	for point in [Vector2i(20, 20), Vector2i(21, 20), Vector2i(21, 21), Vector2i(20, 21)]:
		_check(
			grade_city.building_id(point.x, point.y) == 0x62,
			"The north grade stores composite tile 0x62",
		)

	_check(
		[
			grade_city.terrain_id(20, 20),
			grade_city.terrain_id(21, 20),
			grade_city.terrain_id(21, 21),
			grade_city.terrain_id(20, 21),
		] == [0x0d, 0x0d, 0x02, 0x02],
		"The north grade writes the recovered terrain pattern",
	)
	_check(
		Highways.undo(grade_city, north_grade).ok
		and grade_city.funds() == 5000
		and grade_city.terrain_id(20, 20) == 1
		and grade_city.building_id(20, 20) == 0,
		"Graded highway undo restores terrain, tiles, and funds",
	)

	var east_slope := [
		[Vector2i(30, 30), 0],
		[Vector2i(31, 30), 1],
		[Vector2i(31, 31), 1],
		[Vector2i(30, 31), 0],
	]

	for entry in east_slope:
		_check(
			grade_city.set_terrain_id(entry[0].x, entry[0].y, entry[1]),
			"Graded highway fixture writes the east slope",
		)

	var east_grade := Highways.apply(
		grade_city, 6, 1, Vector2i(30, 30), Vector2i(30, 30)
	)
	_check(
		east_grade.ok
		and east_grade.graded_sections == 1
		and grade_city.building_id(30, 30) == 0x63,
		"An east slope builds composite highway tile 0x63",
	)
	_check(
		[
			grade_city.terrain_id(30, 30),
			grade_city.terrain_id(31, 30),
			grade_city.terrain_id(31, 31),
			grade_city.terrain_id(30, 31),
		] == [0x03, 0x0d, 0x0d, 0x03],
		"The east grade writes the recovered terrain pattern",
	)
	_check(Highways.undo(grade_city, east_grade).ok, "The east grade can be undone")

	var high_neighbor_points := [
		Vector2i(58, 60),
		Vector2i(59, 60),
		Vector2i(59, 61),
		Vector2i(58, 61),
	]

	for point in high_neighbor_points:
		_check(
			grade_city.set_building_id(point.x, point.y, Tiles.HIGHWAY_STRAIGHT_2)
			and grade_city.set_building_corners(point.x, point.y, 0xf0)
			and grade_city.set_land_altitude(point.x, point.y, 2),
			"Highway retile fixture installs a higher west section",
		)

	_check(
		grade_document.set_misc_u32(0x01f0, CityState.TILE_COUNT - 4)
		and grade_document.set_misc_u32(0x01f0 + 0x4a * 4, 4),
		"Highway retile fixture updates its tile counts",
	)
	var compound_slope := [
		[Vector2i(60, 60), 1],
		[Vector2i(61, 60), 0],
		[Vector2i(61, 61), 0],
		[Vector2i(60, 61), 0],
	]

	for entry in compound_slope:
		_check(
			grade_city.set_terrain_id(entry[0].x, entry[0].y, entry[1]),
			"Highway retile fixture writes a two-direction terrain mask",
		)

	var neighbor_grade := Highways.apply(
		grade_city, 6, 1, Vector2i(60, 60), Vector2i(60, 60)
	)
	_check(
		neighbor_grade.ok
		and neighbor_grade.graded_sections == 1
		and grade_city.building_id(60, 60) == 0x61
		and grade_city.building_id(58, 60) == 0x61,
		"A height transition converts both joined sections to grade kind 4",
	)
	_check(
		[
			grade_city.terrain_id(60, 60),
			grade_city.terrain_id(61, 60),
			grade_city.terrain_id(61, 61),
			grade_city.terrain_id(60, 61),
		] == [0x0d, 0x01, 0x01, 0x0d],
		"Elevation-aware highway retile writes the selected kind 4 terrain",
	)
	_check(
		Highways.undo(grade_city, neighbor_grade).ok
		and grade_city.building_id(60, 60) == 0
		and grade_city.building_id(58, 60) == 0x4a,
		"Elevation-aware grade undo preserves the pre-existing neighbor",
	)

	_check(
		grade_city.set_building_id(40, 40, Tiles.CITY_HALL),
		"Invalid highway grade fixture places a building",
	)
	_check(
		HighwayGeometry.terrain_section_shape(
			grade_document.find_chunk("XBLD").decoded_payload,
			grade_document.find_chunk("XTER").decoded_payload,
			grade_document.find_chunk("ALTM").decoded_payload,
			Vector2i(40, 40)
		) == Highways.INVALID_TERRAIN_SHAPE,
		"Highway terrain validation rejects an occupied section",
	)
	_check(
		grade_city.set_building_id(40, 40, Tiles.EMPTY),
		"Invalid highway grade fixture removes its building",
	)

	for x in range(52, 54):
		for y in range(50, 52):
			_check(
				grade_city.set_land_altitude(x, y, 2),
				"Highway elevation fixture raises the next section two levels",
			)

	var steep_route := Highways.apply(
		grade_city, 6, 1, Vector2i(50, 50), Vector2i(52, 50)
	)
	_check(
		steep_route.ok
		and steep_route.stopped_early
		and steep_route.sections == [Vector2i(50, 50)]
		and steep_route.cost == 100,
		"A highway route stops before a section more than one level away",
	)
	_check(Highways.undo(grade_city, steep_route).ok, "The stopped elevation route can be undone")

	for x in range(52, 54):
		for y in range(50, 52):
			_check(
				grade_city.set_land_altitude(x, y, 1),
				"Highway elevation fixture lowers the next section to one level",
			)

	var stepped_route := Highways.apply(
		grade_city, 6, 1, Vector2i(50, 50), Vector2i(52, 50)
	)
	_check(
		stepped_route.ok
		and not stepped_route.stopped_early
		and stepped_route.sections.size() == 2
		and stepped_route.cost == 200,
		"A highway route accepts a section one level away",
	)
	_check(Highways.undo(grade_city, stepped_route).ok, "The one-level route can be undone")


func _test_demolish_command(reference_root: String) -> void:
	_check(Demolish.supports_tool(0, 0), "Demolish command supports its catalog tool")
	_check(not Demolish.supports_tool(0, 4), "Demolish command rejects De-zone")
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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
	var placement_random := LfsrRandom.new(11)
	var process_random := Random.new(17)
	var hospital := Buildings.apply(city, 13, 2, Vector2i(20, 20), placement_random, process_random)
	_check(hospital.ok and hospital.overlay_id == 61, "Demolish fixture places a dynamic hospital")
	var demolition_random := Random.new(29)
	var building := Demolish.apply_path(city, 0, 0, [Vector2i(20, 20)], demolition_random)
	_check(building.ok and building.action_count == 1 and building.tile_indices.size() == 9, "Demolish removes a complete 3-by-3 building")
	_check(
		building.effect_events.size() == 27
		and building.sound_events == [504]
		and building.effect_events[0].point == Vector2i(19, 21)
		and building.effect_events[0].frame == 0
		and building.effect_events[9].frame == 1
		and building.effect_events[9].screen_offset == Vector2i(0, -8)
		and building.effect_events[26].point == Vector2i(21, 19)
		and building.effect_events[26].frame == 2
		and building.effect_events[26].screen_offset == Vector2i(0, -16),
		"Building demolition emits one native dust frame per footprint level",
	)
	var expected_demolition_random := Random.new(29)

	for _value in 63:
		expected_demolition_random.next_u15()

	_check(
		demolition_random.state == expected_demolition_random.state,
		"Building demolition consumes visual values before its nine rubble values",
	)

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

	_check(document.set_misc_u32(ToolAvailability.MISC_GRANTED_REWARDS, 0x02), "Reward demolition fixture grants City Hall")
	var city_hall := Buildings.apply(
		city, 5, 1, Vector2i(30, 30), placement_random, process_random
	)
	_check(
		city_hall.ok
		and document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0,
		"Reward placement consumes the City Hall grant",
	)
	var removed_city_hall := Demolish.apply_path(
		city, 0, 0, [Vector2i(30, 30)], demolition_random
	)
	_check(
		removed_city_hall.ok
		and document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0x02,
		"Demolishing City Hall restores its saved reward bit",
	)
	_check(
		Demolish.undo(city, removed_city_hall, demolition_random).ok
		and document.misc_u32(ToolAvailability.MISC_GRANTED_REWARDS) == 0,
		"Reward demolition undo restores the consumed reward state",
	)
	_check(Buildings.undo(city, city_hall, placement_random, process_random).ok, "Reward demolition fixture removes City Hall")

	var simple_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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
	_check(simple_city.set_building_id(10, 10, Tiles.RUBBLE_3), "Simple demolish fixture places rubble")
	var rubble := Demolish.apply_path(simple_city, 0, 0, [Vector2i(10, 10)], demolition_random)
	_check(rubble.ok and simple_city.building_id(10, 10) == 0, "Demolish clears rubble")
	_check(rubble.cost == 1 and simple_city.funds() == 9, "Rubble demolition charges one dollar")
	_check(Demolish.undo(simple_city, rubble, demolition_random).ok, "Rubble demolition can be undone")
	_check(simple_city.set_building_id(12, 10, Tiles.ROAD_STRAIGHT_1), "Parallel demolish fixture places its first road")
	_check(simple_city.set_building_id(13, 10, Tiles.ROAD_STRAIGHT_1), "Parallel demolish fixture places its second road")
	_check(
		simple_document.set_misc_u32(0x01f0 + 0x1d * 4, 2),
		"Parallel demolish fixture counts both road tiles",
	)
	var parallel_demolition := Demolish.apply_path(
		simple_city,
		0,
		0,
		[Vector2i(12, 10), Vector2i(13, 10)],
		demolition_random,
	)
	var parallel_effects := true
	var first_effect_frames := PackedInt32Array()

	for effect in parallel_demolition.effect_events:
		var frame := int(effect.frame)
		parallel_effects = (
			parallel_effects
			and frame >= 0
			and frame <= Demolish.MAX_PARALLEL_EFFECT_OFFSET_FRAMES
		)
		first_effect_frames.append(frame)

	_check(
		parallel_demolition.ok
		and parallel_demolition.action_count == 2
		and parallel_demolition.sound_events == [Demolish.SOUND_EXPLODE]
		and parallel_effects
		and first_effect_frames.has(0)
		and (first_effect_frames.has(1) or first_effect_frames.has(2)),
		"A bulldozer rectangle starts all tile effects with small parallel offsets",
	)
	_check(
		Demolish.undo(simple_city, parallel_demolition, demolition_random).ok
		and simple_city.building_id(12, 10) == 0x1d
		and simple_city.building_id(13, 10) == 0x1d,
		"One Undo restores the complete parallel bulldozer rectangle",
	)
	_check(simple_city.set_building_id(12, 10, Tiles.EMPTY), "Parallel demolish fixture clears its first road")
	_check(simple_city.set_building_id(13, 10, Tiles.EMPTY), "Parallel demolish fixture clears its second road")
	_check(
		simple_document.set_misc_u32(0x01f0 + 0x1d * 4, 0),
		"Parallel demolish fixture clears its road count",
	)

	for story_slot in NewsQueue.QUEUE_COUNT:
		for story_field in NewsQueue.STORY_FIELD_COUNT:
			_check(
				simple_document.set_misc_u32(
					NewsQueue.STORY_OFFSET
					+ story_slot * NewsQueue.STORY_RECORD_SIZE
					+ story_field * 4,
					0,
				),
				"Forest protest fixture clears a newspaper story field",
			)

	_check(simple_city.set_building_id(10, 10, Tiles.TREES_1), "Forest protest fixture places a tree")
	var forest_random := Random.new(19)
	var forest_protest := Demolish.apply_path(
		simple_city, 0, 0, [Vector2i(10, 10)], forest_random
	)
	var protest_story := NewsQueue.story_record(
		simple_document.find_chunk("MISC").decoded_payload, 0
	)
	_check(
		forest_protest.ok
		and forest_protest.easter_events == 1
		and forest_protest.sound_events == [Demolish.SOUND_FOREST_PROTEST]
		and forest_protest.news_queue_updated
		and NewsEvent.same_arrays(forest_protest.news_items, [NewsEvent.new(0x28, 0)]),
		"The hidden tree branch reports its protest sound and newspaper story",
	)
	var copied_protest := forest_protest.copy() as DemolishEditResult
	_check(NewsEvent.same_arrays(copied_protest.news_items, forest_protest.news_items),
		"Copied demolition results retain every news field")
	copied_protest.news_items[0].argument = 7
	_check(forest_protest.news_items[0].argument == 0,
		"Copied demolition news owns independent event values")
	_check(
		simple_city.building_id(10, 10) == 0x06
		and simple_city.funds() == 9
		and protest_story.type == 0x28
		and protest_story.priority == NewsQueue.STORY_PRIORITIES[0x28],
		"The forest protest charges one dollar, keeps the tree, and updates MISC",
	)
	_check(
		Demolish.undo(simple_city, forest_protest, forest_random).ok
		and simple_city.building_id(10, 10) == 0x06
		and simple_city.funds() == 10
		and NewsQueue.story_record(
			simple_document.find_chunk("MISC").decoded_payload, 0
		).type == 0
		and forest_random.state == 19,
		"Forest protest undo restores funds, news, and process random state",
	)
	_check(simple_city.set_zone_id(10, 10, 7), "Protected demolish fixture sets military zone")
	var military := Demolish.apply_path(simple_city, 0, 0, [Vector2i(10, 10)], demolition_random)
	_check(not military.ok and not military.error.is_empty(), "Demolish rejects military zones")
	_check(simple_city.set_zone_id(10, 10, 0), "Highway demolish fixture clears military zone")
	_check(simple_city.set_building_id(10, 10, Tiles.HIGHWAY_STRAIGHT_1), "Highway demolish fixture places highway")
	var highway := Demolish.apply_path(simple_city, 0, 0, [Vector2i(10, 10)], demolition_random)
	_check(not highway.ok and not highway.error.is_empty(), "Demolish rejects a malformed highway section")
	_check(simple_city.set_building_id(10, 10, Tiles.EMPTY), "Highway demolition fixture removes its malformed tile")
	_check(simple_document.set_misc_i32(0x14, 500), "Highway demolition fixture sets funds")
	var placed_highway := Highways.apply(simple_city, 6, 1, Vector2i(10, 10), Vector2i(10, 10))
	_check(placed_highway.ok, "Highway demolition fixture builds one complete section")
	var removed_highway := Demolish.apply_path(simple_city, 0, 0, [Vector2i(11, 11)], demolition_random)
	_check(
		removed_highway.ok
		and removed_highway.tile_indices.size() == 4
		and removed_highway.effect_events.size() == 8
		and removed_highway.effect_events[0].frame == 0
		and removed_highway.effect_events[4].frame == 1,
		"Demolish removes a complete 2-by-2 highway section with two dust frames",
	)

	for x in range(10, 12):
		for y in range(10, 12):
			_check(simple_city.building_id(x, y) >= 1 and simple_city.building_id(x, y) <= 4, "Demolished highway becomes rubble")

	_check(Demolish.undo(simple_city, removed_highway, demolition_random).ok, "Highway demolition can be undone")
	_check(Highways.undo(simple_city, placed_highway).ok, "Highway fixture can be removed after demolition undo")

	var underground_document := _load_fixture(
		reference_root.path_join("DEFAULT.SC2")
	)

	for chunk_id in ["ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTXT"]:
		var size := 128 * 128 * 2 if chunk_id == "ALTM" else 128 * 128
		_check(
			underground_document.find_chunk(chunk_id).set_decoded_payload(
				_filled_bytes(size, 0)
			),
			"Underground demolition fixture clears %s" % chunk_id,
		)

	_check(
		underground_document.find_chunk("XLAB").set_decoded_payload(
			_filled_bytes(6400, 0)
		),
		"Underground demolition fixture clears XLAB",
	)
	_check(
		underground_document.find_chunk("XMIC").set_decoded_payload(
			_filled_bytes(1200, 0)
		),
		"Underground demolition fixture clears XMIC",
	)
	_check(
		underground_document.set_misc_i32(0x14, 5000),
		"Underground demolition fixture sets funds",
	)
	_check(
		underground_document.set_misc_u32(0x01f0, 16384),
		"Underground demolition fixture counts clear tiles",
	)
	_check(
		underground_document.set_misc_u32(0x0fe8, 3),
		"Underground demolition fixture counts three subway tiles",
	)
	_check(
		underground_document.set_misc_u32(
			ToolAvailability.MISC_INVENTION_YEARS + 9 * 4,
			0,
		),
		"Underground demolition fixture unlocks subway stations",
	)
	var underground_city := CityModel.from_document(underground_document)

	for y in range(19, 22):
		_check(
			underground_city.set_underground_id(20, y, UnderTiles.SUBWAY_LR),
			"Underground demolition fixture places subway",
		)

	var underground_random := Random.new(101)
	var removed_subway := Demolish.apply_path(
		underground_city,
		0,
		0,
		[Vector2i(20, 20)],
		underground_random,
		true
	)
	_check(
		removed_subway.ok
		and removed_subway.underground_view
		and removed_subway.action_count == 1
		and removed_subway.cost == 1
		and underground_city.underground_id(20, 20) == 0
		and underground_document.misc_u32(0x0fe8) == 2,
		"Underground Demolish removes one subway tile and updates its count",
	)
	_check(
		underground_city.underground_id(20, 19) == 0x01
		and underground_city.underground_id(20, 21) == 0x01,
		"Underground Demolish reconnects the remaining subway ends",
	)
	_check(
		Demolish.undo(underground_city, removed_subway, underground_random).ok
		and underground_city.underground_id(20, 20) == 0x01
		and underground_document.misc_u32(0x0fe8) == 3,
		"Underground subway demolition can be undone with its saved count",
	)

	for y in range(29, 32):
		_check(
			underground_city.set_underground_id(30, y, UnderTiles.PIPE_LR),
			"Underground demolition fixture places pipe",
		)
		_check(
			underground_city.set_tile_flag(30, y, 0x20, true),
			"Underground demolition fixture marks pipe",
		)

	var removed_pipe := Demolish.apply_path(
		underground_city,
		0,
		0,
		[Vector2i(30, 30)],
		underground_random,
		true
	)
	_check(
		removed_pipe.ok
		and underground_city.underground_id(30, 30) == 0
		and not underground_city.is_piped(30, 30)
		and underground_document.misc_u32(0x0fe8) == 3,
		"Underground Demolish clears a pipe and its saved piped bit",
	)
	_check(
		underground_city.underground_id(30, 29) == 0x1e
		and underground_city.underground_id(30, 31) == 0x1e,
		"Underground Demolish reconnects the remaining pipe ends",
	)
	_check(
		Demolish.undo(underground_city, removed_pipe, underground_random).ok
		and underground_city.underground_id(30, 30) == 0x10
		and underground_city.is_piped(30, 30),
		"Underground pipe demolition can be undone",
	)
	var station_random := LfsrRandom.new(111)
	var station_process_random := Random.new(113)
	var placed_station := Buildings.apply(
		underground_city,
		7,
		3,
		Vector2i(40, 40),
		station_random,
		station_process_random
	)
	_check(
		placed_station.ok
		and underground_city.underground_id(40, 40) == 0x23
		and underground_document.misc_u32(0x0fe8) == 4,
		"Underground demolition fixture places and counts a subway station",
	)
	var removed_station := Demolish.apply_path(
		underground_city,
		0,
		0,
		[Vector2i(40, 40)],
		underground_random,
		true
	)
	_check(
		removed_station.ok
		and underground_city.underground_id(40, 40) == 0
		and underground_city.building_id(40, 40) >= 1
		and underground_city.building_id(40, 40) <= 4
		and underground_document.misc_u32(0x0fe8) == 3,
		"Underground Demolish removes a subway entrance and its surface station",
	)
	_check(
		Demolish.undo(underground_city, removed_station, underground_random).ok
		and underground_city.underground_id(40, 40) == 0x23
		and underground_city.building_id(40, 40) == 0xe9,
		"Underground subway-station demolition can be undone",
	)
	_check(
		Buildings.undo(
			underground_city,
			placed_station,
			station_random,
			station_process_random
		).ok,
		"Underground demolition fixture removes the restored station",
	)

	var special_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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
	_check(special_city.set_building_id(30, 30, Tiles.TUNNEL_ENTRANCE_1), "Tunnel demolition fixture places its first entrance")
	_check(special_city.set_building_id(28, 30, Tiles.TUNNEL_ENTRANCE_3), "Tunnel demolition fixture places its second entrance")

	for x in range(28, 31):
		_check(special_city.set_tunnel_levels(x, 30, 3), "Tunnel demolition fixture stores tunnel depth")

	var tunnel := Demolish.apply_path(special_city, 0, 0, [Vector2i(30, 30)], demolition_random)
	_check(
		tunnel.ok
		and tunnel.tile_indices.size() == 3
		and tunnel.effect_events.size() == 2
		and tunnel.effect_events[0].point == Vector2i(30, 30)
		and tunnel.effect_events[1].point == Vector2i(28, 30),
		"Demolish follows a tunnel and emits dust at both entrances",
	)
	_check(special_city.building_id(30, 30) == 0 and special_city.building_id(28, 30) == 0, "Tunnel demolition clears both entrances")

	for x in range(28, 31):
		_check(special_city.tunnel_levels(x, 30) == 0, "Tunnel demolition clears each saved depth")

	_check(Demolish.undo(special_city, tunnel, demolition_random).ok, "Tunnel demolition can be undone")

	for point in [Vector2i(40, 40), Vector2i(41, 40), Vector2i(41, 41)]:
		_check(special_city.set_building_id(point.x, point.y, Tiles.RUNWAY), "Runway demolition fixture places a connected tile")

	_check(special_city.set_building_id(45, 45, Tiles.RUNWAY), "Runway demolition fixture places a separate tile")
	var runway := Demolish.apply_path(special_city, 0, 0, [Vector2i(40, 40)], demolition_random)
	_check(
		runway.ok and runway.tile_indices.size() == 3 and runway.effect_events.size() == 3,
		"Demolish removes one connected runway component with dust on each tile",
	)
	_check(special_city.building_id(45, 45) == 0xdd, "Runway demolition preserves a separate component")

	for point in [Vector2i(40, 40), Vector2i(41, 40), Vector2i(41, 41)]:
		_check(special_city.building_id(point.x, point.y) >= 1 and special_city.building_id(point.x, point.y) <= 4, "Demolished runway becomes rubble")

	_check(Demolish.undo(special_city, runway, demolition_random).ok, "Runway demolition can be undone")

	for point in [Vector2i(50, 50), Vector2i(50, 51)]:
		_check(special_city.set_building_id(point.x, point.y, Tiles.PIER), "Pier demolition fixture places a connected tile")

	var pier := Demolish.apply_path(special_city, 0, 0, [Vector2i(50, 50)], demolition_random)
	_check(
		pier.ok
		and special_city.building_id(50, 50) == 0
		and special_city.building_id(50, 51) == 0
		and pier.effect_events.size() == 2,
		"Demolish clears a connected pier component with dust on each tile",
	)
	_check(Demolish.undo(special_city, pier, demolition_random).ok, "Pier demolition can be undone")

	_check(special_document.set_misc_u32(0x0e40, 1), "Bridge demolition fixture sets sea level")

	for x in range(70, 73):
		_check(special_city.set_building_id(x, 70, Tiles.SUSPENSION_BRIDGE_1 + x - 70), "Bridge demolition fixture places a span tile")
		_check(special_city.set_terrain_id(x, 70, 0x30), "Bridge demolition fixture places water terrain")
		_check(special_city.set_tile_flag(x, 70, 0x04, true), "Bridge demolition fixture marks span water")
		_check(special_city.set_tile_flag(x, 70, 0x02, true), "Bridge demolition fixture sets a horizontal span")

	for x in [69, 73]:
		_check(special_city.set_land_altitude(x, 70, 1), "Bridge demolition fixture raises a bank")
		_check(special_city.set_building_id(x, 70, Tiles.ROAD_STRAIGHT_1), "Bridge demolition fixture places a bank road")

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
		_check(special_city.set_building_id(bank_point.x, bank_point.y, Tiles.HIGHWAY_STRAIGHT_1), "Reinforced demolition fixture places a bank")
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

	var deep_water_point := Vector2i(61, 60)
	_check(
		special_city.set_terrain_id(deep_water_point.x, deep_water_point.y, 0x10)
		and special_city.set_tile_flag(
			deep_water_point.x, deep_water_point.y, 0x04, true
		),
		"Deep-water demolition fixture sets submerged terrain",
	)
	var deep_water_funds := special_city.funds()
	var deep_water_random_state := demolition_random.state
	var deep_water := Demolish.apply_path(
		special_city, 0, 0, [deep_water_point], demolition_random
	)
	_check(
		not deep_water.ok
		and not deep_water.error.is_empty()
		and special_city.terrain_id(deep_water_point.x, deep_water_point.y) == 0x10
		and special_city.is_water(deep_water_point.x, deep_water_point.y)
		and special_city.funds() == deep_water_funds
		and demolition_random.state == deep_water_random_state,
		"Demolish protects deep water without charging funds or changing random state",
	)


func _test_terrain_command(reference_root: String) -> void:
	_check(TerrainTools.supports_tool(0, 1), "Terrain command supports Level Terrain")
	_check(TerrainTools.supports_tool(0, 2), "Terrain command supports Raise Terrain")
	_check(TerrainTools.supports_tool(0, 3), "Terrain command supports Lower Terrain")
	_check(not TerrainTools.supports_tool(0, 0), "Terrain command rejects Demolish")
	var executable_shapes := _load_pe_rva_bytes(
		reference_root.path_join("SIMCITY.EXE"), 0x000e7958, TerrainTools.TERRAIN_SHAPES.size()
	)
	var shape_table_matches := executable_shapes.size() == TerrainTools.TERRAIN_SHAPES.size()

	if shape_table_matches:
		for shape_index in executable_shapes.size():
			if executable_shapes[shape_index] != TerrainTools.TERRAIN_SHAPES[shape_index]:
				shape_table_matches = false
				break

	_check(
		shape_table_matches,
		"Terrain shape table matches the reachable supplied executable bytes",
	)
	var ordered_heights := PackedInt32Array()
	ordered_heights.resize(CityState.TILE_COUNT)
	var ordered_zones := _filled_bytes(CityState.TILE_COUNT, 0)
	var ordered_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)
	var ordered_start := Vector2i(20, 20)
	var ordered_west := Vector2i(19, 20)
	var ordered_north := Vector2i(20, 19)
	ordered_heights[ordered_start.x * CityState.MAP_SIZE + ordered_start.y] = 1
	var ordered_raise := TerrainEditHeights.plan_raise(
		ordered_heights, ordered_zones, ordered_buildings, ordered_start, 25
	)
	_check(
		ordered_raise.valid
		and ordered_raise.heights[ordered_west.x * CityState.MAP_SIZE + ordered_west.y] == 1
		and ordered_raise.heights[ordered_north.x * CityState.MAP_SIZE + ordered_north.y] == 0
		and ordered_raise.heights[ordered_start.x * CityState.MAP_SIZE + ordered_start.y] == 1,
		"Partial Raise Terrain funds apply in executable west-north-east-south order",
	)
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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
	_check(city.set_building_id(40, 40, Tiles.ROAD_STRAIGHT_1), "Terrain conflict fixture places a road")
	_check(city.set_underground_id(40, 40, UnderTiles.SUBWAY_LR), "Terrain conflict fixture places a subway")
	_check(document.set_misc_u32(0x01f0, 16383), "Terrain conflict fixture reduces the clear count")
	_check(document.set_misc_u32(0x01f0 + 0x1d * 4, 1), "Terrain conflict fixture counts its road")
	_check(document.set_misc_u32(0x0fe8, 1), "Terrain conflict fixture counts its subway")
	var conflict_without_random := TerrainTools.apply_path(
		city, 0, 2, Vector2i(40, 40), [Vector2i(40, 40)]
	)
	_check(
		not conflict_without_random.ok and not conflict_without_random.error.is_empty(),
		"Terrain conflict demolition requires explicit process random state",
	)
	_check(
		city.building_id(40, 40) == 0x1d and city.underground_id(40, 40) == 0x01,
		"A rejected terrain conflict does not change either network",
	)
	var terrain_random := Random.new(0x1234)
	var terrain_seed := terrain_random.state
	var conflict := TerrainTools.apply_path(
		city, 0, 2, Vector2i(40, 40), [Vector2i(40, 40)], terrain_random
	)
	_check(conflict.ok and city.land_altitude(40, 40) == 1, "Raise Terrain changes a network tile")
	_check(
		city.building_id(40, 40) == 0 and city.underground_id(40, 40) == 0,
		"Terrain retile removes surface and underground networks",
	)
	_check(
		document.misc_u32(0x01f0) == 16384
		and document.misc_u32(0x01f0 + 0x1d * 4) == 0
		and document.misc_u32(0x0fe8) == 0,
		"Terrain conflict demolition updates surface and subway counts",
	)
	_check(
		conflict.random_used and terrain_random.state != terrain_seed
		and not conflict.effect_events.is_empty() and conflict.sound_events == [504],
		"Terrain conflict demolition keeps its dust, sound, and random use",
	)
	_check(TerrainTools.undo(city, conflict, terrain_random).ok, "Network terrain demolition can be undone")
	_check(
		city.building_id(40, 40) == 0x1d and city.underground_id(40, 40) == 0x01
		and city.land_altitude(40, 40) == 0 and terrain_random.state == terrain_seed,
		"Terrain undo restores both networks, altitude, and random state",
	)

	_check(city.set_building_id(40, 40, Tiles.RADIOACTIVE_WASTE), "Terrain radioactivity fixture replaces the road")
	_check(city.set_underground_id(40, 40, UnderTiles.EMPTY), "Terrain radioactivity fixture removes its subway")
	var radioactivity_raise := TerrainTools.apply_path(
		city, 0, 2, Vector2i(40, 40), [Vector2i(40, 40)]
	)
	_check(
		radioactivity_raise.ok
		and city.building_id(40, 40) == 5
		and not radioactivity_raise.random_used,
		"Terrain retile preserves XBLD 0x05 radioactivity without random use",
	)
	_check(
		TerrainTools.undo(city, radioactivity_raise).ok,
		"Radioactivity terrain change can be undone",
	)

	for x in range(60, 62):
		for y in range(60, 62):
			_check(city.set_building_id(x, y, Tiles.CHEAP_APARTMENTS_2X2), "Terrain structure fixture fills its site")

	_check(city.set_building_corners(60, 60, 0x10), "Terrain structure fixture sets bottom-left")
	_check(city.set_building_corners(61, 60, 0x20), "Terrain structure fixture sets bottom-right")
	_check(city.set_building_corners(61, 61, 0x40), "Terrain structure fixture sets top-left")
	_check(city.set_building_corners(60, 61, 0x80), "Terrain structure fixture sets top-right")
	_check(city.set_text_overlay_id(60, 60, 61), "Terrain structure fixture assigns a microsim label")
	var structure_random := Random.new(0x5678)
	var structure_raise := TerrainTools.apply_path(
		city, 0, 2, Vector2i(60, 60), [Vector2i(60, 60)], structure_random
	)
	_check(structure_raise.ok, "Raise Terrain demolishes a complete multi-tile structure")
	_check(
		city.building_id(60, 60) == 0 and city.building_id(61, 60) == 0
		and city.building_id(60, 61) == 0 and city.building_id(61, 61) == 0,
		"Terrain demolition clears the complete two-by-two footprint",
	)
	_check(
		city.text_overlay_id(60, 60) == 0 and structure_raise.changed_ids.has("XTXT"),
		"Terrain demolition releases the structure overlay",
	)
	_check(
		TerrainTools.undo(city, structure_raise, structure_random).ok,
		"Multi-tile terrain demolition can be undone",
	)
	_check(
		city.building_id(60, 60) == 0x8c and city.building_id(61, 61) == 0x8c
		and city.text_overlay_id(60, 60) == 61,
		"Terrain undo restores the complete structure and overlay",
	)

	var basin_altitude := _filled_bytes(CityState.TILE_COUNT * 2, 0)
	var basin_buildings := _filled_bytes(CityState.TILE_COUNT, Tiles.EMPTY)
	var basin_terrain := _filled_bytes(CityState.TILE_COUNT, 0)
	var basin_zones := _filled_bytes(CityState.TILE_COUNT, 0)
	var basin_flags := _filled_bytes(CityState.TILE_COUNT, 0)
	var basin_misc := document.find_chunk("MISC").decoded_payload.duplicate()
	var basin_point := Vector2i(70, 70)
	var basin_index := basin_point.x * CityState.MAP_SIZE + basin_point.y
	basin_zones[basin_index] = 6

	for offset in TerrainTools.CARDINAL_OFFSETS:
		var neighbor: Vector2i = basin_point + offset
		TerrainEditHeights.set_land_altitude(
			basin_altitude,
			neighbor.x * CityState.MAP_SIZE + neighbor.y,
			1,
		)

	TerrainRetile.retile_region(
		basin_altitude,
		basin_buildings,
		basin_terrain,
		basin_zones,
		basin_flags,
		basin_misc,
		PackedInt32Array([basin_index]),
		2,
	)
	_check(
		TerrainEditHeights.land_altitude(basin_altitude, basin_index) == 1,
		"Terrain sentinel 0x32 raises a surrounded basin by one level",
	)
	_check(
		basin_terrain[basin_index] == 0x10
		and (basin_flags[basin_index] & TerrainTools.FLAG_WATER) != 0,
		"A raised basin below sea level uses the executable's deep-water terrain",
	)
	_check(
		basin_zones[basin_index] == 0,
		"The raised-basin terrain shape clears the zone nibble",
	)


func _test_dispatch_command(reference_root: String) -> void:
	_check(Dispatch.supports_tool(2, 0), "Dispatch command supports Police")
	_check(Dispatch.supports_tool(2, 1), "Dispatch command supports Fire")
	_check(Dispatch.supports_tool(2, 2), "Dispatch command supports Military")
	_check(not Dispatch.supports_tool(3, 0), "Dispatch command rejects another tool group")
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))

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
	_check(IsometricStaticVisuals.dispatch_sprite_id(city, 10, 10) == 1382, "Police dispatch selects the recovered large sprite")
	_check(
		IsometricStaticVisuals.dispatch_sprite_id(
			city, 10, 10, IsometricRenderer.VIEW_MEDIUM
		) == 882,
		"Police dispatch selects the native medium sprite",
	)
	_check(
		IsometricStaticVisuals.dispatch_sprite_id(
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
	_check(not water.ok and not water.error.is_empty(), "Dispatch rejects a water target")
	_check(document.set_misc_u32(0x01f0 + 0xd2 * 4, 0), "Dispatch unavailable fixture removes police capacity")
	var no_police := Dispatch.apply(city, 2, 0, Vector2i(31, 30), police.slot_index, false)
	_check(not no_police.ok and not no_police.error.is_empty(), "Dispatch rejects an unavailable unit type")


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
		CityRotation.surface_tile_after_rotation(Tiles.ROAD_SLOPE_1, true) == 0x22
		and CityRotation.surface_tile_after_rotation(Tiles.ROAD_SLOPE_1, false) == 0x20,
		"Rotation uses the recovered surface-network lookup tables",
	)
	_check(
		CityRotation.terrain_tile_after_rotation(0x01, true) == 0x04
		and CityRotation.terrain_tile_after_rotation(0x01, false) == 0x02,
		"Rotation uses the recovered terrain lookup tables",
	)
	_check(
		CityRotation.underground_tile_after_rotation(UnderTiles.SUBWAY_HTB, true) == 0x06
		and CityRotation.underground_tile_after_rotation(UnderTiles.SUBWAY_HTB, false) == 0x04,
		"Rotation uses the recovered underground lookup tables",
	)

	var document := _load_fixture(reference_root.path_join("CITIES/STARTER.SC2"))
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
	_check(city.set_building_id(10, 10, Tiles.SUSPENSION_BRIDGE_1), "Rotation fixture stores an unflipped bridge")
	_check(city.set_tile_flag(10, 10, 0x02, false), "Rotation fixture clears the first bridge flip")
	_check(city.set_building_id(11, 10, Tiles.SUSPENSION_BRIDGE_1), "Rotation fixture stores a flipped bridge")
	_check(city.set_tile_flag(11, 10, 0x02, true), "Rotation fixture sets the second bridge flip")
	_check(city.set_building_id(12, 10, Tiles.HIGHWAY_ONRAMP_1), "Rotation fixture stores an unflipped on-ramp")
	_check(city.set_tile_flag(12, 10, 0x02, false), "Rotation fixture clears the first ramp flip")
	_check(city.set_building_id(13, 10, Tiles.HIGHWAY_ONRAMP_1), "Rotation fixture stores a flipped on-ramp")
	_check(city.set_tile_flag(13, 10, 0x02, true), "Rotation fixture sets the second ramp flip")
	_check(city.set_terrain_id(14, 10, 0x01), "Rotation fixture stores directional terrain")
	_check(city.set_underground_id(15, 10, UnderTiles.SUBWAY_HTB), "Rotation fixture stores a directional subway")
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


func _brute_force_screen_to_tile(city: CityState, point: Vector2) -> Vector2i:
	var result := Vector2i(-1, -1)

	for diagonal in CityModel.MAP_SIZE * 2 - 1:
		for y in diagonal + 1:
			var x := diagonal - y

			if x >= CityModel.MAP_SIZE or y >= CityModel.MAP_SIZE:
				continue

			if Geometry2D.is_point_in_polygon(
				point, IsometricRenderer.terrain_surface_polygon(city, x, y)
			):
				result = Vector2i(x, y)

	return result


func _check(condition: bool, message: String) -> void:
	checks += 1

	if not condition:
		failures += 1
		printerr("FAIL: %s" % message)


func _load_fixture(path: String) -> Sc2File:
	# Cache only read-only inputs. Every caller gets private state; saved outputs
	# still use the actual loader, so reload and round-trip checks are not bypassed.
	if not path.begins_with(fixture_root + "/"):
		return Sc2Document.load_path(path)
	if not fixture_documents.has(path):
		fixture_documents[path] = Sc2Document.load_path(path)
	return fixture_documents[path].duplicate_document()


func _dynamic_command_values(commands: Array[CityDynamicCommand]) -> Array:
	var values: Array = []

	for command in commands:
		values.append([command.sprite_id, command.flip, command.position,
			command.shadow, command.depth_order, command.record, command.overlay,
			command.static_occlusion, command.train, command.same_tile_foreground_indices])

	return values


func _static_command_values(commands: Array[CityStaticCommand], include_region := true) -> Array:
	var values: Array = []

	for command in commands:
		var fields := [command.sprite_id, command.flip, command.position, command.size,
			command.depth_order, command.train_ignore, command.train_foreground_reference_sprite_id,
			command.train_deck_thickness, command.train_deck_reference_sprite_id,
			command.train_foreground_requires_depth]

		if include_region:
			fields.append(command.region_order)

		values.append(fields)

	return values
