class_name ButtonHelpDialog
extends AcceptDialog
## The help for a toolbar button or the status bar. A long topic scrolls.

const TEXT_WIDTH := 460.0
const MAXIMUM_TEXT_HEIGHT := 360.0

# the topic on show, for tests and scripts
var topic := ""
var scroll: ScrollContainer
var text_label: Label


func _init() -> void:
	name = "ButtonHelpDialog"
	theme = AppUiTheme.current()
	exclusive = true
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size.x = TEXT_WIDTH
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(text_label)
	add_child(scroll)


func show_topic(value_topic: String, text: String) -> void:
	topic = value_topic
	title = value_topic
	text_label.text = text

	# a short topic fits without a scroll bar
	var font := text_label.get_theme_font("font")
	var font_size := text_label.get_theme_font_size("font_size")
	var height := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, TEXT_WIDTH, font_size).y
	var scroll_bar := scroll.get_v_scroll_bar().get_combined_minimum_size().x
	scroll.custom_minimum_size = Vector2(TEXT_WIDTH + scroll_bar, minf(ceilf(height), MAXIMUM_TEXT_HEIGHT))
	scroll.scroll_vertical = 0
	reset_size()
	popup_centered()
