extends SceneTree
## Silent standalone review. Pass -- dark to inspect the dark theme.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(2000, 1440)
	root.content_scale_size = Vector2i(1000, 720)
	root.title = "OpenSC2K About review"
	root.theme = AppUiTheme.build("dark" if "dark" in OS.get_cmdline_user_args() else "light")
	var dialog := preload("res://src/ui/settings/about_dialog.tscn").instantiate() as AboutDialog
	root.add_child(dialog)
	var assets := OriginalGameAssets.new()
	assets.load_original_credits(ProjectSettings.globalize_path("res://../references/SIMCITY2000"))
	assets.load_city_graphics(ProjectSettings.globalize_path("res://../references/SIMCITY2000"))
	dialog.set_assets(assets)
	dialog.confirmed.connect(quit)
	dialog.canceled.connect(quit)
	dialog.popup_centered()
	if "credits" in OS.get_cmdline_user_args():
		dialog.get_node("Content/Tabs").current_tab = 1
		dialog.license_picker.select(dialog.original_credits_index)
		dialog._select_license(dialog.original_credits_index)
	if "beam" in OS.get_cmdline_user_args():
		dialog.artwork.animation_time = 4.8
		dialog.artwork.set_process(false)
		dialog.artwork.queue_redraw()
