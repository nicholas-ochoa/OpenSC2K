extends SceneTree

@warning_ignore_start("integer_division")

class ChoiceRandom extends GameLcgRandom:
	var choice: int


	func _init(value: int) -> void:
		choice = value


	func next_mod(limit: int) -> int:
		return choice % limit

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	for edge in [128, 256, 384, 512]:
		# Coast orientation is independent of the resolution of simulation data maps.
		var directions := [0, 1, 2, 3] if edge == 128 else [[128, 256, 384, 512].find(edge)]
		for direction in directions:
			var doc := fixture(edge, direction)
			var city := CityState.from_document(doc)
			var untouched := doc.duplicate_document()
			var before := saved_payloads(doc)
			var declined := MilitaryProposalPhase.resolve(city, false, ChoiceRandom.new(1))
			check(declined.ok and declined.base_type == 1, "Player can decline before naval selection")
			doc = untouched
			city = CityState.from_document(doc)
			var site := NavalBaseSite.find(city)
			check(site.get_area() == 40, "Naval site exists at rotated far-map coast")
			check(saved_payloads(doc) == before, "Coastal search is read-only")
			var funds := city.funds()
			var proposal := MilitaryProposalPhase.resolve(city, true, ChoiceRandom.new(1))
			check(proposal.ok and proposal.base_type == 4 and proposal.notice_id == 0xf3, "Accepted proposal can select Navy")
			check(proposal.changed_indices.size() == 40 and proposal.view_center_requests == [site.get_center()], "Naval proposal publishes plot and center")
			check(city.funds() == funds and doc.misc_u32(0x0fa8) == 40, "Navy transfers counters without cost")
			for index in proposal.changed_indices:
				check((city.zones[index] & 15) == 7 and city.buildings[index] == 0, "Navy reserves clear land")
			# Try growing a crane and pier from the new shoreline plot.
			var p := GrowthState.duplicate_payloads(GrowthState.payloads(city))
			var grown := false
			for index in proposal.changed_indices:
				var point := Vector2i(index / edge, index % edge)
				var result := SpecialZoneSelection.grow_special_zone(p.XBLD, p.XZON, p.XUND, p.XBIT, p.XTER,
					city.altitude_words, p.MISC, point, 0xe0, 7, direction, edge)
				if result.ok and result.changed_tiles == 5:
					grown = true
					break
			check(grown, "Selected naval shore supports crane and four pier tiles")
			var bytes: PackedByteArray = doc.serialize().data
			var loaded := Sc2File.new()
			check(loaded.parse(bytes) and loaded.serialize().data == bytes and loaded.misc_u32(0x0e4c) == 4, "Naval base saves and reloads")
		if edge != 128:
			continue

		# Exclusion rules do not depend on map size or direction.
		for blocked in ["ocean", "fresh", "occupied", "underground", "slope"]:
			var doc := fixture(edge, 0)
			var city := CityState.from_document(doc)
			if blocked == "ocean":
				doc.set_misc_u32(0x0e44, 0)
			elif blocked == "fresh":
				var data := doc.find_chunk("XBIT").decoded_payload.duplicate()
				for index in data.size():
					data[index] &= 0xfe
				doc.find_chunk("XBIT").set_decoded_payload(data)
			else:
				var x: int = edge - 18
				for y in range(edge - 22, edge - 8):
					if blocked == "occupied":
						city.set_zone_id(x, y, 3)
					elif blocked == "underground":
						city.set_underground_id(x, y, 1)
					else:
						city.set_terrain_id(x, y, 1)
			city = CityState.from_document(doc)
			check(not NavalBaseSite.find(city).has_area(), "Navy excludes " + blocked)
	print("Naval base regression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func fixture(edge: int, rotation: int) -> Sc2File:
	var doc := EmptyCityTemplate.create(edge)
	doc.set_misc_u32(0x0e44, 1)
	doc.set_misc_u32(0x0008, rotation)
	var buildings := doc.find_chunk("XBLD").decoded_payload.duplicate()
	buildings.fill(0x0d)
	var flags := doc.find_chunk("XBIT").decoded_payload.duplicate()
	var heights := doc.find_chunk("ALTM").decoded_payload.duplicate()
	var inland: Vector2i = NavalBaseSite.INLAND_STEPS[rotation]
	var along := Vector2i(-inland.y, inland.x)
	var shore := Vector2i(edge - 18, edge - 20)
	if rotation in [1, 2]:
		shore = Vector2i(edge - 12, edge - 12)
	for column in range(-1, 11):
		for row in range(-6, 4):
			var point := shore + along * column + inland * row
			var index := point.x * edge + point.y
			buildings[index] = 0
			flags[index] = 5 if row < 0 else 0
			heights[index * 2 + 1] = 160 if row < 0 else 165
	doc.find_chunk("XBLD").set_decoded_payload(buildings)
	doc.find_chunk("XBIT").set_decoded_payload(flags)
	doc.find_chunk("ALTM").set_decoded_payload(heights)
	doc.set_misc_u32(0x01f0, 120)
	return doc


func saved_payloads(document: Sc2File) -> Array:
	var values: Array = []
	for chunk in document.chunks:
		values.append(chunk.decoded_payload.duplicate())
	return values
