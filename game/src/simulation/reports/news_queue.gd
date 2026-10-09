class_name NewsQueue
extends RefCounted
## The saved newspaper papers and story queue in MISC. The native simulation
## library holds the rules; see native/core/sim/src/sim/reports/news.rs.

const MISC_SIZE := Sc2MiscLayout.SIZE
const PAPER_OFFSET := Sc2MiscLayout.PAPERS
const PAPER_COUNT := 6
const PAPER_FIELD_COUNT := 5
const PAPER_RECORD_SIZE := PAPER_FIELD_COUNT * 4
const STORY_OFFSET := Sc2MiscLayout.STORIES
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
# data_usa resources 1004 and 1005: the priority and decay of each story type
static var STORY_PRIORITIES := NativeNewsQueue.story_priorities()
static var STORY_DECAYS := NativeNewsQueue.story_decays()


static func is_story_type(story_type: int) -> bool:
	return NativeNewsQueue.is_story_type(story_type)


static func initialize_session(misc: PackedByteArray, random: SimRandom) -> Result:
	var validation := _validate_misc(misc)

	if not validation.ok:
		return validation

	if random == null:
		return _failure("newspaper process-random state is missing")

	var draws := PackedInt64Array()

	for _call in NativeNewsQueue.session_random_calls():
		draws.append(random.next_u15())

	var result := _store(misc, NativeNewsQueue.initialize_session(misc, draws))
	result.random_calls = draws.size()

	return result


static func decay_and_sort(misc: PackedByteArray) -> Result:
	return _store(misc, NativeNewsQueue.decay_and_sort(misc))


static func insert(misc: PackedByteArray, story_type: int, argument: int) -> Result:
	var response := NativeNewsQueue.insert(misc, story_type, argument)
	var result := _store(misc, response)
	result.slot = response.slot
	result.priority = response.priority

	return result


static func insert_items(misc: PackedByteArray, news_items: Array[NewsEvent]) -> Result:
	var types := PackedInt64Array()
	var arguments := PackedInt64Array()

	for item in news_items:
		types.append(int(item.type))
		arguments.append(int(item.argument))

	var response := NativeNewsQueue.insert_items(misc, types, arguments)
	var result := _store(misc, response)
	result.inserted = response.inserted

	return result


static func story_record(misc: PackedByteArray, slot: int) -> StoryRecord:
	var fields := NativeNewsQueue.story_record(misc, slot)

	if fields.is_empty():
		return null

	var result := StoryRecord.new(fields.type, fields.argument, fields.auxiliary)
	result.priority = fields.priority

	return result


# the supplied news routine at 0x0047b5c0 opens an extra edition for these
# stories when the extra-edition option is on
static func opens_extra_edition(story_type: int) -> bool:
	return NativeNewsQueue.opens_extra_edition(story_type)


static func available_paper_count(progression: int) -> int:
	return NativeNewsQueue.available_paper_count(progression)


static func prepare_weather_report(misc: PackedByteArray, weather: int) -> Result:
	return _store(misc, NativeNewsQueue.prepare_weather_report(misc, weather))


static func prepare_opinion_report(misc: PackedByteArray, style: int, subject: int) -> Result:
	return _store(misc, NativeNewsQueue.prepare_opinion_report(misc, style, subject))


static func paper_record(misc: PackedByteArray, paper: int) -> PaperRecord:
	var fields := NativeNewsQueue.paper_record(misc, paper)

	if fields.is_empty():
		return null

	var result := PaperRecord.new()
	result.name = fields[PAPER_NAME_FIELD]
	result.layout = fields[PAPER_LAYOUT_FIELD]
	result.price = fields[PAPER_PRICE_FIELD]
	result.opinion = fields[PAPER_OPINION_FIELD]
	result.weather = fields[PAPER_WEATHER_FIELD]

	return result


static func update_story_substitutions(
	misc: PackedByteArray, slot: int, argument: int, auxiliary: PackedByteArray
) -> Result:
	return _store(misc, NativeNewsQueue.update_story_substitutions(misc, slot, argument, auxiliary))


# copy a successful native edit into the caller's MISC array
static func _store(misc: PackedByteArray, response: Dictionary) -> Result:
	if not response.ok:
		return _failure(response.error)

	misc.clear()
	misc.append_array(response.misc)

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


static func _failure(message: String) -> Result:
	var result := Result.new()
	result.ok = false
	result.error = message

	return result


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
