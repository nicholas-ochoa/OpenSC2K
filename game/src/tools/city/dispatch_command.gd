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
) -> DispatchEditResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return DispatchEditResult.rejected("city is invalid")

	if not supports_tool(group_index, subtool_index):
		return DispatchEditResult.rejected("tool is not an emergency dispatch tool")

	var target_index := city.index_of(target.x, target.y)

	if target_index < 0:
		return DispatchEditResult.rejected("dispatch target is outside the city")

	var available := availability(city)

	if not available.ok:
		return DispatchEditResult.rejected(available.error)

	var available_count: int = int(
		[available.police, available.fire, available.military][subtool_index]
	)

	if available_count == 0:
		return DispatchEditResult.rejected("no dispatch units of this type are available")

	var thing_chunk := city.document.find_chunk("XTHG")
	var text_chunk := city.document.find_chunk("XTXT")

	if thing_chunk == null or thing_chunk.decoded_payload.size() != city.document.decoded_size("XTHG"):
		return DispatchEditResult.rejected("XTHG is missing or has the wrong size")

	if text_chunk == null or text_chunk.decoded_payload.size() != city.document.decoded_size("XTXT"):
		return DispatchEditResult.rejected("XTXT is missing or has the wrong size")

	var old_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var old_text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	var things := old_things.duplicate()
	var text := old_text.duplicate()

	if reset_existing:
		_clear_existing_dispatch(things, text, map_edge)

	if (city.tile_flags[target_index] & FLAG_WATER) != 0:
		return DispatchEditResult.rejected("dispatch target is water")

	if OverlayData.read(text, target_index) != 0:
		return DispatchEditResult.rejected("dispatch target has a text overlay")

	var slot_index := cycle_index + 1

	if slot_index > available_count or slot_index < 1:
		slot_index = 1

	var thing_type := int(TYPE_BY_SUBTOOL[subtool_index])
	var active_records := _records_of_type(things, thing_type)

	if slot_index <= active_records.size():
		_delete_thing(things, text, active_records[slot_index - 1], map_edge)

	var thing_index := _first_free_thing(things)

	if thing_index < 0 and city.document.misc_u32(MISC_CITY_MODE) == 2:
		thing_index = ThingData.count(things) - 1
		_delete_thing(things, text, thing_index, map_edge)

	if thing_index < 0:
		return DispatchEditResult.rejected("no moving-thing record is available")

	var offset := thing_index * THING_RECORD_SIZE

	for byte_index in THING_RECORD_SIZE:
		ThingData.write(things, offset + byte_index, 0)

	ThingData.write(things, offset, thing_type)
	ThingData.write(things, offset + 3, target.x)
	ThingData.write(things, offset + 4, target.y)
	OverlayData.write(text, target_index, OverlayData.thing_id(thing_index))

	if not thing_chunk.set_decoded_payload(things):
		return DispatchEditResult.rejected("cannot store the dispatch unit")

	if not text_chunk.set_decoded_payload(text):
		thing_chunk.set_decoded_payload(old_things)

		return DispatchEditResult.rejected("cannot store the dispatch overlay")

	city.text_overlays = text.duplicate()

	var result := DispatchEditResult.new()
	result.ok = true
	result.command_type = "dispatch"
	result.group_index = group_index
	result.subtool_index = subtool_index
	result.thing_type = thing_type
	result.thing_index = thing_index
	result.target = target
	result.available = available_count
	result.slot_index = slot_index
	result.reset_existing = reset_existing
	result.old_things = old_things
	result.new_things = things
	result.old_text = old_text
	result.new_text = text

	return result


static func undo(city: CityState, command: DispatchEditResult) -> EditCommandResult:
	if city == null or not city.is_valid():
		return EditCommandResult.failure("city is invalid")

	if command == null or not command.ok or command.command_type != "dispatch":
		return EditCommandResult.failure("dispatch command is invalid")

	var thing_chunk := city.document.find_chunk("XTHG")
	var text_chunk := city.document.find_chunk("XTXT")

	if thing_chunk == null or text_chunk == null:
		return EditCommandResult.failure("dispatch chunks are missing")

	if thing_chunk.decoded_payload != command.new_things:
		return EditCommandResult.failure("moving things changed after this dispatch command")

	if text_chunk.decoded_payload != command.new_text:
		return EditCommandResult.failure("text overlays changed after this dispatch command")

	if not thing_chunk.set_decoded_payload(command.old_things):
		return EditCommandResult.failure("cannot restore moving things")

	if not text_chunk.set_decoded_payload(command.old_text):
		thing_chunk.set_decoded_payload(command.new_things)

		return EditCommandResult.failure("cannot restore text overlays")

	city.text_overlays = command.old_text.duplicate()

	return EditCommandResult.undone(0)


static func _clear_existing_dispatch(things: PackedByteArray, text: PackedByteArray, map_edge: int = 128) -> void:
	for index in (map_edge * map_edge):
		var overlay := int(OverlayData.read(text, index))

		if not OverlayData.is_thing(overlay) or OverlayData.thing_record(overlay) < FIRST_THING or OverlayData.thing_record(overlay) >= ThingData.count(things):
			continue

		var thing_index := OverlayData.thing_record(overlay)
		var thing_type := int(ThingData.read(things, thing_index * THING_RECORD_SIZE))

		if TYPE_BY_SUBTOOL.has(thing_type):
			OverlayData.write(text, index, 0)
			ThingData.write(things, thing_index * THING_RECORD_SIZE, 0)


static func _records_of_type(things: PackedByteArray, thing_type: int) -> PackedInt32Array:
	var result := PackedInt32Array()

	for thing_index in range(FIRST_THING, ThingData.count(things)):
		if ThingData.read(things, thing_index * THING_RECORD_SIZE) == thing_type:
			result.append(thing_index)

	return result


static func _first_free_thing(things: PackedByteArray) -> int:
	for thing_index in range(FIRST_THING, ThingData.count(things)):
		if ThingData.read(things, thing_index * THING_RECORD_SIZE) == 0:
			return thing_index

	return -1


static func _delete_thing(
	things: PackedByteArray, text: PackedByteArray, thing_index: int,
	map_edge: int = 128,
) -> void:
	if thing_index < FIRST_THING or thing_index >= ThingData.count(things):
		return

	var offset := thing_index * THING_RECORD_SIZE
	var x := int(ThingData.read(things, offset + 3))
	var y := int(ThingData.read(things, offset + 4))

	if x >= 0 and x < map_edge and y >= 0 and y < map_edge:
		var map_index := x * map_edge + y

		if OverlayData.read(text, map_index) == OverlayData.thing_id(thing_index):
			OverlayData.write(text, map_index, 0)

	for byte_index in THING_RECORD_SIZE:
		ThingData.write(things, offset + byte_index, 0)


static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func recall_all(city: CityState) -> DispatchEditResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return DispatchEditResult.rejected("city is invalid")

	var things_chunk := city.document.find_chunk("XTHG")
	var text_chunk := city.document.find_chunk("XTXT")
	var old_things: PackedByteArray = things_chunk.decoded_payload.duplicate()
	var old_text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	var things := old_things.duplicate()
	var text := old_text.duplicate()
	_clear_existing_dispatch(things, text, map_edge)
	things_chunk.set_decoded_payload(things)
	text_chunk.set_decoded_payload(text)
	city.text_overlays = text.duplicate()

	var result := DispatchEditResult.new()
	result.ok = true
	result.command_type = "dispatch"
	result.old_things = old_things
	result.new_things = things
	result.old_text = old_text
	result.new_text = text

	return result
