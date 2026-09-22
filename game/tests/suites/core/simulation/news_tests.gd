extends "res://tests/support/core_test_suite.gd"

## Simulation: news checks.

@warning_ignore_start("integer_division")

const DataUsa = preload("res://src/assets/data_usa_resource.gd")
const Random = preload("res://src/simulation/random/sim_random.gd")
const NewspaperTextGenerator = preload("res://src/simulation/reports/newspaper_text.gd")
const Simulation = preload("res://src/simulation/core/simulation_engine.gd")
const NewspaperTables = preload("res://src/model/newspaper_layout.gd")


func test_news_queue(reference_root: String) -> void:
	var source_priorities := _load_indexed_u16_resource(reference_root, 1004)
	var source_decays := _load_indexed_u16_resource(reference_root, 1005)
	_check(
		source_priorities == PackedInt32Array(NewsQueue.STORY_PRIORITIES),
		"Newspaper priorities match DATA_USA resource 1004",
	)
	_check(
		source_decays == PackedInt32Array(NewsQueue.STORY_DECAYS),
		"Newspaper decays match DATA_USA resource 1005",
	)

	var paper_misc := _filled_bytes(NewsQueue.MISC_SIZE, 0)

	for field in NewsQueue.PAPER_FIELD_COUNT:
		_write_u32_be(paper_misc, NewsQueue.PAPER_OFFSET + field * 4, 0x100 + field)

	var paper := NewsQueue.paper_record(paper_misc, 0)
	_check(
		paper.name == 0 and paper.layout == 1 and paper.price == 2
		and paper.opinion == 3 and paper.weather == 4,
		"Newspaper paper records narrow all five saved fields",
	)
	_check(
		NewsQueue.paper_record(paper_misc, -1) == null
		and NewsQueue.paper_record(paper_misc, NewsQueue.PAPER_COUNT) == null,
		"Newspaper paper reader rejects invalid indices",
	)
	var session_misc := _filled_bytes(NewsQueue.MISC_SIZE, 0)
	var session_random := Random.new(1)
	var session_init := NewsQueue.initialize_session(session_misc, session_random)
	var paper_rows: Array[Array] = []

	for paper_index in NewsQueue.PAPER_COUNT:
		var session_paper := NewsQueue.paper_record(session_misc, paper_index)
		paper_rows.append([
			session_paper.name,
			session_paper.layout,
			session_paper.price,
			session_paper.opinion,
			session_paper.weather,
		])

	_check(
		session_init.ok
		and session_init.random_calls == 122
		and session_random.state == 3018468955
		and paper_rows == [
			[4, 1, 0, 4, 2],
			[1, 0, 1, 3, 1],
			[2, 0, 0, 5, 3],
			[5, 2, 2, 2, 0],
			[3, 1, 1, 0, 4],
			[0, 2, 2, 1, 5],
		],
		"Newspaper session initialization reproduces all 122 seed-one random calls",
	)
	var initial_story_records_valid := true

	for slot in NewsQueue.STORY_RECORD_COUNT:
		var initial_story := NewsQueue.story_record(session_misc, slot)
		initial_story_records_valid = initial_story_records_valid and (
			initial_story.type == 11 + slot
			and initial_story.priority == 0
			and initial_story.argument == 0
			and initial_story.auxiliary == PackedByteArray([0xff, 0xff, 0xff])
		)

	_check(
		initial_story_records_valid,
		"Newspaper session initialization resets all nine story records",
	)
	_check(
		NewspaperTables.PAGE_SIZE == Vector2i(640, 400)
		and NewspaperTables.section_rect(0, 3) == Rect2i(243, 76, 213, 100)
		and NewspaperTables.story_rect(1, 4) == Rect2i(512, 186, 128, 214)
		and NewspaperTables.story_rect(2, 0) == Rect2i(0, 30, 128, 370),
		"Newspaper page exposes the executable's three fixed layouts",
	)

	var misc := _filled_bytes(NewsQueue.MISC_SIZE, 0)
	var decay_types := PackedInt32Array([2, 6, 7, 46, 39, 42, 61])
	var decay_priorities := PackedInt32Array([900, 100, 40, 500, 250, 150, 100])

	for slot in NewsQueue.STORY_RECORD_COUNT:
		var offset := NewsQueue.STORY_OFFSET + slot * NewsQueue.STORY_RECORD_SIZE
		var story_type := decay_types[slot] if slot < NewsQueue.QUEUE_COUNT else 11 + slot
		var priority := decay_priorities[slot] if slot < NewsQueue.QUEUE_COUNT else 700 + slot
		_write_u32_be(misc, offset, story_type)
		_write_u32_be(misc, offset + 4, priority)
		_write_u32_be(misc, offset + 8, slot)
		_write_u32_be(misc, offset + 12, 0xa0 + slot)
		_write_u32_be(misc, offset + 16, 0xb0 + slot)
		_write_u32_be(misc, offset + 20, 0xc0 + slot)

	var decay := NewsQueue.decay_and_sort(misc)
	_check(decay.ok, "Newspaper queue decays and sorts: %s" % decay.error)
	var decayed_types := PackedInt32Array()
	var decayed_priorities := PackedInt32Array()

	for slot in NewsQueue.QUEUE_COUNT:
		var record := NewsQueue.story_record(misc, slot)
		decayed_types.append(record.type)
		decayed_priorities.append(record.priority)

	_check(
		decayed_types == PackedInt32Array([2, 39, 42, 6, 61, 46, 7]),
		"Newspaper decay sorts complete records by descending priority",
	)
	_check(
		decayed_priorities == PackedInt32Array([400, 200, 150, 90, 50, 0, 0]),
		"Newspaper decay subtracts each story-specific value and clamps at zero",
	)
	_check(
		NewsQueue.story_record(misc, 5).argument == 3
		and NewsQueue.story_record(misc, 5).auxiliary == PackedByteArray([0xa3, 0xb3, 0xc3]),
		"Newspaper sorting moves the argument and auxiliary bytes with a story",
	)
	_check(
		NewsQueue.story_record(misc, 7).type == 18
		and NewsQueue.story_record(misc, 7).priority == 707,
		"Monthly newspaper decay does not change display record eight",
	)

	var insert_types := PackedInt32Array([2, 46, 8, 7, 61, 6, 42])
	var insert_priorities := PackedInt32Array([1000, 500, 200, 200, 150, 100, 50])

	for slot in NewsQueue.QUEUE_COUNT:
		var offset := NewsQueue.STORY_OFFSET + slot * NewsQueue.STORY_RECORD_SIZE
		_write_u32_be(misc, offset, insert_types[slot])
		_write_u32_be(misc, offset + 4, insert_priorities[slot])
		_write_u32_be(misc, offset + 8, slot)
		_write_u32_be(misc, offset + 12, 0x80 + slot)
		_write_u32_be(misc, offset + 16, 0x90 + slot)
		_write_u32_be(misc, offset + 20, 0xa0 + slot)

	var inserted := NewsQueue.insert(misc, 17, 0x102)
	_check(
		inserted.ok and inserted.slot == 2 and inserted.priority == 200,
		"Newspaper inserts before older stories with equal priority",
	)
	var inserted_types := PackedInt32Array()

	for slot in NewsQueue.QUEUE_COUNT:
		inserted_types.append(NewsQueue.story_record(misc, slot).type)

	_check(
		inserted_types == PackedInt32Array([2, 46, 17, 8, 7, 61, 6]),
		"Newspaper insertion displaces the seventh story",
	)
	var inserted_record := NewsQueue.story_record(misc, 2)
	_check(
		inserted_record.argument == 2
		and inserted_record.auxiliary == PackedByteArray([0xff, 0xff, 0xff]),
		"Newspaper insertion narrows the argument and resets auxiliary fields",
	)
	_check(
		NewsQueue.story_record(misc, 3).argument == 2
		and NewsQueue.story_record(misc, 3).auxiliary == PackedByteArray([0x82, 0x92, 0xa2]),
		"Newspaper insertion preserves every field of a shifted story",
	)
	var before_invalid := misc.duplicate()
	var invalid := NewsQueue.insert(misc, 80, 0)
	_check(not invalid.ok and misc == before_invalid, "Newspaper rejects an invalid type without a write")
	var substitutions := NewsQueue.update_story_substitutions(
		misc, 0, 0x102, PackedByteArray([3, 4, 5])
	)
	var substituted_record := NewsQueue.story_record(misc, 0)
	_check(
		substitutions.ok
		and substituted_record.argument == 2
		and substituted_record.auxiliary == PackedByteArray([3, 4, 5]),
		"Newspaper stores narrowed generated substitutions in one saved record",
	)
	var mixed := NewsQueue.insert_items(
		misc,
		[NewsEvent.new(0x1f8, 0), NewsEvent.new(39, 4)],
	)
	_check(
		mixed.ok and mixed.inserted == 1 and NewsQueue.story_record(misc, 2).type == 39,
		"Newspaper insertion skips non-story runtime notifications",
	)

	var engine_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(_clear_news_records(engine_document), "Engine newspaper fixture clears story records")
	var engine_city := CityModel.from_document(engine_document)
	var engine := Simulation.new(engine_city, 1, 7, 13)
	var phase_result := PhaseResult.new()
	phase_result.ok = true
	phase_result.news_items = [
		NewsEvent.new(0x1fe, 0),
		NewsEvent.new(9, 4),
	]
	var persisted := engine._persist_news_result(phase_result)
	var persisted_record := NewsQueue.story_record(
		engine_document.find_chunk("MISC").decoded_payload, 0
	)
	_check(
		persisted.ok
		and persisted.inserted == 1
		and phase_result.news_queue_updated
		and phase_result.news_queue_inserted == 1
		and persisted_record.type == 9
		and persisted_record.priority == 200
		and persisted_record.argument == 4,
		"Simulation engine persists valid story events and skips runtime notifications",
	)
	var before_duplicate: PackedByteArray = engine_document.find_chunk("MISC").decoded_payload.duplicate()
	var already_updated := PhaseResult.new()
	already_updated.ok = true
	already_updated.news_queue_updated = true
	already_updated.news_items = [NewsEvent.new(3, 0)]
	var duplicate := engine._persist_news_result(already_updated)
	_check(
		duplicate.ok
		and duplicate.inserted == 0
		and engine_document.find_chunk("MISC").decoded_payload == before_duplicate,
		"Simulation engine does not insert a phase result twice",
	)


func test_newspaper_text(reference_root: String) -> void:
	var data := DataUsa.load_path(
		reference_root.path_join("DATA/DATA_USA.DAT"),
		reference_root.path_join("DATA/DATA_USA.IDX"),
	)
	_check(data.is_valid(), "DATA_USA newspaper grammar loads: %s" % data.load_error)

	if not data.is_valid():
		return

	_check(
		data.bases.size() == 250 and data.counts.size() == 250,
		"Newspaper grammar has both 250-entry phrase tables",
	)
	_check(data.offsets.size() == 2500, "Newspaper grammar has 2,500 phrase offsets")
	_check(
		data.bases[0] == 92 and data.counts[0] == 1,
		"Newspaper grammar decodes the first base and count",
	)
	_check(
		not DataUsa.load_path("/missing/DATA_USA.DAT", "/missing/DATA_USA.IDX").is_valid(),
		"Newspaper grammar loader rejects missing files",
	)

	var executable_tokens := _load_pe_rva_bytes(
		reference_root.path_join("SIMCITY.EXE"), 0x000ea228, 512
	)
	var implemented_tokens := PackedByteArray()

	for token in 256:
		var phrase_id := NewspaperTextGenerator.token_phrase_id(token)
		implemented_tokens.append(phrase_id & 0xff)
		implemented_tokens.append((phrase_id >> 8) & 0xff)

	_check(
		implemented_tokens == executable_tokens,
		"Newspaper token map matches executable table 0x004ea228",
	)
	_check(
		NewspaperTextGenerator.published_seed(0x1234, 250, 2, 0)
		== 0x1234 + 10 + 1000 + 28,
		"Newspaper top-story seed uses session, month, paper, and section values",
	)
	_check(
		NewspaperTextGenerator.published_seed(0, 0, 0, 1) == 49
		and NewspaperTextGenerator.published_seed(0, 0, 0, 4) == 70
		and NewspaperTextGenerator.published_seed(0, 0, 0, 5) == -1,
		"Newspaper seed map covers only the published saved story slots",
	)

	var document := _load_fixture(reference_root.path_join("CITIES/STARTER.SC2"))
	var city := CityModel.from_document(document)
	var misc: PackedByteArray = document.find_chunk("MISC").decoded_payload
	var teams := PackedStringArray()

	for label_id in range(251, 256):
		teams.append(city.label(label_id))

	for slot in [0, 1, 2, 3, 4, 7, 8]:
		var record := NewsQueue.story_record(misc, slot)
		var seed := NewspaperTextGenerator.published_seed(
			0x1234, city.age_in_days(), 0, slot
		)
		var rendered := NewspaperTextGenerator.render_story(
			data, record, seed, city.city_name(), city.mayor_name(), teams
		)
		_check(rendered.ok, "Newspaper story slot %d renders: %s" % [slot, rendered.error])

		if not rendered.ok:
			continue

		_check(not rendered.headline.is_empty(), "Newspaper story slot %d has a headline" % slot)
		_check(not rendered.article.is_empty(), "Newspaper story slot %d has article text" % slot)
		_check(
			not rendered.headline.contains("�") and not rendered.article.contains("�"),
			"Newspaper story slot %d decodes each source character" % slot,
		)
		var repeated := NewspaperTextGenerator.render_story(
			data, record, seed, city.city_name(), city.mayor_name(), teams
		)
		_check(
			repeated.ok
			and repeated.headline == rendered.headline
			and repeated.article == rendered.article
			and repeated.auxiliary == rendered.auxiliary
			and repeated.random_state == rendered.random_state,
			"Newspaper story slot %d is deterministic for one display seed" % slot,
		)
		var headline_only := NewspaperTextGenerator.render_headline(
			data, record, seed, city.city_name(), city.mayor_name(), teams
		)
		_check(
			headline_only.ok and headline_only.headline == rendered.headline,
			"Newspaper story slot %d has the same standalone headline" % slot,
		)

	for story_type in 80:
		var rendered := NewspaperTextGenerator.render_story(
			data,
			NewsQueue.StoryRecord.new(story_type, 0, PackedByteArray([0xff, 0xff, 0xff])),
			0x4000 + story_type * 17,
			city.city_name(),
			city.mayor_name(),
			teams,
		)
		_check(rendered.ok, "Newspaper grammar type %d renders: %s" % [story_type, rendered.error])

		if rendered.ok:
			_check(not rendered.headline.is_empty(), "Newspaper grammar type %d has a headline" % story_type)
			_check(
				not rendered.headline.contains("�") and not rendered.article.contains("�"),
				"Newspaper grammar type %d decodes each source character" % story_type,
			)


func _load_indexed_u16_resource(reference_root: String, resource_id: int) -> PackedInt32Array:
	var index := FileAccess.get_file_as_bytes(reference_root.path_join("DATA/DATA_USA.IDX"))
	var data := FileAccess.get_file_as_bytes(reference_root.path_join("DATA/DATA_USA.DAT"))

	if index.is_empty() or data.is_empty() or index.size() % 8 != 0:
		return PackedInt32Array()

	var start := -1
	var end := -1

	for offset in range(0, index.size(), 8):
		var current_id := _read_u32_le(index, offset)
		var current_start := _read_u32_le(index, offset + 4)

		if start >= 0 and end < 0:
			end = current_start
			break

		if current_id == resource_id:
			start = current_start

	if start < 0:
		return PackedInt32Array()

	if end < 0:
		end = data.size()

	if start > end or end > data.size() or (end - start) % 2 != 0:
		return PackedInt32Array()

	var values := PackedInt32Array()

	for offset in range(start, end, 2):
		values.append((int(data[offset]) << 8) | int(data[offset + 1]))

	return values
