class_name NewspaperDialog
extends AcceptDialog

const NewspaperPageView = preload("res://src/ui/newspaper_page.gd")
const NewsQueue = preload("res://src/simulation/news_queue.gd")
const NewspaperTextGenerator = preload("res://src/simulation/newspaper_text.gd")

const MONTH_NAMES := [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
]

var city: CityState
var document: Sc2File
var newspaper_data: DataUsaResource
var original_strings: Dictionary = {}
var news_names: Dictionary = {}
var session_seed := 0
var selected_newspaper := 0

var page: NewspaperPage
var paper_selector: OptionButton
var article_heading: Label
var article_view: TextEdit


func _ready() -> void:
	title = "Newspaper"
	min_size = Vector2i(700, 650)
	get_ok_button().text = "Close"
	get_label().visible = false
	var paper_selector_row := HBoxContainer.new()
	paper_selector_row.alignment = BoxContainer.ALIGNMENT_CENTER
	paper_selector_row.add_theme_constant_override("separation", 8)
	var paper_selector_label := Label.new()
	paper_selector_label.text = "PAPER"
	paper_selector_label.add_theme_color_override("font_color", Color("f0f0f0"))
	paper_selector_row.add_child(paper_selector_label)
	paper_selector = OptionButton.new()
	paper_selector.name = "NewspaperPaperSelector"
	paper_selector.custom_minimum_size = Vector2i(260, 28)
	paper_selector.item_selected.connect(_on_paper_selected)
	paper_selector_row.add_child(paper_selector)
	page = NewspaperPageView.new()
	page.name = "NewspaperPage"
	page.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.story_selected.connect(_on_story_selected)
	article_heading = Label.new()
	article_heading.text = "SELECTED ARTICLE"
	article_heading.add_theme_color_override("font_color", Color("f0f0f0"))
	article_view = TextEdit.new()
	article_view.name = "NewspaperArticle"
	article_view.custom_minimum_size = Vector2i(640, 140)
	article_view.editable = false
	article_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	article_view.add_theme_color_override("font_color", Color("101010"))
	article_view.add_theme_color_override("font_readonly_color", Color("101010"))
	article_view.add_theme_color_override("background_color", Color("fff9df"))
	var content := get_label().get_parent()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	layout.add_child(paper_selector_row)
	layout.add_child(page)
	layout.add_child(article_heading)
	layout.add_child(article_view)
	content.add_child(layout)
	content.move_child(layout, 0)


func open_reports(
	city_value: CityState,
	document_value: Sc2File,
	data_value: DataUsaResource,
	original_string_values: Dictionary,
	news_name_values: Dictionary,
	session_seed_value: int,
) -> void:
	city = city_value
	document = document_value
	newspaper_data = data_value
	original_strings = original_string_values
	news_names = news_name_values
	session_seed = session_seed_value
	_populate_page()
	popup_centered()


func _populate_page() -> void:
	article_heading.text = "SELECTED ARTICLE"
	article_view.text = "Select a headline on the newspaper page to read its article."
	paper_selector.clear()
	var misc_chunk := document.find_chunk("MISC")
	if misc_chunk == null or misc_chunk.decoded_payload.size() != NewsQueue.MISC_SIZE:
		paper_selector.add_item("Unavailable")
		paper_selector.disabled = true
		page.set_page(
			0,
			"NEWSPAPER",
			"",
			"",
			"Saved reports are unavailable.",
			"",
			PackedStringArray(),
		)
		title = "Newspaper"
		return
	var old_misc: PackedByteArray = misc_chunk.decoded_payload
	var misc := old_misc.duplicate()
	selected_newspaper = clampi(selected_newspaper, 0, NewsQueue.PAPER_COUNT - 1)
	for paper_index in NewsQueue.PAPER_COUNT:
		var selector_record := NewsQueue.paper_record(misc, paper_index)
		paper_selector.add_item(
			_paper_title(paper_index, selector_record), paper_index
		)
	paper_selector.disabled = false
	paper_selector.select(selected_newspaper)
	var paper := NewsQueue.paper_record(misc, selected_newspaper)
	var teams := _team_names()
	var headlines := PackedStringArray()
	for slot in NewspaperTextGenerator.PUBLISHED_SEED_OFFSETS.size():
		if slot == 5 or slot == 6:
			continue
		var record := NewsQueue.story_record(misc, slot)
		if record.is_empty():
			continue
		var story_type := int(record.type)
		var seed := NewspaperTextGenerator.published_seed(
			session_seed, city.age_in_days(), selected_newspaper, slot
		)
		var headline: String = news_names.get(story_type, "City report")
		if seed >= 0 and newspaper_data != null and newspaper_data.is_valid():
			var rendered := NewspaperTextGenerator.render_headline(
				newspaper_data,
				record,
				seed,
				city.city_name(),
				city.mayor_name(),
				teams,
			)
			if rendered.ok:
				headline = rendered.headline
				NewsQueue.update_story_substitutions(
					misc, slot, rendered.argument, rendered.auxiliary
				)
		if slot < 5:
			headlines.append(headline)
		elif slot == 7:
			paper["weather_headline"] = headline
		elif slot == 8:
			paper["opinion_headline"] = headline
	var paper_title := _paper_title(selected_newspaper, paper)
	page.set_page(
		clampi(int(paper.get("layout", 0)), 0, 2),
		paper_title,
		_date_text(),
		_price_text(paper),
		_opinion_text(paper),
		_weather_text(paper),
		headlines,
	)
	title = paper_title
	if misc != old_misc:
		misc_chunk.set_decoded_payload(misc)


func _on_paper_selected(paper_index: int) -> void:
	if city == null or document == null:
		return
	selected_newspaper = clampi(paper_index, 0, NewsQueue.PAPER_COUNT - 1)
	_populate_page()


func _on_story_selected(slot: int) -> void:
	if city == null or document == null or slot < 0 or slot >= 5:
		return
	article_heading.text = page.headline_for_slot(slot).to_upper()
	var seed := NewspaperTextGenerator.published_seed(
		session_seed, city.age_in_days(), selected_newspaper, slot
	)
	if newspaper_data == null or not newspaper_data.is_valid():
		article_view.text = "The local DATA_USA newspaper text is unavailable."
		return
	var misc_chunk := document.find_chunk("MISC")
	if misc_chunk == null or misc_chunk.decoded_payload.size() != NewsQueue.MISC_SIZE:
		article_view.text = "The saved newspaper record is unavailable."
		return
	var record := NewsQueue.story_record(misc_chunk.decoded_payload, slot)
	var rendered := NewspaperTextGenerator.render_story(
		newspaper_data,
		record,
		seed,
		city.city_name(),
		city.mayor_name(),
		_team_names(),
	)
	if not rendered.ok:
		article_view.text = "The article cannot be generated: %s" % rendered.error
		return
	article_view.text = rendered.article
	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var updated := NewsQueue.update_story_substitutions(
		misc, slot, rendered.argument, rendered.auxiliary
	)
	if updated.ok and misc != misc_chunk.decoded_payload:
		misc_chunk.set_decoded_payload(misc)


func _paper_title(paper_index: int, paper: Dictionary) -> String:
	var name_style := clampi(int(paper.get("name", 0)), 0, 5)
	var paper_name: String = original_strings.get(360 + name_style, "Newspaper")
	if paper_index < int(NewsQueue.PAPER_COUNT / 2):
		return "%s%s" % [original_strings.get(376, "The "), paper_name]
	var city_name := city.city_name() if not city.city_name().is_empty() else "City"
	return "%s %s" % [city_name, paper_name]


func _date_text() -> String:
	var month_index := clampi(city.current_month() - 1, 0, MONTH_NAMES.size() - 1)
	return "%s%s %d, %d" % [
		original_strings.get(375, "Sunday "),
		MONTH_NAMES[month_index],
		city.current_day(),
		city.current_year(),
	]


func _price_text(paper: Dictionary) -> String:
	var price_style := clampi(int(paper.get("price", 0)), 0, 2)
	var era := clampi(floori(float(city.current_year() - 1900) / 50.0), 0, 4)
	return original_strings.get(377 + price_style * 5 + era, "Price")


func _opinion_text(paper: Dictionary) -> String:
	var opinion_style := clampi(int(paper.get("opinion", 0)), 0, 5)
	var heading: String = original_strings.get(354 + opinion_style, "Opinion")
	var headline := str(paper.get("opinion_headline", ""))
	if headline.is_empty():
		return heading
	return "%s\n%s" % [heading, headline]


func _weather_text(paper: Dictionary) -> String:
	var weather_style := clampi(int(paper.get("weather", 0)), 0, 5)
	var heading: String = original_strings.get(347 + weather_style, "Weather")
	var headline := str(paper.get("weather_headline", ""))
	if headline.is_empty():
		return heading
	return "%s\n%s" % [heading, headline]


func _team_names() -> PackedStringArray:
	var result := PackedStringArray()
	if city == null:
		return result
	for label_id in range(251, 256):
		result.append(city.label(label_id))
	return result
