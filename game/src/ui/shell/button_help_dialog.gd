class_name ButtonHelpDialog
extends AcceptDialog
## The help for a toolbar button or the status bar. The dialog grows to fit
## the text.

const TEXT_WIDTH := 460.0

# the topic on show, for tests and scripts
var topic := ""
var text_label: Label


func _init() -> void:
	name = "ButtonHelpDialog"
	theme = AppUiTheme.current()
	exclusive = true
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(text_label)


func show_topic(value_topic: String, text: String) -> void:
	topic = value_topic
	title = value_topic
	text_label.text = text

	# a wrapped label measures its height at its current width
	text_label.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	text_label.size = Vector2(TEXT_WIDTH, text_label.size.y)
	text_label.custom_minimum_size.y = text_label.get_minimum_size().y
	reset_size()
	popup_centered()
