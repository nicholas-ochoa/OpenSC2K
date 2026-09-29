extends SceneTree
## SC2X version 4: metadata rules, archive entries, capacities, conversion,
## signs, scenarios, saved simulation state, and verified saves.

@warning_ignore_start("integer_division")

const REQUIRED := Sc2xDocument.REQUIRED_ENTRIES
const FIXTURES := "res://tests/fixtures/cities"

var checks := 0
var failures := 0


func _initialize() -> void:
	_check_metadata()
	_check_schema_asset()
	_check_fresh_archives()
	_check_archive_rules()
	_check_conversion()
	_check_signs()
	_check_scenario()
	_check_resume()
	_check_identities()
	_check_saves()
	print("SC2X format: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(message)


func _minimal() -> Dictionary:
	return {
		"format": "OpenSC2K.SC2X",
		"file_version": 4,
		"map": {"size": 128},
		"city": {
			"name": "Example City",
			"mayor_name": "Mayor",
			"stadium_teams": ["Llamas", "Alpacas", "Camels", "Dromedaries", "Army Ants"],
		},
		"identity_counters": {"next_sign_id": 1, "next_object_id": 1},
		"simulation": {
			"rng_states": {"process_random": 1, "lfsr_random": 1, "game_random": 1},
			"phase_state": {},
		},
	}


func _parses(data: Dictionary) -> bool:
	return Sc2xMetadata.parse(JSON.stringify(data)).ok


func _check_metadata() -> void:
	var minimal := _minimal()
	var parsed := Sc2xMetadata.parse(JSON.stringify(minimal))
	_check(parsed.ok, "The minimal example of the plan parses: %s" % parsed.error)
	_check(parsed.ok and parsed.metadata.map_size == 128 and parsed.metadata.stadium_teams[4] == "Army Ants", "Metadata fields load")

	for key in ["format", "file_version", "map", "city", "identity_counters", "simulation"]:
		var missing := minimal.duplicate(true)
		missing.erase(key)
		_check(not _parses(missing), "Metadata without %s is rejected" % key)

	var no_state := minimal.duplicate(true)
	no_state.simulation.erase("phase_state")
	_check(not _parses(no_state), "Metadata without phase_state is rejected")

	for field in [["simulation", "rng_states", "process_random", 4294967296], ["simulation", "rng_states", "game_random", -1],
			["simulation", "rng_states", "lfsr_random", 0], ["simulation", "rng_states", "lfsr_random", 65536],
			["identity_counters", "next_sign_id", 0], ["map", "size", 65536], ["map", "size", 1.5]]:
		var wide := minimal.duplicate(true)

		if field.size() == 4:
			wide[field[0]][field[1]][field[2]] = field[3]
		else:
			wide[field[0]][field[1]] = field[2]

		_check(not _parses(wide), "Metadata rejects out-of-range value %s" % str(field))

	for bad_name in ["", "a".repeat(65)]:
		var named := minimal.duplicate(true)
		named.city.name = bad_name
		_check(not _parses(named), "Metadata rejects city name of %d characters" % bad_name.length())

	var long_name := minimal.duplicate(true)
	long_name.city.name = "\U01F999".repeat(64)
	_check(_parses(long_name), "A 64-character four-byte name is valid")
	var teams := minimal.duplicate(true)
	teams.city.stadium_teams.pop_back()
	_check(not _parses(teams), "Metadata needs five stadium teams")

	for removed in ["capacities", "manifest", "compression"]:
		var extra := minimal.duplicate(true)
		extra[removed] = {}
		_check(not _parses(extra), "Metadata rejects the removed %s field" % removed)

	var features := minimal.duplicate(true)
	features["required_features"] = ["future-layers"]
	var future := Sc2xMetadata.parse(JSON.stringify(features))
	_check(future.ok and future.metadata.unsupported_features() == PackedStringArray(["future-layers"]),
		"An unknown required feature is reported")
	features["required_features"] = ["a", "a"]
	_check(not _parses(features), "Required features are unique")

	var extended := minimal.duplicate(true)
	extended["extensions"] = {"tool": {"count": 3, "ratio": 0.5}}
	var round_trip := Sc2xMetadata.parse(JSON.stringify(extended))
	var written := round_trip.metadata.to_json() if round_trip.ok else ""
	_check(written.contains("\"count\": 3") and written.contains("0.5"), "Extension integers stay integers")
	_check(written.begins_with("{") and written.find("\"format\"") < written.find("\"city\""), "Metadata keeps its field order")
	_check(Sc2xMetadata.parse(written).ok, "Written metadata parses again")


func _check_schema_asset() -> void:
	var schema: Variant = JSON.parse_string(Sc2xMetadata.schema_bytes().get_string_from_utf8())
	_check(schema is Dictionary and schema["$id"] == "urn:opensc2k:sc2x:metadata:4", "The included schema has its identifier")
	_check(schema is Dictionary and schema.required == ["format", "file_version", "map", "city", "identity_counters", "simulation"],
		"The schema requires the essential metadata")


# Every supported map size: default capacities and exact entry sizes.
func _check_fresh_archives() -> void:
	for edge: int in Sc2File.MAP_SIZES:
		var created := Sc2xDocument.create_empty(edge, "Fresh %d" % edge)
		_check(created.ok, "A fresh %d city converts: %s" % [edge, created.error])

		if not created.ok:
			continue

		var document := created.document
		var profile := Sc2xDocument.profile(edge)
		var prepared := Sc2xDocument.entries(document)
		_check(prepared.ok, "A fresh %d city has entries" % edge)
		var members := prepared.members
		var cells := edge * edge
		_check(prepared.order[0] == "metadata.json" and prepared.order[1] == "metadata.schema.json", "Metadata and schema come first")

		for id in REQUIRED:
			_check(members.has(id + ".bin"), "Fresh %d city has %s.bin" % [edge, id])

		for name in ["CNAM.bin", "SIZE.bin", "FORM.bin"]:
			_check(not members.has(name), "Fresh city has no %s" % name)

		for id in Sc2xDocument.DENSE_ENTRIES:
			_check(members[id + ".bin"].size() == cells * Sc2xDocument.DENSE_ENTRIES[id], "%s is %d bytes per tile at %d" % [
				id, Sc2xDocument.DENSE_ENTRIES[id], edge])

		_check(members["XLAB.bin"].size() == 6400, "A fresh city writes a 6,400-byte compatibility table")
		_check(members["XMIC.bin"].size() == 28 + 32 * int(profile.facilities), "XMIC minimum size at %d" % edge)
		_check(members["XTHG.bin"].size() == 24 + 40 * int(profile.things), "XTHG minimum size at %d" % edge)
		_check(members["XSGN.bin"].size() == 24 + 20 * int(profile.signs), "XSGN minimum size at %d" % edge)
		_check(document.decoded_size("XTXT") == cells * 2, "The working tile index has two planes at %d" % edge)
		var city := CityState.from_document(document)
		_check(city.is_valid() and city.microsim_count() == int(profile.facilities) and city.thing_count() == int(profile.things),
			"The working city uses the %d profile capacities" % edge)


func _central_methods(bytes: PackedByteArray) -> Dictionary:
	var result := {}
	var end := bytes.size() - 22

	while end >= 0 and bytes.decode_u32(end) != 0x06054b50:
		end -= 1

	var position := bytes.decode_u32(end + 16)

	for _entry in bytes.decode_u16(end + 10):
		var name_size := bytes.decode_u16(position + 28)
		var name := bytes.slice(position + 46, position + 46 + name_size).get_string_from_utf8()
		result[name] = bytes.decode_u16(position + 10)
		position += 46 + name_size + bytes.decode_u16(position + 30) + bytes.decode_u16(position + 32)

	return result


func _archive(members: Dictionary[String, PackedByteArray], order: PackedStringArray) -> PackedByteArray:
	return ZipArchive.encode(order, members, 1 << 28, 1 << 28, true).bytes


func _loads(bytes: PackedByteArray) -> Sc2File:
	var document := Sc2File.new()
	document.parse(bytes)

	return document


func _check_archive_rules() -> void:
	var document := Sc2xDocument.create_empty(32).document
	var encoded := document.serialize()
	_check(encoded.ok and Sc2xDocument.is_archive(encoded.data), "A version 4 city is a ZIP archive")
	var methods := _central_methods(encoded.data)
	_check(methods.size() == 23 and methods.values().all(func(method: int) -> bool: return method == 8),
		"Every entry uses DEFLATE")
	_check(methods.keys().all(func(name: String) -> bool: return not name.contains("/")), "Every entry is at the root")
	var reloaded := _loads(encoded.data)
	_check(reloaded.is_valid() and reloaded.is_sc2x() and reloaded.serialize().data == encoded.data,
		"A version 4 file loads and saves the same bytes")
	var prepared := Sc2xDocument.entries(document)

	var with_extra := prepared.members.duplicate()
	var extra_order := prepared.order.duplicate()
	with_extra["notes.txt"] = "kept".to_utf8_buffer()
	with_extra["ABCD.bin"] = PackedByteArray([1, 2, 3])
	extra_order.append_array(["ABCD.bin", "notes.txt"])
	var extra := _loads(_archive(with_extra, extra_order))
	var extra_members := Sc2xDocument.entries(extra).members if extra.is_valid() else {}
	_check(extra.is_valid() and extra_members.get("notes.txt") == "kept".to_utf8_buffer()
		and extra_members.get("ABCD.bin") == PackedByteArray([1, 2, 3]), "Unknown optional entries survive a save")

	for prohibited in ["CNAM.bin", "SIZE.bin", "FORM.bin"]:
		var bad := prepared.members.duplicate()
		var order := prepared.order.duplicate()
		bad[prohibited] = PackedByteArray([0])
		order.append(prohibited)
		_check(not _loads(_archive(bad, order)).is_valid(), "%s is rejected" % prohibited)

	for required in ["metadata.json", "metadata.schema.json", "XSGN.bin", "MISC.bin"]:
		var missing := prepared.members.duplicate()
		var order := prepared.order.duplicate()
		missing.erase(required)
		order.remove_at(order.find(required))
		_check(not _loads(_archive(missing, order)).is_valid(), "A missing %s is rejected" % required)

	var folder := prepared.members.duplicate()
	var folder_order := prepared.order.duplicate()
	folder["extra/XBLD.bin"] = PackedByteArray([0])
	folder_order.append("extra/XBLD.bin")
	_check(not _loads(_archive(folder, folder_order)).is_valid(), "An entry in a folder is rejected")

	var short := prepared.members.duplicate()
	short["XBLD.bin"] = short["XBLD.bin"].slice(1)
	_check(not _loads(_archive(short, prepared.order)).is_valid(), "A dense entry of the wrong size is rejected")

	var markers := prepared.members.duplicate()
	var plane: PackedByteArray = markers["XTXT.bin"].duplicate()
	plane[5] = 51
	markers["XTXT.bin"] = plane
	_check(not _loads(_archive(markers, prepared.order)).is_valid(), "XTXT holds markers only")

	var corrupt := encoded.data.duplicate()
	var local_crc := 14
	corrupt[local_crc] ^= 0xff
	_check(not _loads(corrupt).is_valid(), "A CRC mismatch is rejected")

	var future := prepared.members.duplicate()
	var metadata := Sc2xMetadata.parse_bytes(future["metadata.json"]).metadata
	metadata.required_features = PackedStringArray(["future-layers"])
	future["metadata.json"] = metadata.to_bytes()
	var inspected := _loads(_archive(future, prepared.order))
	_check(inspected.is_valid() and not inspected.compatibility_error().is_empty(),
		"An unknown required feature allows inspection but reports a compatibility error")


func _check_conversion() -> void:
	for name in ["generated-128.SC2", "generated-256.sc2x"]:
		var legacy := Sc2File.load_path(FIXTURES.path_join(name))
		var before := legacy.serialize().data
		var converted := Sc2xDocument.from_legacy(legacy, name.get_basename())
		_check(converted.ok, "%s converts: %s" % [name, converted.error])

		if not converted.ok:
			continue

		var document := converted.document
		_check(legacy.serialize().data == before, "Conversion leaves the source document unchanged")
		_check(document.city_name() == legacy.city_name() and not document.city_name().is_empty(), "The city name moves to metadata")
		var legacy_city := CityState.from_document(legacy)
		var city := CityState.from_document(document)
		var legacy_signs := legacy_city.sign_texts()
		var signs := city.sign_texts()
		_check(signs == legacy_signs and not signs.is_empty(), "Every sign keeps its tile and text (%d signs)" % signs.size())
		_check(city.mayor_name() == legacy_city.mayor_name(), "The mayor name moves to metadata")
		var same_facilities := true

		for record in legacy_city.microsim_count():
			var old := legacy_city.microsim(record)

			if old.tile_id == 0:
				continue

			var new := city.microsim(record)
			same_facilities = same_facilities and new.tile_id == old.tile_id and new.stat_3 == old.stat_3
			same_facilities = same_facilities and (record == 0 or city.label(OverlayData.facility_id(record)) == legacy_city.label(OverlayData.facility_id(record)))

		_check(same_facilities, "Facility records and names keep their slots")
		var same_tiles := true

		for index in legacy_city.buildings.size():
			var old := OverlayData.read(legacy_city.text_overlays, index)

			if OverlayData.is_facility(old) or (old >= 241 and old <= 255):
				same_tiles = same_tiles and OverlayData.read(city.text_overlays, index) == old

		_check(same_tiles, "Facility links and markers keep their tiles")
		var encoded := document.serialize()
		var reloaded := _loads(encoded.data)
		_check(reloaded.is_valid() and Sc2xDocument.entries(reloaded).members == Sc2xDocument.entries(document).members,
			"A converted city saves and loads the same entries")
		var working_equal := true

		for chunk in document.chunks:
			var other := reloaded.find_chunk(chunk.chunk_id)
			working_equal = working_equal and other != null and (chunk.chunk_id == "TEXT" or other.decoded_payload == chunk.decoded_payload)

		_check(working_equal, "A load restores the working chunks exactly")


func _check_signs() -> void:
	var document := Sc2xDocument.create_empty(16).document
	var city := CityState.from_document(document)
	var point := Vector2i(3, 4)
	city.set_text_overlay_id(point.x, point.y, OverlayData.facility_id(12))
	var long_text := "\U01F999".repeat(64)
	var placed := SignCommand.set_sign(city, point, long_text)
	_check(placed.ok, "A sign shares a tile with a facility link: %s" % placed.error)
	_check(city.sign_texts().get(point.x * 16 + point.y) == long_text, "A 64-character sign keeps every character")
	_check(city.text_overlay_id(point.x, point.y) == OverlayData.facility_id(12), "A sign leaves the tile index unchanged")
	_check(not SignCommand.set_sign(city, Vector2i(5, 5), long_text + "x").ok, "A 65-character sign is rejected")
	var renamed := SignCommand.set_sign(city, point, "Main")
	_check(renamed.ok and city.sign_texts().size() == 1, "One sign per tile")
	_check(SignCommand.undo(city, renamed).ok and city.sign_texts().get(point.x * 16 + point.y) == long_text, "Sign undo restores text")
	var first_id := document.sc2x_metadata.next_sign_id

	for index in 15:
		SignCommand.set_sign(city, Vector2i(10, index), "S%d" % index)

	_check(city.sign_texts().size() == 16 and not SignCommand.set_sign(city, Vector2i(11, 0), "Over").ok,
		"New signs stop at the 16-sign budget")
	_check(document.sc2x_metadata.next_sign_id == first_id + 15, "Each new sign takes a new ID")
	var removed := SignCommand.set_sign(city, point, "")
	_check(removed.ok and not city.sign_texts().has(point.x * 16 + point.y), "Empty text removes a sign")
	_check(CityRotationCommand.apply(city, false).ok, "A city with signs rotates")
	_check(city.sign_texts().has(CityRotationCommand.rotate_point(Vector2i(10, 0), 16, false).x * 16
		+ CityRotationCommand.rotate_point(Vector2i(10, 0), 16, false).y), "Rotation moves signs with the map")
	var ids := NativeSc2x.decode_signs(document.find_chunk("XSGN").decoded_payload, 16)
	var saved := _loads(document.serialize().data)
	_check(NativeSc2x.decode_signs(saved.find_chunk("XSGN").decoded_payload, 16).ids == ids.ids, "Sign IDs survive a save")


func _legacy_scenario() -> Sc2File:
	var source := Sc2File.load_path(FIXTURES.path_join("generated-128.SC2"))
	var scenario := PackedByteArray()
	scenario.resize(52)
	BinaryData.write_u32_be(scenario, 0, 0x80000000)
	BinaryData.write_u16_be(scenario, 4, 3)
	scenario[6] = 100
	scenario[7] = 27
	BinaryData.write_u16_be(scenario, 8, 60)
	scenario[46] = 0xd2
	BinaryData.write_u16_be(scenario, 48, 65535)
	var template := PackedByteArray()
	template.resize(4)
	BinaryData.write_u32_be(template, 0, 0x80000000)

	for descriptor in [["Disaster Type", "DWRD"], ["Disaster XLoc", "DBYT"], ["Disaster YLoc", "DBYT"],
			["Time Limit (Months)", "DWRD"], ["City Size Goal", "DLNG"], ["Residential Goal", "DLNG"],
			["Commercial Goal", "DLNG"], ["Industrial Goal", "DLNG"], ["Cash Goal Funds-Bonds", "DLNG"],
			["Land Value Goal", "DLNG"], ["Pollution Limit", "DLNG"], ["Crime Limit", "DLNG"], ["Traffic Limit", "DLNG"],
			["Build Item One", "DBYT"], ["Build Item Two", "DBYT"], ["Item One Tiles", "DWRD"], ["Item Two Tiles", "DWRD"]]:
		template.append(str(descriptor[0]).length())
		template.append_array(str(descriptor[0]).to_ascii_buffer())
		template.append_array(str(descriptor[1]).to_ascii_buffer())

	for entry in [["TMPL", template], ["TEXT", PackedByteArray([0x80, 0, 0, 0, 65, 0, 9])], ["TEXT", PackedByteArray([0x81, 0, 0, 0, 66])],
			["SCEN", scenario], ["PICT", PackedByteArray([0x80, 0, 0, 0, 2, 0, 1, 0, 7, 8])], ["ZZ01", PackedByteArray([5])],
			["ZZ01", PackedByteArray([6])], ["MISC", source.find_chunk("MISC").decoded_payload]]:
		var chunk := Sc2Chunk.new()
		chunk.chunk_id = entry[0]
		chunk.decoded_payload = entry[1]
		chunk.stored_payload = entry[1]
		source.chunks.append(chunk)

	source.rebuild_chunk_cache()

	return source


func _check_scenario() -> void:
	var legacy := _legacy_scenario()
	var converted := Sc2xDocument.from_legacy(legacy)
	_check(converted.ok, "A scenario converts: %s" % converted.error)

	if not converted.ok:
		return

	var document := converted.document
	_check(document.find_chunk("SCEN").decoded_payload.size() == 64, "SCEN becomes schema 2")
	var state := ScenarioState.from_document(document)
	_check(state.is_valid() and state.disaster_x == 100 and state.disaster_y == 27 and state.time_limit_months == 60
		and state.first_building_tile_count == 65535 and state.life_expectancy_goal == 0, "Schema 2 keeps the 52-byte goals")
	var template := state.template_fields()
	_check(template.ok and template.scenario_size == 64 and template.fields[1].type_code == "DWRD"
		and template.fields[17].type_code == "DLNG", "TMPL describes schema 2")
	var texts := []

	for chunk in document.chunks:
		if chunk.chunk_id == "TEXT":
			texts.append(chunk.decoded_payload)

	_check(texts == [PackedByteArray([0x80, 0, 0, 0, 65, 0, 9]), PackedByteArray([0x81, 0, 0, 0, 66])],
		"Both TEXT payloads keep every byte and their order")
	_check(state.selection_description() == "A" and state.opening_description() == "B", "Scenario text roles stay readable")
	var preserved := document.sc2x_preserved.map(func(record: Dictionary) -> String:
		return "%s/%d/%d" % [record.chunk_id, record.occurrence, record.flags])
	_check(preserved == ["ZZ01/0/1", "ZZ01/1/1", "MISC/1/0"], "Repeated unknown chunks and a second MISC are preserved")
	var scenario := document.find_chunk("SCEN").decoded_payload.duplicate()
	BinaryData.write_u16_be(scenario, 6, 300)
	BinaryData.write_u32_be(scenario, 54, 70000)
	document.find_chunk("SCEN").set_decoded_payload(scenario)
	_check(not document.serialize().ok, "A disaster coordinate outside a 128 map is rejected")
	BinaryData.write_u16_be(scenario, 6, 127)
	document.find_chunk("SCEN").set_decoded_payload(scenario)
	var reloaded := _loads(document.serialize().data)
	var widened := ScenarioState.from_document(reloaded)
	_check(reloaded.is_valid() and widened.first_building_tile_count == 70000 and widened.set_time_limit_months(59)
		and ScenarioState.from_document(reloaded).time_limit_months == 59, "Building counts above 65,535 survive, and time counts down")
	var preserved_again := reloaded.sc2x_preserved.map(func(record: Dictionary) -> String:
		return "%s/%d/%d" % [record.chunk_id, record.occurrence, record.flags])
	_check(preserved_again == preserved, "Preserved chunks survive a save")


func _run(controller: GameSpeedController, ticks: int, start: int) -> void:
	for tick in ticks:
		controller.advance_time(200.0, start + tick * 200)


func _check_resume() -> void:
	var source := Sc2File.load_path(FIXTURES.path_join("generated-128.SC2"))
	var document := Sc2xDocument.from_legacy(source).document
	var engine := SimulationEngine.new(CityState.from_document(document), 12345, 777, 4242)
	engine.initialize_loaded_city()
	var controller := GameSpeedController.new(engine)
	controller.set_speed(GameSpeedController.Speed.CHEETAH)
	_run(controller, 40, 1000)
	_check(Sc2xCheckpoint.save_error(controller).is_empty(), "A completed day can be saved")
	Sc2xCheckpoint.capture(controller, document.sc2x_metadata)
	var reloaded := _loads(document.serialize().data)
	var resumed := GameSpeedController.new(SimulationEngine.new(CityState.from_document(reloaded), 1, 1, 1))
	_check(Sc2xCheckpoint.restore(resumed, reloaded.sc2x_metadata).is_empty(), "Saved state restores")
	resumed.set_speed(GameSpeedController.Speed.CHEETAH)
	_check(resumed.engine.random.state == engine.random.state and resumed.engine.lfsr_random.state == engine.lfsr_random.state
		and resumed.engine.game_random.state == engine.game_random.state, "The three random states survive a save")
	_run(controller, 40, 20000)
	_run(resumed, 40, 20000)
	_check(resumed.engine.city.document.content_snapshot() == engine.city.document.content_snapshot()
		and resumed.engine.random.state == engine.random.state, "A saved city continues exactly like the city that was not saved")
	engine.pending_interaction = "annual_budget"
	_check(not Sc2xCheckpoint.save_error(controller).is_empty(), "A day that waits for the player cannot be saved")
	var state := reloaded.sc2x_metadata.phase_state.duplicate()
	state.erase("mayor_approval")
	_check(not Sc2xCheckpoint.validate(state).is_empty(), "Incomplete saved state is rejected")


# the object ID that a save gives the slot
func _object_id(document: Sc2File, slot: int) -> int:
	var prepared := Sc2xDocument.entries(document)

	return int(document.sc2x_object_ids[slot]) if prepared.ok else -1


func _check_identities() -> void:
	var document := Sc2xDocument.from_legacy(Sc2File.load_path(FIXTURES.path_join("generated-128.SC2"))).document
	var chunk := document.find_chunk("XTHG")
	var slot := -1

	for record in range(1, ThingData.count(chunk.decoded_payload)):
		if chunk.decoded_payload[record * Sc2ThingLayout.RECORD_SIZE] != 0:
			slot = record
			break

	_check(slot > 0, "The fixture has a moving object")
	var first := _object_id(document, slot)
	document.reconcile_object_identities()
	_check(first > 0 and _object_id(document, slot) == first, "An object keeps its ID while its slot keeps it")
	var kind := chunk.decoded_payload[slot * Sc2ThingLayout.RECORD_SIZE]
	chunk.write_decoded_byte(slot * Sc2ThingLayout.RECORD_SIZE, 0)
	document.reconcile_object_identities()
	chunk.write_decoded_byte(slot * Sc2ThingLayout.RECORD_SIZE, kind)
	document.reconcile_object_identities()
	var second := _object_id(document, slot)
	_check(second > 0 and second != first, "A freed and reused slot gets a new object ID")
	var ids := {}

	for id in document.sc2x_object_ids:
		_check(id == 0 or not ids.has(id), "Object IDs stay unique")
		ids[id] = true


func _check_saves() -> void:
	var document := Sc2xDocument.create_empty(16).document
	var path := "user://sc2x-format-%d.sc2x" % OS.get_process_id()
	var saved := CityFileStore.save_copy(document, path, "")
	_check(saved.ok and FileAccess.file_exists(path), "A version 4 save writes the file: %s" % saved.error)
	var first := FileAccess.get_file_as_bytes(path)
	document.sc2x_metadata.city_name = "Second Name"
	_check(CityFileStore.save_copy(document, path, "").ok and FileAccess.get_file_as_bytes(path) != first, "A save replaces the file")
	_check(Sc2File.load_path(path).city_name() == "Second Name", "The saved name loads")
	var bad := CityFileStore.write_verified(path, PackedByteArray([1, 2, 3]), Sc2xDocument.entries(document))
	_check(not bad.ok and Sc2File.load_path(path).city_name() == "Second Name", "A failed check keeps the previous save")
	var leftovers := Array(DirAccess.get_files_at("user://")).filter(func(name: String) -> bool: return name.ends_with(".tmp"))
	_check(leftovers.is_empty(), "A failed save removes its temporary file")
	# a worker thread writes the content that prepare copied, even when the city changes meanwhile
	var prepared := CityFileStore.prepare(document, path, "")
	document.sc2x_metadata.city_name = "Changed After Prepare"
	document.find_chunk("XBLD").write_decoded_byte(0, 0x2b)
	var task := WorkerThreadPool.add_task(func() -> void: prepared.set_meta("result", CityFileStore.write(prepared)))
	WorkerThreadPool.wait_for_task_completion(task)
	var background: FileWriteResult = prepared.get_meta("result")
	var written := Sc2File.load_path(path)
	_check(prepared.ok and background.ok and written.city_name() == "Second Name" and written.find_chunk("XBLD").decoded_payload[0] == 0,
		"A background save writes the prepared content")
	_check(prepared.snapshot == Sc2xDocument.content_digest(written) and prepared.snapshot != document.content_snapshot(),
		"The prepared snapshot matches the saved file, not the later changes")
	document.sc2x_converted_from = ProjectSettings.globalize_path(path)
	_check(not CityFileStore.save_copy(document, path, "").ok, "A converted city never replaces its source file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
