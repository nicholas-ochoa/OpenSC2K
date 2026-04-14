class_name NewCitySetup
extends RefCounted

const CityModel = preload("res://src/model/city_state.gd")
const Random = preload("res://src/simulation/random/sim_random.gd")
const GameRandom = preload("res://src/simulation/random/game_lcg_random.gd")
const NewsQueue = preload("res://src/simulation/reports/news_queue.gd")
const Terrain = preload("res://src/model/new_city_terrain.gd")

const MISC_SIZE := 4800
const GRAPH_SIZE := 16 * 52 * 4
const MISC_CITY_MODE := 0x0004
const MISC_START_YEAR := 0x000c
const MISC_FUNDS := 0x0014
const MISC_BONDS := 0x0018
const MISC_DIFFICULTY := 0x001c
const MISC_NATIONAL_POPULATION := 0x0050
const MISC_NATIONAL_FEDERAL_RATE := 0x0058
const MISC_NATIONAL_ECONOMY_TREND := 0x005c
const MISC_BOND_RATES := 0x0610
const MISC_INVENTION_YEARS := 0x0738
const MISC_BUDGETS := 0x077c
const BUDGET_RECORD_SIZE := 0x006c
const BUDGET_BONDS := 4
const BUDGET_CURRENT := 0x00
const BUDGET_FUNDING := 0x04
const BUDGET_YEAR_TO_DATE := 0x08
const BUDGET_COUNT_MONTH_0 := 0x0c
const BUDGET_FUND_MONTH_0 := 0x10
const MAX_BONDS := 50
const HARD_BOND_RATE := 3
const FOUNDING_STORY_TYPE := 2
const GRAPH_GNP := 13
const GRAPH_NATIONAL_POPULATION := 14
const GRAPH_VALUE_COUNT := 52

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


static func create(
	template: Sc2File,
	requested_city_name: String,
	requested_mayor_name: String,
	difficulty: int,
	starting_year: int,
	random: SimRandom,
	game_random: GameLcgRandom = null,
	terrain_options: Dictionary = {},
	newspaper_session_state: PackedByteArray = PackedByteArray(),
) -> Dictionary:
	if template == null or not template.is_valid():
		return _failure("default city template is invalid")

	if difficulty < 1 or difficulty > 3:
		return _failure("difficulty must be Easy, Medium, or Hard")

	if not STARTING_YEARS.has(starting_year):
		return _failure("starting year must be 1900, 1950, 2000, or 2050")

	if random == null:
		return _failure("random state is missing")

	if not terrain_options.is_empty() and game_random == null:
		return _failure("terrain game-random state is missing")

	if (
		not newspaper_session_state.is_empty()
		and newspaper_session_state.size() != NewsQueue.MISC_SIZE
	):
		return _failure("newspaper session state has the wrong size")

	var source_misc := template.find_chunk("MISC")
	var source_graph := template.find_chunk("XGRP")

	if source_misc == null or source_misc.decoded_payload.size() != MISC_SIZE:
		return _failure("default MISC data is missing or invalid")

	if source_graph == null or source_graph.decoded_payload.size() != GRAPH_SIZE:
		return _failure("default XGRP data is missing or invalid")

	if template.find_chunk("CNAM") == null or template.find_chunk("XLAB") == null:
		return _failure("default name data is missing")

	var document := template.duplicate_document()
	document.source_path = ""
	var city_name := requested_city_name.strip_edges()

	if city_name.is_empty():
		city_name = "New City"

	var mayor_name := requested_mayor_name.strip_edges()

	if mayor_name.is_empty():
		mayor_name = "Mayor"

	if not document.set_city_name(city_name):
		return _failure("cannot store the city name")

	var city := CityModel.from_document(document)

	if not city.is_valid() or not city.set_label(0, mayor_name):
		return _failure("cannot store the mayor name")

	var staged_random := Random.new(random.state)
	var staged_game_random = (
		GameRandom.new(game_random.state) if game_random != null else null
	)
	var terrain_result := {}

	if not terrain_options.is_empty():
		terrain_result = Terrain.generate(
			document,
			bool(terrain_options.get("ocean", Terrain.DEFAULT_OCEAN)),
			bool(terrain_options.get("river", Terrain.DEFAULT_RIVER)),
			int(terrain_options.get("hills", Terrain.DEFAULT_HILLS)),
			int(terrain_options.get("water", Terrain.DEFAULT_WATER)),
			int(terrain_options.get("trees", Terrain.DEFAULT_TREES)),
			staged_random,
			staged_game_random,
			str(terrain_options.get("layout", "classic")),
			terrain_options.get("features", []),
			bool(terrain_options.get("smooth_slopes", false)),
		)

		if not terrain_result.ok:
			return _failure("cannot generate terrain: %s" % terrain_result.error)

	var misc_chunk := document.find_chunk("MISC")
	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var national_population := int(NATIONAL_POPULATIONS[starting_year])
	_write_u32(misc, MISC_CITY_MODE, 1)
	_write_u32(misc, MISC_START_YEAR, starting_year)
	_write_u32(misc, MISC_FUNDS, 20000 if difficulty == 1 else 10000)
	_write_u32(misc, MISC_BONDS, 0)
	_write_u32(misc, MISC_DIFFICULTY, difficulty)
	_write_u32(misc, MISC_NATIONAL_POPULATION, national_population)
	_write_u32(misc, MISC_NATIONAL_FEDERAL_RATE, 3)
	_write_u32(misc, MISC_NATIONAL_ECONOMY_TREND, difficulty - 1)

	for bond_index in MAX_BONDS:
		_write_u32(misc, MISC_BOND_RATES + bond_index * 4, 0)

	var bond_budget := MISC_BUDGETS + BUDGET_BONDS * BUDGET_RECORD_SIZE

	for byte_index in BUDGET_RECORD_SIZE:
		misc[bond_budget + byte_index] = 0

	if difficulty == 3:
		_write_u32(misc, MISC_BONDS, 1)
		_write_u32(misc, MISC_BOND_RATES, HARD_BOND_RATE)
		_write_u32(misc, bond_budget + BUDGET_CURRENT, 1)
		_write_u32(misc, bond_budget + BUDGET_FUNDING, 30000)
		_write_u32(misc, bond_budget + BUDGET_YEAR_TO_DATE, 30000)
		_write_u32(misc, bond_budget + BUDGET_COUNT_MONTH_0, 1)
		_write_u32(misc, bond_budget + BUDGET_FUND_MONTH_0, 30000)

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
		_write_u32(
			misc, MISC_INVENTION_YEARS + invention_index * 4, invention_year
		)

	var news_result := NewsQueue.insert(misc, FOUNDING_STORY_TYPE, 0)

	if not news_result.ok:
		return _failure("cannot initialize the founding newspaper: %s" % news_result.error)

	if not misc_chunk.set_decoded_payload(misc):
		return _failure("cannot store new-city settings")

	var graph_chunk := document.find_chunk("XGRP")
	var graph := PackedByteArray()
	graph.resize(GRAPH_SIZE)
	graph.fill(0)
	_write_graph_value(graph, GRAPH_GNP, 0, 3)
	_write_graph_value(
		graph, GRAPH_NATIONAL_POPULATION, 0, national_population
	)

	if not graph_chunk.set_decoded_payload(graph):
		return _failure("cannot initialize graph history")

	random.state = staged_random.state

	if game_random != null:
		game_random.state = staged_game_random.state

	return {
		"ok": true,
		"document": document,
		"city_name": document.city_name(),
		"mayor_name": city.mayor_name(),
		"difficulty": difficulty,
		"starting_year": starting_year,
		"invention_years": invention_years,
		"terrain": terrain_result,
		"error": "",
	}


static func _write_graph_value(
	data: PackedByteArray, series: int, index: int, value: int
) -> void:
	_write_u32(data, (series * GRAPH_VALUE_COUNT + index) * 4, value)


static func _copy_range(
	source: PackedByteArray, target: PackedByteArray, offset: int, length: int
) -> void:
	for index in length:
		target[offset + index] = source[offset + index]


static func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	var encoded := value & 0xffffffff
	data[offset] = (encoded >> 24) & 0xff
	data[offset + 1] = (encoded >> 16) & 0xff
	data[offset + 2] = (encoded >> 8) & 0xff
	data[offset + 3] = encoded & 0xff


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
