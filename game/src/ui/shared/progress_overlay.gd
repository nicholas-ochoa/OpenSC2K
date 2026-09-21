class_name ProgressOverlay
extends Control


var title_label: Label
var bar: ProgressBar
var detail_label: Label


func _ready() -> void:
	hide()
	title_label = $Center/Panel/Rows/Title
	bar = $Center/Panel/Rows/Bar
	detail_label = $Center/Panel/Rows/Detail


# show `fraction` from 0 to 1. a negative fraction shows unknown progress
func show_progress(title: String, detail: String, fraction: float) -> void:
	title_label.text = title
	detail_label.text = detail
	bar.indeterminate = fraction < 0.0
	bar.show_percentage = fraction >= 0.0

	if fraction >= 0.0:
		bar.value = clampf(fraction, 0.0, 1.0)

	show()
