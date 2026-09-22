extends "res://tests/support/core_test_suite.gd"

## Formats: city files checks.

@warning_ignore_start("integer_division")

const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityFileStore = preload("res://src/formats/city_file_store.gd")


func test_reference_corpus(reference_root: String) -> void:
	var paths := PackedStringArray([reference_root.path_join("DEFAULT.SC2")])
	paths.append_array(_files_with_extension(reference_root.path_join("CITIES"), "SC2"))
	paths.append_array(_files_with_extension(reference_root.path_join("SCENARIO"), "SCN"))
	_check(paths.size() >= 80, "Reference corpus contains at least 80 city and scenario files")

	for path in paths:
		var document := Sc2Document.load_path(path)
		_check(document.is_valid(), "%s parses: %s" % [path.get_file(), document.parse_error])

		if not document.is_valid():
			continue

		var rebuilt := document.serialize(true)
		_check(rebuilt.ok, "%s rebuilds" % path.get_file())

		if rebuilt.ok:
			_check(
				rebuilt.data == FileAccess.get_file_as_bytes(path),
				"%s rebuild is byte-identical" % path.get_file()
			)

		var city := CityModel.from_document(document)
		_check(city.is_valid(), "%s creates a city model: %s" % [path.get_file(), city.load_error])

		if city.is_valid():
			_check(city.index_of(0, 0) == 0, "%s map origin is stable" % path.get_file())
			_check(
				city.index_of(127, 127) == 16383,
				"%s map end is stable" % path.get_file()
			)
			_check(
				city.current_month() >= 1 and city.current_month() <= 12,
				"%s month is in range" % path.get_file()
			)
			_check(city.label(0).length() <= 23, "%s mayor label is bounded" % path.get_file())
			_check(city.microsim(149) != null, "%s has 150 microsim records" % path.get_file())
			_check(city.thing(39) != null, "%s has 40 thing records" % path.get_file())
			var graph := city.graph_series(15)
			_check(graph.year.size() == 12, "%s graph has 12 monthly values" % path.get_file())
			_check(graph.decade.size() == 20, "%s graph has 20 decade values" % path.get_file())
			_check(graph.century.size() == 20, "%s graph has 20 century values" % path.get_file())
			var paper_records_valid := true
			var misc_chunk := document.find_chunk("MISC")

			for paper_index in NewsQueue.PAPER_COUNT:
				var paper := NewsQueue.paper_record(misc_chunk.decoded_payload, paper_index)
				paper_records_valid = paper_records_valid and (
					int(paper.name) in range(6)
					and int(paper.layout) in range(3)
					and int(paper.price) in range(3)
					and int(paper.opinion) in range(6)
					and int(paper.weather) in range(6)
				)

			_check(
				paper_records_valid,
				"%s newspaper configurations stay in their recovered ranges" % path.get_file(),
			)

	var default_city := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	_check(default_city.is_valid(), "Default city parses")

	if default_city.is_valid():
		_check(default_city.city_name() == "New City", "Default city name is New City")
		_check(default_city.misc_u32(0) == 0x122, "Default MISC marker is 0x122")
		var render_copy := default_city.duplicate_document()
		_check(render_copy.is_valid(), "A render document copy stays valid")
		_check(
			render_copy.serialize().data == default_city.serialize().data,
			"A render document copy preserves all city bytes",
		)
		_check(render_copy.set_misc_u32(0x10, 123), "A render document copy can change")
		_check(
			default_city.misc_u32(0x10) != 123,
			"A render document copy does not change the live city",
		)
		var default_model := CityModel.from_document(default_city)
		_check(default_model.land_altitude(0, 0) == 4, "Default origin land altitude is 4")
		_check(default_model.water_altitude(0, 0) == 4, "Default origin water level is 4")
		_check(default_model.tunnel_levels(0, 0) == 0, "Default origin tunnel depth is 0")


func test_city_options(reference_root: String) -> void:
	var starter_document := _load_fixture(
		reference_root.path_join("CITIES/STARTER.SC2")
	).duplicate_document()
	var starter := CityModel.from_document(starter_document)
	_check(starter.is_valid(), "Starter city loads for saved-option tests")

	if not starter.is_valid():
		return

	_check(
		starter.auto_budget_enabled()
		and starter.auto_goto_enabled()
		and starter.sound_enabled()
		and starter.music_enabled()
		and starter.no_disasters_enabled(),
		"Starter city exposes all five enabled saved options",
	)
	_check(
		starter.set_auto_budget_enabled(false)
		and starter.set_auto_goto_enabled(false)
		and starter.set_sound_enabled(false)
		and starter.set_music_enabled(false)
		and starter.set_no_disasters_enabled(false),
		"Saved city options can be disabled",
	)
	_check(
		starter_document.misc_u32(CityState.MISC_AUTO_BUDGET_OPTION) == 0
		and starter_document.misc_u32(CityState.MISC_AUTO_GOTO_OPTION) == 0
		and starter_document.misc_u32(CityState.MISC_SOUND_OPTION) == 0
		and starter_document.misc_u32(CityState.MISC_MUSIC_OPTION) == 0
		and starter_document.misc_u32(CityState.MISC_NO_DISASTERS_OPTION) == 0,
		"Disabled options write zero to their original MISC fields",
	)
	_check(
		starter.set_auto_budget_enabled(true)
		and starter.set_auto_goto_enabled(true)
		and starter.set_sound_enabled(true)
		and starter.set_music_enabled(true)
		and starter.set_no_disasters_enabled(true),
		"Saved city options can be enabled",
	)
	_check(
		starter_document.misc_u32(CityState.MISC_AUTO_BUDGET_OPTION) == 1
		and starter_document.misc_u32(CityState.MISC_AUTO_GOTO_OPTION) == 1
		and starter_document.misc_u32(CityState.MISC_SOUND_OPTION) == 1
		and starter_document.misc_u32(CityState.MISC_MUSIC_OPTION) == 1
		and starter_document.misc_u32(CityState.MISC_NO_DISASTERS_OPTION) == 1,
		"Enabled options write one to their original MISC fields",
	)
	var scenario_document := _load_fixture(
		reference_root.path_join("SCENARIO/CHARLEST.SCN")
	)
	var scenario_city := CityModel.from_document(scenario_document)
	_check(
		scenario_city.is_valid()
		and scenario_document.misc_u32(CityState.MISC_AUTO_GOTO_OPTION) == 0xff
		and scenario_city.auto_goto_enabled(),
		"Saved option readers treat a nonzero legacy value as enabled",
	)


func test_modified_save(reference_root: String) -> void:
	var source_path := reference_root.path_join("DEFAULT.SC2")
	var document := _load_fixture(source_path)
	var loaded_city := CityModel.from_document(document)
	_check(loaded_city.set_age_in_days(311), "City age can change")
	_check(loaded_city.set_funds(-12345), "City funds can change")
	_check(loaded_city.set_label(0, "Test Mayor"), "Mayor label can change")
	var serialized := document.serialize()
	_check(serialized.ok, "Modified city serializes")

	if not serialized.ok:
		return

	_check(serialized.data != FileAccess.get_file_as_bytes(source_path), "Modified save bytes change")

	var reparsed := Sc2Document.new()
	_check(reparsed.parse(serialized.data), "Modified save parses again: %s" % reparsed.parse_error)

	if reparsed.is_valid():
		_check(reparsed.misc_u32(0x10) == 311, "Modified city age is preserved")
		_check(reparsed.misc_i32(0x14) == -12345, "Modified city funds are preserved")
		var reparsed_city := CityModel.from_document(reparsed)
		_check(reparsed_city.mayor_name() == "Test Mayor", "Modified mayor label is preserved")

	var original := _load_fixture(source_path)

	for original_chunk in original.chunks:
		if original_chunk.chunk_id == "MISC" or original_chunk.chunk_id == "XLAB":
			continue

		var modified_chunk := reparsed.find_chunk(original_chunk.chunk_id)
		_check(modified_chunk != null, "%s stays present after edit" % original_chunk.chunk_id)

		if modified_chunk != null:
			_check(
				modified_chunk.stored_payload == original_chunk.stored_payload,
				"%s stored bytes stay unchanged after MISC edit" % original_chunk.chunk_id
			)

	var save_base := ProjectSettings.globalize_path(
		"user://test_city_file_store_%d" % OS.get_process_id()
	)
	var saved_copy := CityFileStore.save_copy(document, save_base, reference_root)
	_check(
		saved_copy.ok
		and saved_copy.path == save_base + ".SC2"
		and FileAccess.get_file_as_bytes(saved_copy.path) == serialized.data,
		"City file store adds the SC2 extension and writes exact serialized bytes",
	)

	if saved_copy.ok and FileAccess.file_exists(saved_copy.path):
		DirAccess.remove_absolute(saved_copy.path)

	_check(
		CityFileStore.is_reference_path(
			ProjectSettings.globalize_path("user://original_game/DEFAULT.SC2"),
			ProjectSettings.globalize_path("user://original_game")
		),
		"The selected original support-data directory stays protected",
	)
	var protected_copy := CityFileStore.save_copy(
		document, reference_root.path_join("DO_NOT_WRITE.SC2"), reference_root
	)
	_check(
		not protected_copy.ok and not protected_copy.error.is_empty(),
		"City file store rejects every path inside the reference directory",
	)
	_check(
		not CityFileStore.save_copy(null, save_base, reference_root).ok,
		"City file store rejects a missing city document",
	)
