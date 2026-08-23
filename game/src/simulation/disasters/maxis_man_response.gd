class_name MaxisManResponse
extends RefCounted


const MILITARY_BASE_STATE := 0x0e4c
const ARRIVAL_SOUND := 513
const ARRIVAL_OFFSETS := [Vector2i(16, 0), Vector2i(0, 16), Vector2i(-16, 0), Vector2i(0, -16)]


static func apply(city: CityState, started: Dictionary, random: SimRandom, lfsr_random: SimLfsrRandom) -> Dictionary:
	if not started.get("ok", false) or not started.get("started", false):
		return started

	# State 1 also covers a declined proposal or failed missile search.
	# Draw the random gate before checking for an existing hero or a free slot.
	if city.document.misc_u32(MILITARY_BASE_STATE) != 1 or lfsr_random.next_mask(3) != 0:
		return started

	var thing_chunk := city.document.find_chunk("XTHG")
	var text_chunk := city.document.find_chunk("XTXT")
	var things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var record := 0

	for candidate in range(1, ThingData.count(things)):
		var type := ThingData.read(things, candidate * 12)
		if type == MovingThingSpawner.TYPE_MAXIS_MAN:
			return started
		if type == 0 and record == 0:
			record = candidate

	if record == 0:
		return started

	var edge := city.map_size
	var target: Vector2i = started.point.clamp(Vector2i.ZERO, Vector2i(edge - 1, edge - 1))
	var point: Vector2i = (target + ARRIVAL_OFFSETS[random.next_u15() & 3]).clamp(
		Vector2i.ZERO, Vector2i(edge - 1, edge - 1)
	)
	var offset := record * 12
	# The original allocator leaves old record data in place. Disaster types
	# without a goal assignment reuse that stale goal.
	var goal := ThingData.read(things, offset + 11)
	match int(started.disaster_type):
		1, 5, 6, 9, 10, 11, 12:
			goal = 255
		2, 14:
			goal = 252
		3, 13:
			goal = 253 + (random.next_u15() & 1)
		4, 15:
			goal = 251
		7, 8:
			goal = ThingData.target_id(int(started.record))

	var text := city.text_overlays.duplicate()
	var index := city.index_of(point.x, point.y)
	var fields := {
		0: MovingThingSpawner.TYPE_MAXIS_MAN,
		1: MovingThingSpawner._direction_between(point, target), 2: 0,
		3: point.x, 4: point.y, 5: city.land_altitude(point.x, point.y) + 2,
		6: 8, 7: 8, 8: target.x, 9: target.y,
		10: OverlayData.read(text, index), 11: goal,
	}
	for field in fields:
		ThingData.write(things, offset + field, fields[field])

	# Keep the old label under the hero, as the original does.
	OverlayData.write(text, index, OverlayData.thing_id(record))
	var old_things: PackedByteArray = thing_chunk.decoded_payload
	if not thing_chunk.set_decoded_payload(things):
		return {"ok": false, "error": "cannot store the automatic Maxis Man response"}
	if not text_chunk.set_decoded_payload(text):
		thing_chunk.set_decoded_payload(old_things)
		return {"ok": false, "error": "cannot link the automatic Maxis Man response"}

	city.resync_mirrors(["XTXT"])
	started["maxis_man_response"] = {"record": record, "point": point, "target": target, "goal": goal}
	started.sound_events.append(ARRIVAL_SOUND)
	started.view_center_requests.append(point)
	return started
