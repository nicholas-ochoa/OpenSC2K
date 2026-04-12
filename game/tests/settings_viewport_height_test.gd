extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.gui_embed_subwindows = true
	viewport.size = Vector2i(1000, 900)
	root.add_child(viewport)
	var dialog := (load("res://src/ui/settings/app_settings_dialog.tscn") as PackedScene).instantiate() as AppSettingsDialog
	viewport.add_child(dialog)
	for selected in ["light", "dark"]:
		AppUiTheme.select(selected)
		for height in [900, 480, 600, 768]:
			viewport.size = Vector2i(1000, height)
			dialog.popup_centered()
			for tab in dialog.tabs.get_tab_count():
				dialog.tabs.current_tab = tab
				await process_frame
				await process_frame
				_check_height(dialog, height)
				assert(dialog.tabs.get_child(tab) is ScrollContainer)
			dialog.show_pack_error("A long pack error message.\n".repeat(80))
			await process_frame
			await process_frame
			_check_height(dialog, height)
			var scroll := dialog.tabs.get_child(1) as ScrollContainer
			assert(scroll.get_v_scroll_bar().visible, "Long error text has no scrollbar")
			dialog.show_compatibility_error("A long compatibility message.\n".repeat(80))
			await process_frame
			await process_frame
			_check_height(dialog, height)
			dialog.pack_error_label.hide()
			dialog.compatibility_error_label.hide()
	viewport.queue_free()
	await process_frame
	AppUiTheme.select("light")
	print("PASS: Settings stays within 90% viewport height across themes, tabs, resize and long errors")
	quit()


func _check_height(dialog: AppSettingsDialog, height: int) -> void:
	assert(dialog.size.y + dialog.get_theme_constant("title_height") <= int(height * 0.9),
		"Dialog including title bar must fit within 90% of the viewport")
	assert(dialog.get_ok_button().get_global_rect().end.y <= dialog.size.y,
		"Save Changes must remain inside the dialog")
	assert(dialog.get_cancel_button().get_global_rect().end.y <= dialog.size.y,
		"Cancel must remain inside the dialog")
