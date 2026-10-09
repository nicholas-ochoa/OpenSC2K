class_name ProgressOverlay
extends Control

const PREPARATION_MESSAGES := [
	"Reticulating Splines…",
	"Reticulating Just One More Spline…",
	"Not Cutting Back on Funding…",
	"Convincing Arcologies to Stay…",
	"Checking the Budget for Rosebuds…",
	"Searching for Bella Goth…",
	"Putting the Pool Ladder Back…",
	"Consulting the Llama Committee…",
]

var message_random := RandomNumberGenerator.new()
var message_order: Array[int] = []
var message_index := -1
var message_timer: Timer
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
	if bottom_strip:
		return
	bottom_strip = true
	message_random.randomize()
	message_timer = Timer.new()
	message_timer.wait_time = 6.0
	message_timer.timeout.connect(_next_preparation_message)
	add_child(message_timer)
	visibility_changed.connect(_on_visibility_changed)
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
	if not bottom_strip:
		detail_label.text = detail
	bar.indeterminate = fraction < 0.0
	bar.show_percentage = fraction >= 0.0 and not bottom_strip

	if fraction >= 0.0:
		bar.value = clampf(fraction, 0.0, 1.0)

	if bottom_strip:
		if not visible:
			_next_preparation_message()
			message_timer.start()
		else:
			_update_preparation_detail()
	show()


func _on_visibility_changed() -> void:
	if not visible:
		message_timer.stop()


func _next_preparation_message() -> void:
	if message_order.is_empty():
		for index in PREPARATION_MESSAGES.size():
			message_order.append(index)
		# Shuffle with presentation-only randomness; leave game RNG untouched.
		for index in range(message_order.size() - 1, 0, -1):
			var other := message_random.randi_range(0, index)
			var entry := message_order[index]
			message_order[index] = message_order[other]
			message_order[other] = entry
		if message_order.back() == message_index:
			var other := message_random.randi_range(0, message_order.size() - 2)
			message_order[message_order.size() - 1] = message_order[other]
			message_order[other] = message_index
	message_index = message_order.pop_back()
	_update_preparation_detail()


func _update_preparation_detail() -> void:
	var message: String = PREPARATION_MESSAGES[message_index]
	detail_label.text = message if bar.indeterminate else "%s %d %%" % [message, floori(bar.value * 100.0)]
