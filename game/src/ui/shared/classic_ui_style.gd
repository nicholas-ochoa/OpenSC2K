class_name ClassicUiStyle
extends RefCounted



static func create_theme() -> Theme:
	return AppUiTheme.current()


static func create_dialog_theme() -> Theme:
	return AppUiTheme.current()


static func create_box(background: Color, border: Color, width: int, horizontal_margin := 5, vertical_margin := 3) -> StyleBoxFlat:
	return AppUiThemeDefinitions.create_box(background, border, width, horizontal_margin, vertical_margin)
