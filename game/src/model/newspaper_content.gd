class_name NewspaperContent
extends RefCounted

var layout_index := 0
var title_text := ""
var date_text := ""
var price_text := ""
var opinion_text := ""
var weather_text := ""
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


func set_articles(values: PackedStringArray) -> void:
	articles = values.duplicate()


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

	return {"title": title_text, "headline": headline_for_slot(0), "date": date_text, "price": price_text, "weather": weather_text, "opinion": opinion_text, "headlines": headlines, "articles": articles, "pages": continuation_pages, "picture": picture, "papers": papers, "selected": selected}
