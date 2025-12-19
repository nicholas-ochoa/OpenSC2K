class_name NewspaperPage
extends Control

signal story_selected(slot: int)

const PAGE_SIZE := Vector2i(640, 400)
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
var hovered_story := -1
var title_label: Label
var date_label: Label
var price_label: Label
var opinion_label: Label
var weather_label: Label
var story_labels: Array[Label] = []
var article_labels: Array[Label] = []
var picture_id := 0
var picture_texture: Texture2D


func _ready() -> void:
	custom_minimum_size = PAGE_SIZE
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
	layout_index = clampi(new_layout, 0, LAYOUT_RECTS.size() - 1)
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
	return FONT_SIZES[layout_index][3] == 0 and picture_texture != null


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
	draw_rect(Rect2(Vector2.ZERO, Vector2(PAGE_SIZE)), Color("fffdf2"), true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(PAGE_SIZE)), Color("181818"), false, 1.0)
	# the picture slot is wider than its native bitmap. its bounds overlap a
	# story column in layout 2, so do not outline that empty allocation
	for section in range(4, SECTION_COUNT):
		var rect := Rect2(section_rect(layout_index, section))
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			draw_rect(rect.grow(-1.0), Color("696969"), false, 1.0)
	if shows_picture():
		draw_texture(picture_texture, Vector2(section_rect(layout_index, 3).position))
	if hovered_story >= 0:
		draw_rect(Rect2(story_rect(layout_index, hovered_story)).grow(-2.0), Color("0066cc"), false, 2.0)


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
	_configure_label(opinion_label, 5)
	_configure_label(weather_label, 6)
	for slot in story_labels.size():
		_configure_label(story_labels[slot], STORY_RECT_INDICES[slot])


func _configure_label(label: Label, section: int) -> void:
	var rect := section_rect(layout_index, section)
	var inset := 4 if section >= 4 else 2
	label.position = Vector2(rect.position + Vector2i(inset, inset))
	label.size = Vector2(rect.size - Vector2i(inset * 2, inset * 2))
	var font_size := maxi(9, FONT_SIZES[layout_index][section])
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
		if Rect2(story_rect(layout_index, slot)).has_point(position):
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
	for slot in article_labels.size():
		var headline := story_labels[slot]
		var body := article_labels[slot]
		var rect := story_rect(layout_index, slot)
		body.visible = rect.size.y > 70
		if not body.visible:
			continue
		headline.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		headline.size.y = minf(48.0, rect.size.y * 0.3)
		headline.add_theme_font_size_override("font_size", 13)
		body.position = Vector2(rect.position) + Vector2(5, headline.size.y + 6)
		body.size = Vector2(rect.size) - Vector2(10, headline.size.y + 12)
		body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.add_theme_font_size_override("font_size", 11)
		body.text = articles[slot] if slot < articles.size() else ""
