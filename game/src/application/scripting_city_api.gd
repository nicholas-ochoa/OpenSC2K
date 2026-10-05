class_name ScriptingCityApi
extends ScriptingApiBase
## The `city` functions of scripts: the city values, tiles, data maps,
## graphs, signs, moving objects, the name and saving. See docs/scripting.md.

@warning_ignore_start("integer_division")

# script name -> the chunk of each data map
const DATA_MAPS := {
	"traffic": "XTRF", "pollution": "XPLT", "landValue": "XVAL", "crime": "XCRM",
	"police": "XPLC", "fire": "XFIR", "populationDensity": "XPOP", "growth": "XROG",
}
const GRAPH_PERIODS := ["year", "decade", "century"]


func handlers() -> Dictionary[String, Callable]:
	return {
		"city.loaded": func(_arguments: Array) -> Variant: return app.document_state.city != null,
		"city.info": _city_info,
		"city.setFunds": _city_set_funds,
		"city.addFunds": _city_add_funds,
		"city.tile": _city_tile,
		"city.data": _city_data,
		"city.dataMap": _city_data_map,
		"city.dataMaps": func(_arguments: Array) -> Variant: return DATA_MAPS.keys(),
		"city.graph": _city_graph,
		"city.graphs": func(_arguments: Array) -> Variant: return CityGraphControl.SERIES_NAMES,
		"city.rename": _city_rename,
		"city.sign": _city_sign,
		"city.setSign": _city_set_sign,
		"city.things": _city_things,
		"city.save": _city_save,
	}


func _city_info(_arguments: Array) -> Variant:
	if not need_city():
		return null

	var city := app.document_state.city
	var demand := city.rci_demand()

	return {
		"name": city.city_name(),
		"mayor": city.mayor_name(),
		"size": city.map_size,
		"funds": city.funds(),
		"population": city.population(),
		"foundingYear": city.founding_year(),
		"difficulty": city.difficulty(),
		"scenario": app.simulation_state.simulation_engine.scenario != null,
		"path": app.document_state.current_save_path,
		"date": {"year": city.current_year(), "month": city.current_month(), "day": city.current_day(), "age": city.age_in_days()},
		"demand": {"residential": demand.x, "commercial": demand.y, "industrial": demand.z},
	}


func _city_set_funds(arguments: Array) -> Variant:
	if not need_city():
		return null

	if arguments.is_empty() or not is_number(arguments[0]):
		return fail("Funds must be a number.")

	var result := app.debug.debug_set_funds(int(arguments[0]))

	return app.document_state.city.funds() if result.ok else fail(result.message)


func _city_add_funds(arguments: Array) -> Variant:
	if not need_city():
		return null

	if arguments.is_empty() or not is_number(arguments[0]):
		return fail("The amount must be a number.")

	var total := clampi(app.document_state.city.funds() + int(arguments[0]), CityDebugActions.MIN_FUNDS, CityDebugActions.MAX_FUNDS)

	return _city_set_funds([total])


func _city_tile(arguments: Array) -> Variant:
	if not need_city():
		return null

	var tile := point(arguments, 0)
	var city := app.document_state.city

	if not inside_map(tile):
		return null

	return {
		"x": tile.x,
		"y": tile.y,
		"altitude": city.land_altitude(tile.x, tile.y),
		"waterAltitude": city.water_altitude(tile.x, tile.y),
		"terrain": city.terrain_id(tile.x, tile.y),
		"building": city.building_id(tile.x, tile.y),
		"zone": city.zone_id(tile.x, tile.y),
		"underground": city.underground_id(tile.x, tile.y),
		"overlay": city.text_overlay_id(tile.x, tile.y),
		"water": city.is_water(tile.x, tile.y),
		"saltWater": city.is_salt_water(tile.x, tile.y),
		"powered": city.is_powered(tile.x, tile.y),
		"powerable": city.is_powerable(tile.x, tile.y),
		"watered": city.is_watered(tile.x, tile.y),
		"piped": city.is_piped(tile.x, tile.y),
		"traffic": city.traffic_density(tile.x, tile.y),
		"data": _tile_data(tile),
	}


# each data map value at the tile: { traffic, pollution, ... }
func _tile_data(tile: Vector2i) -> Dictionary:
	var result := {}

	for name: String in DATA_MAPS:
		result[name] = _data_value(DATA_MAPS[name], tile)

	return result


# the value of a data map at a tile. A coarse map gives the value of its cell
func _data_value(chunk_id: String, tile: Vector2i) -> int:
	var city := app.document_state.city
	var chunk := city.document.find_chunk(chunk_id)

	if chunk == null:
		return 0

	var at := CityDataGrid.index(chunk.decoded_payload, city.map_size, tile.x, tile.y)

	return chunk.decoded_payload[at] if at >= 0 else 0


func _data_chunk(arguments: Array) -> String:
	var name := str(argument(arguments, 0, ""))

	if not DATA_MAPS.has(name):
		fail("The data map must be one of: %s." % ", ".join(DATA_MAPS.keys()))

		return ""

	return DATA_MAPS[name]


func _city_data(arguments: Array) -> Variant:
	if not need_city():
		return null

	var chunk_id := _data_chunk(arguments)
	var tile := point(arguments, 1)

	if chunk_id.is_empty():
		return null

	return _data_value(chunk_id, tile) if inside_map(tile) else null


# the whole map: { name, size, scale, values }. One value covers scale by scale
# tiles; the value of grid cell (gx, gy) is values[gx * size + gy]
func _city_data_map(arguments: Array) -> Variant:
	if not need_city():
		return null

	var chunk_id := _data_chunk(arguments)

	if chunk_id.is_empty():
		return null

	var city := app.document_state.city
	var chunk := city.document.find_chunk(chunk_id)
	var data := chunk.decoded_payload if chunk != null else PackedByteArray()
	var size := CityDataGrid.edge(data, city.map_size)

	return {"name": arguments[0], "size": size, "scale": city.map_size / size if size > 0 else 1, "values": data}


# a graph series, oldest value first, as the Graphs window draws it
func _city_graph(arguments: Array) -> Variant:
	if not need_city():
		return null

	var name: Variant = argument(arguments, 0, "")
	var period := str(argument(arguments, 1, "year"))
	var series := -1

	for index in CityGraphControl.SERIES_NAMES.size():
		if (is_number(name) and int(name) == index) or str(name).to_lower() == str(CityGraphControl.SERIES_NAMES[index]).to_lower():
			series = index

	if series < 0:
		return fail("Unknown graph. city.graphs lists them.")

	if period not in GRAPH_PERIODS:
		return fail("The period must be one of: %s." % ", ".join(GRAPH_PERIODS))

	var record := app.document_state.city.graph_series(series)

	if record == null:
		return []

	var stored := record.values_for_period(period)
	var values := []

	for index in range(stored.size() - 1, -1, -1):
		values.append(stored[index])

	return values


func _city_rename(arguments: Array) -> Variant:
	if not need_city():
		return null

	var city_name := str(argument(arguments, 0, "")).strip_edges()
	var document := app.document_state.current_document

	if city_name.is_empty():
		return fail("The city name cannot be empty.")

	if city_name.length() > document.city_name_limit():
		return fail("The city name can have %d characters at most." % document.city_name_limit())

	document.add_city_name_chunk()

	if not document.set_city_name(city_name):
		return fail("Cannot store the city name.")

	app.city_menu_bar.set_city_name(app.document_state.city.display_name(),
		DebugFileInfo.city_tooltip(app.document_state.city.display_name(), document))
	app.reports.refresh_newspaper_menu()
	app.scripting.emit("city.renamed", {"name": app.document_state.city.city_name()})

	return app.document_state.city.city_name()


# the text of the sign on the tile, or null
func _city_sign(arguments: Array) -> Variant:
	if not need_city():
		return null

	var tile := point(arguments, 0)

	if not inside_map(tile):
		return null

	var city := app.document_state.city
	var texts := city.sign_texts()
	var index := city.index_of(tile.x, tile.y)

	return texts[index] if texts.has(index) else null


# places, changes or removes (with an empty text) the sign of a tile, as the
# Sign tool does. Undo restores the previous sign
func _city_set_sign(arguments: Array) -> Variant:
	if not need_city():
		return null

	var tile := point(arguments, 0)

	if not inside_map(tile):
		return fail("The tile %d, %d is outside the map." % [tile.x, tile.y])

	var result := SignCommand.set_sign(app.document_state.city, tile, str(argument(arguments, 1, "")))

	if not result.ok:
		return fail("Cannot change the sign: %s." % result.error)

	app.tool_state.last_edit_command = result
	app.static_render.refresh_after_city_edit(result)

	return true


# the moving objects: { id, type, name, x, y, state }
func _city_things(_arguments: Array) -> Variant:
	if not need_city():
		return null

	var city := app.document_state.city
	var result := []

	for index in city.thing_count():
		var record := city.thing(index)

		if record == null or record.type == 0:
			continue

		result.append({"id": index, "type": record.type, "name": _thing_name(record.type), "x": record.x, "y": record.y,
			"state": record.state})

	return result


static func _thing_name(type: int) -> String:
	return QueryInfo.THING_NAMES[type] if type >= 0 and type < QueryInfo.THING_NAMES.size() else "Unknown"


# saves the city to its file. A city without a file needs Save As
func _city_save(_arguments: Array) -> Variant:
	if not need_city():
		return null

	var path := app.document_state.current_save_path

	if path.is_empty():
		return fail("The city has no file yet. Save it once from the File menu.")

	app.city_files.save_city()

	return path
