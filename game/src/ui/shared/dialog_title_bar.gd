class_name DialogTitleBar
extends ColorRect

signal close_requested

var title_label: Label
var close_button: TextureButton


func _init(title_text := "") -> void:
	var window_theme := AppUiTheme.current()
	var border := window_theme.get_stylebox("embedded_border", "Window") as StyleBoxFlat
	color = border.bg_color
	custom_minimum_size.y = 30
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_right = -4
	add_child(row)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 24
	row.add_child(spacer)
	title_label = Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_override("font", window_theme.get_font("title_font", "Window"))
	title_label.add_theme_font_size_override("font_size", window_theme.get_font_size("title_font_size", "Window"))
	title_label.add_theme_color_override("font_color", window_theme.get_color("title_color", "Window"))
	row.add_child(title_label)
	close_button = TextureButton.new()
	close_button.custom_minimum_size.x = 24
	close_button.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	close_button.texture_normal = window_theme.get_icon("close", "Window")
	close_button.texture_pressed = window_theme.get_icon("close_pressed", "Window")
	close_button.tooltip_text = "Close"
	close_button.pressed.connect(func() -> void:
		close_requested.emit())
	row.add_child(close_button)


func _ready() -> void:
	theme_changed.connect(_refresh_theme)
	_refresh_theme()


func _refresh_theme() -> void:
	color = (get_theme_stylebox("embedded_border", "Window") as StyleBoxFlat).bg_color
	title_label.add_theme_font_override("font", get_theme_font("title_font", "Window"))
	title_label.add_theme_font_size_override("font_size", get_theme_font_size("title_font_size", "Window"))
	title_label.add_theme_color_override("font_color", get_theme_color("title_color", "Window"))
	close_button.texture_normal = get_theme_icon("close", "Window")
	close_button.texture_pressed = get_theme_icon("close_pressed", "Window")
