extends SceneTree

var failures := 0


func _init() -> void:
	for edge in Sc2File.MAP_SIZES:
		check_highways(edge)
		check_size(edge)
		check_large_counts(edge)

	check_format_guards()
	print("Large city checks: %d failures" % failures)
	quit(1 if failures else 0)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func check_size(edge: int) -> void:
	print("Checking %d" % edge)
	if edge == 128:
		var session := NewCityTerrainSession.new()
		session.independent_template = true
		session.begin(123, 456)
		var options := {"size": edge, "ocean": false, "river": true, "hills": 12, "water": 5, "trees": 15}
		var preview := session.generate_preview("", options, false)
		check(preview.ok and preview.city.map_size == edge, "Preview size")
		var created := session.create_city("", "Large City", "Mayor", 1, 1900, options, PackedByteArray())
		check(created.ok and created.document.map_size == edge, "UI creation size")
		check(preview.document.find_chunk("ALTM").decoded_payload == created.document.find_chunk("ALTM").decoded_payload, "Preview matches created terrain")
	var document := EmptyCityTemplate.create(edge)
	var city := CityState.from_document(document)
	check(city.map_size == edge, "City size")
	check(city.index_of(edge - 1, edge - 1) == edge * edge - 1, "Far corner index")
	check(city.index_of(edge, 0) == -1, "Outside map")
	check(city.set_building_id(edge - 2, edge - 2, 0x1d), "Far road edit")
	var saved := document.serialize()
	var loaded := Sc2File.new()
	check(loaded.parse(saved.data), "Reload: " + loaded.parse_error)
	check(loaded.map_size == edge, "Reload size")
	check(loaded.serialize(true).data == saved.data, "Byte round trip")
	check(CityState.from_document(loaded).building_id(edge - 2, edge - 2) == 0x1d, "Reload far road")
	var corner := Vector2i(edge - 10, edge - 10)
	var road := NetworkCommand.apply(city, 6, 0, corner, corner + Vector2i(0, 4))
	check(road.ok, "Far road tool: " + road.error)
	check(NetworkCommand.undo(city, road).ok, "Far road undo")
	var sign := SignCommand.set_sign(city, corner, "Far corner")
	check(sign.ok and SignCommand.undo(city, sign).ok, "Far sign and undo")
	var points: Array[Vector2i] = [corner]
	var raised := TerrainCommand.apply_path(city, 0, 2, corner, points, SimRandom.new(1), true)
	check(raised.ok, "Far terrain edit: " + raised.error)
	check(TerrainCommand.undo(city, raised).ok, "Far terrain undo")
	var polygon := CityIsometricRenderer.tile_polygon(city, corner.x, corner.y)
	var center := (polygon[0] + polygon[1] + polygon[2] + polygon[3]) * 0.25
	check(CityIsometricRenderer.screen_to_tile(city, center) == corner, "Far pointer hit test")
	var things := document.find_chunk("XTHG").decoded_payload.duplicate()
	var text := city.text_overlays.duplicate()
	var spawned := MovingThingSpawner.spawn_helicopter(things, text, corner, SimRandom.new(5), edge)
	check(spawned.spawned, "Far helicopter spawn")
	document.find_chunk("XTHG").set_decoded_payload(things)
	city.replace_text_overlays(text)
	var record: int = spawned.record
	check(city.thing(record).x == corner.x and city.thing(record).y == corner.y, "Wide object coordinates")
	var moving := MovingThingPhase.run(city, SimRandom.new(1), SimLfsrRandom.new(1), GameLcgRandom.new(1))
	check(moving.ok, "Moving phase: " + moving.error)
	var rotated := CityRotationCommand.apply(city, false)
	check(rotated.ok, "Rotation: " + rotated.get("error", ""))
	var rotated_thing := city.thing(record)
	check(rotated_thing.x == edge - 1 - corner.y and rotated_thing.y == corner.x, "Wide object rotation")
	var wide_reload := Sc2File.new()
	check(wide_reload.parse(document.serialize().data), "Wide record reload")
	check(CityState.from_document(wide_reload).thing(record).equals(city.thing(record)), "Wide record preserved")
	check(CityViewFilter.surface_copy(city, {}).map_size == edge, "Display copy size")


func check_format_guards() -> void:
	var document := EmptyCityTemplate.create(512)
	var bytes: PackedByteArray = document.serialize().data
	var invalid := bytes.duplicate()
	invalid[23] = 99
	check(not Sc2File.new().parse(invalid), "Reject unknown format version")
	invalid = bytes.duplicate()
	invalid[27] = 1
	check(not Sc2File.new().parse(invalid), "Reject unsupported dimension")
	invalid = bytes.duplicate()
	invalid[11] = 0x48
	check(not Sc2File.new().parse(invalid), "Reject large chunks under SCDH")
	var refused := CityFileStore.save_copy(document, "user://large-city-must-not-write.SC2", "res://../references/SIMCITY2000")
	check(not refused.ok, "Reject original-game save extension")
	check(not document.resize_empty_map(129), "Reject unsupported resize")
	var image := Image.create(16448, 16, false, Image.FORMAT_RGBA8)
	var source := CityMapTexture.create(image)
	check(source.size == Vector2i(16448, 16) and source.texture == null, "Large texture extent")
	var tiles := source.tiles
	check(tiles.size() == 5, "Large image uses bounded GPU tiles")

	for tile in tiles:
		check(tile.texture.get_width() <= 4096, "GPU tile width")


func check_large_counts(edge: int) -> void:
	var document := EmptyCityTemplate.create(edge)
	var city := CityState.from_document(document)
	var road_offset := 0x01f0 + 0x1d * 4
	document.set_misc_u32(road_offset, 65535)
	document.set_misc_u32(0x01f0, 1)
	var misc := document.find_chunk("MISC").decoded_payload.duplicate()
	BuildingState.update_building_count(misc, 0, 0, 0x1d, edge)
	document.find_chunk("MISC").set_decoded_payload(misc)
	check(document.misc_u32(road_offset) == (0 if edge == 128 else 65536), "building count width %d" % edge)
	document.set_misc_u32(road_offset, 40000)
	var value := CityValuePhase.calculate(city)
	check(value.ok and value.city_value == (-255360 if edge == 128 else 400000), "city value count width %d" % edge)
	var graphs := GraphHistory.calculate_current_values(city, edge * edge, 25, 50)
	check(graphs.ok and graphs.values.size() == 16, "graph values cover full map %d" % edge)

	for change in [GrowthState.replace_building, NetworkState.replace_building, CityRotationCommand._replace_building, RciAftermathPhase._replace_building, SpecialZoneState.replace_building]:
		var buildings := PackedByteArray()
		buildings.resize(edge * edge)
		var zones := buildings.duplicate()
		document.set_misc_u32(road_offset, 65535)
		misc = document.find_chunk("MISC").decoded_payload.duplicate()
		change.call(buildings, zones, misc, buildings.size() - 1, 0x1d)
		document.find_chunk("MISC").set_decoded_payload(misc)
		check(document.misc_u32(road_offset) == (0 if edge == 128 else 65536), "tile count mutation width %d: %s" % [edge, change])


func check_highways(edge: int) -> void:
	var document := EmptyCityTemplate.create(edge)
	var city := CityState.from_document(document)
	var before := saved_payloads(document)
	var far := edge - 10
	var near := mini(20, edge - 10)

	for start in [Vector2i(far, near), Vector2i(near, far), Vector2i(far, far), Vector2i(124, near), Vector2i(near, 124)]:
		if edge <= 128 and (start.x == 124 or start.y == 124):
			continue

		check(HighwayEdit.preview_valid(city, start), "Highway preview at %s on %d map" % [start, edge])
		var finish: Vector2i = start + (Vector2i(0, 4) if start.y == 124 else Vector2i(4, 0))
		var built := HighwayCommand.apply(city, 6, 1, start, finish)
		check(built.ok and built.sections.size() == 3, "Highway route across extended coordinates")

		if not built.ok:
			continue

		check(built.cost == 300, "Highway route charges three sections")
		var random := SimRandom.new(42)
		var removed := DemolishCommand.apply_path(city, 0, 0, [start + Vector2i.ONE], random)
		check(removed.ok and removed.tile_indices.size() == 4, "Extended highway demolition")

		if removed.ok:
			check(DemolishCommand.undo(city, removed, random).ok, "Extended demolition undo")

		check(HighwayCommand.undo(city, built).ok, "Extended highway undo")
		check(saved_payloads(document) == before, "Extended highway exact undo bytes")

	for border in [Vector2i(edge - 2, near), Vector2i(near, edge - 2)]:
		var prompt := HighwayCommand.apply(city, 6, 1, border, border)
		check(prompt.connection_selection_required, "Highway connection uses actual map border")
		check(saved_payloads(document) == before, "Connection prompt does not change city")

	for outside in [Vector2i(edge, near), Vector2i(near, edge), Vector2i(-1, near)]:
		check(not HighwayEdit.preview_valid(city, outside), "Outside highway preview rejected")
		check(not HighwayCommand.apply(city, 6, 1, outside, outside).ok, "Outside highway placement rejected")


func saved_payloads(document: Sc2File) -> Array:
	var values: Array = []
	for chunk in document.chunks:
		values.append(chunk.decoded_payload.duplicate())
	return values
