class_name NewspaperDialog
extends Window

@warning_ignore_start("integer_division")

# the headline of each story type when DATA_USA is missing
const STORY_NAMES := {
	46: CityStatusMessages.NEEDS[0],
	47: CityStatusMessages.NEEDS[1],
	48: CityStatusMessages.NEEDS[2],
	49: CityStatusMessages.NEEDS[3],
	50: CityStatusMessages.NEEDS[4],
	51: CityStatusMessages.NEEDS[5],
	52: CityStatusMessages.NEEDS[6],
	53: CityStatusMessages.NEEDS[7],
	54: CityStatusMessages.NEEDS[8],
	55: CityStatusMessages.NEEDS[9],
	56: CityStatusMessages.NEEDS[10],
	57: CityStatusMessages.NEEDS[11],
	58: CityStatusMessages.NEEDS[12],
	59: CityStatusMessages.NEEDS[13],
	60: CityStatusMessages.NEEDS[14],

	0: "Weather report",
	2: "City founded",
	22: "Fire",
	23: "Flood",
	24: "Plane crash",
	25: "Helicopter crash",
	26: "Tornado",
	27: "Earthquake",
	28: "Monster attack",
	29: "Nuclear meltdown",
	30: "Microwave disaster",
	31: "Volcano",
	32: "Pollution disaster",
	33: "Chemical spill",
	34: "Hurricane",
	35: "Riot",
	37: "Prison overcrowding",
	42: "Opinion column",
	43: "Editorial",
	44: "Public survey",
	45: "Advice column",

	1: "Local news",
	4: "New invention",
	5: "New innovation",
	6: "War report",
	7: "Market report",
	8: "Sports report",
	9: "Federal rate increase",
	10: "Federal rate decrease",
	0x0b: "Political report",
	0x0c: "Diplomatic report",
	0x0d: "Disaster report",
	0x0e: "Medical report",
	0x0f: "Upbeat report",
	0x10: "High crime",
	0x11: "High traffic",
	0x12: "High pollution",
	0x13: "Poor education",
	0x14: "Poor health",
	0x15: "Poor employment",
	3: "City milestone",
	0x24: "Power plant report",
	0x26: "Education report",
	39: "Bridge collapse",
	0x28: "Forest protest",
	0x29: "New ordinance",
	0x3d: "Low crime",
	0x3e: "Low traffic",
	0x3f: "Low pollution",
	0x40: "Good education",
	0x41: "Good health",
	0x42: "Good employment",
	0x1f8: "Explosion",
	0x1fe: "Traffic report",
	0x202: "Monster attack",
	0x203: "Air disaster",
	0x205: "Cargo ship report",
	0x206: "Airplane takeoff",
	0x207: "Airplane landing",
	0x20c: "Train report",
	0x20f: "Sailboat distress",
}
const NewspaperTextGenerator = preload("res://src/ui/shared/localized_newspaper_text.gd")
const MONTH_NAMES := [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
]
const WEATHER_HEADINGS: Array[String] = [
	"Weather Corner", "Weather Report", "Today's Weather", "Weather with Merle", "Weather Forecast",
	"Weather Talk",
]
const OPINION_HEADINGS: Array[String] = [
	"Fred's Opinion", "Editor's Corner", "Commentary", "Opinion Poll", "Survey", "MisSim's Advice",
]
const PAPER_NAMES: Array[String] = ["Picayune", "Courier", "Herald", "Journal", "Times", "Chronicle"]
const SUNDAY := "Sunday "
const THE := "The "
# one row per price style, one column per 50-year era from 1900
const PRICES := [
	["One Cent", "Five Cents", "Twenty-Five Cents", "One Dollar", "Five Dollars"],
	["A Single Penny", "Only A Nickel", "Still A Quarter", "Just A Dollar", "Merely Five Bucks"],
	["Price 1¢", "Price 5¢", "Price 25¢", "Price $1", "Price $5"],
]

var city: CityState
var document: Sc2File
var newspaper_data: DataUsaResource
var news_names: Dictionary = {}
var session_seed := 0
# the top complaint of the approval poll that opened the paper, or -1
var opinion_subject := -1
var selected_newspaper := 0
var published_articles := PackedStringArray()
var page := NewspaperContent.new()
var paper_titles := PackedStringArray()
var control_graphics: CityUiGraphics
var paper_view: NewspaperPage
var reader: NewspaperReader


func _init() -> void:
	title = "Newspaper"
	visible = false
	transient = true
	exclusive = true
	borderless = true
	unresizable = true
	transparent = true
	transparent_bg = true
	wrap_controls = false
	paper_view = NewspaperPage.new()
	add_child(paper_view)
	reader = NewspaperReader.new()
	add_child(reader)
	paper_view.close_pressed.connect(hide)
	paper_view.cancel_pressed.connect(_on_cancel)
	paper_view.read_requested.connect(reader.open)
	close_requested.connect(hide)
	visibility_changed.connect(func() -> void:
		if not visible:
			reader.hide()
			paper_view.finish_opening()
	)


func _ready() -> void:
	get_parent().get_viewport().size_changed.connect(_fit_to_window)


func set_control_graphics(graphics: CityUiGraphics) -> void:
	control_graphics = graphics
	_refresh_picture()


func open_reports(
	city_value: CityState,
	document_value: Sc2File,
	data_value: DataUsaResource,
	news_name_values: Dictionary,
	session_seed_value: int,
	paper_index: int = 0,
	opinion_subject_value := -1,
) -> void:
	city = city_value
	document = document_value
	newspaper_data = data_value
	news_names = news_name_values
	session_seed = session_seed_value
	opinion_subject = opinion_subject_value
	var count := NewsQueue.available_paper_count(city.city_status())

	if count == 0:
		return

	selected_newspaper = clampi(paper_index, 0, count - 1)
	_populate_page()
	reader.hide()
	popup(_window_area())
	_fit_to_window()
	paper_view.show_content(page, selected_newspaper)

	# headless runs show the finished page at once
	if DisplayServer.get_name() != "headless":
		paper_view.play_opening()


func _populate_page() -> void:
	paper_titles.clear()
	var misc_chunk := document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != NewsQueue.MISC_SIZE:
		paper_titles.append(tr("Unavailable"))
		page.set_page(
			0,
			tr("NEWSPAPER"),
			"",
			"",
			tr("Saved reports are unavailable."),
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
	paper_titles = newspaper_titles(city, document)
	selected_newspaper = clampi(selected_newspaper, 0, maxi(0, paper_titles.size() - 1))

	var paper := NewsQueue.paper_record(misc, selected_newspaper)
	var weather_headline := ""
	var weather_article := ""
	var opinion_headline := ""
	var opinion_article := ""

	if paper == null:
		paper = NewsQueue.PaperRecord.new()
	# the original polls the mayor approval when the paper opens and reports
	# the top complaint. a paper without a poll uses the largest weight
	var subject := opinion_subject

	if subject < 0:
		var weights := MayorApprovalPhase.complaint_weights(city)
		subject = 0

		for index in weights.size():
			if weights[index] > weights[subject]:
				subject = index

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
		var story_seed := NewspaperTextGenerator.published_seed(
			session_seed, city.age_in_days(), selected_newspaper, slot
		)
		var headline: String = news_names.get(story_type, tr("City report"))

		if story_seed >= 0 and NewspaperTextGenerator.has_data(newspaper_data):
			var rendered := NewspaperTextGenerator.render_headline(
				newspaper_data,
				record,
				story_seed,
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

			if NewspaperTextGenerator.has_data(newspaper_data):
				var article := NewspaperTextGenerator.render_story(
					newspaper_data,
					record,
					story_seed,
					city.display_name(),
					city.mayor_name(),
					teams,
				)

				if article.ok:
					report.article = article.article
			else:
				headline = report.headline

			headlines.append(headline)
			published_articles.append(str(report.article))
		elif slot == 7:
			weather_headline = headline
			var weather_name: String = RciAftermathPhase.WEATHER_NAMES[clampi(city.weather_type(), 0, 11)]
			weather_article = tr("Current weather: %s.") % tr(weather_name)

			if NewspaperTextGenerator.has_data(newspaper_data):
				var forecast := NewspaperTextGenerator.render_story(
					newspaper_data, record, story_seed, city.display_name(), city.mayor_name(), teams
				)

				if forecast.ok:
					weather_headline = forecast.headline
					weather_article = str(forecast.article).strip_edges()
		elif slot == 8:
			opinion_headline = headline
			var subjects := ["traffic", "pollution", "crime", "unemployment", "taxes", "education", "health"]
			opinion_article = tr("Residents are concerned about %s. The mayor can review current city conditions in the "
				+ "graphs and city maps.") % tr(subjects[subject])

			if NewspaperTextGenerator.has_data(newspaper_data):
				var opinion := NewspaperTextGenerator.render_story(
					newspaper_data, record, story_seed, city.display_name(), city.mayor_name(), teams
				)

				if opinion.ok:
					opinion_headline = opinion.headline
					opinion_article = str(opinion.article).strip_edges()

	var paper_title := _paper_title(city, selected_newspaper, paper)
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
		tr(OPINION_HEADINGS[clampi(int(paper.opinion), 0, 5)]),
		opinion_headline,
		opinion_article,
	)
	page.set_weather(
		tr(WEATHER_HEADINGS[clampi(int(paper.weather), 0, 5)]),
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

	if not NewspaperTextGenerator.has_data(newspaper_data):
		return stories

	# reading the newspaper mustn't spend the city's random numbers
	# remake-only filler uses private deterministic seeds and never updates misc
	var base_seed := session_seed + (city.age_in_days() / CityCalendar.DAYS_PER_MONTH) + selected_newspaper * 500
	var seen := { page.headline_for_slot(0): true }

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


static func newspaper_titles(city_value: CityState, document_value: Sc2File) -> PackedStringArray:
	var titles := PackedStringArray()

	if city_value == null or document_value == null:
		return titles

	var misc := document_value.find_chunk("MISC")

	if misc == null or misc.decoded_payload.size() != NewsQueue.MISC_SIZE:
		return titles

	for index in NewsQueue.available_paper_count(city_value.city_status()):
		titles.append(_paper_title(
			city_value, index, NewsQueue.paper_record(misc.decoded_payload, index)
		))

	return titles


static func _paper_title(
	city_value: CityState, paper_index: int, paper: NewsQueue.PaperRecord
) -> String:
	var paper_name := String(TranslationServer.translate(PAPER_NAMES[clampi(int(paper.name), 0, 5)]))

	if paper_index < int(NewsQueue.PAPER_COUNT / 2):
		return THE + paper_name

	var city_name := city_value.display_name()

	return "%s %s" % [city_name, paper_name]


func _date_text() -> String:
	var month_index := clampi(city.current_month() - 1, 0, MONTH_NAMES.size() - 1)

	return tr("{weekday}{month} {day}, {year}").format({
		"weekday": tr(SUNDAY), "month": tr(MONTH_NAMES[month_index]),
		"day": city.current_day(), "year": city.current_year(),
	})


func _price_text(paper: NewsQueue.PaperRecord) -> String:
	var price_style := clampi(int(paper.price), 0, 2)
	var era := clampi(floori(float(city.current_year() - 1900) / 50.0), 0, 4)

	return tr(PRICES[price_style][era])


func _opinion_text(paper: NewsQueue.PaperRecord, headline: String) -> String:
	var opinion_style := clampi(int(paper.opinion), 0, 5)
	var heading := tr(OPINION_HEADINGS[opinion_style])

	if headline.is_empty():
		return heading

	return "%s\n%s" % [heading, headline]


func _weather_text(paper: NewsQueue.PaperRecord, headline: String) -> String:
	var weather_style := clampi(int(paper.weather), 0, 5)
	var heading := tr(WEATHER_HEADINGS[weather_style])

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
		[
			tr("%s counts %d residents") % [name_text, city.population()],
			tr(
				"%s has a recorded population of %d. City services and transport must keep pace as "
				+ "new neighborhoods develop. Residents need connections to employment, electricity and "
				+ "water. This edition records conditions on %s."
			) % [name_text, city.population(), _date_text()],
		],
		[
			tr("Treasury reports $%d") % city.funds(),
			tr(
				"The city treasury holds $%d. Construction draws from this balance, while taxes and "
				+ "service spending affect the annual budget. The Budget window contains current "
				+ "funding levels and projected totals."
			) % city.funds(),
		],
		[
			tr("Development demand in focus"),
			tr(
				"Current demand readings are %d for homes, %d for commerce and %d for industry. "
				+ "Positive readings indicate room for growth. Tax rates, transport access and city "
				+ "conditions affect development. Zoned land still needs suitable services before it "
				+ "can grow."
			) % [demand.x, demand.y, demand.z],
		],
		[
			tr("Connections keep the city moving"),
			tr(
				"Roads, rail and subway routes connect neighborhoods with jobs. Gaps and disconnected "
				+ "stations can prevent trips. The City Map transport views show where the network is "
				+ "busy and where better connections may help."
			),
		],
		[
			tr("A closer look at city services"),
			tr(
				"Police, fire protection, schools and health services depend on facilities and their "
				+ "funding. The city maps show local coverage. The Budget window lets the mayor review "
				+ "service spending, while Query provides details for individual facilities."
			),
		],
	]
	var report: Array = reports[clampi(slot, 0, reports.size() - 1)]

	var result := NewspaperText.Result.new()
	result.ok = true
	result.headline = report[0]
	result.article = report[1]

	return result


# the newspaper covers the game window, and the paper sits in its center
func _window_area() -> Rect2i:
	var parent := get_parent()

	if parent == null:
		return Rect2i(position, size)

	return Rect2i(parent.get_viewport().get_visible_rect())


func _fit_to_window() -> void:
	if not visible:
		return

	var area := _window_area()
	position = area.position
	size = area.size
	var shell := NewspaperPage.shell_size(Vector2(area.size))
	paper_view.size = shell
	paper_view.position = ((Vector2(area.size) - shell) / 2.0).round()


func _on_cancel() -> void:
	if reader.visible:
		reader.hide()
	else:
		hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible and city != null:
		_populate_page()
		paper_view.show_content(page, selected_newspaper)
