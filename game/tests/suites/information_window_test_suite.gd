extends RefCounted

const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityModel = preload("res://src/model/city_state.gd")
const PeBitmap = preload("res://src/assets/pe_bitmap_resource.gd")
const PeString = preload("res://src/assets/pe_string_resource.gd")
const OriginalAssets = preload("res://src/assets/original_game_assets.gd")
const PopulationView = preload("res://src/view/population_window_control.gd")
const IndustryView = preload("res://src/view/industry_window_control.gd")
const SimNationView = preload("res://src/view/simnation_window_control.gd")
const Ordinances = preload("res://src/simulation/economy/ordinance_command.gd")

var check_callback: Callable


func _init(callback: Callable) -> void:
	check_callback = callback


func run(reference_root: String) -> void:
	_test_original_assets(reference_root)
	_test_population_window(reference_root)
	_test_industry_window(reference_root)
	_test_simnation_window(reference_root)
	_test_ordinance_window(reference_root)


func _test_original_assets(reference_root: String) -> void:
	var resource_ids := OriginalAssets.required_string_ids()
	_check(
		resource_ids.has(OriginalAssets.FOREST_PROTEST_STRING_ID)
		and resource_ids.has(OriginalAssets.BUILDING_OBJECTION_STRING_ID)
		and resource_ids.has(OriginalAssets.INDUSTRY_STRING_FIRST)
		and resource_ids.has(OriginalAssets.INDUSTRY_STRING_LAST)
		and resource_ids.has(OriginalAssets.CITY_MAP_STRING_FIRST)
		and resource_ids.has(OriginalAssets.CITY_MAP_STRING_LAST)
		and resource_ids.has(OriginalAssets.SIMNATION_FORMAT_STRING_ID)
		and resource_ids.has(OriginalAssets.NEIGHBOR_NAME_STRING_FIRST)
		and resource_ids.has(OriginalAssets.NEIGHBOR_NAME_STRING_LAST)
		and resource_ids.has(OriginalAssets.NEWSPAPER_STRING_FIRST)
		and resource_ids.has(OriginalAssets.NEWSPAPER_STRING_LAST),
		"Original asset loader owns every shared string-resource range",
	)
	var assets := OriginalAssets.load_root(reference_root)
	_check(
		assets.error.is_empty()
		and assets.palette != null
		and assets.palette.is_valid()
		and assets.scenario_palette != null
		and assets.scenario_palette.is_valid()
		and assets.large_sprites != null
		and assets.large_sprites.is_valid()
		and assets.small_medium_sprites != null
		and assets.small_medium_sprites.is_valid(),
		"Original asset loader validates required palettes and sprite archives",
	)
	_check(
		assets.newspaper_data != null
		and assets.newspaper_data.is_valid()
		and assets.toolbar_art != null
		and assets.industry_icons != null
		and assets.city_map_icons != null
		and assets.simnation_sprites != null
		and assets.forest_protest_image != null
		and not assets.library_texts.is_empty(),
		"Original asset loader provides shared interface resources",
	)


func _test_population_window(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	_check(document.set_misc_u32(0x102c, 1000), "Population-window fixture sets total population")
	_check(document.set_misc_u32(0x0044, 50), "Population-window fixture sets workforce percentage")
	_check(document.set_misc_u32(0x0048, 75), "Population-window fixture sets workforce health")
	_check(document.set_misc_u32(0x004c, 100), "Population-window fixture sets workforce education")
	_check(document.set_misc_u32(0x007c, 100), "Population-window fixture sets cohort population")
	_check(document.set_misc_u32(0x0080, 12000), "Population-window fixture sets cohort education")
	_check(document.set_misc_u32(0x0084, 8000), "Population-window fixture sets cohort health")
	var city := CityModel.from_document(document)
	var data := PopulationView.snapshot(city)
	_check(
		data.ok
		and data.total_population == 1000
		and data.cohorts.size() == 20
		and data.cohorts[0].age_start == 0
		and data.cohorts[19].age_start == 95,
		"Population window reads all twenty five-year cohorts",
	)
	_check(
		data.cohorts[0].education_quotient == 120
		and data.cohorts[0].life_expectancy == 80,
		"Population window calculates readable cohort averages",
	)
	_check(
		PopulationView.chart_values(data, PopulationWindowControl.Mode.POPULATION)[0] == 60
		and PopulationView.chart_values(data, PopulationWindowControl.Mode.HEALTH)[0] == 80
		and PopulationView.chart_values(data, PopulationWindowControl.Mode.EDUCATION)[0] == 72,
		"Population window uses the recovered chart transforms",
	)
	_check(
		PopulationView.indicator_value(data, PopulationWindowControl.Mode.POPULATION) == 50
		and PopulationView.indicator_value(data, PopulationWindowControl.Mode.HEALTH) == 75
		and PopulationView.indicator_value(data, PopulationWindowControl.Mode.EDUCATION) == 60,
		"Population window scales each saved workforce indicator",
	)
	_check(
		PopulationView.y_axis_label(PopulationWindowControl.Mode.POPULATION, 6) == "15%"
		and PopulationView.y_axis_label(PopulationWindowControl.Mode.HEALTH, 6) == "90 yrs"
		and PopulationView.y_axis_label(PopulationWindowControl.Mode.EDUCATION, 6) == "150 eq",
		"Population window exposes the recovered axis ranges",
	)


func _test_industry_window(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))

	for industry in IndustryView.INDUSTRY_COUNT:
		var offset := 0x016c + industry * 0x0c
		_check(
			document.set_misc_i32(offset, industry * 10),
			"Industry-window fixture sets demand %d" % industry,
		)
		_check(
			document.set_misc_i32(offset + 4, industry),
			"Industry-window fixture sets tax %d" % industry,
		)
		_check(
			document.set_misc_u32(offset + 8, (industry + 1) * 100),
			"Industry-window fixture sets ratio %d" % industry,
		)

	_check(
		document.set_misc_i32(0x077c + 2 * 0x006c + 4, 7),
		"Industry-window fixture sets city tax",
	)
	var city := CityModel.from_document(document)
	var data := IndustryView.snapshot(city)
	_check(
		data.ok
		and data.ratios.size() == 11
		and data.tax_rates.size() == 11
		and data.demands.size() == 11
		and data.industrial_tax == 7,
		"Industry window reads all three saved series and city tax",
	)
	_check(
		IndustryView.values_for_mode(data, IndustryView.Mode.RATIOS)[10] == 1100
		and IndustryView.values_for_mode(data, IndustryView.Mode.TAX_RATES)[10] == 10
		and IndustryView.values_for_mode(data, IndustryView.Mode.DEMAND)[10] == 100,
		"Industry window selects the recovered series",
	)
	_check(
		IndustryView.maximum_for_mode(data, IndustryView.Mode.RATIOS) == 1100
		and IndustryView.maximum_for_mode(data, IndustryView.Mode.TAX_RATES) == 30
		and IndustryView.maximum_for_mode(data, IndustryView.Mode.DEMAND) == 100,
		"Industry window uses the recovered dynamic maxima",
	)
	var changed := IndustryView.set_tax_rate(city, 3, 19)
	_check(
		changed.ok
		and changed.changed
		and document.misc_i32(0x016c + 3 * 0x0c + 4) == 19,
		"Industry window changes one saved tax rate",
	)
	var changed_all := IndustryView.set_tax_rate(city, 0, 99, true)
	var all_clamped: bool = changed_all.ok and changed_all.value == 20

	for industry in IndustryView.INDUSTRY_COUNT:
		all_clamped = (
			all_clamped
			and document.misc_i32(0x016c + industry * 0x0c + 4) == 20
		)

	_check(all_clamped, "Industry window clamps and changes all tax rates")
	_check(
		not IndustryView.set_tax_rate(city, 11, 5).ok,
		"Industry window rejects an invalid industry",
	)
	var names := PeString.load_ids(
		reference_root.path_join("SIMCITY.EXE"),
		PackedInt32Array(range(422, 433)),
	)
	var all_names: bool = names.ok and names.strings.size() == 11

	if all_names:
		for resource_id in range(422, 433):
			all_names = (
				all_names
				and not str(names.strings.get(resource_id, "")).is_empty()
			)

	_check(all_names, "Supplied executable contains all eleven industry labels")
	var icons := PeBitmap.load_numeric(reference_root.path_join("SIMCITY.EXE"), 178)
	var icon_image: Image = icons.image
	_check(
		icons.ok and icon_image != null and not icon_image.is_empty(),
		"Supplied executable contains the industry icon strip",
	)


func _test_simnation_window(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	_check(document.set_misc_u32(0x0008, 2), "SimNation fixture sets compass")
	_check(document.set_misc_u32(0x0050, 123456), "SimNation fixture sets national population")
	_check(document.set_misc_u32(0x1020, 200), "SimNation fixture sets arcology population")
	_check(document.set_misc_u32(0x102c, 1000), "SimNation fixture sets normal population")

	for tile_id in range(0xfb, 0xff):
		_check(
			document.set_misc_i32(0x01f0 + tile_id * 4, 0),
			"SimNation fixture clears arcology count %d" % tile_id,
		)

	_check(
		document.set_misc_i32(0x01f0 + 0xfb * 4, 141 * 16),
		"SimNation fixture sets large arcology count",
	)
	var name_indices := PackedInt32Array([1, 2, 0, 36])
	var populations := PackedInt32Array([1999, 2000, 50000, 100000])

	for index in 4:
		var offset := 0x06d8 + index * 0x10
		_check(document.set_misc_i32(offset, name_indices[index]), "SimNation fixture sets name %d" % index)
		_check(document.set_misc_u32(offset + 4, populations[index]), "SimNation fixture sets population %d" % index)
		_check(document.set_misc_u32(offset + 8, 3000 + index), "SimNation fixture sets value %d" % index)
		_check(document.set_misc_u32(offset + 12, 4000 + index), "SimNation fixture sets fame %d" % index)

	var city := CityModel.from_document(document)
	var data := SimNationView.snapshot(city)
	_check(
		data.ok
		and data.compass == 2
		and data.neighbors.size() == 4
		and data.neighbors[0].name_resource_id == 548
		and data.neighbors[2].name_resource_id == 0
		and data.neighbors[3].name_resource_id == 583,
		"SimNation window reads saved records and maps name resources",
	)
	_check(
		data.arcology_count == 141
		and data.arcology_adjustment == 20000
		and data.display_population == 21200,
		"SimNation window applies the recovered display population adjustment",
	)
	_check(
		SimNationView.display_neighbor_indices(0) == PackedInt32Array([2, 3, 0, 1])
		and SimNationView.display_neighbor_indices(2) == PackedInt32Array([0, 1, 2, 3]),
		"SimNation window rotates neighbors with the saved compass",
	)
	_check(
		SimNationView.sprite_index(0, true) == 0
		and SimNationView.sprite_index(0, false) == 1
		and SimNationView.sprite_index(1999, false) == 1
		and SimNationView.sprite_index(2000, false) == 2
		and SimNationView.sprite_index(9999, false) == 2
		and SimNationView.sprite_index(10000, false) == 3
		and SimNationView.sprite_index(49999, false) == 3
		and SimNationView.sprite_index(50000, false) == 4
		and SimNationView.sprite_index(99999, false) == 4
		and SimNationView.sprite_index(100000, false) == 5,
		"SimNation window selects all recovered population sprites",
	)
	var strings := PeString.load_ids(
		reference_root.path_join("SIMCITY.EXE"),
		PackedInt32Array([421, 548, 583]),
	)
	_check(
		strings.ok
		and str(strings.strings.get(421, "")).contains("%lu000")
		and not str(strings.strings.get(548, "")).is_empty()
		and not str(strings.strings.get(583, "")).is_empty(),
		"Supplied executable contains the SimNation caption and neighbor names",
	)
	_check(
		SimNationView.national_population_text("Nat. Pop: %lu000", 123456)
		== "Nat. Pop: 123456000",
		"SimNation window expands the original national-population format",
	)
	var source := Image.load_from_file(reference_root.path_join("BITMAPS/NEIGHBOR.BMP"))
	var prepared: Image = SimNationView.prepare_sprite_sheet(source)
	_check(
		source != null
		and source.get_size() == Vector2i(128, 448)
		and prepared != null
		and prepared.get_size() == Vector2i(128, 448)
		and prepared.get_pixel(0, 0).a == 0.0,
		"SimNation window loads the original sheet and makes index zero transparent",
	)


func _test_ordinance_window(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var residential_offset := Ordinances.MISC_BUDGETS
	var commercial_offset := residential_offset + Ordinances.BUDGET_RECORD_SIZE
	var industrial_offset := commercial_offset + Ordinances.BUDGET_RECORD_SIZE
	var ordinance_offset := (
		Ordinances.MISC_BUDGETS
		+ Ordinances.BUDGET_ORDINANCES * Ordinances.BUDGET_RECORD_SIZE
	)
	_check(document.set_misc_i32(residential_offset, 7500), "Ordinance fixture sets residents")
	_check(document.set_misc_i32(commercial_offset, 15000), "Ordinance fixture sets commerce")
	_check(document.set_misc_i32(industrial_offset, 22500), "Ordinance fixture sets industry")
	_check(document.set_misc_u32(Ordinances.MISC_NORMAL_POPULATION, 30000), "Ordinance fixture sets population")
	_check(document.set_misc_u32(Ordinances.MISC_ARCOLOGY_POPULATION, 1500), "Ordinance fixture sets arcology population")
	_check(document.set_misc_u32(Ordinances.MISC_CITY_DAYS, 75), "Ordinance fixture selects April")
	_check(document.set_misc_i32(ordinance_offset + Ordinances.BUDGET_YEAR_TO_DATE, -9000), "Ordinance fixture sets year-to-date cost")
	var flags := 0xa0000000 | (1 << 0) | (1 << 4) | (1 << 8) | (1 << 12) | (1 << 16)
	_check(document.set_misc_u32(Ordinances.MISC_ORDINANCES, flags), "Ordinance fixture sets five categories")
	_check(document.set_misc_i32(ordinance_offset, 123456), "Ordinance fixture sets a stale total")
	var city := CityModel.from_document(document)
	var data := Ordinances.snapshot(city)
	_check(
		data.ok
		and data.raw_costs.size() == 20
		and data.raw_costs[0] == 15000
		and data.raw_costs[1] == 7500
		and data.raw_costs[2] == 30000
		and data.raw_costs[3] == 3750
		and data.raw_costs[4] == -2500
		and data.raw_costs[8] == -1250
		and data.raw_costs[12] == -15000
		and data.raw_costs[16] == -31500
		and data.raw_costs[17] == 0
		and data.raw_costs[19] == -22500,
		"Ordinance window uses the recovered bit order and formulas",
	)
	_check(
		data.current_raw == -35250
		and data.item_amounts == PackedInt32Array([200, 0, 0, 0, -33, 0, 0, 0, -16, 0, 0, 0, -200, 0, 0, 0, -420, 0, 0, 0])
		and data.category_amounts == PackedInt32Array([200, -33, -16, -200, -420]),
		"Ordinance window calculates item and category display amounts",
	)
	_check(
		data.year_to_date_amount == -10
		and data.estimated_amount == -323
		and data.month == 3,
		"Ordinance window calculates the in-year totals",
	)
	var synchronized := Ordinances.synchronize_current(city)
	_check(
		synchronized.ok
		and synchronized.changed
		and document.misc_i32(ordinance_offset) == -35250,
		"Opening Ordinances synchronizes its saved budget total",
	)
	var enabled := Ordinances.set_enabled(city, 17, true)
	_check(
		enabled.ok
		and enabled.changed
		and document.misc_u32(Ordinances.MISC_ORDINANCES) == (flags | (1 << 17))
		and document.misc_i32(ordinance_offset) == -35250,
		"Ordinance selection preserves high bits and updates its total",
	)
	var disabled := Ordinances.set_enabled(city, 0, false)
	_check(
		disabled.ok
		and disabled.changed
		and document.misc_u32(Ordinances.MISC_ORDINANCES) == ((flags | (1 << 17)) & ~(1 << 0))
		and document.misc_i32(ordinance_offset) == -50250,
		"Ordinance selection clears one saved bit",
	)
	_check(document.set_misc_u32(Ordinances.MISC_YEAR_END, 1), "Ordinance fixture sets year end")
	var year_end := Ordinances.snapshot(city)
	_check(
		year_end.estimated_amount == -670,
		"Year-end Ordinances estimates twelve months from the active selection",
	)
	_check(
		not Ordinances.set_enabled(city, 20, true).ok,
		"Ordinance selection rejects an invalid bit",
	)
	_check(
		Ordinances.compact_amount(9998) == "9998"
		and Ordinances.compact_amount(9999) == "10k"
		and Ordinances.compact_amount(-9999) == "-9k"
		and Ordinances.compact_amount(9999999) == "10m",
		"Ordinance amounts use the recovered compact-number boundaries",
	)


func _check(condition: bool, message: String) -> void:
	check_callback.call(condition, message)
