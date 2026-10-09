class_name BusyOverlay
extends Control
# a small centered box with a spinner and a message. it covers its parent and
# takes the pointer input while it is visible

const LoadingSpinner = preload("res://src/ui/shared/loading_spinner.gd")

var spinner: Control
var label: Label


func _init(message := "") -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := PanelContainer.new()
	box.theme_type_variation = "PanelPadding8_8_8_8"
	center.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	spinner = LoadingSpinner.new()
	spinner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(spinner)
	label = Label.new()
	label.text = message
	label.custom_minimum_size = Vector2(140, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	hide()


func show_message(message: String) -> void:
	label.text = message
	show()
