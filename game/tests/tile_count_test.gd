extends SceneTree
# SC2 cities keep the original running tile counts and their drift.
# Extended cities recount on load and each month, and keep exact counts.

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")


func _initialize() -> void:
	_check_count_rule()
	_check_load_and_month_recount()
	_check_dezone()
	_check_explosion()
	print("PASS: tile counts keep original drift in SC2 cities and stay exact in extended cities")
	quit()


func _saved(city: CityState) -> PackedInt32Array:
	var counts := PackedInt32Array()

	for tile_id in Tiles.COUNT:
		counts.append(city.document.misc_u32(Sc2MiscLayout.TILE_COUNTS + tile_id * 4))

	return counts


## Military-zone tiles use separate counts. Only changed counts are written.
func _check_count_rule() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(16))
	assert(CityTileCounts.exact(city) and not CityTileCounts.exact(CityState.from_document(EmptyCityTemplate.create(128))))
	assert(city.set_building_id(2, 2, Tiles.POLICE_STATION) and city.set_building_id(3, 3, Tiles.POLICE_STATION))
	assert(city.set_zone_id(3, 3, Sc2ZoneLayout.MILITARY))
	var counts := CityTileCounts.count(city)
	assert(counts[Tiles.POLICE_STATION] == 1, "A military-zone tile is not in the city tile counts")
	assert(counts[Tiles.EMPTY] == 16 * 16 - 2)
	assert(CityTileCounts.recount(city) == 2 and _saved(city) == counts)
	var revision := city.chunk_revision("MISC")
	assert(CityTileCounts.recount(city) == 0 and city.chunk_revision("MISC") == revision, "An exact recount does not change MISC")


func _check_load_and_month_recount() -> void:
	for edge in [128, 16]:
		var document := EmptyCityTemplate.create(edge)

		if edge == 128:
			var sc2x_document := EmptyCityTemplate.create(edge)
			assert(sc2x_document.enable_full_resolution_maps())
			_check_recount_timing(sc2x_document, true)

		_check_recount_timing(document, edge != 128)


func _check_recount_timing(document: Sc2File, exact: bool) -> void:
	var city := CityState.from_document(document)
	assert(CityTileCounts.exact(city) == exact)
	assert(city.set_building_id(1, 1, Tiles.TREES_1))
	var drifted := _saved(city)
	var engine := SimulationEngine.new(city, 123, 456, 789)
	assert(engine.initialize_loaded_city())
	assert((_saved(city) == CityTileCounts.count(city)) == exact, "Only an extended city recounts on load")
	assert((_saved(city) == drifted) != exact, "An SC2 city keeps its saved counts on load")

	# a change without a count update. the next month start corrects it in an extended city
	assert(city.set_building_id(2, 1, Tiles.TREES_1))
	drifted = _saved(city)
	var first_month_day := 0

	while first_month_day == 0:
		var day := engine.advance_day()
		assert(day.ok)

		if not day.interaction_requests.is_empty():
			day = engine.resolve_annual_budget(BudgetPhase.funding_values(city), true)
			assert(day.ok)

		if city.age_in_days() % CityCalendar.DAYS_PER_MONTH == 0:
			first_month_day = city.age_in_days()

			if exact:
				assert(day.timing.steps.has("tile recount"), "The recount is a timed step of the month start")
		else:
			assert(_saved(city)[Tiles.TREES_1] == drifted[Tiles.TREES_1], "No recount before the month starts")

	assert((_saved(city)[Tiles.TREES_1] == CityTileCounts.count(city)[Tiles.TREES_1]) == exact)


func _check_dezone() -> void:
	for edge in [128, 16]:
		var city := CityState.from_document(EmptyCityTemplate.create(edge))
		var point := Vector2i(4, 4)
		assert(city.set_zone_id(point.x, point.y, 1) and city.set_building_id(point.x, point.y, Tiles.RUBBLE_1))
		CityTileCounts.recount(city)
		var before := city.document.serialize().data
		var command := ZoneCommand.apply_rectangle(city, CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.DEZONE, point, point, false, true)
		assert(command.ok and city.building_id(point.x, point.y) == Tiles.EMPTY)
		var exact := _saved(city) == CityTileCounts.count(city)
		assert(exact == (edge != 128), "Only an extended city counts dezoned rubble")
		assert(ZoneCommand.undo(city, command).ok and city.document.serialize().data == before, "Undo restores the counts")


# the fire drift that the original has: an explosion clears its tile without a count change
func _check_explosion() -> void:
	for extended in [false, true]:
		var document := Sc2File.load_path("res://tests/fixtures/cities/generated-128.SC2")

		if extended:
			assert(document.enable_full_resolution_maps())

		var city := CityState.from_document(document)
		var engine := SimulationEngine.new(city, 123, 456, 789)
		assert(engine.initialize_loaded_city())
		CityTileCounts.recount(city)
		# Select an actual developed 1x1 tile. Spawn the explosion directly so this
		# rule does not depend on a particular city's fire spread or coordinates.
		var index := city.buildings.find(Tiles.LOWER_CLASS_HOMES_1X1_1)
		assert(index >= 0)
		var point := Vector2i(index / city.map_size, index % city.map_size)
		var things := document.find_chunk("XTHG").decoded_payload.duplicate()
		var text := city.text_overlays.duplicate()
		assert(DisasterMapState._spawn_explosion(text, things, point, city.land_altitude(point.x, point.y), 0, 0, city.map_size))
		assert(document.find_chunk("XTHG").set_decoded_payload(things))
		assert(document.find_chunk("XTXT").set_decoded_payload(text))
		city.resync_mirrors(["XTXT"])

		for tick in 3:
			assert(engine.advance_moving_things(tick * 200).ok)

		assert(city.building_id(point.x, point.y) == Tiles.EMPTY, "The explosion clears the selected building")

		assert((_saved(city) == CityTileCounts.count(city)) == extended, "Only an extended city counts explosion clearing")
