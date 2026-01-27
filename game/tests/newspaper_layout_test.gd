extends SceneTree
func _initialize() -> void:
	var page := NewspaperContent.new()
	for layout in 3:
		page.set_page(layout, "City Journal", "Date", "Price", "Opinion", "Weather", ["One", "Two", "Three", "Four", "Five"])
		page.set_articles(["A", "B", "C", "D", "E"])
		var payload := page.payload(["City Journal"], 0)
		assert(payload.articles.size() == 5 and payload.headlines.size() == 5)
		assert(payload.pages.size() == 5)
		for number in payload.pages:
			assert(number >= 2 and number <= 30)
	var html := FileAccess.get_file_as_string("res://assets/newspaper/newspaper.html")
	assert(not html.contains('id="dimensions"') and not html.contains('Godot view'))
	assert(html.contains("user-select:none") and html.contains("cursor:default"))
	print("PASS: HTML newspaper content and interaction contract")
	quit()
