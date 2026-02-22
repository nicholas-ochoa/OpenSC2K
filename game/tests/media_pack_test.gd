extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var base := ProjectSettings.globalize_path("res://../ext")
	if not FileAccess.file_exists(base.path_join("graphics/pack.json")):
		print("SKIP: export local examples with res://tools/export_original_packs.gd first")
		quit()
		return
	var original := OriginalGameAssets.load_root(ProjectSettings.globalize_path("res://../references/SIMCITY2000"))
	var graphics := GraphicsPack.load_root(base.path_join("graphics"))
	assert(graphics.error.is_empty(), graphics.error)
	for pair in [[graphics.large_sprites, original.large_sprites], [graphics.small_medium_sprites, original.small_medium_sprites]]:
		assert(pair[0].entries.size() == pair[1].entries.size())
		for index in pair[0].entries.size():
			var actual: Sc2SpriteArchive.SpriteEntry = pair[0].entries[index]
			var expected: Sc2SpriteArchive.SpriteEntry = pair[1].entries[index]
			assert(actual.sprite_id == expected.sprite_id and actual.width == expected.width and actual.height == expected.height)
			assert(actual.decode_indices().pixels == expected.decode_indices().pixels)
	for field in GraphicsPack.UI_FIELDS:
		var actual: Image = graphics.ui_images[field].duplicate()
		var expected: Image = original.get(field).duplicate()
		actual.convert(Image.FORMAT_RGBA8)
		expected.convert(Image.FORMAT_RGBA8)
		assert(actual.get_data() == expected.get_data(), field)
	var original_ui := original.city_ui_graphics
	assert(graphics.apply_to(original) and original.city_ui_graphics == original_ui)
	for kind in ["sound", "music"]:
		var pack := MediaPack.load_folder(base.path_join(kind), kind)
		assert(pack.error.is_empty(), pack.error)
		assert(MediaPack.load_folder(base.path_join(kind + "/pack.json"), kind).error.is_empty())
		assert(pack.files.size() == (30 if kind == "sound" else 19))
		for path in pack.files.values():
			assert(FileAccess.get_sha256(path) == FileAccess.get_sha256(ProjectSettings.globalize_path("res://../references/SIMCITY2000/SOUNDS").path_join(path.get_file())))
	var temporary := "user://media-pack-test-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temporary))
	var manifest := {"format": "opensc2k-sound", "version": 1, "name": "Test", "files": {}}
	_write_manifest(temporary, manifest)
	assert(MediaPack.load_folder(temporary, "sound").error.is_empty())
	for invalid in ["../505.WAV", "/505.WAV", "a\\505.WAV", "missing.wav", "a//b.wav"]:
		manifest.files = {"505": invalid}
		_write_manifest(temporary, manifest)
		assert(not MediaPack.load_folder(temporary, "sound").error.is_empty())
	manifest.files = {"499": "505.WAV"}
	_write_manifest(temporary, manifest)
	assert(not MediaPack.load_folder(temporary, "sound").error.is_empty())
	var audio := CityAudioController.new()
	root.add_child(audio)
	audio.setup("/missing", 0.5, 0.5, false)
	assert(audio.set_media_packs(base.path_join("sound"), base.path_join("music")))
	assert(audio.wave_stream_cache.size() == 30)
	assert(audio.play_music_track(10001))
	assert(not audio.set_media_packs(temporary, base.path_join("music")))
	assert(audio.wave_stream_cache.size() == 30 and audio.current_track_id == 10001)
	assert(audio.play_music_track(10000))
	var count := get_nodes_in_group(CityAudioController.SOUND_EFFECT_GROUP).size()
	audio.play_toolbar_click(true)
	audio.play_toolbar_click(true)
	assert(get_nodes_in_group(CityAudioController.SOUND_EFFECT_GROUP).size() == count + 2)
	audio.play_toolbar_click(false)
	assert(get_nodes_in_group(CityAudioController.SOUND_EFFECT_GROUP).size() == count + 2)
	var config := temporary.path_join("settings.cfg")
	assert(AppSettingsStore.load_values(config).toolbar_sounds)
	assert(AppSettingsStore.save_values(0.5, 0.5, false, config, "auto", "", null, null, null, null, false, base.path_join("sound"), base.path_join("music")) == OK)
	var values := AppSettingsStore.load_values(config)
	assert(not values.toolbar_sounds and values.sound_pack_folder == base.path_join("sound") and values.music_pack_folder == base.path_join("music"))
	var toolbar := CityToolbar.new(original.toolbar_art)
	root.add_child(toolbar)
	var clicks := [0]
	toolbar.button_clicked.connect(func() -> void: clicks[0] += 1)
	toolbar.toolbar_buttons[6].pressed.emit()
	toolbar.zoom_in_button.pressed.emit()
	toolbar.view_mode_buttons.underground.pressed.emit()
	toolbar.show_tool_group(6, null)
	(toolbar.child_tool_buttons[0] as Button).pressed.emit()
	assert(clicks[0] == 4)
	toolbar.free()
	audio.stop_sound_effects()
	await process_frame
	audio.free()
	for name in ["settings.cfg", "pack.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	await process_frame
	print("PASS: original pack pixel and byte equality, manifest validation, atomic audio replacement, rapid toolbar feedback, dynamic buttons, settings persistence")
	call_deferred("quit")

func _write_manifest(folder: String, value: Dictionary) -> void:
	var file := FileAccess.open(folder.path_join("pack.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
