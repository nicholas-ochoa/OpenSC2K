class_name NewspaperPage
extends Control

signal story_selected(slot: int)

const PAGE_SIZE := Vector2i(640, 400)
const PRESENTATION_SIZE := Vector2i(800, 500)
# retain the source rect tables below for evidence; this larger reading layout
# leaves room for modern font metrics and full article columns
const MASTHEAD_LAYOUT := [
	Rect2i(14, 4, 772, 54), Rect2i(14, 61, 380, 22), Rect2i(406, 61, 380, 22),
	Rect2i(278, 164, 244, 136), Rect2i(14, 94, 772, 60),
	Rect2i(14, 440, 508, 54), Rect2i(542, 440, 244, 54),
	Rect2i(14, 164, 244, 258), Rect2i(542, 164, 244, 258),
	Rect2i(278, 314, 116, 108), Rect2i(406, 314, 116, 108),
]
# headline-first edition, matching the original new city journal arrangement
const READING_RECTS := [
	Rect2i(180, 46, 360, 44), Rect2i(545, 68, 245, 22), Rect2i(8, 68, 165, 22),
	Rect2i(218, 290, 256, 202), Rect2i(20, 0, 760, 45),
	Rect2i(408, 94, 384, 48), Rect2i(8, 94, 384, 48),
	Rect2i(8, 146, 784, 140), Rect2i(8, 290, 202, 202),
	Rect2i(480, 290, 154, 202), Rect2i(640, 290, 152, 202),
]
const COLUMN_LAYOUT := [
	Rect2i(8, 0, 464, 52), Rect2i(480, 4, 312, 22), Rect2i(480, 28, 312, 22),
	Rect2i(166, 60, 150, 240), Rect2i(8, 60, 150, 432),
	Rect2i(324, 60, 150, 120), Rect2i(640, 60, 152, 300),
	Rect2i(480, 60, 154, 432), Rect2i(166, 306, 150, 186),
	Rect2i(324, 186, 150, 306), Rect2i(640, 366, 152, 126),
]
const READING_LAYOUTS := [MASTHEAD_LAYOUT, READING_RECTS, COLUMN_LAYOUT]
const SECTION_COUNT := 11
const STORY_RECT_INDICES := [4, 7, 8, 9, 10]

# each row contains the 11 rect values initialized by executable function
# 0x00476ff0. the order is title, date, price, picture, main story,
# opinion, weather, and four secondary stories
const LAYOUT_RECTS := [
	[
		Rect2i(0, 6, 640, 30),
		Rect2i(5, 16, 213, 15),
		Rect2i(315, 16, 320, 15),
		Rect2i(243, 76, 213, 100),
		Rect2i(0, 36, 640, 40),
		Rect2i(0, 300, 213, 100),
		Rect2i(426, 300, 214, 100),
		Rect2i(0, 76, 213, 224),
		Rect2i(426, 76, 214, 224),
		Rect2i(213, 176, 107, 224),
		Rect2i(320, 176, 106, 224),
	],
	[
		Rect2i(0, 37, 640, 36),
		Rect2i(421, 53, 214, 15),
		Rect2i(5, 53, 213, 15),
		Rect2i(178, 186, 256, 100),
		Rect2i(0, 0, 640, 37),
		Rect2i(0, 300, 128, 100),
		Rect2i(0, 73, 128, 227),
		Rect2i(128, 73, 512, 113),
		Rect2i(128, 287, 256, 113),
		Rect2i(384, 186, 128, 214),
		Rect2i(512, 186, 128, 214),
	],
	[
		Rect2i(0, 0, 384, 30),
		Rect2i(0, 0, 635, 12),
		Rect2i(0, 12, 635, 12),
		Rect2i(128, 30, 128, 210),
		Rect2i(0, 30, 128, 370),
		Rect2i(256, 30, 128, 105),
		Rect2i(512, 24, 128, 315),
		Rect2i(384, 24, 128, 376),
		Rect2i(128, 240, 128, 160),
		Rect2i(256, 135, 128, 265),
		Rect2i(512, 339, 128, 61),
	],
]

# these are the executable's point sizes for the same 11 sections
const FONT_SIZES := [
	[24, 12, 12, 0, 32, 12, 12, 10, 10, 10, 10],
	[24, 12, 12, 0, 30, 12, 12, 10, 10, 10, 10],
	[24, 10, 10, 1, 10, 0, 0, 10, 10, 10, 10],
]

# 0 is left, 1 is center, and 2 is right in the original text helper
const ALIGNMENTS := [
	[1, 0, 2, 1, 1, 0, 0, 1, 1, 1, 1],
	[1, 2, 0, 1, 1, 1, 1, 0, 1, 1, 1],
	[1, 1, 2, 2, 0, 0, 0, 0, 0, 0, 0],
]

var layout_index := 0
var _reading_rects: Array = MASTHEAD_LAYOUT.duplicate()
var hovered_story := -1
var title_label: Label
var date_label: Label
var price_label: Label
var opinion_label: Label
var weather_label: Label
var story_labels: Array[Label] = []
var article_labels: Array[Label] = []
var extra_columns: Array[Label] = []
var continuation_pages: Array[int] = []
var continuation_random := RandomNumberGenerator.new()
const BODY_FONT_SIZE := 8
const BODY_LINE_SPACING := -2
var serif_font := newspaper_font()
var headline_font := newspaper_font(true)
var picture_id := 0
var picture_texture: Texture2D


func _ready() -> void:
	continuation_random.randomize()
	custom_minimum_size = PRESENTATION_SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title_label = _new_label("PaperTitle")
	date_label = _new_label("PaperDate")
	price_label = _new_label("PaperPrice")
	opinion_label = _new_label("OpinionColumn")
	weather_label = _new_label("WeatherColumn")
	for slot in STORY_RECT_INDICES.size():
		story_labels.append(_new_label("Story%d" % slot))
		article_labels.append(_new_label("Article%d" % slot))
	_apply_layout()


func set_page(
	new_layout: int,
	paper_title: String,
	date_text: String,
	price_text: String,
	opinion_text: String,
	weather_text: String,
	headlines: PackedStringArray
) -> void:
	continuation_pages.clear()
	for slot in STORY_RECT_INDICES.size():
		continuation_pages.append(continuation_random.randi_range(2, 30))
	layout_index = clampi(new_layout, 0, LAYOUT_RECTS.size() - 1)
	_reading_rects = READING_LAYOUTS[layout_index].duplicate()
	title_label.text = paper_title
	date_label.text = date_text
	price_label.text = price_text
	opinion_label.text = opinion_text
	weather_label.text = weather_text
	for slot in story_labels.size():
		story_labels[slot].text = headlines[slot] if slot < headlines.size() else ""
	hovered_story = -1
	_apply_layout()
	queue_redraw()


func headline_for_slot(slot: int) -> String:
	if slot < 0 or slot >= story_labels.size():
		return ""
	return story_labels[slot].text


func set_picture(resource_id: int, image: Image) -> void:
	picture_id = resource_id
	picture_texture = null if image == null else ImageTexture.create_from_image(image)
	queue_redraw()


func shows_picture() -> bool:
	return picture_texture != null


static func section_rect(layout: int, section: int) -> Rect2i:
	if layout < 0 or layout >= LAYOUT_RECTS.size():
		return Rect2i()
	if section < 0 or section >= SECTION_COUNT:
		return Rect2i()
	return LAYOUT_RECTS[layout][section]


static func story_rect(layout: int, slot: int) -> Rect2i:
	if slot < 0 or slot >= STORY_RECT_INDICES.size():
		return Rect2i()
	return section_rect(layout, STORY_RECT_INDICES[slot])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(PRESENTATION_SIZE)), Color("c0c0c0"), true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(PRESENTATION_SIZE)), Color("181818"), false, 1.0)
	var rule_y := 45 if layout_index == 1 else 54
	draw_line(Vector2(8, rule_y), Vector2(792, rule_y), Color("303030"), 1.0)
	if layout_index != 2:
		draw_line(Vector2(8, 91 if layout_index == 1 else 87), Vector2(792, 91 if layout_index == 1 else 87), Color("303030"), 1.0)
	if shows_picture():
		var bounds := Rect2(_reading_rects[3])
		var factor := minf(bounds.size.x / picture_texture.get_width(), bounds.size.y / picture_texture.get_height())
		var extent := picture_texture.get_size() * factor
		draw_texture_rect(picture_texture, Rect2(bounds.get_center() - extent / 2.0, extent), false)
	if hovered_story >= 0:
		draw_rect(Rect2(_reading_rects[STORY_RECT_INDICES[hovered_story]]).grow(-2.0), Color("0066cc"), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered_story(_story_at(event.position))
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var slot := _story_at(event.position)
			if slot >= 0 and not story_labels[slot].text.is_empty():
				story_selected.emit(slot)
				accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_set_hovered_story(-1)


func _new_label(label_name: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.add_theme_font_override("font", serif_font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("151515"))
	add_child(label)
	return label


func _apply_layout() -> void:
	if not is_instance_valid(title_label):
		return
	_configure_label(title_label, 0)
	_configure_label(date_label, 1)
	_configure_label(price_label, 2)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if layout_index == 1 else HORIZONTAL_ALIGNMENT_LEFT
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if layout_index == 1 else HORIZONTAL_ALIGNMENT_RIGHT
	opinion_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	weather_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_configure_label(opinion_label, 5)
	_configure_label(weather_label, 6)
	for slot in story_labels.size():
		_configure_label(story_labels[slot], STORY_RECT_INDICES[slot])


func _configure_label(label: Label, section: int) -> void:
	var rect: Rect2i = _reading_rects[section]
	var inset := 4 if section >= 4 else 2
	label.position = Vector2(rect.position + Vector2i(inset, inset))
	label.size = Vector2(rect.size - Vector2i(inset * 2, inset * 2))
	var font_size := 14
	if section == 0:
		font_size = 30 if layout_index == 1 else 36
	elif section == 4:
		font_size = 32 if layout_index == 1 else 16 if layout_index == 2 else 26
	if section == 0 or section == 4:
		label.add_theme_font_override("font", headline_font)
	label.add_theme_font_size_override("font_size", font_size)
	# godot font metrics can exceed the original windows section height
	# keep at least one complete line visible inside each fixed source rect
	while font_size > 1 and label.get_line_height() > label.size.y:
		font_size -= 1
		label.add_theme_font_size_override("font_size", font_size)
	match ALIGNMENTS[layout_index][section]:
		1:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		2:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _story_at(position: Vector2) -> int:
	for slot in STORY_RECT_INDICES.size():
		if Rect2(_reading_rects[STORY_RECT_INDICES[slot]]).has_point(position):
			return slot
	return -1


func _set_hovered_story(slot: int) -> void:
	if hovered_story == slot:
		return
	hovered_story = slot
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if slot >= 0 else Control.CURSOR_ARROW
	)
	tooltip_text = (
		"Open this report" if slot >= 0 and not story_labels[slot].text.is_empty() else ""
	)
	queue_redraw()


func set_articles(articles: PackedStringArray) -> void:
	_fit_story_row(articles)
	for column in extra_columns:
		column.free()
	extra_columns.clear()
	for slot in article_labels.size():
		var headline := story_labels[slot]
		var body := article_labels[slot]
		var rect: Rect2i = _reading_rects[STORY_RECT_INDICES[slot]]
		body.visible = rect.size.y > 70
		body.text = ""
		if not body.visible:
			continue
		headline.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		headline.add_theme_font_override("font", headline_font)
		headline.add_theme_font_size_override("font_size", 15)
		var heading_size := 15
		var heading_extent := headline_font.get_multiline_string_size(headline.text, HORIZONTAL_ALIGNMENT_LEFT, headline.size.x, heading_size)
		while heading_size > 11 and heading_extent.y > 56:
			heading_size -= 1
			heading_extent = headline_font.get_multiline_string_size(headline.text, HORIZONTAL_ALIGNMENT_LEFT, headline.size.x, heading_size)
		headline.add_theme_font_size_override("font_size", heading_size)
		headline.size.y = minf(56.0, heading_extent.y + 2.0)
		var count := maxi(1, roundi(rect.size.x / 158.0))
		var width := float(rect.size.x) / count
		var remaining := articles[slot].strip_edges() if slot < articles.size() else ""
		for index in count:
			var column := body if index == 0 else _new_label("Article%dColumn%d" % [slot, index])
			if index > 0:
				extra_columns.append(column)
			column.position = Vector2(rect.position) + Vector2(index * width + 4, headline.size.y + 6)
			column.size = Vector2(width - 8, rect.size.y - headline.size.y - 10)
			column.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			column.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
			column.justification_flags = TextServer.JUSTIFICATION_WORD_BOUND | TextServer.JUSTIFICATION_SKIP_LAST_LINE
			column.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
			column.add_theme_constant_override("line_spacing", BODY_LINE_SPACING)
			var words := remaining.split(" ", false)
			var taken := _fitting_words(words, column.size)
			var notice := ""
			if index == count - 1 and taken < words.size():
				notice = "\n... (continued on pg %d)" % continuation_pages[slot]
				taken = _fitting_words(words, column.size, notice)
			column.text = " ".join(words.slice(0, taken)) + notice
			remaining = " ".join(words.slice(taken)).strip_edges()


func _fit_story_row(articles: PackedStringArray) -> void:
	if layout_index != 1 or articles.size() < 2:
		return
	var top_rect: Rect2i = READING_RECTS[7]
	var line_height := serif_font.get_height(BODY_FONT_SIZE) + BODY_LINE_SPACING
	var rows := ceili(_body_text_height(articles[1], top_rect.size.x / 5.0 - 8) / (line_height * 5))
	var heading_height := headline_font.get_multiline_string_size(story_labels[1].text, HORIZONTAL_ALIGNMENT_LEFT, top_rect.size.x - 8, 15).y
	top_rect.size.y = clampi(ceili(heading_height + rows * line_height + 16), 48, READING_RECTS[7].size.y)
	_reading_rects[7] = top_rect
	for section in [3, 8, 9, 10]:
		var rect: Rect2i = READING_RECTS[section]
		rect.position.y = top_rect.end.y + 4
		rect.size.y = 492 - rect.position.y
		_reading_rects[section] = rect
	_apply_layout()
	queue_redraw()


func _fitting_words(words: PackedStringArray, bounds: Vector2, suffix := "") -> int:
	var low := 0
	var high := words.size()
	while low < high:
		var middle := (low + high + 1) / 2
		var candidate := " ".join(words.slice(0, middle)) + suffix
		if _body_text_height(candidate, bounds.x) <= bounds.y:
			low = middle
		else:
			high = middle - 1
	return low



func _body_text_height(text: String, width: float) -> float:
	var height := serif_font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, BODY_FONT_SIZE).y
	var lines := maxi(1, roundi(height / serif_font.get_height(BODY_FONT_SIZE)))
	return height + (lines - 1) * BODY_LINE_SPACING


static func newspaper_font(bold := false) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Times New Roman", "Liberation Serif", "Noto Serif", "serif"])
	font.font_weight = 700 if bold else 400
	return font
