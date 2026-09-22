class_name NewCitySetup
extends RefCounted

const CityModel = preload("res://src/model/city_state.gd")
const Random = preload("res://src/simulation/random/sim_random.gd")
const GameRandom = preload("res://src/simulation/random/game_lcg_random.gd")
const NewsQueue = preload("res://src/simulation/reports/news_queue.gd")
const Terrain = preload("res://src/model/new_city_terrain.gd")

const MISC_SIZE := Sc2MiscLayout.SIZE
const GRAPH_SIZE := Sc2GraphLayout.SIZE
const MISC_START_YEAR := Sc2MiscLayout.START_YEAR
const MISC_FUNDS := Sc2MiscLayout.FUNDS
const MISC_BONDS := Sc2MiscLayout.BONDS
const MISC_DIFFICULTY := Sc2MiscLayout.DIFFICULTY
const MISC_NATIONAL_POPULATION := Sc2MiscLayout.NATIONAL_POPULATION
const MISC_NATIONAL_FEDERAL_RATE := Sc2MiscLayout.NATIONAL_FEDERAL_RATE
const MISC_NATIONAL_ECONOMY_TREND := Sc2MiscLayout.NATIONAL_ECONOMY_TREND
const MISC_BOND_RATES := Sc2MiscLayout.BOND_RATES
const MISC_INVENTION_YEARS := Sc2MiscLayout.INVENTION_YEARS
const MISC_BUDGETS := Sc2MiscLayout.BUDGETS
const BUDGET_RECORD_SIZE := Sc2BudgetLayout.RECORD_SIZE
const BUDGET_BONDS := Sc2BudgetLayout.BONDS
const BUDGET_CURRENT := Sc2BudgetLayout.CURRENT
const BUDGET_FUNDING := Sc2BudgetLayout.FUNDING
const BUDGET_YEAR_TO_DATE := Sc2BudgetLayout.YEAR_TO_DATE
const BUDGET_COUNT_MONTH_0 := Sc2BudgetLayout.MONTHS
const BUDGET_FUND_MONTH_0 := Sc2BudgetLayout.MONTHS + Sc2BudgetLayout.MONTH_FUNDING
const MAX_BONDS := 50
const HARD_BOND_RATE := 3
const FOUNDING_STORY_TYPE := 2
const GRAPH_GNP := 13
const GRAPH_NATIONAL_POPULATION := 14
const GRAPH_VALUE_COUNT := Sc2GraphLayout.VALUES_PER_SERIES

const STARTING_YEARS := [1900, 1950, 2000, 2050]
const NATIONAL_POPULATIONS := {
	1900: 10000,
	1950: 25000,
	2000: 60000,
	2050: 150000,
}

# The 17 invention years at SIMCITY.EXE 0x004e99e8 are signed little-endian
# words, unlike the big-endian save fields.
const INVENTION_BASE_YEARS := [
	1940, 1950, 1980, 1970, 2020, 2050, 1920, 1920, 1910,
	1900, 1925, 1980, 1990, 2040, 2090, 2140, 2190,
]


class Result extends RefCounted:
	var ok := false
	var error := ""
	var stage := ""
	var document: Sc2File
	var city_name := ""
	var mayor_name := ""
	var difficulty := 0
	var starting_year := 0
	var invention_years := PackedInt32Array()
	var terrain: NewCityTerrain.Result
	var process_state := 0
	var game_state := 0

	static func failure(message: String, failed_stage := "") -> Result:
		var result := Result.new()
		result.error = message
		result.stage = failed_stage

		return result


static func create(
	template: Sc2File,
	requested_city_name: String,
	requested_mayor_name: String,
	difficulty: int,
	starting_year: int,
	random: SimRandom,
	game_random: GameLcgRandom = null,
	terrain_options: NewCityTerrain.Options = null,
	newspaper_session_state: PackedByteArray = PackedByteArray(),
) -> Result:
	if template == null or not template.is_valid():
		return Result.failure("default city template is invalid")

	if difficulty < 1 or difficulty > 3:
		return Result.failure("difficulty must be Easy, Medium, or Hard")

	if not STARTING_YEARS.has(starting_year):
		return Result.failure("starting year must be 1900, 1950, 2000, or 2050")

	if random == null:
		return Result.failure("random state is missing")

	if terrain_options != null and game_random == null:
		return Result.failure("terrain game-random state is missing")

	if (
		not newspaper_session_state.is_empty()
		and newspaper_session_state.size() != NewsQueue.MISC_SIZE
	):
		return Result.failure("newspaper session state has the wrong size")

	var source_misc := template.find_chunk("MISC")
	var source_graph := template.find_chunk("XGRP")

	if source_misc == null or source_misc.decoded_payload.size() != MISC_SIZE:
		return Result.failure("default MISC data is missing or invalid")

	if source_graph == null or source_graph.decoded_payload.size() != GRAPH_SIZE:
		return Result.failure("default XGRP data is missing or invalid")

	if template.find_chunk("CNAM") == null or template.find_chunk("XLAB") == null:
		return Result.failure("default name data is missing")

	var document := template.duplicate_document()
	document.source_path = ""
	var city_name := requested_city_name.strip_edges()

	if city_name.is_empty():
		city_name = "New City"

	var mayor_name := requested_mayor_name.strip_edges()

	if mayor_name.is_empty():
		mayor_name = "Mayor"

	if not document.set_city_name(city_name):
		return Result.failure("cannot store the city name")

	var city := CityModel.from_document(document)

	if not city.is_valid() or not city.set_label(0, mayor_name):
		return Result.failure("cannot store the mayor name")

	var staged_random := Random.new(random.state)
	var staged_game_random = (
		GameRandom.new(game_random.state) if game_random != null else null
	)
	var terrain_result: NewCityTerrain.Result

	if terrain_options != null:
		terrain_result = Terrain.generate(
			document,
			bool(terrain_options.ocean),
			bool(terrain_options.river),
			int(terrain_options.hills),
			int(terrain_options.water),
			int(terrain_options.trees),
			staged_random,
			staged_game_random,
			str(terrain_options.layout),
			terrain_options.features,
			bool(terrain_options.smooth_slopes),
		)

		if not terrain_result.ok:
			return Result.failure("cannot generate terrain: %s" % terrain_result.error)

	var misc_chunk := document.find_chunk("MISC")
	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var national_population := int(NATIONAL_POPULATIONS[starting_year])
	BinaryData.write_u32_be(misc, Sc2MiscLayout.CITY_MODE, 1)
	BinaryData.write_u32_be(misc, MISC_START_YEAR, starting_year)
	BinaryData.write_u32_be(misc, MISC_FUNDS, 20000 if difficulty == 1 else 10000)
	BinaryData.write_u32_be(misc, MISC_BONDS, 0)
	BinaryData.write_u32_be(misc, MISC_DIFFICULTY, difficulty)
	BinaryData.write_u32_be(misc, MISC_NATIONAL_POPULATION, national_population)
	BinaryData.write_u32_be(misc, MISC_NATIONAL_FEDERAL_RATE, 3)
	BinaryData.write_u32_be(misc, MISC_NATIONAL_ECONOMY_TREND, difficulty - 1)

	for bond_index in MAX_BONDS:
		BinaryData.write_u32_be(misc, MISC_BOND_RATES + bond_index * 4, 0)

	var bond_budget := MISC_BUDGETS + BUDGET_BONDS * BUDGET_RECORD_SIZE

	for byte_index in BUDGET_RECORD_SIZE:
		misc[bond_budget + byte_index] = 0

	if difficulty == 3:
		BinaryData.write_u32_be(misc, MISC_BONDS, 1)
		BinaryData.write_u32_be(misc, MISC_BOND_RATES, HARD_BOND_RATE)
		BinaryData.write_u32_be(misc, bond_budget + BUDGET_CURRENT, 1)
		BinaryData.write_u32_be(misc, bond_budget + BUDGET_FUNDING, 30000)
		BinaryData.write_u32_be(misc, bond_budget + BUDGET_YEAR_TO_DATE, 30000)
		BinaryData.write_u32_be(misc, bond_budget + BUDGET_COUNT_MONTH_0, 1)
		BinaryData.write_u32_be(misc, bond_budget + BUDGET_FUND_MONTH_0, 30000)

	if not newspaper_session_state.is_empty():
		_copy_range(
			newspaper_session_state,
			misc,
			NewsQueue.PAPER_OFFSET,
			NewsQueue.PAPER_COUNT * NewsQueue.PAPER_RECORD_SIZE,
		)
		_copy_range(
			newspaper_session_state,
			misc,
			NewsQueue.STORY_OFFSET,
			NewsQueue.STORY_RECORD_COUNT * NewsQueue.STORY_RECORD_SIZE,
		)

	var invention_years := PackedInt32Array()

	for invention_index in INVENTION_BASE_YEARS.size():
		var invention_year := (
			int(INVENTION_BASE_YEARS[invention_index])
			+ staged_random.next_u15() % 20
		)

		if invention_year < starting_year:
			invention_year = 0

		invention_years.append(invention_year)
		BinaryData.write_u32_be(
			misc, MISC_INVENTION_YEARS + invention_index * 4, invention_year
		)

	var news_result := NewsQueue.insert(misc, FOUNDING_STORY_TYPE, 0)

	if not news_result.ok:
		return Result.failure("cannot initialize the founding newspaper: %s" % news_result.error)

	if not misc_chunk.set_decoded_payload(misc):
		return Result.failure("cannot store new-city settings")

	var graph_chunk := document.find_chunk("XGRP")
	var graph := PackedByteArray()
	graph.resize(GRAPH_SIZE)
	graph.fill(0)
	_write_graph_value(graph, GRAPH_GNP, 0, 3)
	_write_graph_value(
		graph, GRAPH_NATIONAL_POPULATION, 0, national_population
	)

	if not graph_chunk.set_decoded_payload(graph):
		return Result.failure("cannot initialize graph history")

	random.state = staged_random.state

	if game_random != null:
		game_random.state = staged_game_random.state

	var result := Result.new()
	result.ok = true
	result.document = document
	result.city_name = document.city_name()
	result.mayor_name = city.mayor_name()
	result.difficulty = difficulty
	result.starting_year = starting_year
	result.invention_years = invention_years
	result.terrain = terrain_result
	result.error = ""

	return result


static func _write_graph_value(
	data: PackedByteArray, series: int, index: int, value: int
) -> void:
	BinaryData.write_u32_be(data, (series * GRAPH_VALUE_COUNT + index) * Sc2GraphLayout.VALUE_SIZE, value)


static func _copy_range(
	source: PackedByteArray, target: PackedByteArray, offset: int, length: int
) -> void:
	for index in length:
		target[offset + index] = source[offset + index]
