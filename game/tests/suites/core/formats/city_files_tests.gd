extends "res://tests/support/core_test_suite.gd"
## Formats: city files checks.

@warning_ignore_start("integer_division")

const Sc2Document = preload("res://src/formats/sc2_file.gd")


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
		var unnamed := default_city.duplicate_document()
		unnamed.chunks.remove_at(0)
		unnamed.rebuild_chunk_cache()
		var added_name := unnamed.add_city_name_chunk()
		_check(
			unnamed.set_city_name("Renamed City")
			and added_name == unnamed.chunks[-1]
			and added_name.decoded_payload[0] == 0x1f
			and unnamed.add_city_name_chunk() == added_name
			and unnamed.chunks.size() == default_city.chunks.size(),
			"Rename adds a missing CNAM chunk at the end of the file",
		)
		var renamed := Sc2Document.new()
		_check(
			renamed.parse(unnamed.serialize().data)
			and renamed.city_name() == "Renamed City"
			and renamed.chunks[-1].chunk_id == "CNAM",
			"A renamed city without CNAM reloads with the new name",
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


func test_zero_form_length(reference_root: String) -> void:
	var source := FileAccess.get_file_as_bytes(reference_root.path_join("DEFAULT.SC2"))
	var damaged := source.duplicate()
	BinaryData.write_u32_be(damaged, 4, 0)
	var document := Sc2Document.new()
	_check(document.parse(damaged), "A city with a zero FORM length loads: %s" % document.parse_error)
	_check(document.repaired_form_length, "The loader reports the repaired FORM length")
	_check(document.serialize().data == source, "An unchanged save writes the repaired FORM length")

	var intact := Sc2Document.new()
	_check(intact.parse(source) and not intact.repaired_form_length, "An intact city reports no repair")


func test_sc2kfix_archive(reference_root: String) -> void:
	for name in ["DEFAULT.SC2", "CITIES/CAPEQUES.SC2", "CITIES/STARTER.SC2"]:
		var path := reference_root.path_join(name)
		var source := Sc2Document.load_path(path)
		var encoded := Sc2kfixArchive.encode(source, 1234)
		_check(encoded.ok, "%s encodes as an sc2kfix city: %s" % [name, encoded.error])

		if not encoded.ok:
			continue

		var bytes := encoded.bytes
		_check(Sc2kfixArchive.is_archive(bytes) and not Sc2kfixArchive.is_archive(FileAccess.get_file_as_bytes(path)),
			"%s sc2kfix detection uses the first archive member" % name)
		var reloaded := Sc2Document.new()
		_check(reloaded.parse(bytes) and reloaded.source_format == "sc2kfix", "%s loads as an sc2kfix city: %s" % [name, reloaded.parse_error])
		var same := reloaded.chunks.size() == source.chunks.size()

		for index in mini(reloaded.chunks.size(), source.chunks.size()):
			same = same and reloaded.chunks[index].chunk_id == source.chunks[index].chunk_id
			same = same and reloaded.chunks[index].decoded_payload == source.chunks[index].decoded_payload

		_check(same, "%s keeps every chunk, in order, through an OpenSC2K sc2kfix save" % name)
		_check(reloaded.city_name() == source.city_name(), "%s keeps its city name" % name)

		# sc2kfix rewrites a file without the OpenSC2K entries
		var archive := ZipArchive.decode(bytes, Sc2kfixArchive.MAX_ARCHIVE_BYTES, Sc2kfixArchive.MAX_DATA_BYTES)
		var names := PackedStringArray()
		var members: Dictionary[String, PackedByteArray] = {}

		for member in archive.order:
			if not member.begins_with("opensc2k/"):
				names.append(member)
				members[member] = archive.members[member]

		_check(names[0] == "META.json" and names.has("current/XFIX.json"), "%s has the members that sc2kfix requires" % name)
		var plain := ZipArchive.encode(names, members, Sc2kfixArchive.MAX_ARCHIVE_BYTES, Sc2kfixArchive.MAX_DATA_BYTES, true)
		var plain_city := Sc2Document.new()
		_check(plain.ok and plain_city.parse(plain.bytes), "%s loads without the OpenSC2K entries: %s" % [name, plain_city.parse_error])

		if not plain_city.is_valid():
			continue

		var misc := source.find_chunk("MISC").decoded_payload
		var plain_misc := plain_city.find_chunk("MISC").decoded_payload
		var words_match := true

		for word: int in [1, 4, 5, 9, 22, 30, 124 + 0x1d, 388, 438, 479, 479 + 26 * 3, 911, 916, 946, 1000, 1018, 1034, 1043]:
			words_match = words_match and (BinaryData.read_u32_be(misc, word * 4) & 0xffff) == (BinaryData.read_u32_be(plain_misc, word * 4) & 0xffff)

		_check(words_match, "%s MISC.json holds the original MISC words" % name)
		_check(BinaryData.read_u32_be(plain_misc, 0) == 290, "%s MISC.json load writes the MISC version" % name)

		for id in ["ALTM", "XBLD", "XMIC", "XTHG", "XGRP", "XTXT"]:
			_check(plain_city.find_chunk(id).decoded_payload == source.find_chunk(id).decoded_payload,
				"%s %s converts from the sc2kfix runtime layout" % [name, id])

		var altm := source.find_chunk("ALTM").decoded_payload
		var runtime_altm: PackedByteArray = members["current/ALTM"]
		_check(runtime_altm[0] == altm[1] and runtime_altm[1] == altm[0], "%s ALTM is little-endian at run time" % name)

		var misc_json: Dictionary = JSON.parse_string(members["current/MISC.json"].get_string_from_utf8())
		_check(misc_json.city.funds == BinaryData.read_i32_be(misc, 5 * 4) and misc_json.city.budget.has("raods"),
			"%s MISC.json uses the sc2kfix keys" % name)

	var target := OS.get_user_data_dir().path_join("sc2kfix_save_test.sc2x")
	var city := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var saved := CityFileStore.save_copy(city, target, reference_root)
	var loaded := Sc2Document.load_path(target)
	_check(saved.ok and loaded.is_valid() and loaded.source_format == "sc2kfix",
		"An original city saved to an .sc2x file uses the sc2kfix format: %s" % saved.error)
	_check(CityFileStore.uses_sc2kfix_format(city, "a.SC2X") and not CityFileStore.uses_sc2kfix_format(city, "a.sc2"),
		"Only the .sc2x extension selects the sc2kfix format")
	DirAccess.remove_absolute(target)


func test_sc2kfix_xfix(reference_root: String) -> void:
	var document := Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))
	var text := '{"meta":{"creator":"sc2kfix r12","porntipsguzzardo":false},"map":{"terrain_cosmetic_mode":0,"tilesets":["C:\\\\SC2K\\\\SCURKART\\\\XFIXTEST.MIF","D:\\\\missing.mif"]}}'
	var payload := text.to_utf8_buffer()
	payload.append(0)
	var chunk := Sc2Chunk.new()
	chunk.chunk_id = "XFIX"
	chunk.expected_decoded_size = document.decoded_size("XFIX")
	chunk.decoded_payload = payload
	chunk.is_dirty = true
	document.chunks.append(chunk)
	document.rebuild_chunk_cache()
	var saved := document.serialize()
	var reloaded := Sc2Document.new()
	_check(saved.ok and reloaded.parse(saved.data), "A city with an XFIX chunk saves and loads")
	_check(reloaded.chunks[-1].chunk_id == "XFIX" and reloaded.chunks[-1].decoded_payload == payload
		and not reloaded.chunks[-1].is_compressed, "The XFIX chunk stays unchanged, uncompressed and in place")
	var city := CityModel.from_document(reloaded)
	_check(city.set_funds(4321), "A city with an XFIX chunk can change")
	var changed := Sc2Document.new()
	_check(changed.parse(reloaded.serialize().data) and changed.find_chunk("XFIX").decoded_payload == payload,
		"A changed city keeps its XFIX chunk")
	_check(Sc2kfixXfix.tile_set_paths(reloaded) == PackedStringArray(["C:\\SC2K\\SCURKART\\XFIXTEST.MIF", "D:\\missing.mif"]),
		"XFIX lists its tile sets in load order")
	_check(Sc2kfixXfix.tile_set_paths(Sc2Document.load_path(reference_root.path_join("DEFAULT.SC2"))).is_empty(),
		"A city without XFIX lists no tile sets")

	var directory := OS.get_user_data_dir().path_join("xfix_tile_sets")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("XfixTest.mif"), FileAccess.WRITE)
	file.close()
	_check(Sc2kfixXfix.resolve_tile_set("C:\\SC2K\\SCURKART\\XFIXTEST.MIF", PackedStringArray(["", directory]))
		== directory.path_join("XfixTest.mif"), "A saved tile set path is found by file name in any letter case")
	_check(Sc2kfixXfix.resolve_tile_set("D:\\missing.mif", PackedStringArray([directory])).is_empty(),
		"A missing tile set does not resolve")
	DirAccess.remove_absolute(directory.path_join("XfixTest.mif"))
	DirAccess.remove_absolute(directory)
