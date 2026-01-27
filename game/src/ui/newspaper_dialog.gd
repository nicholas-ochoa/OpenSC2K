class_name NewspaperDialog
extends AcceptDialog

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
var published_articles := PackedStringArray()

var page := NewspaperContent.new()
var paper_titles := PackedStringArray()
var control_graphics: CityUiGraphics
var web_paper: NewspaperWebView


func _ready() -> void:
	title = "Newspaper"
	exclusive = true
	borderless = true
	min_size = Vector2i.ONE
	size = Vector2i.ONE
	if NewspaperWebView.supported():
		get_ok_button().hide()
		get_label().hide()
	else:
		dialog_text = "The HTML newspaper requires the WebView extension."
		get_ok_button().text = "Close"
		min_size = Vector2i(400, 120)
	web_paper = NewspaperWebView.new()
	add_child(web_paper)
	web_paper.action_requested.connect(_on_web_action)
	visibility_changed.connect(func() -> void:
		if not visible:
			web_paper.close()
	)


func set_control_graphics(graphics: CityUiGraphics) -> void:
	control_graphics = graphics
	_refresh_picture()


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
	call_deferred("_open_web_newspaper")


func _populate_page() -> void:
	paper_titles.clear()
	var misc_chunk := document.find_chunk("MISC")
	if misc_chunk == null or misc_chunk.decoded_payload.size() != NewsQueue.MISC_SIZE:
		paper_titles.append("Unavailable")
		page.set_page(
			0,
			"NEWSPAPER",
			"",
			"",
			"Saved reports are unavailable.",
			"",
			PackedStringArray(),
		)
		page.set_picture(0, null)
		title = "Newspaper"
		return
	var old_misc: PackedByteArray = misc_chunk.decoded_payload
	var misc := old_misc.duplicate()
	selected_newspaper = clampi(selected_newspaper, 0, NewsQueue.PAPER_COUNT - 1)
	for paper_index in NewsQueue.PAPER_COUNT:
		var selector_record := NewsQueue.paper_record(misc, paper_index)
		paper_titles.append(_paper_title(paper_index, selector_record))
	var paper := NewsQueue.paper_record(misc, selected_newspaper)
	var teams := _team_names()
	var headlines := PackedStringArray()
	published_articles.clear()
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
			var report := _local_report(slot)
			if newspaper_data != null and newspaper_data.is_valid():
				var article := NewspaperTextGenerator.render_story(newspaper_data, record, seed, city.city_name(), city.mayor_name(), teams)
				if article.ok:
					report.article = article.article
			else:
				headline = report.headline
			headlines.append(headline)
			published_articles.append(str(report.article))
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
	page.set_articles(published_articles)
	title = paper_title
	_refresh_picture()
	if misc != old_misc:
		misc_chunk.set_decoded_payload(misc)


func _refresh_picture() -> void:
	if page == null:
		return
	var resource_id := 0
	if city != null and document != null:
		var misc := document.find_chunk("MISC")
		if misc != null and misc.decoded_payload.size() == NewsQueue.MISC_SIZE:
			var story := NewsQueue.story_record(misc.decoded_payload, 0)
			if not story.is_empty():
				resource_id = NewspaperPicture.select(int(story.type), session_seed, city.age_in_days(), selected_newspaper)
	var image: Image = null if control_graphics == null else control_graphics.notices.get(resource_id)
	page.set_picture(resource_id, image)


func _on_paper_selected(paper_index: int) -> void:
	if city == null or document == null:
		return
	selected_newspaper = clampi(paper_index, 0, NewsQueue.PAPER_COUNT - 1)
	_populate_page()


func _paper_title(paper_index: int, paper: Dictionary) -> String:
	var name_style := clampi(int(paper.get("name", 0)), 0, 5)
	var paper_name: String = original_strings.get(360 + name_style, ["Gazette", "Herald", "Chronicle", "Times", "Journal", "Dispatch"][name_style])
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
	return original_strings.get(377 + price_style * 5 + era, "25 cents")


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


func _local_report(slot: int) -> Dictionary:
	var name_text := city.city_name()
	var demand := city.rci_demand()
	var reports := [
		["%s counts %d residents" % [name_text, city.population()], "%s has a recorded population of %d. City services and transport must keep pace as new neighborhoods develop. Residents need connections to employment, electricity and water. This edition records conditions on %s." % [name_text, city.population(), _date_text()]],
		["Treasury reports $%d" % city.funds(), "The city treasury holds $%d. Construction draws from this balance, while taxes and service spending affect the annual budget. The Budget window contains current funding levels and projected totals." % city.funds()],
		["Development demand in focus", "Current demand readings are %d for homes, %d for commerce and %d for industry. Positive readings indicate room for growth. Tax rates, transport access and city conditions affect development. Zoned land still needs suitable services before it can grow." % [demand.x, demand.y, demand.z]],
		["Connections keep the city moving", "Roads, rail and subway routes connect neighborhoods with jobs. Gaps and disconnected stations can prevent trips. The City Map transport views show where the network is busy and where better connections may help."],
		["A closer look at city services", "Police, fire protection, schools and health services depend on facilities and their funding. The city maps show local coverage. The Budget window lets the mayor review service spending, while Query provides details for individual facilities."]
	]
	var report: Array = reports[clampi(slot, 0, reports.size() - 1)]
	return {"headline": report[0], "article": report[1]}


func _web_payload() -> Dictionary:
	page.set_articles(published_articles)
	return page.payload(paper_titles, selected_newspaper)


func _open_web_newspaper() -> void:
	if visible and web_paper != null:
		web_paper.open(_web_payload())


func _on_web_action(action: Dictionary) -> void:
	match str(action.get("action", "")):
		"close":
			hide()
		"paper":
			_on_paper_selected(clampi(int(action.get("index", 0)), 0, 5))
			_open_web_newspaper()
