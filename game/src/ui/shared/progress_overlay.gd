class_name ProgressOverlay
extends Control

var title_label: Label
var bar: ProgressBar
var detail_label: Label
var bottom_strip := false


func _ready() -> void:
	hide()
	title_label = $Center/Panel/Rows/Title
	bar = $Center/Panel/Rows/Bar
	detail_label = $Center/Panel/Rows/Detail


# The background preparation strip never captures map clicks or keyboard focus.
func use_bottom_strip() -> void:
	bottom_strip = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for control in find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Shade.hide()
	var center: CenterContainer = $Center
	center.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top = -50.0
	center.offset_bottom = -4.0
	$Center/Panel/Rows/Title.hide()
	$Center/Panel/Rows.add_theme_constant_override("separation", 2)
	bar.custom_minimum_size.y = 8.0
	bar.show_percentage = false


func avoid_footer(footer: Control) -> void:
	footer.resized.connect(_position_above_footer.bind(footer))
	_position_above_footer(footer)


func _position_above_footer(footer: Control) -> void:
	var center: CenterContainer = $Center
	var clearance := maxf(footer.size.y, footer.get_combined_minimum_size().y) + 6.0
	center.offset_bottom = -clearance
	center.offset_top = -clearance - maxf(46.0, $Center/Panel.get_combined_minimum_size().y)


# show `fraction` from 0 to 1. a negative fraction shows unknown progress
func show_progress(title: String, detail: String, fraction: float) -> void:
	title_label.text = title
	detail_label.text = detail
	bar.indeterminate = fraction < 0.0
	bar.show_percentage = fraction >= 0.0 and not bottom_strip

	if fraction >= 0.0:
		bar.value = clampf(fraction, 0.0, 1.0)

	show()
