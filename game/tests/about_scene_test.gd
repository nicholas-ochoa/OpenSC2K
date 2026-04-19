extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := preload("res://src/ui/settings/about_dialog.tscn")
	var dialog := scene.instantiate() as AboutDialog
	var second := scene.instantiate() as AboutDialog
	root.add_child(dialog)
	root.add_child(second)
	assert(dialog.artwork.owner == dialog)
	assert(dialog.artwork != second.artwork)
	assert(dialog.title == "About OpenSC2K" and dialog.exclusive)
	dialog.set_assets(null)
	assert(not dialog.artwork.available)
	assert(dialog.get_node("Content/Tabs/About/Scene/MissingArtwork").visible)
	assert(dialog.project_text.text.contains("MIT license"))
	assert(dialog.project_text.text.contains("Electronic Arts"))
	assert(dialog.project_text.text.contains("sc2kfix"))
	assert(dialog.license_documents.size() == 9)
	for document in dialog.license_documents:
		assert(document.length() > 100)
	assert(dialog.license_documents[6].contains("MPL-2.0"))
	assert(dialog.license_documents[7].contains("CC BY-SA 4.0"))
	assert(dialog.license_documents[dialog.original_credits_index].contains("not contributions to OpenSC2K"))
	assert(dialog.license_documents[dialog.original_credits_index].contains("credits are unavailable"))
	var main_menu := preload("res://src/ui/startup/main_menu_control.tscn").instantiate()
	for part in ["Open", "SC2K"]:
		var menu_label: Label = main_menu.get_node("Center/Panel/Content/GameTitle/" + part)
		var about_label: Label = dialog.get_node("Content/GameTitle/" + part)
		var about_font := about_label.get_theme_font("font")
		if about_font is FontVariation:
			about_font = about_font.base_font
		assert(menu_label.get_theme_font("font") == about_font)
		assert(menu_label.get_theme_font_size("font_size") == about_label.get_theme_font_size("font_size"))
	main_menu.free()

	var assets := OriginalGameAssets.new()
	assets.load_original_credits(ProjectSettings.globalize_path("res://../references/SIMCITY2000"))
	assert(assets.original_credits.sha256_text() == "be75e74b6b557a65148733935569a4a109fe7ee14ccea7bd51f220ad3e9f96fc")
	assets.load_city_graphics(ProjectSettings.globalize_path("res://../references/SIMCITY2000"))
	var entry := assets.large_sprites.find_sprite(1490)
	var before: PackedInt32Array = entry.decode_indices().pixels
	dialog.license_picker.select(dialog.original_credits_index)
	dialog.set_assets(assets)
	var credit_text := assets.original_credits.replace("\r\n", "\n").strip_edges()
	assert(dialog.license_text.text.ends_with(credit_text))
	assert(dialog.license_text.text == dialog.license_documents[dialog.original_credits_index])
	assert(second.license_documents[second.original_credits_index].contains("credits are unavailable"))
	assert(dialog.artwork.available)
	dialog.artwork.set_active(true)
	dialog.artwork.animation_time = 0.0
	assert(dialog.artwork.drop_offset() == -260.0)
	var first_fire := dialog.artwork.fire_frame(0)
	dialog.artwork._process(0.2)
	assert(dialog.artwork.fire_frame(0) != first_fire)
	dialog.artwork.animation_time = 1.5
	assert(dialog.artwork.drop_offset() == -260.0)
	assert(not dialog.artwork.beam_active())
	assert(dialog.artwork.visible_fire_count() == 0)
	dialog.artwork.animation_time = 2.0
	assert(dialog.artwork.drop_offset() > -260.0 and dialog.artwork.drop_offset() < 0.0)
	dialog.artwork.animation_time = 3.9
	assert(is_zero_approx(dialog.artwork.drop_offset()))
	dialog.artwork.animation_time = 4.8
	assert(dialog.artwork.beam_active() and dialog.artwork.eye_open())
	assert(dialog.artwork.visible_fire_count() == 0)
	for stage in 3:
		dialog.artwork.animation_time = 5.2 + float(stage) * 0.8
		assert(dialog.artwork.visible_fire_count() == stage + 1)
	for step in 400:
		dialog.artwork.animation_time = float(step) * 0.05
		assert(not dialog.artwork.beam_active() or dialog.artwork.eye_open())
	dialog.artwork.animation_time = 6.0
	assert(not dialog.artwork.beam_active())
	dialog.artwork.set_active(false)
	assert(not dialog.artwork.is_processing())
	assert(not second.artwork.available and second.artwork.textures.is_empty())
	assert(entry.decode_indices().pixels == before, "About dialog changed shared sprite data")
	assert(dialog.artwork.textures[Vector2i(1385, 0)].get_size() == Vector2(32, 91))
	assert(dialog.artwork.textures[Vector2i(1208, 0)].get_size() == Vector2(96, 77))
	for mode in ["light", "dark"]:
		dialog.theme = AppUiTheme.build(mode)
		assert(dialog.project_text.get_theme_color("default_color") == dialog.theme.get_color("font_color", "Label"))
		for height in [480, 768]:
			root.size = Vector2i(1000, height)
			dialog.popup_centered()
			await process_frame
			await process_frame
			assert(dialog.visible and dialog.artwork.is_processing())
			dialog.get_node("Content/Tabs").current_tab = 1
			assert(not dialog.artwork.is_processing())
			dialog.get_node("Content/Tabs").current_tab = 0
			assert(dialog.artwork.animation_time == 0.0)
			assert(dialog.size.y + dialog.get_theme_constant("title_height") <= height * 0.9 + 1)
			for index in dialog.license_documents.size():
				dialog._select_license(index)
				assert(dialog.license_text.text == dialog.license_documents[index])
			dialog.get_ok_button().pressed.emit()
			assert(not dialog.visible)
	dialog.set_assets(null)
	assert(not dialog.artwork.available and dialog.artwork.textures.is_empty())
	assert(dialog.license_text.text.contains("credits are unavailable"))
	assert(dialog.license_documents.size() == 9)
	dialog.free()
	second.free()
	print("PASS: About native sprite composition, source preservation, typography, notices, missing assets, themes, viewport limits and close")
	quit()
