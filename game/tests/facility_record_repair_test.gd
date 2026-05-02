extends SceneTree

class RepairApp extends "res://src/main.gd":
	func _show_main_menu() -> void:
		pass


var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	for edge in [128, 512]:
		# All orientations at the original size; far-map repair at every larger size.
		var rotations := [0, 1, 2, 3] if edge == 128 else [[128, 256, 384, 512].find(edge)]
		for rotation in rotations:
			check_repair(edge, rotation)

	check_version_one()
	check_capacity()
	check_shared_and_obstacles()
	await check_load()
	print("Facility record repair: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func stamp(city: CityState, tile: int, origin: Vector2i) -> Rect2i:
	var area := DemolishCommand.structure_area(tile)
	var site := Rect2i(origin, Vector2i(area, area))
	var buildings := city.buildings.duplicate()
	var zones := city.zones.duplicate()

	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			buildings[x * city.map_size + y] = tile

	BuildingCommand._set_corners(zones, site, area, city.compass_rotation(), city.map_size)
	city.replace_buildings(buildings)
	city.replace_zones(zones)
	return site


func check_repair(edge: int, rotation: int) -> void:
	var doc := EmptyCityTemplate.create(edge)
	doc.enable_full_resolution_maps()
	# Repair needs the saved orientation, not a rotation of every empty grid.
	doc.set_misc_u32(0x0008, (4 - rotation) % 4)
	var city := CityState.from_document(doc)

	var sites: Array[Rect2i] = []
	var tiles: Array = BuildingCommand.MICROSIM_TYPE_BY_TILE.keys()

	for n in tiles.size():
		var origin := Vector2i(edge - 5 - (n % 8) * 5, edge - 5 - IntegerMath.div_trunc(n, 8) * 5)
		sites.append(stamp(city, tiles[n], origin))

	var untouched := doc.duplicate_document()
	var original := saved_payloads(doc)
	CityState.from_document(untouched)
	check(saved_payloads(untouched) == original, "Model creation does not repair snapshots")
	var result := FacilityRecordRepair.apply(city)
	check(result.ok and result.linked == tiles.size() and result.unfilled == 0, "All facility types repaired at %d rotation %d" % [edge, rotation])

	for n in sites.size():
		var site := sites[n]
		var id := city.text_overlay_id(site.position.x, site.position.y)
		check(OverlayData.is_facility(id), "Facility receives link")
		var record := OverlayData.facility_record(id)
		var kind := int(BuildingCommand.MICROSIM_TYPE_BY_TILE[tiles[n]])
		check(city.microsim(record).tile_id == tiles[n] or kind == 21, "Facility type initialized; hydro shares one record")

		for x in range(site.position.x, site.end.x):
			for y in range(site.position.y, site.end.y):
				check(city.text_overlay_id(x, y) == id, "One link covers complete footprint")

	for chunk in doc.chunks:
		if chunk.chunk_id not in ["XMIC", "XLAB", "XTXT"]:
			check(chunk.decoded_payload == untouched.find_chunk(chunk.chunk_id).decoded_payload, "Repair preserves " + chunk.chunk_id)

	var repaired := saved_payloads(doc)
	check(FacilityRecordRepair.apply(city).linked == 0, "Repeat repair is idle")
	check(saved_payloads(doc) == repaired, "Repeat repair preserves every payload")
	if not (edge == 128 and rotation == 0) and edge != 512:
		return
	var encoded: PackedByteArray = doc.serialize().data
	var reload := Sc2File.new()
	check(reload.parse(encoded), "Repaired city reloads")
	check(FacilityRecordRepair.apply(CityState.from_document(reload)).linked == 0, "Reload preserves records")
	check(reload.serialize().data == encoded, "Repaired save round trip is byte exact")
	var second := untouched.duplicate_document()
	FacilityRecordRepair.apply(CityState.from_document(second))
	check(saved_payloads(second) == repaired, "Fresh repair is deterministic")


func check_version_one() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(256))
	stamp(city, 0xd2, Vector2i(251, 251))
	var doc := city.document
	doc.large_version = 1

	for id in ["XTXT", "XMIC", "XLAB", "XTHG"]:
		var chunk := doc.find_chunk(id)
		chunk.expected_decoded_size = doc.decoded_size(id)
		var bytes := PackedByteArray()
		bytes.resize(chunk.expected_decoded_size)
		chunk.set_decoded_payload(bytes)

	var encoded: PackedByteArray = doc.serialize().data
	var loaded := Sc2File.new()
	check(loaded.parse(encoded), "Old SC2X version parses")
	var activated := CityState.from_document(loaded)
	check(loaded.large_version == 2, "Old SC2X capacity upgrades before repair")
	check(FacilityRecordRepair.apply(activated).created == 1, "Old SC2X receives missing facility record")
	check(activated.text_overlay_id(251, 251) == 61, "Old SC2X far-edge facility linked")


func check_capacity() -> void:
	var doc := EmptyCityTemplate.create(512)
	var city := CityState.from_document(doc)
	var microsims := doc.find_chunk("XMIC").decoded_payload.duplicate()
	# Reproduce the original full dynamic table, then use extended slots.
	for slot in range(10, 150):
		microsims[slot * 8] = 0xd2
		microsims[slot * 8 + 1] = 99
	doc.find_chunk("XMIC").set_decoded_payload(microsims)
	stamp(city, 0xd1, Vector2i(500, 500))
	var result := FacilityRecordRepair.apply(city)
	check(result.created == 1 and city.text_overlay_id(500, 500) == 256, "Old full table uses first extended slot")
	check(doc.find_chunk("XMIC").decoded_payload.slice(0, 1200) == microsims.slice(0, 1200), "Existing statistics preserved")
	var labels := doc.find_chunk("XLAB").decoded_payload.duplicate()
	BuildingCommand._write_label(labels, 256, "Existing hospital")
	doc.find_chunk("XLAB").set_decoded_payload(labels)
	var before: PackedByteArray = doc.serialize().data
	FacilityRecordRepair.apply(city)
	check(doc.serialize().data == before, "Custom name and existing record preserved")
	microsims = doc.find_chunk("XMIC").decoded_payload.duplicate()
	for slot in range(150, city.microsim_count()):
		microsims[slot * 8] = 0xd1
	doc.find_chunk("XMIC").set_decoded_payload(microsims)
	stamp(city, 0xfb, Vector2i(490, 490))
	before = doc.serialize().data
	result = FacilityRecordRepair.apply(city)
	check(result.unfilled == 1 and result.linked == 0, "Full table reports unfilled arcology")
	check(doc.serialize().data == before, "Repair never evicts existing records")
	var legacy := CityState.from_document(EmptyCityTemplate.create())
	stamp(legacy, 0xd2, Vector2i(10, 10))
	before = legacy.document.serialize().data
	check(FacilityRecordRepair.apply(legacy).linked == 0, "Original SC2 is excluded")
	check(legacy.document.serialize().data == before, "Original SC2 remains byte exact")


func check_shared_and_obstacles() -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(256))
	stamp(city, 0xc8, Vector2i(250, 250))
	stamp(city, 0xc8, Vector2i(251, 250))
	check(FacilityRecordRepair.apply(city).created == 1, "Shared wind record created once")
	var micro := city.document.find_chunk("XMIC").decoded_payload.duplicate()
	check(micro[4 * 8 + 3] == 2 and micro[4 * 8 + 5] == 8, "Missing shared record aggregates both wind plants")
	stamp(city, 0xc8, Vector2i(252, 250))
	check(FacilityRecordRepair.apply(city).linked == 1, "New wind links to existing shared record")
	check(city.document.find_chunk("XMIC").decoded_payload == micro, "Existing shared statistics are not reset or counted twice")
	stamp(city, 0xd2, Vector2i(240, 240))
	var things := city.document.find_chunk("XTHG").decoded_payload.duplicate()
	for field in {0: 2, 3: 240, 4: 240}:
		ThingData.write(things, 12 + field, {0: 2, 3: 240, 4: 240}[field])
	city.document.find_chunk("XTHG").set_decoded_payload(things)
	var text := city.text_overlays.duplicate()
	OverlayData.write(text, 240 * 256 + 240, 202)
	city.replace_text_overlays(text)
	check(FacilityRecordRepair.apply(city).linked == 1, "Repair reaches facility beneath aircraft")
	check(city.text_overlay_id(240, 240) == 202, "Aircraft overlay is preserved")
	check(ThingData.read(city.document.find_chunk("XTHG").decoded_payload, 22) == city.text_overlay_id(241, 240), "Aircraft restores repaired facility link")
	stamp(city, 0xd3, Vector2i(230, 230))
	city.set_text_overlay_id(230, 230, 1)
	stamp(city, 0xd6, Vector2i(220, 220))
	city.set_building_id(221, 221, 0)
	var before: Array = saved_payloads(city.document)
	check(FacilityRecordRepair.apply(city).linked == 0, "Signs and incomplete footprints are preserved")
	check(saved_payloads(city.document) == before, "Ambiguous structures are unchanged")


func check_load() -> void:
	var settings_path := "user://facility-repair-%d.cfg" % OS.get_process_id()
	var save_path := "user://facility-repair-%d.sc2x" % OS.get_process_id()
	OS.set_environment("OPENSC2K_GRAPHICS_PACK", ProjectSettings.globalize_path("res://../ext/graphics"))
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	main.set_script(RepairApp)
	main.reference_root = ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	main.app_settings_path = settings_path
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.map_view.zoom_factor = 0.25
	var fixture := CityState.from_document(EmptyCityTemplate.create(16))
	stamp(fixture, 0xd2, Vector2i(10, 10))
	fixture.set_simulation_speed(1)
	var bytes: PackedByteArray = fixture.document.serialize().data
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var seed: int = main.tool_random.state
	main._load_city_unchecked(ProjectSettings.globalize_path(save_path))
	check(main.city.text_overlay_id(10, 10) == 61, "Actual file load repairs missing facility")
	check(main._city_has_unsaved_changes(), "Load repair is marked unsaved")
	check(main.tool_random.state == seed, "Load repair does not consume process RNG")
	check(FileAccess.get_file_as_bytes(save_path) == bytes, "Loading never writes source file")
	check(main._save_copy(ProjectSettings.globalize_path(save_path)), "User save persists repair")
	var saved := FileAccess.get_file_as_bytes(save_path)
	main._load_city_unchecked(ProjectSettings.globalize_path(save_path))
	check(not main._city_has_unsaved_changes(), "Repaired city loads without new changes")
	check(main.current_document.serialize().data == saved, "Actual reload is byte exact")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func saved_payloads(document: Sc2File) -> Array:
	var values: Array = []
	for chunk in document.chunks:
		values.append(chunk.decoded_payload.duplicate())
	return values
