class_name NewsQueue
extends RefCounted

const MISC_SIZE := 4800
const PAPER_OFFSET := 0x0e50
const PAPER_COUNT := 6
const PAPER_FIELD_COUNT := 5
const PAPER_RECORD_SIZE := PAPER_FIELD_COUNT * 4
const STORY_OFFSET := 0x0ec8
const QUEUE_COUNT := 7
const STORY_RECORD_COUNT := 9
const STORY_FIELD_COUNT := 6
const STORY_RECORD_SIZE := STORY_FIELD_COUNT * 4

const STORY_TYPE_FIELD := 0
const PRIORITY_FIELD := 1
const ARGUMENT_FIELD := 2
const FIRST_AUXILIARY_FIELD := 3

const PAPER_NAME_FIELD := 0
const PAPER_LAYOUT_FIELD := 1
const PAPER_PRICE_FIELD := 2
const PAPER_OPINION_FIELD := 3
const PAPER_WEATHER_FIELD := 4

# data_usa resources 1004 and 1005 are big-endian unsigned 16-bit tables
# the supplied executable byte-swaps them after loading
const STORY_PRIORITIES := [
	0, 0, 1000, 1000, 1000, 1000, 360, 200, 200, 200,
	200, 200, 200, 200, 200, 200, 200, 200, 200, 200,
	200, 200, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000,
	1000, 1000, 1000, 1000, 1000, 1000, 1000, 200, 200, 300,
	200, 200, 0, 0, 0, 0, 500, 500, 500, 500,
	500, 500, 500, 500, 500, 500, 500, 500, 500, 500,
	500, 200, 200, 200, 200, 200, 200, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
]

const STORY_DECAYS := [
	0, 0, 500, 500, 250, 250, 10, 50, 50, 50,
	50, 50, 50, 50, 50, 50, 50, 50, 50, 50,
	50, 50, 250, 250, 250, 250, 250, 250, 250, 250,
	250, 250, 250, 250, 250, 250, 100, 50, 50, 50,
	50, 50, 0, 0, 0, 0, 500, 500, 500, 500,
	500, 500, 500, 500, 500, 500, 500, 500, 500, 500,
	500, 50, 50, 50, 50, 50, 50, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
]


static func is_story_type(story_type: int) -> bool:
	return story_type >= 0 and story_type < STORY_PRIORITIES.size()


static func decay_and_sort(misc: PackedByteArray) -> Dictionary:
	var validation := _validate_misc(misc)
	if not validation.ok:
		return validation
	for slot in QUEUE_COUNT:
		var offset := _story_offset(slot)
		var story_type := _to_i16(_read_u32(misc, offset))
		if not is_story_type(story_type):
			return _failure("newspaper queue story type is out of range")
		var priority := _to_i16(_read_u32(misc, offset + 4))
		var decay: int = STORY_DECAYS[story_type]
		_write_u32(misc, offset + 4, priority - decay if decay < priority else 0)

	for first_slot in QUEUE_COUNT - 1:
		for candidate_slot in range(first_slot + 1, QUEUE_COUNT):
			var first_priority := _story_priority(misc, first_slot)
			var candidate_priority := _story_priority(misc, candidate_slot)
			if first_priority < candidate_priority:
				_swap_story_records(misc, first_slot, candidate_slot)
	return {"ok": true, "error": ""}


static func insert(misc: PackedByteArray, story_type: int, argument: int) -> Dictionary:
	var validation := _validate_misc(misc)
	if not validation.ok:
		return validation
	if not is_story_type(story_type):
		return _failure("newspaper story type is out of range")

	var priority: int = STORY_PRIORITIES[story_type]
	var slot := QUEUE_COUNT - 2
	while slot >= 0:
		if priority < _story_priority(misc, slot):
			break
		_copy_story_record(misc, slot, slot + 1)
		slot -= 1
	var inserted_slot := slot + 1
	var offset := _story_offset(inserted_slot)
	_write_u32(misc, offset + STORY_TYPE_FIELD * 4, story_type)
	_write_u32(misc, offset + PRIORITY_FIELD * 4, priority)
	_write_u32(misc, offset + ARGUMENT_FIELD * 4, argument & 0xff)
	for field in range(FIRST_AUXILIARY_FIELD, STORY_FIELD_COUNT):
		_write_u32(misc, offset + field * 4, 0xff)
	return {
		"ok": true,
		"error": "",
		"slot": inserted_slot,
		"priority": priority,
	}


static func insert_items(misc: PackedByteArray, news_items: Array) -> Dictionary:
	var inserted := 0
	for item in news_items:
		var story_type := int(item.get("type", -1))
		if not is_story_type(story_type):
			continue
		var result := insert(misc, story_type, int(item.get("argument", 0)))
		if not result.ok:
			return result
		inserted += 1
	return {"ok": true, "error": "", "inserted": inserted}


static func story_record(misc: PackedByteArray, slot: int) -> Dictionary:
	if not _validate_misc(misc).ok or slot < 0 or slot >= STORY_RECORD_COUNT:
		return {}
	var offset := _story_offset(slot)
	return {
		"type": _to_i16(_read_u32(misc, offset)),
		"priority": _to_i16(_read_u32(misc, offset + 4)),
		"argument": _read_u32(misc, offset + 8) & 0xff,
		"auxiliary": PackedByteArray([
			_read_u32(misc, offset + 12) & 0xff,
			_read_u32(misc, offset + 16) & 0xff,
			_read_u32(misc, offset + 20) & 0xff,
		]),
	}


static func paper_record(misc: PackedByteArray, paper: int) -> Dictionary:
	if not _validate_misc(misc).ok or paper < 0 or paper >= PAPER_COUNT:
		return {}
	var offset := PAPER_OFFSET + paper * PAPER_RECORD_SIZE
	return {
		"name": _read_u32(misc, offset + PAPER_NAME_FIELD * 4) & 0xff,
		"layout": _read_u32(misc, offset + PAPER_LAYOUT_FIELD * 4) & 0xff,
		"price": _read_u32(misc, offset + PAPER_PRICE_FIELD * 4) & 0xff,
		"opinion": _read_u32(misc, offset + PAPER_OPINION_FIELD * 4) & 0xff,
		"weather": _read_u32(misc, offset + PAPER_WEATHER_FIELD * 4) & 0xff,
	}


static func update_story_substitutions(
	misc: PackedByteArray, slot: int, argument: int, auxiliary: PackedByteArray
) -> Dictionary:
	var validation := _validate_misc(misc)
	if not validation.ok:
		return validation
	if slot < 0 or slot >= STORY_RECORD_COUNT:
		return _failure("newspaper story slot is out of range")
	if auxiliary.size() != 3:
		return _failure("newspaper story auxiliary data has the wrong size")
	var offset := _story_offset(slot)
	_write_u32(misc, offset + ARGUMENT_FIELD * 4, argument & 0xff)
	for index in 3:
		_write_u32(
			misc,
			offset + (FIRST_AUXILIARY_FIELD + index) * 4,
			auxiliary[index],
		)
	return {"ok": true, "error": ""}


static func _validate_misc(misc: PackedByteArray) -> Dictionary:
	if misc.size() != MISC_SIZE:
		return _failure("MISC is missing or has the wrong size")
	return {"ok": true, "error": ""}


static func _story_offset(slot: int) -> int:
	return STORY_OFFSET + slot * STORY_RECORD_SIZE


static func _story_priority(misc: PackedByteArray, slot: int) -> int:
	return _to_i16(_read_u32(misc, _story_offset(slot) + 4))


static func _copy_story_record(misc: PackedByteArray, source_slot: int, target_slot: int) -> void:
	var source := _story_offset(source_slot)
	var target := _story_offset(target_slot)
	for index in STORY_RECORD_SIZE:
		misc[target + index] = misc[source + index]


static func _swap_story_records(misc: PackedByteArray, first_slot: int, second_slot: int) -> void:
	var first := _story_offset(first_slot)
	var second := _story_offset(second_slot)
	for index in STORY_RECORD_SIZE:
		var temporary := misc[first + index]
		misc[first + index] = misc[second + index]
		misc[second + index] = temporary


static func _to_i16(value: int) -> int:
	var word := value & 0xffff
	return word - 0x10000 if word & 0x8000 else word


static func _read_u32(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	var encoded := value & 0xffffffff
	data[offset] = (encoded >> 24) & 0xff
	data[offset + 1] = (encoded >> 16) & 0xff
	data[offset + 2] = (encoded >> 8) & 0xff
	data[offset + 3] = encoded & 0xff


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
