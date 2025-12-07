class_name NewCityTerrainSession
extends RefCounted

const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityModel = preload("res://src/model/city_state.gd")
const NewCity = preload("res://src/model/new_city_setup.gd")
const NewTerrain = preload("res://src/model/new_city_terrain.gd")
const Random = preload("res://src/simulation/sim_random.gd")
const GameRandom = preload("res://src/simulation/game_lcg_random.gd")

var preview_document: Sc2File
var independent_template := false
var preview_options: Dictionary = {}
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
	preview_options.clear()


func matches(options: Dictionary) -> bool:
	return preview_document != null and preview_options == options


func generate_preview(
	template_path: String, options: Dictionary, advance_seed: bool
) -> Dictionary:
	var document := _load_template(template_path)
	if not document.is_valid():
		return {
			"ok": false,
			"stage": "template",
			"error": document.parse_error,
		}
	if advance_seed or preview_document == null:
		preview_process_start = preview_process_cursor
		preview_game_start = preview_game_cursor
	var preview_process := Random.new(preview_process_start)
	var preview_game := GameRandom.new(preview_game_start)
	var generated := NewTerrain.generate(
		document,
		bool(options.ocean),
		bool(options.river),
		int(options.hills),
		int(options.water),
		int(options.trees),
		preview_process,
		preview_game,
	)
	if not generated.ok:
		return {
			"ok": false,
			"stage": "terrain",
			"error": generated.error,
		}
	var preview_city := CityModel.from_document(document)
	if not preview_city.is_valid():
		return {
			"ok": false,
			"stage": "city",
			"error": preview_city.load_error,
		}
	preview_document = document
	preview_options = options.duplicate(true)
	preview_process_cursor = preview_process.state
	preview_game_cursor = preview_game.state
	var result: Dictionary = generated.duplicate(true)
	result["document"] = document
	result["city"] = preview_city
	return result


func create_city(
	template_path: String,
	city_name: String,
	mayor_name: String,
	difficulty: int,
	starting_year: int,
	terrain_options: Dictionary,
	newspaper_session_state: PackedByteArray,
) -> Dictionary:
	var template := _load_template(template_path)
	if not template.is_valid():
		return {
			"ok": false,
			"stage": "template",
			"error": template.parse_error,
		}
	var process_random := Random.new(preview_process_start)
	var game_random := GameRandom.new(preview_game_start)
	var created := NewCity.create(
		template,
		city_name,
		mayor_name,
		difficulty,
		starting_year,
		process_random,
		game_random,
		terrain_options,
		newspaper_session_state,
	)
	if not created.ok:
		return {
			"ok": false,
			"stage": "setup",
			"error": created.error,
		}
	var result: Dictionary = created.duplicate(true)
	result["process_state"] = process_random.state
	result["game_state"] = game_random.state
	return result


func _load_template(path: String) -> Sc2File:
	return EmptyCityTemplate.create() if independent_template else Sc2Document.load_path(path)
