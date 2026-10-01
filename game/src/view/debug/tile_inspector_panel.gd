class_name CityTileInspectorPanel
extends PanelContainer
## The Tile Inspector text beside the pointer, or at a pinned tile. The text
## changes only when the inspected tile or the city revision changes.

const FONT_SIZE := 13
const POINTER_OFFSET := Vector2(20, 24)

var _label: Label
var _text_key: Array = []


func _ready() -> void:
	name = "TileInspector"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"TooltipPanel"
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.theme_type_variation = &"TooltipLabel"
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono", "monospace"])
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	add_child(_label)
	FrostedTooltipPanel.bind(self)
	hide()


# `key` names the text; the same key keeps the text and skips `text_source`
func show_text(key: Array, text_source: Callable, anchor: Vector2, area: Vector2) -> void:
	if key != _text_key:
		_text_key = key
		_label.text = str(text_source.call())
		size = Vector2.ZERO
		size = get_combined_minimum_size()

	var point := anchor + POINTER_OFFSET
	point.x = clampf(point.x, 4, maxf(4, area.x - size.x - 4))
	point.y = clampf(point.y, 4, maxf(4, area.y - size.y - 4))
	position = point
	show()


func text() -> String:
	return _label.text if _label != null else ""


func close() -> void:
	_text_key.clear()
	hide()
