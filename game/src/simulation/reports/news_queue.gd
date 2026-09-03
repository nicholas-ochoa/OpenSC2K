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


class Result extends RefCounted:
	var ok := false
	var error := ""
	var random_calls := 0
	var slot := 0
	var priority := 0
	var inserted := 0


class StoryRecord extends RefCounted:
	var type := 0
	var priority := 0
	var argument := 0
	var auxiliary := PackedByteArray()

	func _init(story_type := 0, story_argument := 0, story_auxiliary := PackedByteArray()) -> void:
		type = story_type
		argument = story_argument
		auxiliary = story_auxiliary


class PaperRecord extends RefCounted:
	var name := 0
	var layout := 0
	var price := 0
	var opinion := 0
	var weather := 0


static func is_story_type(story_type: int) -> bool:
	return story_type >= 0 and story_type < STORY_PRIORITIES.size()


static func initialize_session(misc: PackedByteArray, random: SimRandom) -> Result:
	var validation := _validate_misc(misc)

	if not validation.ok:
		return validation

	if random == null:
		return _failure("newspaper process-random state is missing")

	for paper in PAPER_COUNT:
		_write_paper_field(misc, paper, PAPER_NAME_FIELD, paper)
		_write_paper_field(misc, paper, PAPER_LAYOUT_FIELD, paper % 3)
		_write_paper_field(misc, paper, PAPER_PRICE_FIELD, paper % 3)
		_write_paper_field(misc, paper, PAPER_OPINION_FIELD, paper)
		_write_paper_field(misc, paper, PAPER_WEATHER_FIELD, paper)

	_swap_paper_field(
		misc,
		0,
		3 + (int(random.next_u15()) & 1),
		PAPER_OPINION_FIELD,
	)

	if int(random.next_u15()) & 1:
		_swap_paper_field(misc, 0, 1, PAPER_LAYOUT_FIELD)

	for _pass in 12:
		_swap_random_paper_field(misc, random, PAPER_NAME_FIELD, 0, 6)
		_swap_random_paper_field(misc, random, PAPER_LAYOUT_FIELD, 1, 5)
		_swap_random_paper_field(misc, random, PAPER_PRICE_FIELD, 0, 6)
		_swap_random_paper_field(misc, random, PAPER_OPINION_FIELD, 1, 5)
		_swap_random_paper_field(misc, random, PAPER_WEATHER_FIELD, 0, 6)

	for slot in STORY_RECORD_COUNT:
		var offset := _story_offset(slot)
		_write_u32(misc, offset, 11 + slot)
		_write_u32(misc, offset + 4, 0)
		_write_u32(misc, offset + 8, 0)

		for field in range(FIRST_AUXILIARY_FIELD, STORY_FIELD_COUNT):
			_write_u32(misc, offset + field * 4, 0xff)

	var result := Result.new()
	result.ok = true
	result.error = ""
	result.random_calls = 122

	return result


static func decay_and_sort(misc: PackedByteArray) -> Result:
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

	var result := Result.new()
	result.ok = true
	result.error = ""

	return result


static func insert(misc: PackedByteArray, story_type: int, argument: int) -> Result:
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

	var result := Result.new()
	result.ok = true
	result.error = ""
	result.slot = inserted_slot
	result.priority = priority

	return result


static func insert_items(misc: PackedByteArray, news_items: Array) -> Result:
	var inserted := 0

	for item in news_items:
		var story_type := int(item.get("type", -1))

		if not is_story_type(story_type):
			continue

		var result := insert(misc, story_type, int(item.get("argument", 0)))

		if not result.ok:
			return result

		inserted += 1

	var result := Result.new()
	result.ok = true
	result.error = ""
	result.inserted = inserted

	return result


static func story_record(misc: PackedByteArray, slot: int) -> StoryRecord:
	if not _validate_misc(misc).ok or slot < 0 or slot >= STORY_RECORD_COUNT:
		return null

	var offset := _story_offset(slot)

	var result := StoryRecord.new()
	result.type = _to_i16(_read_u32(misc, offset))
	result.priority = _to_i16(_read_u32(misc, offset + 4))
	result.argument = _read_u32(misc, offset + 8) & 0xff
	result.auxiliary = PackedByteArray([
		_read_u32(misc, offset + 12) & 0xff,
		_read_u32(misc, offset + 16) & 0xff,
		_read_u32(misc, offset + 20) & 0xff,
	])

	return result


static func available_paper_count(progression: int) -> int:
	# the supplied menu builder at 0x00406d70 reads a signed progression word
	var level := progression & 0xffff

	if level & 0x8000:
		level -= 0x10000

	return clampi(level + 1, 0, PAPER_COUNT)


static func prepare_weather_report(misc: PackedByteArray, weather: int) -> Result:
	var validation := _validate_misc(misc)

	if not validation.ok:
		return validation

	# newspaper opening sets display slot 7 to weather type 0 and the current trend
	var offset := STORY_OFFSET + 7 * STORY_RECORD_SIZE
	_write_u32(misc, offset, 0)
	_write_u32(misc, offset + 8, weather & 0xff)

	var result := Result.new()
	result.ok = true
	result.error = ""

	return result


static func prepare_opinion_report(misc: PackedByteArray, style: int, subject: int) -> Result:
	var validation := _validate_misc(misc)

	if not validation.ok:
		return validation

	# the supplied newspaper opener selects these types from the paper's opinion style
	var types := [42, 43, 43, 44, 44, 45]
	var offset := STORY_OFFSET + 8 * STORY_RECORD_SIZE
	_write_u32(misc, offset, types[clampi(style, 0, 5)])
	_write_u32(misc, offset + 8, subject & 0xff)

	var result := Result.new()
	result.ok = true
	result.error = ""

	return result


static func paper_record(misc: PackedByteArray, paper: int) -> PaperRecord:
	if not _validate_misc(misc).ok or paper < 0 or paper >= PAPER_COUNT:
		return null

	var offset := PAPER_OFFSET + paper * PAPER_RECORD_SIZE

	var result := PaperRecord.new()
	result.name = _read_u32(misc, offset + PAPER_NAME_FIELD * 4) & 0xff
	result.layout = _read_u32(misc, offset + PAPER_LAYOUT_FIELD * 4) & 0xff
	result.price = _read_u32(misc, offset + PAPER_PRICE_FIELD * 4) & 0xff
	result.opinion = _read_u32(misc, offset + PAPER_OPINION_FIELD * 4) & 0xff
	result.weather = _read_u32(misc, offset + PAPER_WEATHER_FIELD * 4) & 0xff

	return result


static func update_story_substitutions(
	misc: PackedByteArray, slot: int, argument: int, auxiliary: PackedByteArray
) -> Result:
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

	var result := Result.new()
	result.ok = true
	result.error = ""

	return result


static func _validate_misc(misc: PackedByteArray) -> Result:
	if misc.size() != MISC_SIZE:
		return _failure("MISC is missing or has the wrong size")

	var result := Result.new()
	result.ok = true
	result.error = ""

	return result


static func _story_offset(slot: int) -> int:
	return STORY_OFFSET + slot * STORY_RECORD_SIZE


static func _paper_field_offset(paper: int, field: int) -> int:
	return PAPER_OFFSET + paper * PAPER_RECORD_SIZE + field * 4


static func _write_paper_field(
	misc: PackedByteArray, paper: int, field: int, value: int
) -> void:
	_write_u32(misc, _paper_field_offset(paper, field), value)


static func _swap_paper_field(
	misc: PackedByteArray, first_paper: int, second_paper: int, field: int
) -> void:
	var first_offset := _paper_field_offset(first_paper, field)
	var second_offset := _paper_field_offset(second_paper, field)
	var first_value := _read_u32(misc, first_offset)
	_write_u32(misc, first_offset, _read_u32(misc, second_offset))
	_write_u32(misc, second_offset, first_value)


static func _swap_random_paper_field(
	misc: PackedByteArray,
	random: SimRandom,
	field: int,
	first_paper: int,
	paper_count: int
) -> void:
	var source := first_paper + int(random.next_u15()) % paper_count
	var target := first_paper + int(random.next_u15()) % paper_count
	_swap_paper_field(misc, source, target, field)


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


static func _failure(message: String) -> Result:
	var result := Result.new()
	result.ok = false
	result.error = message

	return result
