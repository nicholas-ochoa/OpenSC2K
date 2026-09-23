extends SceneTree

## Select and run core suites with one shared result and fixture context.

const CoreTestContext = preload("res://tests/support/core_test_context.gd")
const CodecTests = preload("res://tests/suites/core/formats/codec_tests.gd")
const PaletteMinimapTests = preload("res://tests/suites/core/rendering/palette_minimap_tests.gd")
const SpriteArchivesTests = preload("res://tests/suites/core/rendering/sprite_archives_tests.gd")
const TileSetsTests = preload("res://tests/suites/core/scurk/tile_sets_tests.gd")
const CityFilesTests = preload("res://tests/suites/core/formats/city_files_tests.gd")
const ScenariosTests = preload("res://tests/suites/core/formats/scenarios_tests.gd")
const ClockEngineTests = preload("res://tests/suites/core/simulation/clock_engine_tests.gd")
const InfrastructureTests = preload("res://tests/suites/core/simulation/infrastructure_tests.gd")
const DataMapsTests = preload("res://tests/suites/core/simulation/data_maps_tests.gd")
const DemandTests = preload("res://tests/suites/core/simulation/demand_tests.gd")
const NewsTests = preload("res://tests/suites/core/simulation/news_tests.gd")
const WeatherTests = preload("res://tests/suites/core/simulation/weather_tests.gd")
const ServicesTests = preload("res://tests/suites/core/simulation/services_tests.gd")
const EconomyTests = preload("res://tests/suites/core/simulation/economy_tests.gd")
const CatalogTests = preload("res://tests/suites/core/tools/catalog_tests.gd")
const CivicTests = preload("res://tests/suites/core/simulation/civic_tests.gd")
const DisasterStartTests = preload("res://tests/suites/core/simulation/disaster_start_tests.gd")
const DisasterMapTests = preload("res://tests/suites/core/simulation/disaster_map_tests.gd")
const AnnualMicrosimsTests = preload("res://tests/suites/core/simulation/annual_microsims_tests.gd")
const GrowthTests = preload("res://tests/suites/core/simulation/growth_tests.gd")
const MovingThingsTests = preload("res://tests/suites/core/simulation/moving_things_tests.gd")
const GameSpeedTests = preload("res://tests/suites/core/simulation/game_speed_tests.gd")
const NewCityTests = preload("res://tests/suites/core/tools/new_city_tests.gd")
const ZonesSignsTests = preload("res://tests/suites/core/tools/zones_signs_tests.gd")
const QueryTests = preload("res://tests/suites/core/tools/query_tests.gd")
const BuildingsTests = preload("res://tests/suites/core/tools/buildings_tests.gd")
const NetworksTests = preload("res://tests/suites/core/tools/networks_tests.gd")
const ConnectionsTests = preload("res://tests/suites/core/tools/connections_tests.gd")
const HighwaysTests = preload("res://tests/suites/core/tools/highways_tests.gd")
const DemolitionTests = preload("res://tests/suites/core/tools/demolition_tests.gd")
const TerrainTests = preload("res://tests/suites/core/tools/terrain_tests.gd")
const DispatchRotationTests = preload("res://tests/suites/core/tools/dispatch_rotation_tests.gd")
const AudioTests = preload("res://tests/suites/audio_test_suite.gd")
const InformationWindowTests = preload("res://tests/suites/information_window_test_suite.gd")
const UiShellTests = preload("res://tests/suites/ui_shell_test_suite.gd")

var selected_domains := PackedStringArray()


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	var reference_root := ProjectSettings.globalize_path("res://../references/SIMCITY2000")

	if not arguments.is_empty():
		reference_root = arguments[0]

	var context := CoreTestContext.new(reference_root)

	for argument in arguments.slice(1):
		if argument not in ["formats", "simulation", "tools", "rendering", "scurk", "ui", "audio"]:
			push_error("Unknown core domain: " + argument)
			quit(1)
			return
		selected_domains.append(argument)

	var audio_tests := AudioTests.new(Callable(context, "check"))
	var information_window_tests := InformationWindowTests.new(
		Callable(context, "check")
	)
	var ui_shell_tests := UiShellTests.new(Callable(context, "check"))

	if _selected("formats"):
		CodecTests.new(context).test_rle()
	if _selected("formats"):
		CodecTests.new(context).test_invalid_rle()
	if _selected("formats"):
		CodecTests.new(context).test_original_game_installer(reference_root)
	if _selected("rendering"):
		PaletteMinimapTests.new(context).test_view_configurations()
		PaletteMinimapTests.new(context).test_palette_and_minimap(reference_root)
	if _selected("rendering"):
		SpriteArchivesTests.new(context).test_sprite_archives(reference_root)
	if _selected("scurk"):
		TileSetsTests.new(context).test_scurk_mif(reference_root)
	if _selected("formats"):
		CityFilesTests.new(context).test_reference_corpus(reference_root)
	if _selected("formats"):
		CityFilesTests.new(context).test_city_options(reference_root)
	if _selected("audio"):
		audio_tests.test_music(reference_root)
	if _selected("ui"):
		ui_shell_tests.test_shell_controls()
	if _selected("ui"):
		ui_shell_tests.test_rci_status_control()
	if _selected("formats"):
		ScenariosTests.new(context).test_scenarios(reference_root)
	if _selected("simulation"):
		ClockEngineTests.new(context).test_simulation_clock()
	if _selected("simulation"):
		InfrastructureTests.new(context).test_random_and_power(reference_root)
	if _selected("simulation"):
		InfrastructureTests.new(context).test_water(reference_root)
	if _selected("simulation"):
		InfrastructureTests.new(context).test_traffic(reference_root)
	if _selected("simulation"):
		DataMapsTests.new(context).test_pollution(reference_root)
	if _selected("simulation"):
		DataMapsTests.new(context).test_graph_history(reference_root)
	if _selected("simulation"):
		DemandTests.new(context).test_rci_demand(reference_root)
	if _selected("simulation"):
		NewsTests.new(context).test_news_queue(reference_root)
	if _selected("simulation"):
		NewsTests.new(context).test_newspaper_text(reference_root)
	if _selected("simulation"):
		DemandTests.new(context).test_rci_aftermath(reference_root)
	if _selected("simulation"):
		WeatherTests.new(context).test_weather_disaster_phase(reference_root)
	if _selected("simulation"):
		ServicesTests.new(context).test_simnation(reference_root)
	if _selected("simulation"):
		ServicesTests.new(context).test_industries(reference_root)
	if _selected("simulation"):
		ServicesTests.new(context).test_education_health(reference_root)
	if _selected("ui"):
		information_window_tests.run(reference_root)
	if _selected("simulation"):
		EconomyTests.new(context).test_month_start(reference_root)
	if _selected("simulation"):
		EconomyTests.new(context).test_city_value_phase(reference_root)
	if _selected("tools"):
		CatalogTests.new(context).test_bond_command(reference_root)
	if _selected("simulation"):
		EconomyTests.new(context).test_budget_phase(reference_root)
	if _selected("simulation"):
		EconomyTests.new(context).test_january_budget_order(reference_root)
	if _selected("simulation"):
		EconomyTests.new(context).test_january_unknown_utilities(reference_root)
	if _selected("simulation"):
		EconomyTests.new(context).test_fiscal_crisis_notice(reference_root)
	if _selected("simulation"):
		CivicTests.new(context).test_milestone_phase(reference_root)
	if _selected("simulation"):
		CivicTests.new(context).test_military_proposal_phase(reference_root)
	if _selected("simulation"):
		DisasterStartTests.new(context).test_disaster_start_phase(reference_root)
	if _selected("simulation"):
		DisasterMapTests.new(context).test_disaster_map_phase(reference_root)
	if _selected("simulation"):
		AnnualMicrosimsTests.new(context).test_annual_microsim_phase(reference_root)
	if _selected("simulation"):
		AnnualMicrosimsTests.new(context).test_annual_service_microsim_phase(reference_root)
	if _selected("simulation"):
		AnnualMicrosimsTests.new(context).test_annual_prison_overcrowding(reference_root)
	if _selected("simulation"):
		AnnualMicrosimsTests.new(context).test_annual_special_microsim_phase(reference_root)
	if _selected("simulation"):
		AnnualMicrosimsTests.new(context).test_arcology_launch_phase(reference_root)
	if _selected("simulation"):
		CivicTests.new(context).test_mayor_approval_phase(reference_root)
	if _selected("simulation"):
		InfrastructureTests.new(context).test_transport_trip(reference_root)
	if _selected("simulation"):
		GrowthTests.new(context).test_growth_phase(reference_root)
	if _selected("simulation"):
		MovingThingsTests.new(context).test_moving_thing_phase(reference_root)
	if _selected("simulation"):
		ClockEngineTests.new(context).test_simulation_engine(reference_root)
	if _selected("simulation"):
		GameSpeedTests.new(context).test_game_speed_controller(reference_root)
	if _selected("formats"):
		CityFilesTests.new(context).test_modified_save(reference_root)
	if _selected("tools"):
		NewCityTests.new(context).test_new_city_terrain(reference_root)
	if _selected("tools"):
		NewCityTests.new(context).test_new_city_setup(reference_root)
	if _selected("tools"):
		NewCityTests.new(context).test_map_edits(reference_root)
	if _selected("tools"):
		CatalogTests.new(context).test_tool_catalog()
	if _selected("audio"):
		audio_tests.test_sound_rules()
	if _selected("tools"):
		CatalogTests.new(context).test_tool_availability(reference_root)
	if _selected("tools"):
		ZonesSignsTests.new(context).test_zone_command(reference_root)
	if _selected("tools"):
		ZonesSignsTests.new(context).test_sign_command(reference_root)
	if _selected("tools"):
		QueryTests.new(context).test_query_info(reference_root)
	if _selected("tools"):
		BuildingsTests.new(context).test_landscape_command(reference_root)
	if _selected("tools"):
		BuildingsTests.new(context).test_building_command(reference_root)
	if _selected("tools"):
		NetworksTests.new(context).test_network_command(reference_root)
	if _selected("tools"):
		ConnectionsTests.new(context).test_hydro_command(reference_root)
	if _selected("tools"):
		ConnectionsTests.new(context).test_subway_to_rail_command(reference_root)
	if _selected("tools"):
		ConnectionsTests.new(context).test_onramp_command(reference_root)
	if _selected("tools"):
		ConnectionsTests.new(context).test_tunnel_command(reference_root)
	if _selected("tools"):
		HighwaysTests.new(context).test_highway_command(reference_root)
	if _selected("tools"):
		DemolitionTests.new(context).test_demolish_command(reference_root)
	if _selected("tools"):
		TerrainTests.new(context).test_terrain_command(reference_root)
	if _selected("tools"):
		DispatchRotationTests.new(context).test_dispatch_command(reference_root)
	if _selected("tools"):
		DispatchRotationTests.new(context).test_city_rotation(reference_root)

	if context.failures == 0:
		print("PASS: %d checks" % context.checks)
		quit(0)
	else:
		printerr("FAIL: %d of %d checks failed" % [context.failures, context.checks])
		quit(1)


func _selected(domain: String) -> bool:
	return selected_domains.is_empty() or domain in selected_domains
