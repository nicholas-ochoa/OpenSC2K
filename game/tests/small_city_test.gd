extends SceneTree

@warning_ignore_start("integer_division")

var checks := 0
var failures := 0


func _init() -> void:
	for edge in [16, 32, 64]:
		for native in [false, true]:
			check_storage(edge, native)
			check_growth_and_facilities(edge, native)
		check_terrain(edge)
		check_vehicles(edge)
		print("PASS: small-map cases completed at %d" % edge)
	print("Small city: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func fixture(edge: int, native := false) -> Sc2File:
	var doc := EmptyCityTemplate.create(edge)
	if native:
		check(doc.enable_full_resolution_maps(), "Enable per-tile data maps")
	return doc


func check_storage(edge: int, native: bool) -> void:
	var doc := fixture(edge, native)
	var city := CityState.from_document(doc)
	check(city.is_valid() and doc.is_extended(), "Small map uses valid SC2X state")
	check(city.microsim_count() == 150 and ThingData.count(doc.find_chunk("XTHG").decoded_payload) == 40,
		"Small maps retain original facility and moving-object capacity")
	check(doc.decoded_size("XLAB") == 6400 and doc.decoded_size("XTXT") == edge * edge,
		"Small maps retain original labels and byte overlay IDs")
	check(not city.set_text_overlay_id(0, 0, 256), "Reject overlay IDs that do not fit storage")
	var unknown := Sc2Chunk.new()
	unknown.chunk_id = "TEST"
	unknown.set_decoded_payload(PackedByteArray([7, 9, 23]))
	doc.chunks.append(unknown)
	for id in Sc2File.HALF_MAP_CHUNKS + Sc2File.QUARTER_MAP_CHUNKS:
		var chunk := doc.find_chunk(id)
		var data := chunk.decoded_payload.duplicate()
		for index in data.size():
			data[index] = (index * 17) % 256
		chunk.set_decoded_payload(data)
	var bytes: PackedByteArray = doc.serialize().data
	check(bytes.slice(8, 12).get_string_from_ascii() == "SCLG", "Small map writes SIZE header")
	var loaded := Sc2File.new()
	check(loaded.parse(bytes) and loaded.map_size == edge and loaded.full_resolution_maps() == native,
		"Small-map format reloads with its grid mode")
	check(loaded.serialize(true).data == bytes, "Small map rebuild preserves exact bytes and unknown chunks")
	for turn in 4:
		check(CityRotationCommand.apply(city, false).ok, "Small map rotation succeeds")
	check(doc.serialize().data == bytes, "Four turns preserve every data grid")
	var path := "user://small-city-%d-%d" % [edge, int(native)]
	var saved := CityFileStore.save_copy(doc, path, "res://../references")
	check(saved.ok and saved.path.ends_with(".sc2x"), "Small map defaults to SC2X extension")
	if saved.ok:
		check(Sc2File.load_path(saved.path).serialize(true).data == bytes, "Small map survives disk save and reload")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(saved.path))
	check(not CityFileStore.save_copy(doc, path + ".SC2", "res://../references").ok, "Small map rejects original format")
	var invalid := bytes.duplicate()
	invalid[23] = 1
	check(not Sc2File.new().parse(invalid), "Small map rejects legacy SCLG version one")
	invalid = bytes.duplicate()
	invalid[27] = 8
	check(not Sc2File.new().parse(invalid), "Small map rejects unsupported size")


func check_growth_and_facilities(edge: int, native: bool) -> void:
	var doc := fixture(edge, native)
	var city := CityState.from_document(doc)
	var original: PackedByteArray = doc.serialize().data
	var built := BuildingCommand.apply(city, 13, 0, Vector2i(edge - 4, edge - 4), SimLfsrRandom.new(1), SimRandom.new(1))
	check(built.ok, "Small map places a police station with facility state")
	check(PollutionPhase.run(city).ok, "Small map computes clipped service coverage")
	check(doc.find_chunk("XPLC").decoded_payload.count(0) < doc.decoded_size("XPLC"), "Station supplies coverage")
	# Use a fresh transaction so simulation changes do not enter the Undo check.
	city = CityState.from_document(fixture(edge, native))
	built = BuildingCommand.apply(city, 13, 0, Vector2i(edge - 4, edge - 4), SimLfsrRandom.new(1), SimRandom.new(1))
	check(
		built.ok and BuildingCommand.undo(city, built, SimLfsrRandom.new(1), SimRandom.new(1)).ok,
		"Small facility placement supports Undo",
	)
	check(city.document.serialize().data == original, "Facility Undo preserves exact bytes")


func check_terrain(edge: int) -> void:
	for random_seed in [123]:
		# Representative resampling shapes: dry ground, channel, islands, coast, lakes.
		for layout in (["classic", "branch", "islands", "cliffs", "lakes"] if edge == 16 else ["classic"]):
			var doc := fixture(edge)
			var result := NewCityTerrain.generate(doc, true, true, 12, 5, 0,
				SimRandom.new(random_seed), GameLcgRandom.new(random_seed), layout)
			check(result.ok, "Small terrain layout %s at %d seed %d" % [layout, edge, random_seed])
			if layout == "classic":
				var repeat_doc := fixture(edge)
				var repeat_result := NewCityTerrain.generate(repeat_doc, true, true, 12, 5, 0,
					SimRandom.new(random_seed), GameLcgRandom.new(random_seed), layout)
				check(_terrain_result_values(repeat_result) == _terrain_result_values(result)
					and repeat_doc.serialize().data == doc.serialize().data,
					"Small terrain layout and seed are deterministic")
	for slider in [0, 47]:
		var result := NewCityTerrain.generate(fixture(edge), false, false, slider, slider, slider,
			SimRandom.new(123), GameLcgRandom.new(456))
		check(result.ok, "Small terrain accepts slider endpoints")
		if slider == 47:
			check(result.tree_tiles > 0, "Small terrain retains forest generation")


# the native spawner and tick rules have their own unit tests. check that the
# small-map record pool ticks and that the debug actions accept it
func check_vehicles(edge: int) -> void:
	var doc := fixture(edge)
	var city := CityState.from_document(doc)
	var spawned: Dictionary = NativeSimulationBridge.run("spawn_thing", city, SimRandom.new(1), SimLfsrRandom.new(1),
		GameLcgRandom.new(1), {"kind": 0, "points": [Vector2i(5, 5)], "view_center": Vector2i(5, 5)}).result
	check(spawned.count == 1, "Small map retains helicopter capacity")
	check(MovingThingPhase.run(city, SimRandom.new(1), SimLfsrRandom.new(1), GameLcgRandom.new(1)).ok,
		"Small-map vehicles tick safely")
	check(CityDebugActions._valid_disaster_chunks(doc.find_chunk("XTHG"), doc.find_chunk("XTXT"), doc.find_chunk("MISC"), edge),
		"Debug disaster actions accept the small-map record pool")


func _terrain_result_values(result: NewCityTerrain.Result) -> Array:
	return [result.ok, result.error,
		result.has_ocean, result.has_river, result.hills, result.water, result.trees,
		result.water_level, result.water_tiles, result.salt_water_tiles,
		result.tree_tiles, result.minimum_altitude, result.maximum_altitude]


class SequenceRandom extends SimRandom:
	var values: Array[int]
	var position := 0

	func _init(sequence: Array[int] = [0]) -> void:
		values = sequence

	func next_u15() -> int:
		var value := values[position % values.size()]
		position += 1
		return value


class SequenceLfsr extends SimLfsrRandom:
	var values: Array[int]
	var position := 0

	func _init(sequence: Array[int] = [0]) -> void:
		values = sequence

	func next_mod(limit: int) -> int:
		return _next() % limit

	func next_mask(mask: int) -> int:
		return _next() & mask

	func _next() -> int:
		var value := values[position % values.size()]
		position += 1
		return value


class SequenceGameLcg extends GameLcgRandom:
	var values: Array[int]
	var position := 0

	func _init(sequence: Array[int] = [0]) -> void:
		values = sequence

	func next_mod(limit: int) -> int:
		var value := values[position % values.size()]
		position += 1
		return value % limit
