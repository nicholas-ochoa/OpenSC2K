# todo: save a copy without overwriting the source city

extends Control

const Sc2Document = preload("res://src/formats/sc2_file.gd")
const CityModel = preload("res://src/model/city_state.gd")
const Palette = preload("res://src/assets/sc2_palette.gd")
const SpriteArchive = preload("res://src/assets/sc2_sprite_archive.gd")
const Minimap = preload("res://src/view/city_minimap.gd")
const IsometricRenderer = preload("res://src/view/city_isometric_renderer.gd")

var city: CityState
var palette: Sc2Palette
var large_sprites: Sc2SpriteArchive
var overlay_mode := "city"

var map_texture: TextureRect
var city_label: Label
var details_label: Label
var status_label: Label
var file_dialog: FileDialog


func _ready() -> void:
	_build_interface()
	var reference_root := ProjectSettings.globalize_path("res://../references")
	palette = Palette.load_bmp(reference_root.path_join("BITMAPS/PAL_MSTR.BMP"))
	if not palette.is_valid():
		_show_error(palette.load_error)
		return
	large_sprites = SpriteArchive.load_path(reference_root.path_join("DATA/LARGE.DAT"))
	if not large_sprites.is_valid():
		_show_error(large_sprites.parse_error)
		return

	var initial_city := reference_root.path_join("CITIES/STARTER.SC2")
	if FileAccess.file_exists(initial_city):
		_load_city(initial_city)
	else:
		_show_error("Choose an original SC2 or SCN file to start.")


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("101820")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 20)
	root_margin.add_theme_constant_override("margin_top", 16)
	root_margin.add_theme_constant_override("margin_right", 20)
	root_margin.add_theme_constant_override("margin_bottom", 18)
	add_child(root_margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	root_margin.add_child(page)

	var header := HBoxContainer.new()
	page.add_child(header)

	var title := Label.new()
	title.text = "SIMCITY 2000"
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var open_button := Button.new()
	open_button.text = "Open City"
	open_button.pressed.connect(_open_city_dialog)
	header.add_child(open_button)

	var mode_bar := HBoxContainer.new()
	mode_bar.add_theme_constant_override("separation", 6)
	page.add_child(mode_bar)
	for mode in ["city", "structures", "zones", "power", "water"]:
		var button := Button.new()
		button.text = mode.capitalize()
		button.pressed.connect(_set_overlay.bind(mode))
		mode_bar.add_child(button)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	page.add_child(content)

	var map_panel := PanelContainer.new()
	map_panel.custom_minimum_size = Vector2(640, 640)
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(map_panel)

	map_texture = TextureRect.new()
	map_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_panel.add_child(map_texture)

	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(295, 0)
	sidebar.add_theme_constant_override("separation", 12)
	content.add_child(sidebar)

	city_label = Label.new()
	city_label.text = "No city loaded"
	city_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	city_label.add_theme_font_size_override("font_size", 26)
	sidebar.add_child(city_label)

	details_label = Label.new()
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.add_theme_font_size_override("font_size", 18)
	sidebar.add_child(details_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("9db2c5"))
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(status_label)

	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.SC2, *.sc2", "SimCity 2000 cities")
	file_dialog.add_filter("*.SCN, *.scn", "SimCity 2000 scenarios")
	file_dialog.file_selected.connect(_load_city)
	add_child(file_dialog)


func _open_city_dialog() -> void:
	var city_directory := ProjectSettings.globalize_path("res://../references/CITIES")
	if DirAccess.dir_exists_absolute(city_directory):
		file_dialog.current_dir = city_directory
	file_dialog.popup_centered_ratio(0.8)


func _load_city(path: String) -> void:
	var document := Sc2Document.load_path(path)
	if not document.is_valid():
		_show_error(document.parse_error)
		return

	var loaded_city := CityModel.from_document(document)
	if not loaded_city.is_valid():
		_show_error(loaded_city.load_error)
		return

	city = loaded_city
	city_label.text = (
		city.city_name() if not city.city_name().is_empty() else path.get_file().get_basename()
	)
	var demand := city.rci_demand()
	details_label.text = (
		"Mayor: %s\nDate: %04d-%02d-%02d\nPopulation: %s\nFunds: $%s\n\nDemand\nR: %+d\nC: %+d\nI: %+d"
		% [
			city.mayor_name() if not city.mayor_name().is_empty() else "Unknown",
			city.current_year(),
			city.current_month(),
			city.current_day(),
			_format_number(city.population()),
			_format_number(city.funds()),
			demand.x,
			demand.y,
			demand.z,
		]
	)
	status_label.remove_theme_color_override("font_color")
	status_label.text = "Loaded %s\nMap view: %s" % [path.get_file(), overlay_mode.capitalize()]
	_refresh_map()


func _set_overlay(mode: String) -> void:
	overlay_mode = mode
	if city != null:
		status_label.text = "Map view: %s" % overlay_mode.capitalize()
		_refresh_map()


func _refresh_map() -> void:
	if city == null or palette == null:
		return
	var image: Image
	if overlay_mode == "city":
		var rendered := IsometricRenderer.create_image(city, palette, large_sprites)
		if not rendered.ok:
			_show_error(rendered.error)
			return
		image = rendered.image
	else:
		image = Minimap.create_image(city, palette, overlay_mode)
	map_texture.texture = ImageTexture.create_from_image(image)


func _show_error(message: String) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("ff877d"))


func _format_number(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var output := ""
	while digits.length() > 3:
		output = "," + digits.right(3) + output
		digits = digits.left(digits.length() - 3)
	output = digits + output
	return "-" + output if negative else output
