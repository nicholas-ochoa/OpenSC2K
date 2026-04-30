extends SceneTree

var checks := 0
var failures := 0


func _init() -> void:
	for edge in [128, 512]:
		for enabled in [false, true]:
			for fixture in ["plane_building", "plane_arcology", "landing", "falling_plane", "helicopter_arcology", "falling_helicopter"]:
				check_aircraft(edge, enabled, fixture)

	print("No-disasters aircraft: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(message)


func check_aircraft(edge: int, enabled: bool, fixture: String) -> void:
	var city := CityState.from_document(EmptyCityTemplate.create(edge))
	city.set_no_disasters_enabled(enabled)
	var point := Vector2i(edge - 10, edge - 10)
	var helicopter := "helicopter" in fixture
	var falling := "falling" in fixture
	var type := 2 if helicopter else 1
	var state := (5 if helicopter else 7) if falling else (1 if fixture == "landing" else 0)
	var building := 0xfb if "arcology" in fixture else (0xd2 if fixture == "plane_building" else 0)
	city.set_building_id(point.x, point.y, building)
	var things := city.document.find_chunk("XTHG").decoded_payload.duplicate()
	var record := city.thing_count() - 1
	var fields := {0: type, 1: 2, 2: state, 3: point.x, 4: point.y, 5: 1 if fixture == "landing" else (2 if helicopter else 0), 6: 8, 7: 8, 10: 61}

	for field in fields:
		ThingData.write(things, record * 12 + field, fields[field])

	city.document.find_chunk("XTHG").set_decoded_payload(things)
	city.set_text_overlay_id(point.x, point.y, OverlayData.thing_id(record))
	var buildings_before := city.buildings.duplicate()
	var random := SimRandom.new(123)
	var lfsr := SimLfsrRandom.new(7)
	var result := MovingThingPhase.run(city, random, lfsr)
	check(result.ok, "Aircraft tick succeeds")
	var crashes: int = result.crashed_airplanes + result.crashed_helicopters
	check(crashes == (0 if enabled else 1), "%s edge %d respects No disasters=%s" % [fixture, edge, enabled])
	check(city.thing(record).type != 6 if enabled else city.thing(record).type == 6, "No crash explosion when disabled")

	if enabled:
		check(result.disaster_start_requests.is_empty() and city.document.misc_u32(0x0070) == 0, "No crash disaster request")
		check(city.buildings == buildings_before, "Aircraft leaves buildings unchanged")
		check(lfsr.state == 7, "Blocked crashes do not draw damage RNG")

		if falling:
			check(city.thing(record).type == 0, "Falling aircraft removed safely")
			check(city.text_overlay_id(point.x, point.y) == 61, "Safe removal restores underlying facility")
			check(result.sound_events.is_empty(), "Falling aircraft emits no disaster sound")
		elif fixture != "landing":
			check(city.thing(record).type == type, "Normal aircraft continue to operate")

		# Keep ticking to catch a delayed explosion after a suppressed crash.
		for tick in 3:
			result = MovingThingPhase.run(city, random, lfsr)
			check(result.ok and result.crashed_airplanes == 0 and result.crashed_helicopters == 0, "Later tick stays crash-free")
			check(city.buildings == buildings_before, "Later tick preserves buildings")
