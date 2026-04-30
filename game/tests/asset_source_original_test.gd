extends SceneTree
## This separate source-selection regression does read the local installation.


func _initialize() -> void:
	var reference := ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	var original := GameAssetSource.load_source(reference, "original", "", "res://../ext/graphics")
	assert(original.error.is_empty(), original.error)
	assert(original.use_original_data and original.uses_graphics_pack)
	assert(original.assets.newspaper_data.is_valid() and not original.assets.strings.is_empty())
	assert(not GameAssetSource.load_source(reference, "original", "", "/missing-pack").error.is_empty())
	var folder := "user://source-pack-test-%d" % OS.get_process_id()
	assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
	var png := FileAccess.open(folder.path_join("tile.png"), FileAccess.WRITE)
	png.store_buffer(preload("res://tests/indexed_png_test.gd").FIXTURE.hex_decode())
	png.close()
	var manifest := {"format": "opensc2k-graphics", "version": 1, "name": "External fixture",
		"palette": "tile.png", "scenario_palette": "tile.png", "ui": {},
		"large_sprites": [{"id": 1001, "png": "tile.png"}],
		"small_medium_sprites": [{"id": 1, "png": "tile.png"}]}

	for field in GraphicsPack.UI_FIELDS:
		manifest.ui[field] = "tile.png"

	var file := FileAccess.open(folder.path_join("pack.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()

	for mode in ["folder"]:
		var external := GameAssetSource.load_source(reference, mode, folder, folder if mode == "auto" else "")
		assert(external.error.is_empty(), external.error)
		assert(external.use_original_data and external.uses_graphics_pack)
		assert(external.assets.newspaper_data.is_valid())
		assert(external.assets.large_sprites.find_sprite(1001).decode_indices().pixels == PackedInt32Array([-1, 1, 171, 172]))

	for name in ["tile.png", "pack.json"]:
		assert(DirAccess.remove_absolute(folder.path_join(name)) == OK)

	assert(DirAccess.remove_absolute(folder) == OK)
	print("PASS: original source, external folder/override packs with original data, and invalid pack rejection")
	quit()
