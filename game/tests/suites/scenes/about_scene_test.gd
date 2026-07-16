extends "res://tests/support/scene_case.gd"


func run() -> void:
	var scene := preload("res://src/ui/settings/about_dialog.tscn")
	var dialog := scene.instantiate() as AboutDialog
	var second := scene.instantiate() as AboutDialog
	root.add_child(dialog)
	root.add_child(second)
	assert(dialog.artwork != second.artwork)
	assert(dialog.exclusive)
	dialog.set_assets(null)
	assert(not dialog.artwork.available)
	assert(dialog.get_node("Content/Tabs/About/Scene/MissingArtwork").visible)
	assert(not dialog.license_documents.is_empty())
	for document in dialog.license_documents:
		assert(not document.is_empty())
	var missing_credits: String = dialog.license_documents[dialog.original_credits_index]
	var assets := OriginalGameAssets.new()
	assets.load_original_credits(ProjectSettings.globalize_path("res://../references/SIMCITY2000"))
	assets.load_city_graphics(ProjectSettings.globalize_path("res://../references/SIMCITY2000"))
	var entry := assets.large_sprites.find_sprite(1490)
	var before: PackedInt32Array = entry.decode_indices().pixels
	dialog.license_picker.select(dialog.original_credits_index)
	dialog.set_assets(assets)
	var credit_text := assets.original_credits.replace("\r\n", "\n").strip_edges()
	assert(dialog.license_text.text.ends_with(credit_text))
	assert(dialog.license_text.text == dialog.license_documents[dialog.original_credits_index])
	assert(second.license_documents[second.original_credits_index] == missing_credits)
	assert(dialog.artwork.available)
	dialog.artwork.set_active(true)
	assert(dialog.artwork.is_processing())
	var animation_time := dialog.artwork.animation_time
	dialog.artwork._process(0.2)
	assert(dialog.artwork.animation_time > animation_time)
	dialog.artwork.set_active(false)
	assert(not dialog.artwork.is_processing())
	assert(not second.artwork.available and second.artwork.textures.is_empty())
	assert(entry.decode_indices().pixels == before, "About dialog changed shared sprite data")
	for index in dialog.license_documents.size():
		dialog._select_license(index)
		assert(dialog.license_text.text == dialog.license_documents[index])
	for mode in ["light", "dark"]:
		dialog.theme = AppUiTheme.build(mode)
		for height in [480, 768]:
			root.size = Vector2i(1000, height)
			dialog.popup_centered()
			assert(dialog.artwork.animation_time == 0.0, "Opening About restarts the animation")
			await process_frame
			await process_frame
			assert(dialog.visible and dialog.artwork.is_processing())
			dialog.artwork._process(0.25)
			var paused_at := dialog.artwork.animation_time
			assert(paused_at > 0.0)
			dialog.get_node("Content/Tabs").current_tab = 1
			assert(not dialog.artwork.is_processing())
			dialog.get_node("Content/Tabs").current_tab = 0
			assert(
				dialog.artwork.is_processing() and dialog.artwork.animation_time == paused_at,
				"Returning to the About tab resumes the paused animation"
			)
			assert(dialog.size.y + dialog.get_theme_constant("title_height") <= height)
			dialog.get_ok_button().pressed.emit()
			assert(not dialog.visible)
	dialog.set_assets(null)
	assert(not dialog.artwork.available and dialog.artwork.textures.is_empty())
	assert(dialog.license_text.text == missing_credits)
	assert(not dialog.license_documents.is_empty())
	dialog.free()
	second.free()
	print("PASS: About asset loading, source preservation, notices, missing assets, themes, viewport limits and close")
