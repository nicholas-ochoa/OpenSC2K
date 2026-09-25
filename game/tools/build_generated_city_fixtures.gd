extends SceneTree
## Build independent fixtures with terrain, edit commands, and five simulation years.

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

var random: SimRandom
var lfsr: SimLfsrRandom
var names := RandomNumberGenerator.new()
var command_failed := false
var city: CityState
var destination_hashes: Dictionary[String, String] = {}


func _init() -> void:
	var root := GeneratedCityFixture.ROOT
	var regenerate := false
	var selected := GeneratedCityFixture.SIZES.duplicate()

	for argument in OS.get_cmdline_user_args():
		if argument == "--regenerate":
			regenerate = true
		elif argument.begins_with("--output="):
			root = argument.trim_prefix("--output=")
		elif argument.begins_with("--size="):
			selected = [int(argument.trim_prefix("--size="))]
		else:
			push_error("Unknown argument: " + argument)
			quit(1)
			return

	# Preflight every destination before generating or writing any output.
	for edge in selected:
		assert(edge in GeneratedCityFixture.SIZES, "Unsupported fixture size")
		var path := GeneratedCityFixture.path(edge, root)

		for destination in [path, path + ".json"]:
			destination_hashes[destination] = FileAccess.get_sha256(destination) if FileAccess.file_exists(destination) else ""

		if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".json"):
			var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ".json"))

			if not regenerate or not FileAccess.file_exists(path) or not report is Dictionary or report.get("output_sha256", "") != FileAccess.get_sha256(path):
				push_error("Refuse to overwrite an existing or edited fixture. Use --regenerate only for unchanged fixtures: " + path)
				quit(1)
				return

	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)) == OK)

	for edge in selected:
		if not build(edge, root):
			quit(1)
			return

	quit()


func build(edge: int, root: String) -> bool:
	command_failed = false
	random = SimRandom.new(17000 + edge)
	lfsr = SimLfsrRandom.new(23000 + edge)
	names.seed = 31000 + edge
	var game_random := GameLcgRandom.new(29000 + edge)
	var options := NewCityTerrain.Options.new()
	options.hills = 0
	options.water = 0
	options.trees = 15
	options.ocean = true
	options.river = true
	options.features = ["lake"]
	var created := NewCitySetup.create(EmptyCityTemplate.create(edge), CityNameGenerator.generate("lake", names),
		"Test Mayor", 1, 2050, random, game_random, options)
	assert(created.ok, created.error)

	if edge > 128:
		assert(created.document.enable_full_resolution_maps())

	city = CityState.from_document(created.document)
	city.set_funds(100000000)
	city.set_auto_budget_enabled(true)
	city.set_no_disasters_enabled(true)
	# The normal 2050 setup retains later inventions. Use the game's explicit unlock action.
	assert(CityDebugActions.unlock_everything(city, city.document).ok)
	# A stream on a natural hill supplies a waterfall for the hydro command.
	var summit := Vector2i(2, 2)

	for x in range(2, edge - 2):
		for y in range(2, edge - 2):
			if city.land_altitude(x, y) > city.land_altitude(summit.x, summit.y):
				summit = Vector2i(x, y)

	assert(LandscapeEditorCommand.apply(city, 1, 2, summit, random).ok)
	assert(ensure_waterfall(), "Terrain must include a hydro site")
	var sites: Array[Vector2i] = []

	for x in range(2, edge - 18, 16):
		for y in range(2, edge - 18, 16):
			if clear_site(Rect2i(x, y, 16, 16)):
				sites.append(Vector2i(x, y))

	assert(sites.size() >= 16, "Terrain must have enough district sites")
	var count := mini(sites.size(), edge / 4)
	var chosen: Array[Vector2i] = []

	for index in count:
		chosen.append(sites[index * sites.size() / count])

	var facilities := [[3, 2], [3, 4], [3, 6], [3, 8], [3, 10], [4, 2], [4, 3],
		[12, 0], [12, 1], [12, 2], [12, 3], [13, 0], [13, 1], [13, 2], [13, 3],
		[14, 2], [14, 3], [5, 5], [5, 6], [5, 7], [5, 8], [6, 4], [7, 2]]
	var facility_index := 0

	for index in chosen.size():
		var base := chosen[index]
		# The first site is a transport interchange. Other districts have local utilities.
		if index == 0:
			transport(base)
			continue

		for y in [0, 8, 15]:
			network(6, 0, base + Vector2i(0, y), base + Vector2i(15, y))

		for x in [0, 15]:
			network(6, 0, base + Vector2i(x, 0), base + Vector2i(x, 15))

		building(3, 8, base + Vector2i(1, 1))
		building(4, 1, base + Vector2i(5, 1))
		network(3, 0, base + Vector2i(5, 4), base + Vector2i(5, 14))
		network(3, 0, base + Vector2i(1, 7), base + Vector2i(14, 7))
		network(4, 0, base + Vector2i(5, 1), base + Vector2i(5, 14))
		network(4, 0, base + Vector2i(1, 7), base + Vector2i(14, 7))

		if facility_index < facilities.size():
			for offset in [Vector2i(9, 1), Vector2i(9, 10)]:
				if facility_index == facilities.size():
					break

				var tool: Array = facilities[facility_index]
				building(tool[0], tool[1], base + offset)
				facility_index += 1

		var group := 9 + (index % 3)
		var density := (index / 3) % 2
		assert(ZoneCommand.apply_rectangle(city, group, density, base + Vector2i(1, 1), base + Vector2i(14, 6)).ok)
		assert(ZoneCommand.apply_rectangle(city, group, density, base + Vector2i(1, 9), base + Vector2i(14, 14)).ok)

		if index <= 6:
			assert(SignCommand.set_sign(city, base, CityNameGenerator.generate("classic", names)).ok)

	# Port zones need space to develop their large structures.
	for index in [chosen.size() - 2, chosen.size() - 1]:
		var base := chosen[index]
		assert(ZoneCommand.apply_rectangle(city, 8, index % 2, base + Vector2i(6, 1), base + Vector2i(14, 6)).ok)

	assert(not command_failed, "A district edit failed; no file was written")
	assert(add_landmark_routes(), "All landmark commands must succeed")
	assert(DispatchCommand.apply(city, 2, 0, chosen[6] + Vector2i(1, 0)).ok)
	print("Built %d districts at %d" % [chosen.size(), edge])
	var engine := SimulationEngine.new(city, random.state, lfsr.state, game_random.state)
	assert(engine.initialize_loaded_city())

	for day in GeneratedCityFixture.DAYS:
		var result := engine.advance_day()
		assert(result.ok, result.error)

		while not engine.pending_interaction.is_empty():
			assert(engine.pending_interaction == "military_proposal")
			assert(engine.resolve_military_proposal(false).ok)

		assert(engine.advance_moving_things(day * 200).ok)

		if (day + 1) % CityCalendar.DAYS_PER_YEAR == 0:
			print("%d year %d population %d" % [edge, city.current_year(), city.population()])

	assert(city.age_in_days() == GeneratedCityFixture.DAYS)
	print("Coverage ", GeneratedCityFixture.counts(city))
	var coverage := GeneratedCityFixture.validate(city.document, edge)
	assert(not coverage.is_empty(), "Fixture validation failed; no file was written")
	var path := GeneratedCityFixture.path(edge, root)
	for destination in [path, path + ".json"]:
		var current := FileAccess.get_sha256(destination) if FileAccess.file_exists(destination) else ""
		assert(current == destination_hashes[destination], "Destination changed during generation: " + destination)

	var data: PackedByteArray = city.document.serialize().data
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	output.store_buffer(data)
	output.close()
	var report := {"seed": 17000 + edge, "lfsr_seed": 23000 + edge, "game_seed": 29000 + edge,
		"name_seed": 31000 + edge, "size": edge, "format": "SC2" if edge == 128 else "SC2X",
		"simulation_days": GeneratedCityFixture.DAYS, "starting_year": 2050, "counts": coverage,
		"output_sha256": FileAccess.get_sha256(path)}
	output = FileAccess.open(path + ".json", FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	print("PASS: generated ", path)
	return true


func clear_site(site: Rect2i) -> bool:
	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var index := city.index_of(x, y)

			if index < 0 or city.terrain[index] != 0 or city.tile_flags[index] & Sc2TileFlags.WATER or city.buildings[index] >= Tiles.FIRST_ROAD:
				return false

	return true


func building(group: int, tool: int, origin: Vector2i) -> void:
	var area := int(ToolCatalog.tool(group, tool).area)
	var point := origin + (Vector2i.ONE if area > 2 else Vector2i.ZERO)
	var result := BuildingCommand.apply(city, group, tool, point, lfsr, random)
	command_failed = command_failed or not result.ok
	assert(result.ok, "Building %d/%d at %s: %s" % [group, tool, origin, result.error])


func network(group: int, tool: int, start: Vector2i, finish: Vector2i) -> void:
	var result := NetworkCommand.apply(city, group, tool, start, finish)
	command_failed = command_failed or not result.ok
	assert(result.ok, "Network %d/%d: %s" % [group, tool, result.error])


func transport(base: Vector2i) -> void:
	assert(HighwayCommand.apply(city, 6, 1, base + Vector2i(2, 2), base + Vector2i(12, 2), 0).ok)

	for x in [4, 10]:
		network(6, 0, base + Vector2i(x, 4), base + Vector2i(x, 7))
		assert(OnrampCommand.apply(city, 6, 3, base + Vector2i(x + 1, 4)).ok)

	network(7, 0, base + Vector2i(1, 9), base + Vector2i(14, 9))
	building(7, 2, base + Vector2i(2, 10))
	network(7, 1, base + Vector2i(1, 14), base + Vector2i(14, 14))
	building(7, 3, base + Vector2i(1, 14))
	building(7, 3, base + Vector2i(14, 14))


func add_landmark_routes() -> bool:
	var bridge := false
	var tunnel := false
	var marina := false
	var hydro := false

	for x in range(2, city.map_size - 4):
		for y in range(2, city.map_size - 4):
			var point := Vector2i(x, y)
			var index := city.index_of(x, y)

			if not marina and BuildingCommand.preview_error(city, 14, 4, point).is_empty():
				marina = BuildingCommand.apply(city, 14, 4, point, lfsr, random).ok

			if not hydro and city.terrain[index] in [0x2e, 0x3e]:
				hydro = HydroCommand.apply(city, 3, 3, point, random).ok

			if not tunnel and city.terrain[index] in [1, 2, 3, 4] and city.buildings[index] < Tiles.FIRST_ROAD:
				tunnel = TunnelCommand.apply(city, 6, 2, point, TunnelCommand.CONFIRMATION_CONFIRMED).ok

			if not bridge and city.terrain[index] == 0 and not city.tile_flags[index] & Sc2TileFlags.WATER:
				for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
					var next: Vector2i = point + direction

					if city.tile_flags[city.index_of(next.x, next.y)] & Sc2TileFlags.WATER:
						var result := NetworkCommand.apply(city, 6, 0, point, next, NetworkCommand.BRIDGE_ROAD_CAUSEWAY)
						bridge = result.ok and GeneratedCityFixture.counts(city).bridges > 0

			if bridge and tunnel and marina and hydro:
				return true

	print("Landmarks: bridge=%s tunnel=%s marina=%s hydro=%s" % [bridge, tunnel, marina, hydro])

	return false


func ensure_waterfall() -> bool:
	if city.terrain.has(0x2e) or city.terrain.has(0x3e):
		return true

	for x in range(2, city.map_size - 2):
		for y in range(2, city.map_size - 2):
			if city.terrain_id(x, y) not in [1, 2, 3, 4]:
				continue

			var stream := LandscapeEditorCommand.apply(city, 1, 2, Vector2i(x, y), random)

			if not stream.ok:
				continue

			if city.terrain.has(0x2e) or city.terrain.has(0x3e):
				return true

			assert(TerrainCommand.undo(city, stream, random).ok)

	return false
