class_name NewspaperText
extends RefCounted
## The newspaper story text. The native simulation library expands the DATA_USA
## grammar; see native/core/game/src/newspaper/mod.rs.

# the seed offset of each saved story slot. -1 marks a slot without a published story
static var PUBLISHED_SEED_OFFSETS: PackedInt64Array = NativeNewspaper.published_seed_offsets()
# the grammar token bytes of phrases 32 and up
static var EXTENDED_TOKEN_BYTES: PackedByteArray = NativeNewspaper.extended_token_bytes()


static func published_seed(
	session_seed: int, city_days: int, paper_index: int, story_slot: int
) -> int:
	return NativeNewspaper.published_seed(session_seed, city_days, paper_index, story_slot)


static func token_phrase_id(value: int) -> int:
	return NativeNewspaper.token_phrase_id(value)


static func render_story(
	data: DataUsaResource,
	record: NewsQueue.StoryRecord,
	story_seed: int,
	city_text: String,
	mayor_text: String,
	teams: PackedStringArray
) -> Result:
	return _render(data, record, story_seed, city_text, mayor_text, teams, false)


static func render_headline(
	data: DataUsaResource,
	record: NewsQueue.StoryRecord,
	story_seed: int,
	city_text: String,
	mayor_text: String,
	teams: PackedStringArray
) -> Result:
	return _render(data, record, story_seed, city_text, mayor_text, teams, true)


static func _render(
	data: DataUsaResource,
	record: NewsQueue.StoryRecord,
	story_seed: int,
	city_text: String,
	mayor_text: String,
	teams: PackedStringArray,
	headline_only: bool,
) -> Result:
	var result := Result.new()

	if data == null or not data.is_valid():
		result.error = "newspaper grammar data is invalid"

		return result

	if record == null:
		result.error = "newspaper story record is incomplete"

		return result

	var grammar := {
		"bases": data.bases, "counts": data.counts, "offsets": data.offsets, "grammar": data.grammar,
		"is_johab": data.is_johab,
	}
	var story := {"type": int(record.type), "argument": int(record.argument), "auxiliary": record.auxiliary}
	var names := {"city": city_text, "mayor": mayor_text, "teams": teams}
	var rendered := NativeNewspaper.render(grammar, story, story_seed, names, headline_only)
	result.ok = rendered.ok
	result.error = rendered.error

	if result.ok:
		result.headline = rendered.headline
		result.article = rendered.article
		result.argument = rendered.argument
		result.auxiliary = rendered.auxiliary
		result.random_state = rendered.random_state

	return result


class Result extends RefCounted:
	var ok := false
	var error := ""
	var headline := ""
	var article := ""
	var argument := 0
	var auxiliary := PackedByteArray()
	var random_state := 0
