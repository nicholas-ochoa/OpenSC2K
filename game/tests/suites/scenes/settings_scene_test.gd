extends "res://tests/support/scene_case.gd"

const SettingsScene = preload("res://src/ui/settings/app_settings_dialog.tscn")
var import_requests := 0


func run() -> void:
	var first := SettingsScene.instantiate() as AppSettingsDialog
	var second := SettingsScene.instantiate() as AppSettingsDialog
	root.add_child(first)
	root.add_child(second)
	first.default_mayor_edit.text = "Alice"
	first.music_slider.value = 75
	first.effects_slider.value = 25
	first.fullscreen_check.button_pressed = true
	var values := first.selected_values()
	assert(values.music_volume == 0.75 and values.effects_volume == 0.25 and values.fullscreen)
	assert(second.default_mayor_edit.text.is_empty())
	assert(second.music_slider.value == 0)
	first.set_loaded_pack("graphics", "Example", "/tmp/example")
	first.folder_edit.text = "/tmp/example/pack.json"
	first.folder_edit.text_changed.emit(first.folder_edit.text)
	assert(first.pack_name_labels.graphics.text == "Example")
	assert(second.pack_name_labels.graphics.text.is_empty())
	first.zoom_graphics_selectors[0].select(2)
	first.zoom_graphics_selectors[0].item_selected.emit(2)
	assert(first.selected_values().zoom_graphics == [2, 2, 2, 2, 2, 2])
	assert(second.zoom_graphics_selectors[0].selected == 0)
	first.import_original_requested.connect(func() -> void:
		import_requests += 1)
	first.show_values(0.25, 0.75, false)
	assert(first.visible)
	first.get_node("%ImportButton").pressed.emit()
	assert(import_requests == 1 and not first.visible)
	first.get_node("%GraphicsBrowse").pressed.emit()
	assert(first.folder_dialog.visible)
	first.folder_dialog.hide()
	first.free()
	second.free()
	await process_frame
	print("PASS: Settings independent instances, and signal bindings")
