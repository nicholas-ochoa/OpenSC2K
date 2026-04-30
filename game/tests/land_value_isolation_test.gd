extends SceneTree

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	for edge in [128, 512]:
		for native in [false, true]:
			for zone in [3, 5]:
				var baseline := fixture(edge, native, zone)
				var polluted := baseline.duplicate_document()
				var data := polluted.find_chunk("XPLT").decoded_payload.duplicate()
				var point := Vector2i(IntegerMath.div_trunc(edge, 8), IntegerMath.div_trunc(edge, 8))
				data[CityDataGrid.index(data, edge, point.x, point.y)] = 255
				polluted.find_chunk("XPLT").set_decoded_payload(data)
				check(PollutionPhase.run(CityState.from_document(baseline)).ok, "Clean data phase")
				check(PollutionPhase.run(CityState.from_document(polluted)).ok, "Polluted data phase")
				var clean_land := baseline.find_chunk("XVAL").decoded_payload
				var dirty_land := polluted.find_chunk("XVAL").decoded_payload
				var dirty_pollution := polluted.find_chunk("XPLT").decoded_payload
				var unaffected_equal := true
				var never_increases := true
				for index in clean_land.size():
					if dirty_pollution[index] == 0:
						unaffected_equal = unaffected_equal and clean_land[index] == dirty_land[index]
					never_increases = never_increases and dirty_land[index] <= clean_land[index]
				check(unaffected_equal, "Pollution cannot change land value at unrelated coordinates")
				check(never_increases, "Pollution cannot increase land value")
				for scale in [2, 4]:
					var index := CityDataGrid.index(clean_land, edge, point.x * scale, point.y * scale)
					check(clean_land[index] == dirty_land[index], "No scaled-coordinate ghost")
	print("Land value isolation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func fixture(edge: int, native: bool, zone: int) -> Sc2File:
	var doc := EmptyCityTemplate.create(edge)
	if native:
		doc.enable_full_resolution_maps()
	var zones := doc.find_chunk("XZON").decoded_payload.duplicate()
	zones.fill(zone)
	doc.find_chunk("XZON").set_decoded_payload(zones)
	return doc
