extends SceneTree
## The interface language: translated text, language glyphs, the setting, and
## translations whose format placeholders match their source text.

# a literal percent sign (%%) can move; the other placeholders fill in order
# The original German text uses "1%ige" as prose, not a %i placeholder.
const FORMAT := "%[-+0-9.*]*[sdifxXc](?![A-Za-z])"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous := TranslationServer.get_locale()
	_check_placeholders()

	AppLocalization.select("ko")
	assert(TranslationServer.get_locale() == "ko")
	assert(tr("Water Pipes") != "Water Pipes")
	assert(tr("Population: %s") % "12,345" == "인구: 12,345")
	assert(tr("Fire", "budget") != tr("Fire"), "Fire spending and the fire disaster have different translations")

	# The fallback fonts supply the Hangul glyphs of each interface font.
	var fonts: Array[Font] = [NewspaperFonts.headline(), NewspaperFonts.body(), NewspaperFonts.interface(),
		AppUiThemeDefinitions.build("light").default_font, AppUiThemeDefinitions.build("dark").default_font]

	for font in fonts:
		for character in "물펌프수도관전선도로한글시장":
			assert(_has_char(font, character.unicode_at(0)), "%s has no Hangul" % font)

	# The setting keeps its value. An unknown language is English.
	var path := "user://localization-test-%d.cfg" % OS.get_process_id()
	DirAccess.remove_absolute(path)
	assert(AppSettingsStore.load_values(path).ui_language == "en")
	var preferences := AppPreferences.new()
	preferences.ui_language = "ko"
	preferences.default_mayor_name = "한글 시장"
	assert(AppSettingsStore.save_values(0.5, 0.5, false, path, preferences.save_options()) == OK)
	var saved := AppSettingsStore.load_values(path)
	assert(saved.ui_language == "ko" and saved.default_mayor_name == "한글 시장")
	assert(AppLocalization.normalize("xx") == "en")

	var dialog := preload("res://src/ui/settings/app_settings_dialog.tscn").instantiate() as AppSettingsDialog
	root.add_child(dialog)
	assert(dialog.language_selector.item_count == AppLocalization.LANGUAGES.size())

	for index in AppLocalization.codes().size():
		dialog.language_selector.select(index)
		assert(dialog.selected_values().ui_language == AppLocalization.codes()[index])

	# The logo is not translated. A tool button changes with the language.
	var menu := (load("res://src/ui/startup/main_menu_control.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	var title := menu.get_node("Center/Panel/Content/GameTitle") as Control

	for label: Label in title.get_children():
		assert(not label.can_auto_translate(), "The logo letters keep their text")

	var palette := CityChildToolPalette.new()
	root.add_child(palette)
	palette.show_tool_group(CityToolIds.Group.WATER, null)
	var button := palette.buttons[CityToolIds.Water.PIPES] as Button
	assert(button.text.begins_with(tr("Water Pipes")))
	assert(button.tooltip_text.contains(tr("Cost: %s").get_slice("%s", 0)))

	AppLocalization.select("de")
	await process_frame
	assert(TranslationServer.get_locale() == "de")
	_check_original_texts()
	await _check_toolbar_layout()
	assert(tr("Water Pipes") != "Water Pipes")
	assert(button.text.begins_with(tr("Water Pipes")), "The existing palette updates to German")
	assert(button.tooltip_text.contains(tr("Cost: %s").get_slice("%s", 0)))
	assert(tr("Fire", "budget") != tr("Fire"), "German distinguishes fire spending from a fire disaster")
	assert((tr("Population: %s") % "12,345").contains("12,345"))
	assert(tr("{city} · {month} {year}").format({ "city": "Köln", "month": "März", "year": 2000 }) == "Köln · März 2000")

	for font in fonts:
		for character in "ÄÖÜäöüß":
			assert(_has_char(font, character.unicode_at(0)), "%s has no German glyphs" % font)

	preferences.ui_language = "de"
	preferences.default_mayor_name = "Bürgermeister"
	assert(AppSettingsStore.save_values(0.5, 0.5, false, path, preferences.save_options()) == OK)
	saved = AppSettingsStore.load_values(path)
	assert(saved.ui_language == "de" and saved.default_mayor_name == "Bürgermeister")

	var city := CityState.from_document(EmptyCityTemplate.create())
	var before := city.document.serialize().data
	var budget := preload("res://src/ui/city_windows/budget_dialog.tscn").instantiate() as BudgetDialog
	root.add_child(budget)
	budget.set_city(city)
	budget.open_budget(BudgetPhase.funding_values(city), false, false)
	assert(budget.get_node("Margin/Content/Heading").text.contains(tr("January")))
	for label in budget.budget_labels:
		if label.get_meta("budget_source") == "Fire":
			assert(label.text == tr("Fire", "budget"))
	var ordinance_tooltip := budget.ordinance_control.ordinance_checks[0].tooltip_text
	assert(ordinance_tooltip.begins_with(tr(OrdinanceWindowControl.EFFECTS[0])))
	budget.hide()

	AppLocalization.select("en")
	await process_frame
	assert(button.text.begins_with("Water Pipes"), "The tool buttons change with the language")
	assert(tr("Population: %s") % "12,345" == "Population: 12,345")
	assert(ToolCatalog.tool(CityToolIds.Group.WATER, CityToolIds.Water.PIPES).id == "pipes")

	assert(budget.get_node("Margin/Content/Heading").text.contains("January"))
	for label in budget.budget_labels:
		if label.get_meta("budget_source") == "Fire":
			assert(label.text == "Fire")
	assert(budget.ordinance_control.ordinance_checks[0].tooltip_text.begins_with(OrdinanceWindowControl.EFFECTS[0]))
	assert(budget.ordinance_control.ordinance_checks[0].tooltip_text != ordinance_tooltip)
	assert(city.document.serialize().data == before, "Changing the display language leaves the city unchanged")
	budget.queue_free()
	TranslationServer.set_locale(previous)
	dialog.queue_free()
	palette.queue_free()
	menu.queue_free()
	DirAccess.remove_absolute(path)
	await process_frame
	print("PASS: interface language")
	quit()


# Each translation has the format placeholders of its source text, in order.
func _check_placeholders() -> void:
	var expression := RegEx.create_from_string(FORMAT)

	for code: String in AppLocalization.TRANSLATIONS:
		var translation := load(AppLocalization.TRANSLATIONS[code]) as Translation

		for message: StringName in translation.get_message_list():
			var source := String(message)
			var translated := String(translation.get_message(message))
			var expected := expression.search_all(source).map(func(found: RegExMatch) -> String: return found.get_string())
			var actual := expression.search_all(translated).map(func(found: RegExMatch) -> String: return found.get_string())
			assert(expected == actual, "%s: %s has other placeholders than %s" % [code, translated, source])


func _has_char(font: Font, character: int) -> bool:
	if font.has_char(character):
		return true

	for fallback: Font in font.fallbacks:
		if fallback.has_char(character):
			return true

	return false


# German prose works without German assets; translated choices never enter saves.
func _check_original_texts() -> void:
	assert(not OriginalTextLocalization.text(1000).is_empty())
	assert(OriginalTextLocalization.library_texts({}).size() == 4)
	var imported := DataUsaResource.new()
	imported.bases.resize(250)
	imported.counts.resize(250)
	imported.offsets.resize(2500)
	imported.grammar = PackedByteArray([0])
	imported.grammar.append_array("English headline+English article.".to_ascii_buffer())
	imported.grammar.append(0)
	imported.offsets[1] = 1
	for table in 250:
		imported.bases[table] = 1
		imported.counts[table] = 1
	var glyphs := LocalizedNewspaperText._compile("äöüÄÖÜß – Köln")
	var literal_data := DataUsaResource.new()
	literal_data.bases = imported.bases.duplicate()
	literal_data.counts = imported.counts.duplicate()
	literal_data.offsets = imported.offsets.duplicate()
	literal_data.grammar = PackedByteArray([0])
	literal_data.grammar.append_array(glyphs)
	literal_data.grammar.append(0)
	var literal_record := NewsQueue.StoryRecord.new(2, 0, PackedByteArray([255, 255, 255]))
	var literal_result := NewspaperText.render_story(literal_data, literal_record, 1, "", "", PackedStringArray())
	assert(literal_result.ok, literal_result.error)
	assert(not LocalizedNewspaperText._restore_literals(literal_result.headline, "", "", "").contains("�"))
	var original_grammar := imported.grammar.duplicate()
	for story_type in 80:
		if not LocalizedNewspaperText.TABLES.has(story_type):
			continue
		for seed_value in [1, 17, 12345]:
			var record := NewsQueue.StoryRecord.new(story_type, 0, PackedByteArray([255, 255, 255]))
			var plain := NewspaperText.render_story(imported, record, seed_value, "Köln", "Bürgermeister", PackedStringArray(["Löwen"]))
			var localized := LocalizedNewspaperText.render_story(imported, record, seed_value, "Köln", "Bürgermeister", PackedStringArray(["Löwen"]))
			assert(localized.ok, localized.error)
			assert(localized.argument == plain.argument and localized.auxiliary == plain.auxiliary)
			assert(localized.random_state == plain.random_state)
			assert(localized.headline != plain.headline, "German story %d must not fall back to English" % story_type)
			assert(not (localized.headline + localized.article).contains("�"))
			var independent := LocalizedNewspaperText.render_story(null, record, seed_value, "Köln", "Bürgermeister", PackedStringArray(["Löwen"]))
			assert(independent.ok, "German story %d needs no imported data: %s" % [story_type, independent.error])
			assert(independent.argument == record.argument and independent.auxiliary == record.auxiliary)
	assert(imported.grammar == original_grammar)
	var baseline := EmptyCityTemplate.create()
	var misc := baseline.find_chunk("MISC").decoded_payload.duplicate()
	assert(NewsQueue.insert(misc, 3, 0).ok)
	assert(baseline.find_chunk("MISC").set_decoded_payload(misc))
	var english_document := baseline.duplicate_document()
	var german_document := baseline.duplicate_document()
	var english_city := CityState.from_document(english_document)
	var german_city := CityState.from_document(german_document)
	var paper := NewspaperDialog.new()
	root.add_child(paper)
	AppLocalization.select("en")
	paper.open_reports(english_city, english_document, imported, {}, 1234, 0)
	paper.hide()
	AppLocalization.select("de")
	paper.open_reports(german_city, german_document, imported, {}, 1234, 0)
	assert(english_document.serialize().data == german_document.serialize().data,
		"German newspaper display must preserve the English substitution/save behavior")
	var before_switch := german_document.serialize().data
	AppLocalization.select("en")
	AppLocalization.select("de")
	assert(german_document.serialize().data == before_switch)
	paper.hide()
	paper.free()
	var scenario_document := Sc2File.load_path("res://../references/SIMCITY2000/SCENARIO/ATLANTA.SCN")
	assert(scenario_document.is_valid())
	var description := ScenarioState.from_document(scenario_document).opening_description()
	assert(OriginalTextLocalization.scenario(description) != description.strip_edges())
	assert(OriginalTextLocalization.scenario("Custom description") == "Custom description")
	AppLocalization.select("en")
	assert(OriginalTextLocalization.text(1000, "source") == "source")
	assert(OriginalTextLocalization.library_texts({}).is_empty())
	assert(not LocalizedNewspaperText.has_data(null))
	var english := LocalizedNewspaperText.render_story(imported, literal_record, 1, "Town", "Mayor", PackedStringArray())
	assert(english.ok and english.headline == "English Headline")
	AppLocalization.select("de")


# Long translations and artwork must stay inside the toolbar at each UI scale.
func _check_toolbar_layout() -> void:
	var old_size := root.size
	var old_factor := root.content_scale_factor
	root.size = Vector2i(1600, 1000)
	var row := HBoxContainer.new()
	root.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var toolbar := preload("res://src/ui/shell/city_toolbar.tscn").instantiate() as CityToolbar
	row.add_child(toolbar)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var pixels := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	var icon := ImageTexture.create_from_image(pixels)
	var provider := func(_group: int, _tool: int) -> Texture2D: return icon
	for theme_name in ["light", "dark"]:
		row.theme = AppUiThemeDefinitions.build(theme_name)
		for language in ["en", "de", "ko"]:
			AppLocalization.select(language)
			for ui_scale in AppUiScale.OPTIONS:
				AppUiScale.apply(root, ui_scale)
				for group in [CityToolIds.Group.POWER, CityToolIds.Group.WATER, CityToolIds.Group.REWARDS]:
					toolbar.show_tool_group(group, null, provider)
					for frame in 6:
						await process_frame
					var bounds := toolbar.get_global_rect().grow(0.5)
					for path in ["Margin", "Margin/Column", "Margin/Column/Layers", "Margin/Column/DataViewInput"]:
						var control := toolbar.get_node(path) as Control
						assert(bounds.encloses(control.get_global_rect()), "%s overflows the %s toolbar at scale %s" % [path, language, ui_scale])
					for button: Button in toolbar.child_tool_buttons.values():
						var rect := button.get_global_rect()
						assert(rect.position.x >= bounds.position.x and rect.end.x <= bounds.end.x,
							"Translated tool buttons must fit the sidebar horizontally")
						assert(button.size.x >= button.get_minimum_size().x,
							"Tool text and artwork must have their requested width")
	row.free()
	root.size = old_size
	root.content_scale_factor = old_factor
	AppLocalization.select("de")
