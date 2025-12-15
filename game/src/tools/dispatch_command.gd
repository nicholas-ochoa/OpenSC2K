class_name DispatchCommand
extends RefCounted

const GROUP_DISPATCH := 2
const FLAG_WATER := 0x04
const MISC_CITY_MODE := 0x0004
const MISC_TILE_COUNTS := 0x01f0
const MISC_MILITARY_BASE_TYPE := 0x0e4c
const POLICE_STATION := 0xd2
const FIRE_STATION := 0xd3
const TYPE_POLICE := 7
const TYPE_FIRE := 8
const TYPE_MILITARY := 14
const FIRST_THING := 1
const LAST_THING := 39
const THING_RECORD_SIZE := 12
const THING_LABEL_BASE := 201
const MILITARY_AVAILABILITY := [0, 0, 5, 2, 3, 0]
const TYPE_BY_SUBTOOL := [TYPE_POLICE, TYPE_FIRE, TYPE_MILITARY]


static func supports_tool(group_index: int, subtool_index: int) -> bool:
	return group_index == GROUP_DISPATCH and subtool_index >= 0 and subtool_index < 3


static func availability(city: CityState) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	var misc := city.document.find_chunk("MISC")
	if misc == null or misc.decoded_payload.size() != 4800:
		return {"ok": false, "error": "MISC is missing or has the wrong size"}
	var data: PackedByteArray = misc.decoded_payload
	var police := int(_read_u32_be(data, MISC_TILE_COUNTS + POLICE_STATION * 4) >> 3)
	var fire := int(_read_u32_be(data, MISC_TILE_COUNTS + FIRE_STATION * 4) >> 3)
	var base_type := int(_read_u32_be(data, MISC_MILITARY_BASE_TYPE))
	var military := 0
	if base_type >= 0 and base_type < MILITARY_AVAILABILITY.size():
		military = int(MILITARY_AVAILABILITY[base_type])
	if police == 0 and fire == 0 and military == 0:
		military = 1
	return {
		"ok": true,
		"police": police,
		"fire": fire,
		"military": military,
		"base_type": base_type,
		"error": "",
	}


static func apply(
	city: CityState,
	group_index: int,
	subtool_index: int,
	target: Vector2i,
	cycle_index: int = 0,
	reset_existing: bool = false
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not supports_tool(group_index, subtool_index):
		return {"ok": false, "error": "tool is not an emergency dispatch tool"}
	var target_index := city.index_of(target.x, target.y)
	if target_index < 0:
		return {"ok": false, "error": "dispatch target is outside the city"}
	var available := availability(city)
	if not available.ok:
		return available
	var available_count: int = int(
		[available.police, available.fire, available.military][subtool_index]
	)
	if available_count == 0:
		return {"ok": false, "error": "no dispatch units of this type are available"}

	var thing_chunk := city.document.find_chunk("XTHG")
	var text_chunk := city.document.find_chunk("XTXT")
	if thing_chunk == null or thing_chunk.decoded_payload.size() != CityState.THING_COUNT * THING_RECORD_SIZE:
		return {"ok": false, "error": "XTHG is missing or has the wrong size"}
	if text_chunk == null or text_chunk.decoded_payload.size() != CityState.TILE_COUNT:
		return {"ok": false, "error": "XTXT is missing or has the wrong size"}
	var old_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var old_text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	var things := old_things.duplicate()
	var text := old_text.duplicate()
	if reset_existing:
		_clear_existing_dispatch(things, text)
	if (city.tile_flags[target_index] & FLAG_WATER) != 0:
		return {"ok": false, "error": "dispatch target is water"}
	if text[target_index] != 0:
		return {"ok": false, "error": "dispatch target has a text overlay"}

	var slot_index := cycle_index + 1
	if slot_index > available_count or slot_index < 1:
		slot_index = 1
	var thing_type := int(TYPE_BY_SUBTOOL[subtool_index])
	var active_records := _records_of_type(things, thing_type)
	if slot_index <= active_records.size():
		_delete_thing(things, text, active_records[slot_index - 1])

	var thing_index := _first_free_thing(things)
	if thing_index < 0 and city.document.misc_u32(MISC_CITY_MODE) == 2:
		thing_index = LAST_THING
		_delete_thing(things, text, thing_index)
	if thing_index < 0:
		return {"ok": false, "error": "no moving-thing record is available"}
	var offset := thing_index * THING_RECORD_SIZE
	for byte_index in THING_RECORD_SIZE:
		things[offset + byte_index] = 0
	things[offset] = thing_type
	things[offset + 3] = target.x
	things[offset + 4] = target.y
	text[target_index] = thing_index + THING_LABEL_BASE

	if not thing_chunk.set_decoded_payload(things):
		return {"ok": false, "error": "cannot store the dispatch unit"}
	if not text_chunk.set_decoded_payload(text):
		thing_chunk.set_decoded_payload(old_things)
		return {"ok": false, "error": "cannot store the dispatch overlay"}
	city.text_overlays = text.duplicate()
	return {
		"ok": true,
		"command_type": "dispatch",
		"group_index": group_index,
		"subtool_index": subtool_index,
		"thing_type": thing_type,
		"thing_index": thing_index,
		"target": target,
		"available": available_count,
		"slot_index": slot_index,
		"reset_existing": reset_existing,
		"old_things": old_things,
		"new_things": things,
		"old_text": old_text,
		"new_text": text,
		"error": "",
	}


static func undo(city: CityState, command: Dictionary) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if not command.get("ok", false) or command.get("command_type", "") != "dispatch":
		return {"ok": false, "error": "dispatch command is invalid"}
	var thing_chunk := city.document.find_chunk("XTHG")
	var text_chunk := city.document.find_chunk("XTXT")
	if thing_chunk == null or text_chunk == null:
		return {"ok": false, "error": "dispatch chunks are missing"}
	if thing_chunk.decoded_payload != command.get("new_things", PackedByteArray()):
		return {"ok": false, "error": "moving things changed after this dispatch command"}
	if text_chunk.decoded_payload != command.get("new_text", PackedByteArray()):
		return {"ok": false, "error": "text overlays changed after this dispatch command"}
	if not thing_chunk.set_decoded_payload(command.old_things):
		return {"ok": false, "error": "cannot restore moving things"}
	if not text_chunk.set_decoded_payload(command.old_text):
		thing_chunk.set_decoded_payload(command.new_things)
		return {"ok": false, "error": "cannot restore text overlays"}
	city.text_overlays = command.old_text.duplicate()
	return {"ok": true, "restored_thing": int(command.thing_index), "error": ""}


static func _clear_existing_dispatch(things: PackedByteArray, text: PackedByteArray) -> void:
	for index in CityState.TILE_COUNT:
		var overlay := int(text[index])
		if overlay <= THING_LABEL_BASE or overlay > THING_LABEL_BASE + LAST_THING:
			continue
		var thing_index := overlay - THING_LABEL_BASE
		var thing_type := int(things[thing_index * THING_RECORD_SIZE])
		if TYPE_BY_SUBTOOL.has(thing_type):
			text[index] = 0
			things[thing_index * THING_RECORD_SIZE] = 0


static func _records_of_type(things: PackedByteArray, thing_type: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for thing_index in range(FIRST_THING, LAST_THING + 1):
		if things[thing_index * THING_RECORD_SIZE] == thing_type:
			result.append(thing_index)
	return result


static func _first_free_thing(things: PackedByteArray) -> int:
	for thing_index in range(FIRST_THING, LAST_THING + 1):
		if things[thing_index * THING_RECORD_SIZE] == 0:
			return thing_index
	return -1


static func _delete_thing(
	things: PackedByteArray, text: PackedByteArray, thing_index: int
) -> void:
	if thing_index < FIRST_THING or thing_index > LAST_THING:
		return
	var offset := thing_index * THING_RECORD_SIZE
	var x := int(things[offset + 3])
	var y := int(things[offset + 4])
	if x >= 0 and x < 128 and y >= 0 and y < 128:
		var map_index := x * CityState.MAP_SIZE + y
		if text[map_index] == thing_index + THING_LABEL_BASE:
			text[map_index] = 0
	for byte_index in THING_RECORD_SIZE:
		things[offset + byte_index] = 0


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func recall_all(city: CityState) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	var things_chunk := city.document.find_chunk("XTHG")
	var text_chunk := city.document.find_chunk("XTXT")
	var old_things: PackedByteArray = things_chunk.decoded_payload.duplicate()
	var old_text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	var things := old_things.duplicate()
	var text := old_text.duplicate()
	_clear_existing_dispatch(things, text)
	things_chunk.set_decoded_payload(things)
	text_chunk.set_decoded_payload(text)
	city.text_overlays = text.duplicate()
	return {"ok": true, "command_type": "dispatch", "thing_index": -1,
		"old_things": old_things, "new_things": things, "old_text": old_text, "new_text": text}
