class_name NewspaperContent
extends RefCounted

var layout_index := 0
var title_text := ""
var date_text := ""
var price_text := ""
var opinion_text := ""
var opinion_heading := ""
var opinion_headline := ""
var opinion_article := ""
var weather_text := ""
var weather_heading := ""
var weather_headline := ""
var weather_article := ""
var weather_page := 2
var opinion_page := 3
var extra_stories: Array[Dictionary] = []
var headlines := PackedStringArray()
var articles := PackedStringArray()
var continuation_pages: Array[int] = []
var picture_id := 0
var picture_texture: Texture2D
var continuation_random := RandomNumberGenerator.new()


func set_page(layout: int, title: String, date: String, price: String, opinion: String, weather: String, headings: PackedStringArray) -> void:
	layout_index = clampi(layout, 0, 2)
	title_text = title
	date_text = date
	price_text = price
	opinion_text = opinion
	weather_text = weather
	headlines = headings.duplicate()
	continuation_pages.clear()

	for slot in 5:
		continuation_pages.append(continuation_random.randi_range(2, 30))

	weather_page = continuation_random.randi_range(2, 30)
	opinion_page = continuation_random.randi_range(2, 30)


func set_articles(values: PackedStringArray) -> void:
	articles = values.duplicate()


func set_opinion(heading: String, headline: String, article: String) -> void:
	opinion_heading = heading
	opinion_headline = headline
	opinion_article = article


func set_weather(heading: String, headline: String, article: String) -> void:
	weather_heading = heading
	weather_headline = headline
	weather_article = article


func set_picture(id: int, image: Image) -> void:
	picture_id = id
	picture_texture = ImageTexture.create_from_image(image) if image != null else null


func shows_picture() -> bool:
	return picture_texture != null


func headline_for_slot(slot: int) -> String:
	return headlines[slot] if slot >= 0 and slot < headlines.size() else ""


func payload(papers: PackedStringArray, selected: int) -> Dictionary:
	var picture := ""

	if picture_texture != null:
		picture = "data:image/png;base64," + Marshalls.raw_to_base64(picture_texture.get_image().save_png_to_buffer())

	return {"title": title_text, "headline": headline_for_slot(0), "date": date_text, "price": price_text, "weather": weather_text, "weather_heading": weather_heading, "weather_headline": weather_headline, "weather_article": weather_article, "weather_page": weather_page, "opinion_page": opinion_page, "extra_stories": extra_stories, "opinion": opinion_text, "opinion_heading": opinion_heading, "opinion_headline": opinion_headline, "opinion_article": opinion_article, "headlines": headlines, "articles": articles, "pages": continuation_pages, "picture": picture, "papers": papers, "selected": selected}
