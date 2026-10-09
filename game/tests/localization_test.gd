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
