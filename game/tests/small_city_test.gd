extends SceneTree

@warning_ignore_start("integer_division")

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
	for rotation in 4:
		for density in range(2, 5):
			var city := CityState.from_document(fixture(edge, native))
			var p := GrowthState.payloads(city)
			var radius := density / 2
			var anchor := Vector2i(edge - 2 - radius, edge - 2 - radius)
			check(GrowthDevelopment.place_zone(p.XBLD, p.XZON, p.XBIT, p.MISC, p.XVAL,
				anchor, density, GrowthConstants.CLASS_CONSTRUCTION, SequenceRandom.new(), rotation, edge),
				"Small map grows each density at its interior edge")
			var count := 0
			for tile in p.XBLD:
				count += int(tile != 0)
			check(count == (radius + 1) * (radius + 1), "Small-map growth has the full footprint")
			var before: PackedByteArray = p.XBLD.duplicate()
			check(not GrowthDevelopment.place_zone(p.XBLD, p.XZON, p.XBIT, p.MISC, p.XVAL,
				anchor + Vector2i.ONE, density, GrowthConstants.CLASS_CONSTRUCTION, SequenceRandom.new(), rotation, edge),
				"Small-map growth rejects the outside margin")
			check(p.XBLD == before, "Rejected growth preserves map bytes")
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
	check(built.ok and BuildingCommand.undo(city, built, SimLfsrRandom.new(1), SimRandom.new(1)).ok, "Small facility placement supports Undo")
	check(city.document.serialize().data == original, "Facility Undo preserves exact bytes")


func check_terrain(edge: int) -> void:
	for seed in [123]:
		# Representative resampling shapes: dry ground, channel, islands, coast, lakes.
		for layout in (["classic", "branch", "islands", "cliffs", "lakes"] if edge == 16 else ["classic"]):
			var doc := fixture(edge)
			var result := NewCityTerrain.generate(doc, true, true, 12, 5, 0,
				SimRandom.new(seed), GameLcgRandom.new(seed), layout)
			check(result.ok, "Small terrain layout %s at %d seed %d" % [layout, edge, seed])
			if layout == "classic":
				var repeat_doc := fixture(edge)
				var repeat_result := NewCityTerrain.generate(repeat_doc, true, true, 12, 5, 0,
					SimRandom.new(seed), GameLcgRandom.new(seed), layout)
				check(repeat_result == result and repeat_doc.serialize().data == doc.serialize().data,
					"Small terrain layout and seed are deterministic")
	for slider in [0, 47]:
		var result := NewCityTerrain.generate(fixture(edge), false, false, slider, slider, slider,
			SimRandom.new(123), GameLcgRandom.new(456))
		check(result.ok, "Small terrain accepts slider endpoints")
		if slider == 47:
			check(result.tree_tiles > 0, "Small terrain retains forest generation")


func check_vehicles(edge: int) -> void:
	for direction in 4:
		for coordinate_roll in [0, 32767]:
			var doc := fixture(edge)
			var things := doc.find_chunk("XTHG").decoded_payload.duplicate()
			var text := doc.find_chunk("XTXT").decoded_payload.duplicate()
			var random := SequenceRandom.new([0, direction, coordinate_roll])
			var result := MovingThingSpawner.spawn_airplane(things, text, Vector2i(5, 5), 0, random, edge)
			check(result.spawned, "Small map admits an incoming airplane")
			var point: Vector2i = result.point
			check(point.x >= 0 and point.y >= 0 and point.x < edge and point.y < edge,
				"Aircraft entry from every edge stays inside small map")
			check(random.position == 3, "Aircraft entry preserves random-call count")
	var doc := fixture(edge)
	var city := CityState.from_document(doc)
	var things := doc.find_chunk("XTHG").decoded_payload.duplicate()
	var text := city.text_overlays.duplicate()
	var point := Vector2i(5, 5)
	check(MovingThingSpawner.spawn_helicopter(things, text, point, SimRandom.new(1), edge).spawned,
		"Small map retains helicopter capacity")
	check(not MovingThingSpawner.spawn_helicopter(things, text, point + Vector2i.ONE, SimRandom.new(1), edge).spawned,
		"Small map retains the one-helicopter limit")
	things.fill(0)
	text.fill(0)
	var terrain := city.terrain.duplicate()
	terrain.fill(0x10)
	check(MovingThingSpawner.spawn_ship(terrain, things, text, point, SequenceRandom.new(), edge).spawned,
		"Small map retains cargo ship capacity")
	things.fill(0)
	text.fill(0)
	var flags := city.tile_flags.duplicate()
	flags.fill(4)
	check(MovingThingSpawner.spawn_sailboats(city.buildings, flags, things, text, point, SequenceLfsr.new(), edge) == 4,
		"Small map retains four sailboats")
	check(MovingThingSpawner.spawn_sailboats(city.buildings, flags, things, text, point + Vector2i(3, 3), SequenceLfsr.new(), edge) == 0,
		"Small map enforces its sailboat limit")
	doc.find_chunk("XTHG").set_decoded_payload(things)
	city.replace_text_overlays(text)
	city.replace_tile_flags(flags)
	check(MovingThingPhase.run(city, SimRandom.new(1), SimLfsrRandom.new(1), GameLcgRandom.new(1)).ok,
		"Small-map sailboats tick safely")
	check(CityDebugActions._valid_disaster_chunks(doc.find_chunk("XTHG"), doc.find_chunk("XTXT"), doc.find_chunk("MISC"), edge),
		"Debug disaster actions accept the small-map record pool")

	for start in [Vector2i(edge - 4, edge - 4), Vector2i(edge - 3, edge - 3)]:
		var p := GrowthState.payloads(CityState.from_document(fixture(edge)))
		for delta in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var track: Vector2i = start + delta
			p.XBLD[track.x * edge + track.y] = 0x2c
		var spawned := MovingThingSpawner._spawn_train_record(p.XBLD, p.XTHG, p.XTXT,
			start, SequenceGameLcg.new(), SequenceLfsr.new(), edge)
		check(spawned == (start.x == edge - 4), "Small-map trains retain capacity and edge margins")
