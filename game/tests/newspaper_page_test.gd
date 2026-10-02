extends SceneTree

@warning_ignore_start("integer_division")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var newspaper := NewspaperDialog.new()
	root.add_child(newspaper)
	_check_page_layout(newspaper)
	_check_reader_and_close(newspaper)
	_check_menu_and_forecast(newspaper)
	_check_city_name_fallback(newspaper)
	newspaper.free()
	print("PASS: newspaper layout, reader, progression menu, forecast, opinion and city name")
	quit()


func _sample_content(article_words: int, extra_count: int) -> NewspaperContent:
	var content := NewspaperContent.new()
	var literal := "<script>alert('city')</script> & \"Mayor\""
	content.set_page(0, literal, "Sunday May 1, 1950", "Five Cents", "Opinion", "Weather",
		PackedStringArray(["Lead story", "Second story", "Third story", "Fourth story", "Fifth story"]))
	var words := PackedStringArray()

	for index in article_words:
		words.append("word%d" % (index % 17))

	var article := " ".join(words)
	content.set_articles(PackedStringArray([literal + " " + article, article, "Short.", article, "Two words"]))
	content.set_weather("Weather Corner", "Sunny skies", "Clear and dry weather continues across the city.")
	content.set_opinion("Fred's Opinion", "Fix the roads", "Residents want better roads near the industrial zone.")

	for index in extra_count:
		var extra := NewspaperContent.ExtraStory.new()
		extra.headline = "Extra %d" % index
		extra.article = "Brief extra story text about the city. " .repeat(3)
		extra.page = index + 2
		content.extra_stories.append(extra)

	return content


func _check_page_layout(newspaper: NewspaperDialog) -> void:
	var view := newspaper.paper_view
	assert(NewspaperPage.shell_size(Vector2(1280, 800)).is_equal_approx(Vector2(1088, 680)))
	assert(NewspaperPage.shell_size(Vector2(2000, 800)).x == NewspaperPage.MAX_WIDTH)

	# each paper keeps its own masthead, and every third paper is a Chronicle
	for index in 6:
		view.size = Vector2(1088, 680)
		view.show_content(_sample_content(400, 8), index)
		var info := view.diagnostics
		assert(info.edition == ("chronicle" if index % 3 == 1 else "herald"))
		assert(info.masthead_font == NewspaperFonts.MASTHEAD_NAMES[index % 3])
		assert(info.articles == 5)
		assert(info.fits, "A story panel overflows at paper %d" % index)
		assert(info.continuations > 0, "A long story has no continuation notice")
		_check_no_overlap(view)

	# a long lead story stops at the panel and names its continuation page
	var lead := view.articles[0]
	assert(lead.truncated and lead.notice_text.begins_with("... (continued on pg "))
	assert(lead.read_text.contains("<script>"), "The reader shows story text literally")
	# a short story shrinks to its text, and extra stories fill the space below it
	view.show_content(_sample_content(400, 8), 0)
	assert(not view.articles[2].truncated)
	assert(view.articles[2].size.y < 200.0)
	assert(view.extra_stories.size() > 0 and view.diagnostics.extra_stories == view.extra_stories.size())
	assert(not view.rules.is_empty(), "Side-by-side panels have no column rule")

	for story in view.extra_stories:
		assert(story.shows_copy())

	# a narrow panel uses one column, and a wide one uses two
	assert(NewspaperStory.columns_for_width(120.0) == 1)
	assert(NewspaperStory.columns_for_width(400.0) == 2)
	# the interface is never smaller than 1280 x 800, and a large window still fits every panel
	view.size = NewspaperPage.shell_size(Vector2(2560, 1600))
	assert(view.diagnostics.fits)
	_check_no_overlap(view)
	# the entrance spin starts small and turned, and ends flat at full size
	var start := NewspaperPage.spin_state(0.0)
	assert(is_equal_approx(start.x, 0.03) and is_equal_approx(start.y, -1080.0) and is_zero_approx(start.z))
	assert(NewspaperPage.spin_state(1.0).is_equal_approx(Vector3(1.0, 0.0, 1.0)))
	assert(NewspaperPage.spin_state(0.76).is_equal_approx(Vector3(1.08, 12.0, 1.0)))
	view.play_opening()
	assert(view.is_opening())
	view.finish_opening()
	assert(view.scale.is_equal_approx(Vector2.ONE) and is_zero_approx(view.rotation))
	# the picture prints in gray
	var image := Image.create(4, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 0.0, 0.0))
	var gray := NewspaperPage.grayscale(ImageTexture.create_from_image(image)).get_image()
	var pixel := gray.get_pixel(1, 1)
	assert(is_equal_approx(pixel.r, pixel.g) and is_equal_approx(pixel.g, pixel.b) and absf(pixel.r - 0.2126) < 0.01)
	var pictured := _sample_content(80, 4)
	pictured.set_picture(400, Image.create(160, 120, false, Image.FORMAT_RGBA8))
	view.size = Vector2(1088, 680)
	view.show_content(pictured, 0)
	assert(view.photo != null and view.diagnostics.fits)
	assert(Rect2(view.stories_rect).grow(0.5).encloses(view.photo.get_rect()))
	_check_no_overlap(view)


func _check_no_overlap(view: NewspaperPage) -> void:
	var boxes: Array[Rect2] = []

	for story in view.all_stories():
		boxes.append(story.get_rect())

	if view.photo != null:
		boxes.append(view.photo.get_rect())

	for first in boxes.size():
		assert(view.stories_rect.grow(0.5).encloses(boxes[first]), "A panel is outside the story area")

		for second in range(first + 1, boxes.size()):
			var shared := boxes[first].intersection(boxes[second])
			assert(shared.get_area() < 1.0, "Two newspaper panels overlap")


func _check_reader_and_close(newspaper: NewspaperDialog) -> void:
	var reference_root := ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	var document := Sc2File.load_path(reference_root.path_join("CITIES/CAPEQUES.SC2"))
	var city := CityState.from_document(document)
	newspaper.open_reports(city, document, null, {}, 123, 0)
	assert(newspaper.visible)
	var view := newspaper.paper_view
	assert(view.diagnostics.fits)
	var story := view.articles[1]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	story._gui_input(click)
	assert(newspaper.reader.visible)
	assert(newspaper.reader.title_label.text == story.read_title)
	assert(newspaper.reader.text_label.text == NewspaperReader.pre_line(story.read_text))
	assert(NewspaperReader.pre_line("  One   two\n\tThree ") == "One two\nThree")
	assert(newspaper.reader.panel.size.x <= NewspaperReader.MAX_WIDTH)
	# Escape closes the story first, then the newspaper
	newspaper._on_cancel()
	assert(not newspaper.reader.visible and newspaper.visible)
	view.read_requested.emit("Title", "Text")
	click.position = Vector2.ONE
	newspaper.reader._gui_input(click)
	assert(not newspaper.reader.visible, "A click outside the story did not close it")
	newspaper._on_cancel()
	assert(not newspaper.visible)
	newspaper.open_reports(city, document, null, {}, 123, 0)
	view.close_button.pressed.emit()
	assert(not newspaper.visible)


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
	var paper := NewsQueue.PaperRecord.new()
	paper.name = 2
	assert(NewspaperDialog._paper_title(city, 3, paper).contains(city.display_name()))

	# Reproduce the first growth milestone in memory. Do not save the supplied city.
	var misc := document.find_chunk("MISC").decoded_payload.duplicate()
	assert(NewsQueue.insert(misc, 3, 0).ok)
	assert(document.find_chunk("MISC").set_decoded_payload(misc))
	var data := DataUsaResource.load_path(
		reference_root.path_join("DATA/DATA_USA.DAT"),
		reference_root.path_join("DATA/DATA_USA.IDX"),
	)
	assert(data.is_valid())
	var story_seed := -28 - (city.age_in_days() / 25)
	newspaper.open_reports(city, document, data, {}, story_seed, 0)
	assert(newspaper.page.headline_for_slot(0) == "BABAR Awakens!!")
	assert(newspaper.page.articles[0].contains("BABAR"))
	assert(document.find_chunk("CNAM") == null, "Opening the newspaper added a saved city name")
	assert(city.city_name().is_empty())
	newspaper.hide()

	newspaper.open_reports(city, document, null, {}, story_seed, 0)
	assert(newspaper.page.headline_for_slot(0).begins_with("BABAR counts "))
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
		var titles := NewspaperDialog.newspaper_titles(city, document)
		assert(titles.size() == mini(level + 1, 6))
		menu.set_newspapers(titles, level % 2 == 1, level % 3 == 1, level - 1)
		var popup := menu.newspaper_menu.get_popup()
		assert(popup.item_count == titles.size() + 3)
		var subscription_index := popup.get_item_index(CityMenuBar.MENU_NEWSPAPER_SUBSCRIPTION)
		var extras_index := popup.get_item_index(CityMenuBar.MENU_NEWSPAPER_EXTRAS)
		assert(subscription_index == 0 and extras_index == 1 and popup.is_item_separator(2))
		assert(popup.is_item_checked(subscription_index) == (level % 2 == 1))
		assert(popup.is_item_checked(extras_index) == (level % 3 == 1))

		for index in titles.size():
			var item_index := popup.get_item_index(index)
			assert(item_index == index + 3)
			assert(popup.get_item_text(item_index) == titles[index])
			assert(popup.is_item_radio_checkable(item_index))
			assert(popup.is_item_checked(item_index) == (index == level - 1))

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
	newspaper.open_reports(city, document, data, {}, 123, 5)
	var saved_weather := NewsQueue.story_record(document.find_chunk("MISC").decoded_payload, 7)
	assert(saved_weather.type == 0 and saved_weather.argument == city.weather_type())
	assert(newspaper.selected_newspaper == 1, "Unavailable newspaper selection was not clamped")
	var content := newspaper.page
	assert(newspaper.paper_titles.size() == 2)
	assert(not content.weather_heading.is_empty())
	assert(not content.weather_headline.is_empty())
	assert(content.weather_article.length() > content.weather_headline.length())
	assert(not content.opinion_heading.is_empty())
	assert(content.opinion_article.length() > content.opinion_headline.length())
	assert(content.articles.size() == 5, "Forecast replaced a published story")
	assert(content.weather_page >= 2 and content.weather_page <= 30)
	assert(content.opinion_page >= 2 and content.opinion_page <= 30)
	assert(not content.extra_stories.is_empty())
	var extra_before := document.serialize().data as PackedByteArray
	var extra_stories := newspaper._extra_stories(document.find_chunk("MISC").decoded_payload, newspaper._team_names())
	assert(extra_stories.size() == content.extra_stories.size(), "Extra story count changed")
	for index in extra_stories.size():
		var expected := content.extra_stories[index]
		var actual := extra_stories[index]
		assert(actual.headline == expected.headline and actual.article == expected.article and actual.page == expected.page,
			"Extra stories must use stable private seeds")
	assert(document.serialize().data == extra_before, "Extra stories changed saved news")
	var headlines: PackedStringArray = content.headlines.duplicate()

	for extra in extra_stories:
		assert(not headlines.has(str(extra.headline)))
		assert(not str(extra.article).is_empty())
		assert(extra.page >= 2 and extra.page <= 30)
		headlines.append(str(extra.headline))

	var forecast := content.weather_article
	newspaper._populate_page()
	assert(newspaper.page.weather_article == forecast)
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
	var crime_opinion := newspaper.page.opinion_headline
	assert(NewsQueue.story_record(document.find_chunk("MISC").decoded_payload, 8).argument == 2)
	assert(document.find_chunk("XMIC").decoded_payload == microsims_before)
	graphs[7 * 52 * 4 + 2] = 0
	graphs[7 * 52 * 4 + 3] = 0
	graphs[5 * 52 * 4 + 2] = 0x7f
	graphs[5 * 52 * 4 + 3] = 0xff
	graph_chunk.set_decoded_payload(graphs)
	newspaper._populate_page()
	assert(NewsQueue.story_record(document.find_chunk("MISC").decoded_payload, 8).argument == 1)
	assert(newspaper.page.opinion_headline != crime_opinion)
	assert(document.find_chunk("XMIC").decoded_payload == microsims_before)
	graph_chunk.set_decoded_payload(graph_before)
	newspaper.hide()
	newspaper.open_reports(city, document, null, {}, 123, 0)
	assert(newspaper.page.weather_article.contains(RciAftermathPhase.WEATHER_NAMES[city.weather_type()]))
	newspaper.hide()
