class_name NewspaperPage
extends Control
## The open newspaper: the masthead, the banner headline and the story panels.
## The fixed regions follow the supplied original-game examples. The Herald
## edition uses three equal columns. The Chronicle edition puts a wide lead
## above a central picture.

@warning_ignore_start("integer_division")

signal close_pressed
signal cancel_pressed
signal read_requested(title: String, text: String)

const PAPER := Color("#d0cfc9")
const BORDER := Color("#666666")
# a soft shadow like CSS box-shadow: 0 8px 40px. a StyleBoxFlat shadow is
# denser than a CSS blur of the same size, so it uses a lighter color
const SHADOW := Color(0.0, 0.0, 0.0, 0.3)
const SHADOW_SIZE := 40
const SHADOW_OFFSET := Vector2(0.0, 8.0)
const HEADER_RULE := Color("#34342e")
const CHRONICLE_RULE := Color("#555555")
const CLOSE_HOVER := Color(0.0, 0.0, 0.0, 0.13)
const INK := NewspaperStory.INK

const MAX_WIDTH := 1280.0
const AREA_SHARE := 0.85
const PAPER_TOP := 30.0
const PAPER_SIDE := 16.0
const PAPER_BOTTOM := 16.0
const STORIES_GAP := 8.0
const GAP := 16.0
const HEADER_PADDING := 3.0
const SMALL_SIZE := 16
const SMALL_LINE := 18.4
const MASTHEAD_SIZES := Vector2(28.0, 44.0)
const MASTHEAD_SHARE := 0.035
const MASTHEAD_LINE := 1.1
const BANNER_SIZES := Vector2(24.0, 44.0)
const BANNER_SHARE := 0.038
const BANNER_LINE := 1.03
const BANNER_TOP := 5.0
const BANNER_BOTTOM := 8.0
const CLOSE_SIZE := Vector2(30.0, 28.0)
const CLOSE_MARGIN := Vector2(5.0, 3.0)
const CLOSE_FONT_SIZE := 24

# the share of a column that each of two stories receives
const SPLIT_LIMITS := Vector2(0.4, 0.72)
const PHOTO_SHARE := 0.42
const PHOTO_MAX_HEIGHT := 190.0
const OPINION_MIN_HEIGHT := 140.0
const OPINION_SHARE := 0.27
const LEFT_SHARE_LIMIT := 0.48
const LEFT_MIN_BELOW := 80.0
const WEATHER_SHARE := 0.36
const CHRONICLE_COLUMNS := 5
const CHRONICLE_LEAD_SHARE := 0.29
const CHRONICLE_PHOTO_SHARE := 0.32
const CHRONICLE_LEFT_SHARE := 0.66
# the smallest picture margin that can hold a story beside the picture
const MIN_BESIDE_PHOTO := 120.0
const EXTRA_ONE_COLUMN_HEIGHT := 120.0
const RULE_TOLERANCE := 2.0
const DEFAULT_EXTRA_PAGE := 2

const SPIN_SECONDS := 0.75
# CSS cubic-bezier(0.16, 0.75, 0.28, 1) on each step of the entrance spin
const SPIN_EASE := [Vector2(0.16, 0.75), Vector2(0.28, 1.0)]
const SPIN_FADE_END := 0.12
# full turns before the paper settles
const SPIN_TURNS := 6
# progress, scale, rotation in degrees
const SPIN_KEYS := [
	Vector3(0.0, 0.03, -360.0 * SPIN_TURNS), Vector3(0.76, 1.08, 12.0), Vector3(0.9, 0.98, -4.0), Vector3(1.0, 1.0, 0.0),
]

const ARTICLE_COUNT := 5

var content: NewspaperContent
var paper_index := 0
var edition := "herald"
var diagnostics: Dictionary = {}
var articles: Array[NewspaperStory] = []
var weather: NewspaperStory
var opinion: NewspaperStory
var extra_stories: Array[NewspaperStory] = []
var photo: TextureRect
var close_button: Button
var stories_rect := Rect2()
var rules: Array[Rect2] = []

var _masthead: TextParagraph
var _price: TextParagraph
var _date: TextParagraph
var _banner: TextParagraph
var _masthead_line := 0.0
var _banner_line := 0.0
var _header_top := 0.0
var _header_height := 0.0
var _banner_top := 0.0
var _banner_height := 0.0
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	close_button = Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Close newspaper"
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_override("font", NewspaperFonts.interface())
	close_button.add_theme_font_size_override("font_size", CLOSE_FONT_SIZE)

	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		close_button.add_theme_color_override(color_name, INK)

	var hover := StyleBoxFlat.new()
	hover.bg_color = CLOSE_HOVER
	close_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	close_button.add_theme_stylebox_override("hover", hover)
	close_button.add_theme_stylebox_override("pressed", hover)
	close_button.pressed.connect(close_pressed.emit)
	add_child(close_button)
	resized.connect(layout)


# the paper size in the area of the game window
static func shell_size(area: Vector2) -> Vector2:
	return Vector2(minf(MAX_WIDTH, area.x * AREA_SHARE), area.y * AREA_SHARE)


func show_content(value: NewspaperContent, index: int) -> void:
	content = value
	paper_index = index
	edition = "chronicle" if posmod(index, 3) == 1 else "herald"
	_clear_stories()

	for slot in ARTICLE_COUNT:
		var headline := content.headline_for_slot(slot)
		var article := content.articles[slot] if slot < content.articles.size() else ""
		var page := content.continuation_pages[slot] if slot < content.continuation_pages.size() else DEFAULT_EXTRA_PAGE
		# the banner shows the lead headline
		var heading := "" if slot == 0 else headline
		articles.append(_add_story("", heading, article, tr("... (continued on pg %d)") % page, headline, article))

	weather = _add_report(content.weather_heading, tr("Weather"), content.weather_headline, content.weather_article,
		tr("Turn to pg %d for the full forecast") % content.weather_page)
	opinion = _add_report(content.opinion_heading, tr("Opinion"), content.opinion_headline, content.opinion_article,
		tr("Turn to pg %d for the full column") % content.opinion_page)

	if content.shows_picture():
		photo = TextureRect.new()
		photo.texture = grayscale(content.picture_texture)
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		photo.mouse_filter = Control.MOUSE_FILTER_STOP
		photo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		photo.focus_mode = Control.FOCUS_ALL
		photo.tooltip_text = content.headline_for_slot(0)
		photo.gui_input.connect(_on_photo_input)
		add_child(photo)

	move_child(close_button, -1)
	layout()


func layout() -> void:
	pivot_offset = size / 2.0
	close_button.position = Vector2(size.x - CLOSE_MARGIN.x - CLOSE_SIZE.x, CLOSE_MARGIN.y)
	close_button.size = CLOSE_SIZE

	if content == null or size.x <= 0.0 or size.y <= 0.0:
		return

	var inner := size.x - PAPER_SIDE * 2.0
	var masthead_size := int(clampf(inner * MASTHEAD_SHARE, MASTHEAD_SIZES.x, MASTHEAD_SIZES.y))
	var banner_size := int(clampf(inner * BANNER_SHARE, BANNER_SIZES.x, BANNER_SIZES.y))
	_masthead_line = masthead_size * MASTHEAD_LINE
	_banner_line = banner_size * BANNER_LINE
	_masthead = NewspaperStory.paragraph(content.title_text, NewspaperFonts.masthead(paper_index), masthead_size,
		inner / 2.0, HORIZONTAL_ALIGNMENT_CENTER)
	_price = NewspaperStory.paragraph(content.price_text, NewspaperFonts.body(), SMALL_SIZE, inner / 4.0,
		HORIZONTAL_ALIGNMENT_LEFT)
	_date = NewspaperStory.paragraph(content.date_text, NewspaperFonts.body(), SMALL_SIZE, inner / 4.0,
		HORIZONTAL_ALIGNMENT_RIGHT)
	_banner = NewspaperStory.paragraph(content.headline_for_slot(0), NewspaperFonts.headline(), banner_size, inner,
		HORIZONTAL_ALIGNMENT_CENTER)

	_header_height = HEADER_PADDING * 2.0 + 1.0 + _header_content_height()
	_banner_height = BANNER_TOP + NewspaperStory.paragraph_height(_banner, _banner_line) + BANNER_BOTTOM

	if edition == "chronicle":
		_banner_height += 1.0
		_banner_top = PAPER_TOP
		_header_top = _banner_top + _banner_height
	else:
		_header_top = PAPER_TOP
		_banner_top = _header_top + _header_height

	var top := maxf(_header_top + _header_height, _banner_top + _banner_height) + STORIES_GAP
	stories_rect = Rect2(PAPER_SIDE, top, inner, maxf(0.0, size.y - PAPER_BOTTOM - top))
	_layout_stories()
	queue_redraw()


func play_opening() -> void:
	if _tween != null:
		_tween.kill()

	pivot_offset = size / 2.0
	apply_spin(0.0)
	_tween = create_tween()
	_tween.tween_method(apply_spin, 0.0, 1.0, SPIN_SECONDS)


func finish_opening() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null

	apply_spin(1.0)


func is_opening() -> bool:
	return _tween != null and _tween.is_running()


func apply_spin(progress: float) -> void:
	var state := spin_state(progress)
	scale = Vector2(state.x, state.x)
	rotation_degrees = state.y
	modulate.a = state.z


# scale, rotation in degrees and opacity at a point of the entrance spin
static func spin_state(progress: float) -> Vector3:
	var t := clampf(progress, 0.0, 1.0)
	var opacity := 1.0 if t >= SPIN_FADE_END else spin_ease(t / SPIN_FADE_END)

	for index in SPIN_KEYS.size() - 1:
		var from: Vector3 = SPIN_KEYS[index]
		var to: Vector3 = SPIN_KEYS[index + 1]

		if t <= to.x:
			var eased := spin_ease((t - from.x) / (to.x - from.x))

			return Vector3(lerpf(from.y, to.y, eased), lerpf(from.z, to.z, eased), opacity)

	return Vector3(1.0, 0.0, 1.0)


static func spin_ease(t: float) -> float:
	var first: Vector2 = SPIN_EASE[0]
	var second: Vector2 = SPIN_EASE[1]
	var low := 0.0
	var high := 1.0

	# find the curve parameter for this time, then return the curve value
	for step in 24:
		var middle := (low + high) / 2.0

		if _bezier(first.x, second.x, middle) < t:
			low = middle
		else:
			high = middle

	return _bezier(first.y, second.y, (low + high) / 2.0)


static func _bezier(first: float, second: float, t: float) -> float:
	var rest := 1.0 - t

	return 3.0 * rest * rest * t * first + 3.0 * rest * t * t * second + t * t * t


# the picture in gray, as the original prints it
static func grayscale(texture: Texture2D) -> Texture2D:
	var image := texture.get_image().duplicate() as Image

	if image.is_compressed():
		image.decompress()

	image.convert(Image.FORMAT_RGBA8)

	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			var light := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			image.set_pixel(x, y, Color(light, light, light, color.a))

	return ImageTexture.create_from_image(image)


func all_stories() -> Array[NewspaperStory]:
	var result: Array[NewspaperStory] = []
	result.append_array(articles)

	if weather != null:
		result.append(weather)

	if opinion != null:
		result.append(opinion)

	result.append_array(extra_stories)

	return result


func _header_content_height() -> float:
	return maxf(NewspaperStory.paragraph_height(_masthead, _masthead_line),
		maxf(NewspaperStory.paragraph_height(_price, SMALL_LINE), NewspaperStory.paragraph_height(_date, SMALL_LINE)))


func _add_story(title: String, heading: String, copy: String, notice: String, read_title: String,
		read_text: String) -> NewspaperStory:
	var story := NewspaperStory.new()
	story.title_text = title
	story.heading_text = heading
	story.copy_text = copy
	story.notice_text = notice
	story.read_title = read_title
	story.read_text = read_text
	story.read_requested.connect(read_requested.emit)
	add_child(story)

	return story


func _add_report(title: String, fallback: String, headline: String, article: String, notice: String) -> NewspaperStory:
	var heading := fallback if title.is_empty() else title
	var report := _add_story(heading, headline, article, notice, heading if headline.is_empty() else headline, article)
	report.report = true

	return report


func _clear_stories() -> void:
	for story in all_stories():
		remove_child(story)
		story.queue_free()

	if photo != null:
		remove_child(photo)
		photo.queue_free()
		photo = null

	articles.clear()
	extra_stories.clear()
	weather = null
	opinion = null
	rules.clear()


func _word_count(text: String) -> int:
	var words := NewspaperStory.collapse_spaces(text)

	return 0 if words.is_empty() else words.count(" ") + 1


func _split(first: int, second: int) -> float:
	var total := first + second

	return clampf(float(first) / (total if total > 0 else 1), SPLIT_LIMITS.x, SPLIT_LIMITS.y)


func _layout_stories() -> void:
	for story in extra_stories:
		remove_child(story)
		story.queue_free()

	extra_stories.clear()
	var w := stories_rect.size.x
	var h := stories_rect.size.y
	var words: Array[int] = []

	for story in articles:
		words.append(_word_count(story.copy_text))

	var left_split := _split(words[1], words[4])
	var right_split := _split(words[2], words[3])
	var third := (w - GAP * 2.0) / 3.0
	var center := third + GAP
	var right := center * 2.0
	var photo_height := minf(h * PHOTO_SHARE, PHOTO_MAX_HEIGHT) if photo != null else 0.0
	var photo_gap := GAP if photo_height > 0.0 else 0.0
	var places: Array[Rect2] = []
	places.resize(ARTICLE_COUNT)
	places[0] = Rect2(center, photo_height + photo_gap, third, h - photo_height - photo_gap)
	var photo_place := Rect2(center, 0.0, third, photo_height)
	var opinion_height := maxf(OPINION_MIN_HEIGHT, h * OPINION_SHARE)
	var left_top := minf(h * minf(left_split, LEFT_SHARE_LIMIT), h - opinion_height - LEFT_MIN_BELOW)
	places[1] = Rect2(0.0, 0.0, third, left_top - GAP)
	var opinion_place := Rect2(0.0, left_top, third, opinion_height - GAP)
	places[4] = Rect2(0.0, left_top + opinion_height, third, h - left_top - opinion_height)
	var weather_height := h * WEATHER_SHARE
	var reports_top := weather_height + GAP
	var reports_height := h - reports_top
	var weather_place := Rect2(right, 0.0, third, weather_height)
	places[2] = Rect2(right, reports_top, third, reports_height * right_split - GAP / 2.0)
	places[3] = Rect2(right, reports_top + reports_height * right_split + GAP / 2.0, third,
		reports_height * (1.0 - right_split) - GAP / 2.0)

	if edition == "chronicle":
		var column := (w - GAP * (CHRONICLE_COLUMNS - 1)) / CHRONICLE_COLUMNS
		var step := column + GAP
		var lead := h * CHRONICLE_LEAD_SHARE
		var picture := h * CHRONICLE_PHOTO_SHARE if photo != null else 0.0
		var picture_gap := GAP if picture > 0.0 else 0.0
		places[1] = Rect2(0.0, 0.0, column, h * CHRONICLE_LEFT_SHARE - GAP)
		opinion_place = Rect2(0.0, h * CHRONICLE_LEFT_SHARE, column, h * (1.0 - CHRONICLE_LEFT_SHARE))
		places[0] = Rect2(step, 0.0, column * 3.0 + GAP * 2.0, lead)
		weather_place = Rect2(step * 4.0, 0.0, column, weather_height)
		photo_place = Rect2(step, lead + GAP, column * 2.0 + GAP, picture)
		places[4] = Rect2(step, lead + GAP + picture + picture_gap, column * 2.0 + GAP,
			h - lead - GAP - picture - picture_gap)
		places[2] = Rect2(step * 3.0, lead + GAP, column, h - lead - GAP)
		places[3] = Rect2(step * 4.0, reports_top, column, reports_height)

	var origin := stories_rect.position

	for slot in ARTICLE_COUNT:
		var story := articles[slot]
		story.columns = NewspaperStory.columns_for_width(places[slot].size.x)
		story.fit(Rect2(origin + places[slot].position, places[slot].size))

	weather.fit(Rect2(origin + weather_place.position, weather_place.size))
	opinion.fit(Rect2(origin + opinion_place.position, opinion_place.size))
	var spaces: Array[Rect2] = []

	if photo != null:
		var frame := Rect2(origin + photo_place.position, Vector2(maxf(1.0, photo_place.size.x), maxf(1.0, photo_place.size.y)))
		var natural := photo.texture.get_size()
		var image_width := minf(frame.size.x, frame.size.y * natural.x / natural.y)
		var spare := frame.size.x - image_width - GAP

		# put a story beside the picture when its frame is wider than the image
		if spare >= MIN_BESIDE_PHOTO:
			spaces.append(Rect2(frame.position, Vector2(spare, frame.size.y)))
			frame = Rect2(frame.position.x + spare + GAP, frame.position.y, image_width, frame.size.y)

		photo.position = frame.position
		photo.size = frame.size

	_fill_free_space(spaces)
	_find_rules()
	_record_diagnostics()


func _fill_free_space(spaces: Array[Rect2]) -> void:
	var panels: Array[NewspaperStory] = []
	panels.append_array(articles)
	panels.append_array([weather, opinion])

	for story in panels:
		var space := story.take_free_space(GAP)

		if space.has_area():
			spaces.append(space)

	spaces.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		return a.position.y < b.position.y or (a.position.y == b.position.y and a.position.x < b.position.x)
	)
	var candidates: Array[NewspaperContent.ExtraStory] = []
	candidates.append_array(content.extra_stories)

	for space in spaces:
		var available := space
		var skipped: Array[NewspaperContent.ExtraStory] = []

		while available.has_area() and not candidates.is_empty():
			var extra: NewspaperContent.ExtraStory = candidates.pop_front()
			var page := extra.page if extra.page > 0 else DEFAULT_EXTRA_PAGE
			var story := _add_story("", extra.headline, extra.article, tr("Turn to pg %d for the full story") % page,
				extra.headline, extra.article)
			story.columns = 1 if available.size.y < EXTRA_ONE_COLUMN_HEIGHT else NewspaperStory.columns_for_width(available.size.x)
			story.fit(available)

			if not story.shows_copy():
				remove_child(story)
				story.queue_free()
				skipped.append(extra)

				continue

			extra_stories.append(story)
			available = story.take_free_space(GAP)

		candidates.append_array(skipped)

	move_child(close_button, -1)


# a rule in the middle of each gap between two panels side by side
func _find_rules() -> void:
	rules.clear()
	var boxes: Array[Rect2] = []

	for story in all_stories():
		boxes.append(story.get_rect())

	if photo != null:
		boxes.append(photo.get_rect())

	for left in boxes:
		for right in boxes:
			var space := right.position.x - left.end.x
			var top := maxf(left.position.y, right.position.y)
			var bottom := minf(left.end.y, right.end.y)

			if absf(space - GAP) > RULE_TOLERANCE or bottom <= top:
				continue

			rules.append(Rect2(right.position.x - space / 2.0, top, 0.0, bottom - top))


func _record_diagnostics() -> void:
	var fits := true

	for story in all_stories():
		fits = fits and story.fits() and stories_rect.grow(0.5).encloses(story.get_rect())

	var continuations := 0

	for story in articles:
		if story.truncated:
			continuations += 1

	diagnostics = {
		"masthead_font": NewspaperFonts.masthead_name(paper_index),
		"edition": edition,
		"articles": articles.size(),
		"extra_stories": extra_stories.size(),
		"width": stories_rect.size.x,
		"height": stories_rect.size.y,
		"fits": fits,
		"continuations": continuations,
	}


func _draw() -> void:
	var shell := StyleBoxFlat.new()
	shell.bg_color = PAPER
	shell.border_color = BORDER
	shell.set_border_width_all(1)
	shell.shadow_color = SHADOW
	shell.shadow_size = SHADOW_SIZE
	shell.shadow_offset = SHADOW_OFFSET
	draw_style_box(shell, Rect2(Vector2.ZERO, size))

	if content == null or _masthead == null:
		return

	var canvas := get_canvas_item()
	var inner := stories_rect.size.x
	var header_bottom := _header_top + _header_height - 1.0
	var content_bottom := header_bottom - HEADER_PADDING
	# the price, masthead and date share the bottom of the header row
	var masthead_height := NewspaperStory.paragraph_height(_masthead, _masthead_line)
	NewspaperStory.draw_paragraph(canvas, _price,
		Vector2(PAPER_SIDE, content_bottom - NewspaperStory.paragraph_height(_price, SMALL_LINE)), SMALL_LINE, INK)
	NewspaperStory.draw_paragraph(canvas, _masthead, Vector2(PAPER_SIDE + inner / 4.0, content_bottom - masthead_height),
		_masthead_line, INK)
	NewspaperStory.draw_paragraph(canvas, _date,
		Vector2(PAPER_SIDE + inner * 0.75, content_bottom - NewspaperStory.paragraph_height(_date, SMALL_LINE)), SMALL_LINE, INK)
	_draw_rule(header_bottom, HEADER_RULE)
	NewspaperStory.draw_paragraph(canvas, _banner, Vector2(PAPER_SIDE, _banner_top + BANNER_TOP), _banner_line, INK)

	if edition == "chronicle":
		_draw_rule(_banner_top + _banner_height - 1.0, CHRONICLE_RULE)

	for rule in rules:
		var x := floorf(rule.position.x) + 0.5
		draw_line(Vector2(x, rule.position.y), Vector2(x, rule.end.y), NewspaperStory.RULE)


func _draw_rule(y: float, color: Color) -> void:
	var line := floorf(y) + 0.5
	draw_line(Vector2(PAPER_SIDE, line), Vector2(size.x - PAPER_SIDE, line), color)


func _on_photo_input(event: InputEvent) -> void:
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT

	if clicked or event.is_action_pressed("ui_accept"):
		photo.accept_event()
		read_requested.emit(content.headline_for_slot(0), articles[0].read_text)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel_pressed.emit()
