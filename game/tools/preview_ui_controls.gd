extends SceneTree
## Standalone style reference. Always launch with --audio-driver Dummy.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.title = "OpenSC2K - UI Control Gallery"
	root.mode = Window.MODE_WINDOWED
	var display_scale := maxf(DisplayServer.screen_get_scale(), 1.0)
	root.content_scale_size = Vector2i(1240, 720)
	root.size = Vector2i(Vector2(1240, 720) * display_scale)
	root.min_size = Vector2i(Vector2(1000, 600) * display_scale)
	var gallery := (load("res://tools/ui_gallery/ui_control_gallery.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	if "--smoke" in OS.get_cmdline_user_args():
		await process_frame
		for theme_index in 7:
			gallery.get_node("%ThemeSelector").select(theme_index)
			gallery.get_node("%ThemeSelector").item_selected.emit(theme_index)
			var tabs: TabContainer = gallery.get_node("%Tabs")
			assert(tabs.get_tab_count() == 9)
			for tab_index in tabs.get_tab_count():
				tabs.current_tab = tab_index
				await process_frame
		gallery.free()
		print("PASS: UI control gallery builds all nine pages with all seven preview themes")
		quit()
