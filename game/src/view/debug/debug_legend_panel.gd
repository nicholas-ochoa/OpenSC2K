class_name CityDebugLegendPanel
extends PanelContainer
## The key of the active debug tile layer: its title, its colors and a summary
## line, such as the network counts or the changed tile counts.

const SWATCH_SIZE := Vector2(14, 14)

var _rows: VBoxContainer
var _layer := -1
var _summary: Label


func _ready() -> void:
	name = "DebugLegend"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"TooltipPanel"
	_rows = VBoxContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("separation", 3)
	add_child(_rows)
	FrostedTooltipPanel.bind(self)
	hide()


func show_layer(layer: DebugTileLayers.Layer, summary: String) -> void:
	if layer == DebugTileLayers.Layer.NONE:
		_layer = -1
		hide()

		return

	if _layer != layer:
		_layer = layer
		_build(layer)

	_summary.text = summary
	_summary.visible = not summary.is_empty()
	size = Vector2.ZERO
	size = get_combined_minimum_size()
	show()


func _build(layer: DebugTileLayers.Layer) -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	_rows.add_child(_text_row("Debug layer: " + DebugTileLayers.title(layer)))

	for row in DebugLayerColors.legend(layer):
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var swatch := ColorRect.new()
		swatch.color = Color(row[0], 1.0)
		swatch.custom_minimum_size = SWATCH_SIZE
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(swatch)
		line.add_child(_text_row(row[1]))
		_rows.add_child(line)

	_summary = _text_row("")
	_rows.add_child(_summary)


func _text_row(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = &"TooltipLabel"
	label.add_theme_font_size_override("font_size", 13)

	return label
