class_name NewspaperDialog
extends AcceptDialog

@warning_ignore_start("integer_division")

const NewsQueue = preload("res://src/simulation/reports/news_queue.gd")
const NewspaperTextGenerator = preload("res://src/simulation/reports/newspaper_text.gd")

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
		transparent_bg = true
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
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
	paper_index: int = 0,
) -> void:
	city = city_value
	document = document_value
	newspaper_data = data_value
	original_strings = original_string_values
	news_names = news_name_values
	session_seed = session_seed_value
	var count := NewsQueue.available_paper_count(city.city_status())

	if count == 0:
		return

	selected_newspaper = clampi(paper_index, 0, count - 1)
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
		page.set_weather("", "", "")
		page.set_opinion("", "", "")
		page.extra_stories.clear()
		title = "Newspaper"

		return

	var old_misc: PackedByteArray = misc_chunk.decoded_payload
	var misc := old_misc.duplicate()
	NewsQueue.prepare_weather_report(misc, city.weather_type())
	paper_titles = newspaper_titles(city, document, original_strings)
	selected_newspaper = clampi(selected_newspaper, 0, maxi(0, paper_titles.size() - 1))

	var paper := NewsQueue.paper_record(misc, selected_newspaper)
	var weather_headline := ""
	var weather_article := ""
	var opinion_headline := ""
	var opinion_article := ""

	if paper == null:
		paper = NewsQueue.PaperRecord.new()
	var weights := MayorApprovalPhase.complaint_weights(city)
	var subject := 0

	for index in weights.size():
		if weights[index] > weights[subject]:
			subject = index

	# use current survey weights without running a poll or changing simulation rng/xmic
	NewsQueue.prepare_opinion_report(misc, int(paper.opinion), subject)
	var teams := _team_names()
	var headlines := PackedStringArray()
	published_articles.clear()

	for slot in NewspaperTextGenerator.PUBLISHED_SEED_OFFSETS.size():
		if slot == 5 or slot == 6:
			continue

		var record := NewsQueue.story_record(misc, slot)

		if record == null:
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
				city.display_name(),
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
				var article := NewspaperTextGenerator.render_story(newspaper_data, record, seed, city.display_name(), city.mayor_name(), teams)

				if article.ok:
					report.article = article.article
			else:
				headline = report.headline

			headlines.append(headline)
			published_articles.append(str(report.article))
		elif slot == 7:
			weather_headline = headline
			var weather_name: String = RciAftermathPhase.WEATHER_NAMES[clampi(city.weather_type(), 0, 11)]
			weather_article = "Current weather: %s." % weather_name

			if newspaper_data != null and newspaper_data.is_valid():
				var forecast := NewspaperTextGenerator.render_story(
					newspaper_data, record, seed, city.display_name(), city.mayor_name(), teams
				)

				if forecast.ok:
					weather_headline = forecast.headline
					weather_article = str(forecast.article).strip_edges()
		elif slot == 8:
			opinion_headline = headline
			var subjects := ["traffic", "pollution", "crime", "unemployment", "taxes", "education", "health"]
			opinion_article = "Residents are concerned about %s. The mayor can review current city conditions in the graphs and city maps." % subjects[subject]

			if newspaper_data != null and newspaper_data.is_valid():
				var opinion := NewspaperTextGenerator.render_story(
					newspaper_data, record, seed, city.display_name(), city.mayor_name(), teams
				)

				if opinion.ok:
					opinion_headline = opinion.headline
					opinion_article = str(opinion.article).strip_edges()

	var paper_title := _paper_title(city, original_strings, selected_newspaper, paper)
	page.set_page(
		clampi(int(paper.layout), 0, 2),
		paper_title,
		_date_text(),
		_price_text(paper),
		_opinion_text(paper, opinion_headline),
		_weather_text(paper, weather_headline),
		headlines,
	)
	page.set_articles(published_articles)
	page.set_opinion(
		original_strings.get(354 + clampi(int(paper.opinion), 0, 5), "Opinion"),
		opinion_headline,
		opinion_article,
	)
	page.set_weather(
		original_strings.get(347 + clampi(int(paper.weather), 0, 5), "Weather"),
		weather_headline,
		weather_article,
	)
	page.extra_stories = _extra_stories(misc, teams)
	title = paper_title
	_refresh_picture()

	if misc != old_misc:
		misc_chunk.set_decoded_payload(misc)


func _extra_stories(misc: PackedByteArray, teams: PackedStringArray) -> Array[NewspaperContent.ExtraStory]:
	var stories: Array[NewspaperContent.ExtraStory] = []

	if newspaper_data == null or not newspaper_data.is_valid():
		return stories

	# reading the newspaper mustn't spend the city's random numbers
	# remake-only filler uses private deterministic seeds and never updates misc
	var base_seed := session_seed + (city.age_in_days() / 25) + selected_newspaper * 500
	var seen := {page.headline_for_slot(0): true}

	for headline in page.headlines:
		seen[headline] = true

	for index in 14:
		var record := NewsQueue.story_record(misc, index + 5) if index < 2 else NewsQueue.StoryRecord.new(
			1, 0, PackedByteArray([0xff, 0xff, 0xff])
		)
		var story := NewspaperTextGenerator.render_story(
			newspaper_data, record, base_seed + 77 + index * 7,
			city.display_name(), city.mayor_name(), teams,
		)

		if not story.ok or seen.has(story.headline) or str(story.article).strip_edges().is_empty():
			continue

		seen[story.headline] = true
		var extra := NewspaperContent.ExtraStory.new()
		extra.headline = story.headline
		extra.article = story.article.strip_edges()
		extra.page = posmod(base_seed + index * 7, 29) + 2
		stories.append(extra)

	return stories


func _refresh_picture() -> void:
	if page == null:
		return

	var resource_id := 0

	if city != null and document != null:
		var misc := document.find_chunk("MISC")

		if misc != null and misc.decoded_payload.size() == NewsQueue.MISC_SIZE:
			var story := NewsQueue.story_record(misc.decoded_payload, 0)

			if story != null:
				resource_id = NewspaperPicture.select(int(story.type), session_seed, city.age_in_days(), selected_newspaper)

	var image: Image = null if control_graphics == null else control_graphics.notices.get(resource_id)
	page.set_picture(resource_id, image)


static func newspaper_titles(
	city_value: CityState, document_value: Sc2File, strings: Dictionary
) -> PackedStringArray:
	var titles := PackedStringArray()

	if city_value == null or document_value == null:
		return titles

	var misc := document_value.find_chunk("MISC")

	if misc == null or misc.decoded_payload.size() != NewsQueue.MISC_SIZE:
		return titles

	for index in NewsQueue.available_paper_count(city_value.city_status()):
		titles.append(_paper_title(
			city_value, strings, index, NewsQueue.paper_record(misc.decoded_payload, index)
		))

	return titles


static func _paper_title(
	city_value: CityState, strings: Dictionary, paper_index: int, paper: NewsQueue.PaperRecord
) -> String:
	var name_style := clampi(int(paper.name), 0, 5)
	var paper_name: String = strings.get(360 + name_style, ["Gazette", "Herald", "Chronicle", "Times", "Journal", "Dispatch"][name_style])

	if paper_index < int(NewsQueue.PAPER_COUNT / 2):
		return "%s%s" % [strings.get(376, "The "), paper_name]

	var city_name := city_value.display_name()

	return "%s %s" % [city_name, paper_name]


func _date_text() -> String:
	var month_index := clampi(city.current_month() - 1, 0, MONTH_NAMES.size() - 1)

	return "%s%s %d, %d" % [
		original_strings.get(375, "Sunday "),
		MONTH_NAMES[month_index],
		city.current_day(),
		city.current_year(),
	]


func _price_text(paper: NewsQueue.PaperRecord) -> String:
	var price_style := clampi(int(paper.price), 0, 2)
	var era := clampi(floori(float(city.current_year() - 1900) / 50.0), 0, 4)

	return original_strings.get(377 + price_style * 5 + era, "25 cents")


func _opinion_text(paper: NewsQueue.PaperRecord, headline: String) -> String:
	var opinion_style := clampi(int(paper.opinion), 0, 5)
	var heading: String = original_strings.get(354 + opinion_style, "Opinion")

	if headline.is_empty():
		return heading

	return "%s\n%s" % [heading, headline]


func _weather_text(paper: NewsQueue.PaperRecord, headline: String) -> String:
	var weather_style := clampi(int(paper.weather), 0, 5)
	var heading: String = original_strings.get(347 + weather_style, "Weather")

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


func _local_report(slot: int) -> NewspaperText.Result:
	var name_text := city.display_name()
	var demand := city.rci_demand()
	var reports := [
		["%s counts %d residents" % [name_text, city.population()], "%s has a recorded population of %d. City services and transport must keep pace as new neighborhoods develop. Residents need connections to employment, electricity and water. This edition records conditions on %s." % [name_text, city.population(), _date_text()]],
		["Treasury reports $%d" % city.funds(), "The city treasury holds $%d. Construction draws from this balance, while taxes and service spending affect the annual budget. The Budget window contains current funding levels and projected totals." % city.funds()],
		["Development demand in focus", "Current demand readings are %d for homes, %d for commerce and %d for industry. Positive readings indicate room for growth. Tax rates, transport access and city conditions affect development. Zoned land still needs suitable services before it can grow." % [demand.x, demand.y, demand.z]],
		["Connections keep the city moving", "Roads, rail and subway routes connect neighborhoods with jobs. Gaps and disconnected stations can prevent trips. The City Map transport views show where the network is busy and where better connections may help."],
		["A closer look at city services", "Police, fire protection, schools and health services depend on facilities and their funding. The city maps show local coverage. The Budget window lets the mayor review service spending, while Query provides details for individual facilities."]
	]
	var report: Array = reports[clampi(slot, 0, reports.size() - 1)]

	var result := NewspaperText.Result.new()
	result.ok = true
	result.headline = report[0]
	result.article = report[1]

	return result


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
