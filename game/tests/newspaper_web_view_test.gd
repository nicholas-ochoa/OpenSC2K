extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var newspaper := NewspaperDialog.new()
	root.add_child(newspaper)
	var literal := "<script>alert('city')</script> & \"Mayor\""
	newspaper.page.set_page(0, literal, "Date", "Price", "Opinion", "Weather", [literal, "Two", "Three", "Four", "Five"])
	newspaper.published_articles = [literal, "B", "C", "D", "E"]
	newspaper.paper_titles.append(literal)
	var payload := newspaper._web_payload()
	assert(JSON.parse_string(JSON.stringify(payload)).articles[0] == literal)
	assert(payload.title == literal)
	assert(payload.headlines.size() == 5)
	assert(payload.pages.all(func(number: int) -> bool:
		return number >= 2 and number <= 30))
	assert(payload.picture == "")
	var html := NewspaperWebView.html_document()
	assert(not html.contains("__NEWSPAPER_HEADLINE_FONT__"))
	assert(not html.contains("__NEWSPAPER_CHOMSKY_FONT__"))
	assert(not html.contains("__NEWSPAPER_GRENZE_FONT__"))
	assert(not html.contains("__NEWSPAPER_MAGUNTIA_FONT__"))
	var font := load("res://assets/fonts/anton/Anton-Regular.ttf") as FontFile
	assert(not font.data.is_empty())
	assert(html.contains(Marshalls.raw_to_base64(font.data)))
	for path in [
		"res://assets/fonts/chomsky/Chomsky.otf",
		"res://assets/fonts/grenzegotisch/GrenzeGotisch[wght].ttf",
		"res://assets/fonts/unifrakturmaguntia/UnifrakturMaguntia-Book.ttf",
	]:
		var masthead := load(path) as FontFile
		assert(not masthead.data.is_empty())
		assert(html.contains(Marshalls.raw_to_base64(masthead.data)))
	newspaper.web_paper.open(payload)
	assert(newspaper.web_paper.view == null, "Headless run created a native WebView")
	newspaper.web_paper._on_message("not JSON")
	newspaper.web_paper._on_message('{"action":"metrics","articles":5}')
	assert(newspaper.web_paper.diagnostics.articles == 5)
	newspaper.web_paper.close()
	_check_menu_and_forecast(newspaper)
	_check_city_name_fallback(newspaper)
	newspaper.free()
	print("PASS: newspaper payload, licensed font, progression menu, forecast, opinion and headless guard")
	quit()


func _check_city_name_fallback(newspaper: NewspaperDialog) -> void:
	var reference_root := ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	var path := reference_root.path_join("CITIES/BABAR.SC2")
	var source_bytes := FileAccess.get_file_as_bytes(path)
	var document := Sc2File.load_path(path)
	assert(document.is_valid())
	assert(document.find_chunk("CNAM") == null)
	var city := CityState.from_document(document)
	assert(city.city_name().is_empty())
	assert(city.display_name() == "BABAR")
	assert(document.serialize().data == source_bytes, "Reading the display name changed city bytes")
	assert(NewspaperDialog._paper_title(city, {}, 3, {"name": 2}).contains(city.display_name()))

	# Reproduce the first growth milestone in memory. Do not save the supplied city.
	var misc := document.find_chunk("MISC").decoded_payload.duplicate()
	assert(NewsQueue.insert(misc, 3, 0).ok)
	assert(document.find_chunk("MISC").set_decoded_payload(misc))
	var data := DataUsaResource.load_path(
		reference_root.path_join("DATA/DATA_USA.DAT"),
		reference_root.path_join("DATA/DATA_USA.IDX"),
	)
	assert(data.is_valid())
	var seed := -28 - IntegerMath.div_trunc(city.age_in_days(), 25)
	newspaper.open_reports(city, document, data, {}, {}, seed, 0)
	var payload := newspaper._web_payload()
	assert(payload.headline == "BABAR Awakens!!")
	assert(str(payload.articles[0]).contains("BABAR"))
	assert(document.find_chunk("CNAM") == null, "Opening the newspaper added a saved city name")
	assert(city.city_name().is_empty())
	newspaper.hide()

	newspaper.open_reports(city, document, null, {}, {}, seed, 0)
	assert(str(newspaper._web_payload().headlines[0]).begins_with("BABAR counts "))
	newspaper.hide()
	var before := document.serialize().data as PackedByteArray
	document.source_path = ""
	assert(city.display_name() == "New City")
	assert(document.serialize().data == before)
	assert(FileAccess.get_file_as_bytes(path) == source_bytes)

	var named_document := Sc2File.load_path(reference_root.path_join("DEFAULT.SC2"))
	assert(named_document.set_city_name("Saved Name"))
	named_document.source_path = "/different/File Name.SC2"
	var named_city := CityState.from_document(named_document)
	assert(named_city.display_name() == "Saved Name", "Filename used instead of the saved city name")
	assert(named_document.set_city_name(""))
	assert(named_city.display_name() == "File Name", "Empty saved name did not fall back to the filename")


func _check_menu_and_forecast(newspaper: NewspaperDialog) -> void:
	for level in 11:
		assert(NewsQueue.available_paper_count(level) == mini(level + 1, 6))

	assert(NewsQueue.available_paper_count(0xffff) == 0)
	assert(NewsQueue.available_paper_count(0x10002) == 3)
	var weather_misc := PackedByteArray()
	weather_misc.resize(NewsQueue.MISC_SIZE)
	weather_misc.fill(0x55)
	var weather_before := weather_misc.duplicate()
	assert(NewsQueue.prepare_weather_report(weather_misc, 0x107).ok)
	var weather_record := NewsQueue.story_record(weather_misc, 7)
	assert(weather_record.type == 0 and weather_record.argument == 7)
	var weather_offset := NewsQueue.STORY_OFFSET + 7 * NewsQueue.STORY_RECORD_SIZE

	for index in weather_misc.size():
		if index in range(weather_offset, weather_offset + 4) or index in range(weather_offset + 8, weather_offset + 12):
			continue

		assert(weather_misc[index] == weather_before[index])

	assert(not NewsQueue.prepare_weather_report(PackedByteArray(), 0).ok)
	var opinion_types := [42, 43, 43, 44, 44, 45]
	var opinion_offset := NewsQueue.STORY_OFFSET + 8 * NewsQueue.STORY_RECORD_SIZE

	for style in opinion_types.size():
		var opinion_misc := weather_before.duplicate()
		assert(NewsQueue.prepare_opinion_report(opinion_misc, style, 0x102).ok)
		var opinion_record := NewsQueue.story_record(opinion_misc, 8)
		assert(opinion_record.type == opinion_types[style] and opinion_record.argument == 2)

		for index in opinion_misc.size():
			if index in range(opinion_offset, opinion_offset + 4) or index in range(opinion_offset + 8, opinion_offset + 12):
				continue

			assert(opinion_misc[index] == weather_before[index])

	assert(not NewsQueue.prepare_opinion_report(PackedByteArray(), 0, 0).ok)
	var reference_root := ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	var document := Sc2File.load_path(reference_root.path_join("CITIES/CAPEQUES.SC2"))
	assert(document.is_valid())
	var city := CityState.from_document(document)
	var menu := CityMenuBar.new()
	root.add_child(menu)

	for level in 7:
		document.set_misc_u32(0x20, level)
		# Menu availability follows saved progression even after population drops.
		document.set_misc_u32(0x102c, 0)
		var before := document.serialize().data as PackedByteArray
		var titles := NewspaperDialog.newspaper_titles(city, document, {})
		assert(titles.size() == mini(level + 1, 6))
		menu.set_newspapers(titles)
		var popup := menu.newspaper_menu.get_popup()
		assert(popup.item_count == titles.size())

		for index in popup.item_count:
			assert(popup.get_item_id(index) == index)
			assert(popup.get_item_text(index) == titles[index])
			assert(not popup.is_item_checkable(index))
			assert(not popup.is_item_radio_checkable(index))

		assert(document.serialize().data == before)

	menu.free()
	document.set_misc_u32(0x20, 1)
	var data := DataUsaResource.load_path(
		reference_root.path_join("DATA/DATA_USA.DAT"),
		reference_root.path_join("DATA/DATA_USA.IDX"),
	)
	assert(data.is_valid())
	document.set_misc_u32(NewsQueue.STORY_OFFSET + 7 * NewsQueue.STORY_RECORD_SIZE, 18)
	document.set_misc_u32(NewsQueue.STORY_OFFSET + 7 * NewsQueue.STORY_RECORD_SIZE + 8, 0)
	newspaper.open_reports(city, document, data, {}, {}, 123, 5)
	var saved_weather := NewsQueue.story_record(document.find_chunk("MISC").decoded_payload, 7)
	assert(saved_weather.type == 0 and saved_weather.argument == city.weather_type())
	assert(newspaper.selected_newspaper == 1, "Unavailable newspaper selection was not clamped")
	var payload := newspaper._web_payload()
	assert(payload.papers.size() == 2)
	assert(not str(payload.weather_heading).is_empty())
	assert(not str(payload.weather_headline).is_empty())
	assert(str(payload.weather_article).length() > str(payload.weather_headline).length())
	assert(not str(payload.opinion_heading).is_empty())
	assert(str(payload.opinion_article).length() > str(payload.opinion_headline).length())
	assert(payload.articles.size() == 5, "Forecast replaced a published story")
	assert(payload.weather_page >= 2 and payload.weather_page <= 30)
	assert(payload.opinion_page >= 2 and payload.opinion_page <= 30)
	assert(not payload.extra_stories.is_empty())
	var extra_before := document.serialize().data as PackedByteArray
	var extra_stories := newspaper._extra_stories(document.find_chunk("MISC").decoded_payload, newspaper._team_names())
	assert(extra_stories == payload.extra_stories, "Extra stories must use stable private seeds")
	assert(document.serialize().data == extra_before, "Extra stories changed saved news")
	var headlines: PackedStringArray = payload.headlines.duplicate()

	for extra in extra_stories:
		assert(not headlines.has(str(extra.headline)))
		assert(not str(extra.article).is_empty())
		assert(extra.page >= 2 and extra.page <= 30)
		headlines.append(str(extra.headline))

	var forecast := str(payload.weather_article)
	newspaper._populate_page()
	assert(newspaper._web_payload().weather_article == forecast)
	# Opening uses current concern weights instead of the stale saved traffic subject.
	var graph_chunk := document.find_chunk("XGRP")
	var graph_before := graph_chunk.decoded_payload.duplicate()
	var graphs := graph_before.duplicate()
	var microsims_before := document.find_chunk("XMIC").decoded_payload.duplicate()
	graphs.encode_u32(7 * 52 * 4, 0)
	graphs[7 * 52 * 4 + 2] = 0x7f
	graphs[7 * 52 * 4 + 3] = 0xff
	graph_chunk.set_decoded_payload(graphs)
	newspaper._populate_page()
	var crime_opinion := newspaper._web_payload().opinion_headline as String
	assert(NewsQueue.story_record(document.find_chunk("MISC").decoded_payload, 8).argument == 2)
	assert(document.find_chunk("XMIC").decoded_payload == microsims_before)
	graphs[7 * 52 * 4 + 2] = 0
	graphs[7 * 52 * 4 + 3] = 0
	graphs[5 * 52 * 4 + 2] = 0x7f
	graphs[5 * 52 * 4 + 3] = 0xff
	graph_chunk.set_decoded_payload(graphs)
	newspaper._populate_page()
	assert(NewsQueue.story_record(document.find_chunk("MISC").decoded_payload, 8).argument == 1)
	assert(newspaper._web_payload().opinion_headline != crime_opinion)
	assert(document.find_chunk("XMIC").decoded_payload == microsims_before)
	graph_chunk.set_decoded_payload(graph_before)
	newspaper.hide()
	newspaper.open_reports(city, document, null, {}, {}, 123, 0)
	assert(str(newspaper._web_payload().weather_article).contains(RciAftermathPhase.WEATHER_NAMES[city.weather_type()]))
	newspaper.hide()
