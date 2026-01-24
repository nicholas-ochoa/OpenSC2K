extends SceneTree
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var page := NewspaperPage.new()
	root.add_child(page)
	for layout in range(3):
		var rects: Array = NewspaperPage.READING_LAYOUTS[layout]
		for a in rects.size():
			assert(Rect2i(Vector2i.ZERO, NewspaperPage.PRESENTATION_SIZE).encloses(rects[a]))
			for b in range(a+1,rects.size()):
				assert(not rects[a].intersects(rects[b]))
		page.set_page(layout,'New City Journal','Sunday 4 January 1900','One Cent','Survey\nTrouble Getting Around','Weather Report\nChilly Weather',['Crowd Celebrates New City Founding','New City Founded','Inhabitants Cannot Get Around','Brownouts Cost','More Power To Us'])
		page.set_articles(['The new city is ready. '.repeat(100),'Residents celebrate their new city. '.repeat(150),'The city needs transport. '.repeat(100),'More electricity is needed. '.repeat(100),'Power reaches more homes. '.repeat(100)])
		assert(not page.article_labels[1].text.is_empty())
		assert(page.article_labels[1].horizontal_alignment == HORIZONTAL_ALIGNMENT_FILL)
		assert(not page.article_labels[1].justification_flags & TextServer.JUSTIFICATION_DO_NOT_SKIP_SINGLE_LINE)
		assert(page.article_labels[1].get_theme_font_size("font_size") == 8)
		assert(page.article_labels[1].get_theme_constant("line_spacing") == -2)
		if layout == 1:
			assert(page.extra_columns.size() == 4)
			assert(page.weather_label.size.y < 50 and page.opinion_label.size.y < 50)
			assert(page.story_labels[0].position.y < page.title_label.position.y)
		var all_columns: Array[Label] = page.article_labels + page.extra_columns
		var notices := 0
		for column in all_columns:
			if column.text.contains("... (continued on pg "):
				notices += 1
				assert(page._body_text_height(column.text, column.size.x) <= column.size.y)
		assert(notices >= 4)
		for number in page.continuation_pages:
			assert(number >= 2 and number <= 30)
		page.set_articles(['Brief.', 'Brief.', 'Brief.', 'Brief.', 'Brief.'])
		if layout == 1:
			assert(page._reading_rects[7].size.y < 140)
			assert(page._reading_rects[3].position.y == page._reading_rects[7].end.y + 4)
		for column in page.article_labels + page.extra_columns:
			assert(not column.text.contains("continued on pg"))
	page.free()
	print('PASS: three newspaper layouts, bounds, column flow and headline-first edition')
	quit()
