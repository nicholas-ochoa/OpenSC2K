extends "res://tests/support/core_test_suite.gd"

## Formats: scenarios checks.

@warning_ignore_start("integer_division")

const ScenarioModel = preload("res://src/model/scenario_state.gd")
const Palette = preload("res://src/assets/sc2_palette.gd")
const Pollution = preload("res://src/simulation/data_maps/pollution_phase.gd")
const ScenarioPhaseRunner = preload("res://src/simulation/civic/scenario_phase.gd")
const Bankruptcy = preload("res://src/simulation/economy/bankruptcy_phase.gd")


func test_scenarios(reference_root: String) -> void:
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
	victory.land_value_goal = 0
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
