extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var newspaper := NewspaperDialog.new()
	root.add_child(newspaper)
	var literal := "<script>alert('city')</script> & \"Mayor\""
	newspaper.page.set_page(0, literal, "Date", "Price", "Opinion", "Weather", [literal, "Two", "Three", "Four", "Five"])
	newspaper.published_articles = [literal, "B", "C", "D", "E"]
	newspaper.paper_selector.add_item(literal)
	var payload := newspaper._web_payload()
	assert(JSON.parse_string(JSON.stringify(payload)).articles[0] == literal)
	assert(payload.title == literal)
	assert(payload.headlines.size() == 5)
	assert(payload.pages.all(func(number: int) -> bool: return number >= 2 and number <= 30))
	assert(payload.picture == "")
	newspaper.web_paper.open(payload)
	assert(newspaper.web_paper.view == null, "Headless checks must use the Godot fallback")
	newspaper.web_paper._on_message("not JSON")
	newspaper.web_paper._on_message('{"action":"metrics","articles":5}')
	assert(newspaper.web_paper.diagnostics.articles == 5)
	newspaper.web_paper.close()
	newspaper.free()
	print("PASS: newspaper payload, literal text, page numbers and headless fallback")
	quit()
