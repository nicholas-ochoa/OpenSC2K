class_name CityDebugActions
extends RefCounted

const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
const DisasterStart = preload("res://src/simulation/disasters/disaster_start_phase.gd")
const MovingThingSpawner = preload("res://src/simulation/moving_things/moving_thing_spawner.gd")

const MAX_FUNDS := 0x7fffffff
const MISC_SIZE := 4800
const MISC_CITY_MODE := 0x0004
const MISC_DISASTER_TYPE := 0x0070
const NORMAL_CITY_MODE := 1
const DISASTER_OVERLAY_FIRST := 0xfb
const MAXIS_TARGET_OVERLAY_FIRST := 241


static func add_funds(city: CityState, amount: int) -> Dictionary:
	if city == null or amount <= 0:
		return {"ok": false, "error": "No city is loaded."}

	var new_funds := mini(MAX_FUNDS, city.funds() + amount)

	if not city.set_funds(new_funds):
		return {"ok": false, "error": "Funds could not be changed."}

	return {"ok": true, "new_funds": new_funds}


static func unlock_everything(city: CityState, document: Sc2File) -> Dictionary:
	if city == null or document == null:
		return {"ok": false, "error": "No city is loaded."}

	var misc_chunk := document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		return {"ok": false, "error": "The city MISC data is not valid."}

	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	ToolAvailability._write_u32_be(misc, ToolAvailability.MISC_PROGRESSION, 6)
	ToolAvailability._write_u32_be(
		misc, ToolAvailability.MISC_GRANTED_REWARDS, 0xffff
	)

	for invention_index in ToolAvailability.INVENTION_COUNT:
		ToolAvailability._write_u32_be(
			misc,
			ToolAvailability.MISC_INVENTION_YEARS + invention_index * 4,
			0,
		)

	var ordinances := ToolAvailability._read_u32_be(
		misc, ToolAvailability.MISC_ORDINANCES
	)
	ToolAvailability._write_u32_be(
		misc,
		ToolAvailability.MISC_ORDINANCES,
		ordinances & ~ToolAvailability.ORDINANCE_NUCLEAR_FREE,
	)

	if not misc_chunk.set_decoded_payload(misc):
		return {"ok": false, "error": "The unlock state could not be stored."}

	return {"ok": true}


static func set_no_disasters(city: CityState, enabled: bool) -> Dictionary:
	if city == null:
		return {"ok": false, "error": "No city is loaded."}

	if not city.set_no_disasters_enabled(enabled):
		return {
			"ok": false,
			"error": "The random-disaster option could not be stored.",
		}

	return {"ok": true}


static func end_disaster(
	city: CityState,
	document: Sc2File,
	engine: SimulationEngine,
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or document == null or engine == null:
		return {"ok": false, "error": "No city is loaded."}

	var thing_chunk := document.find_chunk("XTHG")
	var text_chunk := document.find_chunk("XTXT")
	var misc_chunk := document.find_chunk("MISC")

	if not _valid_disaster_chunks(thing_chunk, text_chunk, misc_chunk, map_edge):
		return {"ok": false, "error": "The city disaster data is not valid."}

	var old_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var old_text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	var things := old_things.duplicate()
	var text := old_text.duplicate()
	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var disaster_records := _disaster_record_indices(things)
	var cleared_markers := _clear_disaster_markers(text, things, disaster_records, map_edge)
	_clear_thing_records(things, disaster_records)
	ToolAvailability._write_u32_be(misc, MISC_CITY_MODE, NORMAL_CITY_MODE)
	ToolAvailability._write_u32_be(misc, MISC_DISASTER_TYPE, 0)
	var active_type := engine.active_disaster_type
	var had_disaster := (
		active_type != 0
		or engine.pending_disaster_type != 0
		or not disaster_records.is_empty()
		or cleared_markers > 0
	)

	if not had_disaster:
		return {"ok": false, "error": "No active disaster was found."}

	if not thing_chunk.set_decoded_payload(things):
		return {"ok": false, "error": "The disaster objects could not be cleared."}

	if not text_chunk.set_decoded_payload(text):
		thing_chunk.set_decoded_payload(old_things)

		return {"ok": false, "error": "The disaster markers could not be cleared."}

	if not misc_chunk.set_decoded_payload(misc):
		thing_chunk.set_decoded_payload(old_things)
		text_chunk.set_decoded_payload(old_text)

		return {"ok": false, "error": "The disaster mode could not be cleared."}

	city.text_overlays = text.duplicate()
	_reset_disaster_engine(engine)

	return {
		"ok": true,
		"active_type": active_type,
		"cleared_markers": cleared_markers,
		"cleared_objects": disaster_records.size(),
	}


static func dispatch_maxis_man(
	city: CityState,
	document: Sc2File,
	view_center: Vector2i,
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or document == null:
		return {"ok": false, "error": "No city is loaded."}

	var target := _disaster_target(city, document, view_center)

	if target.is_empty():
		return {"ok": false, "error": "No active disaster target was found."}

	var start := _maxis_man_start(city, target.point)

	if start.x < 0:
		return {"ok": false, "error": "No clear launch tile was found."}

	var thing_chunk := document.find_chunk("XTHG")
	var text_chunk := document.find_chunk("XTXT")

	if thing_chunk == null or text_chunk == null:
		return {"ok": false, "error": "The moving-object data is missing."}

	var old_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var things: PackedByteArray = old_things.duplicate()
	var text: PackedByteArray = city.text_overlays.duplicate()
	var spawned := MovingThingSpawner.spawn_maxis_man(
		things,
		text,
		start,
		target.point,
		int(target.goal),
		city.object_altitude(start.x, start.y) + 4, map_edge,
	)

	if not spawned.spawned:
		return {
			"ok": false,
			"error": "Maxis Man is already active or no record is free.",
		}

	if not thing_chunk.set_decoded_payload(things):
		return {"ok": false, "error": "The Maxis Man record could not be stored."}

	if not text_chunk.set_decoded_payload(text):
		thing_chunk.set_decoded_payload(old_things)

		return {"ok": false, "error": "The Maxis Man map link could not be stored."}

	city.text_overlays = text

	return {"ok": true, "start": start, "target": target.point}


static func _valid_disaster_chunks(
	thing_chunk: Sc2Chunk,
	text_chunk: Sc2Chunk,
	misc_chunk: Sc2Chunk,
	map_edge: int = 128,
) -> bool:
	return (
		thing_chunk != null
		and thing_chunk.decoded_payload.size()
		== ThingData.BASE_SIZE * (1 if map_edge <= 128 else IntegerMath.div_trunc(2 * map_edge * map_edge, 16384))
		and text_chunk != null
		and OverlayData.count(text_chunk.decoded_payload) == (map_edge * map_edge)
		and misc_chunk != null
		and misc_chunk.decoded_payload.size() == MISC_SIZE
	)


static func _disaster_record_indices(things: PackedByteArray) -> Dictionary:
	var result := {}

	for record in range(1, ThingData.count(things)):
		var offset := record * CityState.THING_RECORD_SIZE
		var thing_type := int(ThingData.read(things, offset))
		var is_disaster_object := thing_type in [
			DisasterStart.TYPE_MONSTER,
			DisasterStart.TYPE_EXPLOSION,
			DisasterStart.TYPE_TORNADO,
		]
		var is_crashing_airplane := (
			thing_type == DisasterStart.TYPE_AIRPLANE and ThingData.read(things, offset + 2) == 7
		)

		if is_disaster_object or is_crashing_airplane:
			result[record] = true

	return result


static func _clear_disaster_markers(
	text: PackedByteArray,
	things: PackedByteArray,
	disaster_records: Dictionary,
	map_edge: int = 128,
) -> int:
	var cleared_markers := 0

	for index in (map_edge * map_edge):
		var overlay := int(OverlayData.read(text, index))

		if overlay >= DISASTER_OVERLAY_FIRST and overlay <= 255:
			OverlayData.write(text, index, 0)
			cleared_markers += 1
			continue

		if not OverlayData.is_thing(overlay):
			continue

		var record := OverlayData.thing_record(overlay)

		if not disaster_records.has(record):
			continue

		var offset := record * CityState.THING_RECORD_SIZE
		var point_index := (
			int(ThingData.read(things, offset + 3)) * map_edge + int(ThingData.read(things, offset + 4))
		)
		var prior_overlay := int(ThingData.read(things, offset + 10))
		OverlayData.write(text, index, (
			prior_overlay
			if index == point_index and not OverlayData.blocks_thing(prior_overlay)
			else 0
		))

	return cleared_markers


static func _clear_thing_records(
	things: PackedByteArray,
	disaster_records: Dictionary,
) -> void:
	for record in disaster_records:
		var offset := int(record) * CityState.THING_RECORD_SIZE

		for byte_index in CityState.THING_RECORD_SIZE:
			ThingData.write(things, offset + byte_index, 0)


static func _reset_disaster_engine(engine: SimulationEngine) -> void:
	engine.pending_disaster_type = 0
	engine.pending_disaster_point = Vector2i.ZERO
	engine.active_disaster_type = 0
	engine.unsupported_disaster_type = 0
	engine.disaster_map_counter = 0
	engine.disaster_hurricane_counter = 0


static func _disaster_target(
	city: CityState,
	document: Sc2File,
	view_center: Vector2i,
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128
	var thing_chunk := document.find_chunk("XTHG")

	if thing_chunk != null:
		var things: PackedByteArray = thing_chunk.decoded_payload

		for record in range(1, ThingData.count(things)):
			var offset := record * CityState.THING_RECORD_SIZE

			if int(ThingData.read(things, offset)) in [5, 15]:
				return {
					"point": Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4)),
					"goal": ThingData.target_id(record),
				}

	var nearest := Vector2i(-1, -1)
	var nearest_distance := MAX_FUNDS

	for x in map_edge:
		for y in map_edge:
			if city.text_overlay_id(x, y) < MAXIS_TARGET_OVERLAY_FIRST:
				continue

			var point := Vector2i(x, y)
			var distance := absi(point.x - view_center.x) + absi(point.y - view_center.y)

			if distance < nearest_distance:
				nearest = point
				nearest_distance = distance

	return {} if nearest.x < 0 else {"point": nearest, "goal": MAXIS_TARGET_OVERLAY_FIRST}


static func _maxis_man_start(city: CityState, target: Vector2i) -> Vector2i:
	const DIRECTIONS := [
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]

	for radius in range(12, 0, -1):
		for direction in DIRECTIONS:
			var point: Vector2i = target + Vector2i(direction) * radius

			if (
				city.index_of(point.x, point.y) >= 0
				and not OverlayData.blocks_thing(city.text_overlay_id(point.x, point.y))
			):
				return point

	return Vector2i(-1, -1)
