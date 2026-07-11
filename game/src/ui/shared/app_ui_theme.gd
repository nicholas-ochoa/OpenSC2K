class_name AppUiTheme
extends RefCounted


static var selected := "light"
static var translucent_menus := true
static var _current: Theme
static var _files: Theme


static func current() -> Theme:
	if _current == null:
		_current = build(selected)
	return _current


static func file_dialog() -> Theme:
	if _files == null:
		_files = build(selected, true)
	return _files


static func select(value: String, translucent := true) -> void:
	selected = "dark" if value == "dark" else "light"
	translucent_menus = translucent
	# keep resource identities so hidden windows and retained editors update too
	if _current != null:
		_current.set_block_signals(true)
		_current.clear()
		_current.merge_with(build(selected))
		_current.set_block_signals(false)
		_current.emit_changed()
	if _files != null:
		_files.set_block_signals(true)
		_files.clear()
		_files.merge_with(build(selected, true))
		_files.set_block_signals(false)
		_files.emit_changed()


static func bind_canvas(control: ColorRect, role := "canvas") -> void:
	var refresh := func() -> void: control.color = control.get_theme_color(role, "AppPalette")
	control.theme_changed.connect(refresh)
	refresh.call()


static func bind_frosted_panel(control: Control, background_copy: BackBufferCopy = null) -> void:
	var glass_material := control.material
	var refresh := func() -> void:
		control.material = glass_material if translucent_menus else null
		if background_copy != null:
			background_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if translucent_menus else BackBufferCopy.COPY_MODE_DISABLED
	control.theme_changed.connect(refresh)
	refresh.call()


static func build(value: String, files := false) -> Theme:
	return AppUiThemeDefinitions.build(value, files, translucent_menus)


static func _light_theme() -> Theme:
	return AppUiThemeDefinitions._light_theme()


static func _dark_theme() -> Theme:
	return AppUiThemeDefinitions._dark_theme()


static func _copy_style(source: Theme, type_name: String, state: String) -> StyleBoxFlat:
	return AppUiThemeDefinitions._copy_style(source, type_name, state)


static func _tinted_icon(texture: Texture2D, color: Color) -> Texture2D:
	return AppUiThemeDefinitions._tinted_icon(texture, color)


static func _light_file_dialog_theme() -> Theme:
	return AppUiThemeDefinitions._light_file_dialog_theme()


static func create_box(
	background: Color,
	border: Color,
	width: int,
	horizontal_margin := 5,
	vertical_margin := 3
) -> StyleBoxFlat:
	return AppUiThemeDefinitions.create_box(background, border, width, horizontal_margin, vertical_margin)


static func _base_light_controls() -> Theme:
	return AppUiThemeDefinitions._base_light_controls()


static func _base_light_theme() -> Theme:
	return AppUiThemeDefinitions._base_light_theme()
