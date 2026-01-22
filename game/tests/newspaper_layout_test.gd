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
		assert(page.article_labels[1].get_theme_font_size("font_size") == 12)
		if layout == 1:
			assert(page.extra_columns.size() == 4)
			assert(page.story_labels[0].position.y < page.title_label.position.y)
	page.free()
	print('PASS: three newspaper layouts, bounds, column flow and headline-first edition')
	quit()
