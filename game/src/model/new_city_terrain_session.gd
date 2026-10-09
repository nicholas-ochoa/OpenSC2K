class_name NewCityTerrainSession
extends RefCounted

const CityModel = preload("res://src/model/city_state.gd")
const NewCity = preload("res://src/model/new_city_setup.gd")
const NewTerrain = preload("res://src/model/new_city_terrain.gd")
const Random = preload("res://src/simulation/random/sim_random.gd")
const GameRandom = preload("res://src/simulation/random/game_lcg_random.gd")

var preview_document: Sc2File
var preview_options: NewCityTerrain.Options
var preview_process_start := 1
var preview_game_start := 1
var preview_process_cursor := 1
var preview_game_cursor := 1


func begin(process_state: int, game_state: int) -> void:
	clear()
	preview_process_cursor = process_state
	preview_game_cursor = game_state
	preview_process_start = process_state
	preview_game_start = game_state


func clear() -> void:
	preview_document = null
	preview_options = null


func matches(options: NewCityTerrain.Options) -> bool:
	return preview_document != null and preview_options.same_values(options)


func generate_preview(options: NewCityTerrain.Options, advance_seed: bool) -> PreviewResult:
	if int(options.size) not in Sc2File.MAP_SIZES:
		return PreviewResult.failure("Unsupported city size", "size")

	var document := EmptyCityTemplate.create(int(options.size))

	if options.native_maps and not document.enable_full_resolution_maps():
		return PreviewResult.failure("Cannot enable per-tile data maps", "data_maps")

	if advance_seed or preview_document == null:
		preview_process_start = preview_process_cursor
		preview_game_start = preview_game_cursor

	var preview_process := Random.new(preview_process_start)
	var preview_game := GameRandom.new(preview_game_start)

	# the original draws the neighbors before it makes the terrain
	NewCity.draw_neighbors(document, preview_process)
	var generated := NewTerrain.generate(
		document,
		bool(options.ocean),
		bool(options.river),
		int(options.hills),
		int(options.water),
		int(options.trees),
		preview_process,
		preview_game,
		str(options.layout),
		options.features,
		bool(options.smooth_slopes),
	)

	if not generated.ok:
		return PreviewResult.failure(generated.error, "terrain")

	var preview_city := CityModel.from_document(document)

	if not preview_city.is_valid():
		return PreviewResult.failure(preview_city.load_error, "city")

	preview_document = document
	preview_options = options.copy()
	preview_process_cursor = preview_process.state
	preview_game_cursor = preview_game.state
	var result := PreviewResult.new()
	result.ok = true
	result.terrain = generated
	result.document = document
	result.city = preview_city

	return result


func create_city(
	city_name: String,
	mayor_name: String,
	difficulty: int,
	starting_year: int,
	terrain_options: NewCityTerrain.Options,
	newspaper_session_state: PackedByteArray) -> NewCitySetup.Result:
	if not matches(terrain_options):
		return NewCitySetup.Result.failure("Regenerate terrain first", "terrain")

	# Found the displayed city. Generating it again here could produce a different map.
	var template := preview_document.duplicate_document()
	var process_random := Random.new(preview_process_cursor)
	var game_random := GameRandom.new(preview_game_cursor)
	var created := NewCity.create(
		template,
		city_name,
		mayor_name,
		difficulty,
		starting_year,
		process_random,
		game_random,
		null,
		newspaper_session_state,
		NewTerrain.is_island(str(preview_options.layout), preview_options.features),
	)

	if not created.ok:
		return NewCitySetup.Result.failure(created.error, "setup")

	created.process_state = process_random.state
	created.game_state = game_random.state

	return created


class PreviewResult extends RefCounted:
	var ok := false
	var error := ""
	var stage := ""
	var terrain: NewCityTerrain.Result
	var document: Sc2File
	var city: CityState
	var landscape_image: Image
	# the landscape has HD art
	var landscape_artwork := false
	var minimap_image: Image

	static func failure(message: String, failed_stage: String) -> PreviewResult:
		var result := PreviewResult.new()
		result.error = message
		result.stage = failed_stage

		return result
