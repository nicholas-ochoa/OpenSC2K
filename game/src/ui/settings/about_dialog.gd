class_name AboutDialog
extends AcceptDialog

@warning_ignore_start("integer_division")

var artwork: AboutArtwork
var project_text: RichTextLabel
var license_picker: OptionButton
var license_text: RichTextLabel
var license_documents: Array[String] = []
var original_credits_index := -1


func _ready() -> void:
	# keep the scene visible in the editor, but closed until requested in game
	hide()
	get_label().hide()
	artwork = $Content/Tabs/About/Scene/Artwork
	project_text = $Content/Tabs/About/Summary
	var body_font := SystemFont.new()
	body_font.font_names = PackedStringArray(["Arial", "Liberation Sans", "Noto Sans"])
	body_font.font_weight = 400
	var heading_font := SystemFont.new()
	heading_font.font_names = body_font.font_names
	heading_font.font_weight = 600
	project_text.add_theme_font_override("normal_font", body_font)
	project_text.add_theme_font_override("bold_font", heading_font)
	license_picker = $Content/Tabs/Licenses/LicensePicker
	license_text = $Content/Tabs/Licenses/LicenseText
	license_text.add_theme_font_override("normal_font", body_font)
	license_picker.item_selected.connect(_select_license)
	project_text.meta_clicked.connect(_open_link)
	license_text.meta_clicked.connect(_open_link)
	about_to_popup.connect(_fit_to_viewport)
	visibility_changed.connect(_update_animation)
	$Content/Tabs.tab_changed.connect(_on_tab_changed)
	_build_licenses()


func set_assets(assets: OriginalGameAssets) -> void:
	artwork.set_assets(assets)
	license_documents[original_credits_index] = _original_credits_document("" if assets == null else assets.original_credits)
	if license_picker.selected == original_credits_index:
		_select_license(original_credits_index)
	$Content/Tabs/About/Scene/MissingArtwork.visible = not artwork.available


func _on_tab_changed(_index: int) -> void:
	_update_animation(false)


func _update_animation(restart := true) -> void:
	artwork.set_active(visible and $Content/Tabs.current_tab == 0, restart)


func _build_licenses() -> void:
	_add_license("OpenSC2K — MIT", FileAccess.get_file_as_string("res://assets/licenses/OpenSC2K-MIT.txt"))
	_add_license("sc2kfix — MIT", FileAccess.get_file_as_string("res://assets/licenses/sc2kfix-MIT.txt"))
	_add_license("Godot Engine — MIT", Engine.get_license_text())
	var engine_notices := "Godot Engine third-party components\n\n"
	for component in Engine.get_copyright_info():
		engine_notices += str(component.name) + "\n"
		for part in component.parts:
			engine_notices += "\n".join(part.copyright) + "\nLicense: " + str(part.license) + "\n"
		engine_notices += "\n"
	var engine_licenses := Engine.get_license_info()
	for license_name in engine_licenses:
		engine_notices += str(license_name) + "\n" + str(engine_licenses[license_name]) + "\n\n"
	_add_license("Godot Engine — dependency notices", engine_notices)
	_add_license("Rajdhani — SIL OFL 1.1", FileAccess.get_file_as_string("res://assets/fonts/rajdhani/OFL.txt"))
	_add_license("Anton — SIL OFL 1.1", FileAccess.get_file_as_string("res://assets/fonts/anton/OFL.txt"))
	_add_license("UnifrakturMaguntia — SIL OFL 1.1", FileAccess.get_file_as_string("res://assets/fonts/unifrakturmaguntia/OFL.txt"))
	_add_license("Grenze Gotisch — SIL OFL 1.1", FileAccess.get_file_as_string("res://assets/fonts/grenzegotisch/OFL.txt"))
	_add_license("Chomsky — SIL OFL 1.1", FileAccess.get_file_as_string("res://assets/fonts/chomsky/OFL.txt"))
	_add_license("Godot WRY — MIT", FileAccess.get_file_as_string("res://addons/godot_wry/LICENSE"))
	_add_license("Godot WRY — dependency notices", FileAccess.get_file_as_string("res://assets/licenses/wry-dependencies.txt"))
	_add_license("Research and original game", """RESEARCH

sc2json — MIT
https://github.com/sc2kfix/sc2json
Save-file and compression research.

SC2k-docs — OpenCity2k contributors — CC BY-SA 4.0
https://github.com/OpenCity2k/SC2k-docs
File-format and simulation research. OpenSC2K's implementations and descriptions may differ.

sc2k-reverse wiki — contributors — CC BY-SA 4.0
https://wiki.sc2kfix.net/
Function and structure research.
https://creativecommons.org/licenses/by-sa/4.0/

ORIGINAL GAME

SimCity 2000 and its imported graphics, text, sound, and music belong to their respective rights holders. They are not covered by OpenSC2K's MIT license.

""" + (
		"OpenSC2K is an independent project. It is not affiliated with, sponsored by, or endorsed by Electronic "
		+ "Arts or Maxis. SimCity and related names and marks belong to their respective owners."
		+ "\n"
	))
	original_credits_index = license_documents.size()
	_add_license("Original SimCity 2000 credits", _original_credits_document(""))
	_select_license(0)


func _original_credits_document(credits: String) -> String:
	var introduction := """ORIGINAL SIMCITY 2000 CREDITS

""" + (
		"These credits recognize the people who created the original SimCity 2000. They describe their work on "
		+ "that game, not contributions to OpenSC2K. Their inclusion does not imply affiliation or endorsement."
		+ "\n\n"
	)
	if credits.is_empty():
		return introduction + "The original credits are unavailable. Import a complete supported game installation to view them."
	return introduction + "Credits from the imported SimCity 2000 for Windows 95 installation:\n\n" + credits.replace("\r\n", "\n").strip_edges()


func _add_license(label: String, text: String) -> void:
	license_picker.add_item(label)
	license_documents.append(text)


func _select_license(index: int) -> void:
	license_text.text = license_documents[index]
	license_text.scroll_to_line(0)


func _open_link(meta: Variant) -> void:
	var url := str(meta)
	if url.begins_with("https://"):
		OS.shell_open(url)


func _fit_to_viewport() -> void:
	if get_parent() == null:
		return
	var viewport_size := Vector2i(get_parent().get_viewport().get_visible_rect().size)
	var height_limit := maxi(1, int(viewport_size.y * 0.9) - get_theme_constant("title_height"))
	max_size = Vector2i(0, height_limit)
	size = Vector2i(mini(760, int(viewport_size.x * 0.95)), mini(550, height_limit))
	position = (viewport_size - size) / 2
