extends SceneTree
## A loaded city restores the SCURK tile sets that its sc2kfix XFIX chunk lists.

const AppFixture = preload("res://tests/support/app_fixture.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate() as CityApplication
	AppFixture.configure(main)
	root.add_child(main)
	await process_frame
	assert(main.asset_state.assets_ready)
	var document := Sc2File.load_path(GeneratedCityFixture.path(128))
	var payload := '{"map":{"tilesets":["C:\\\\Games\\\\SC2K\\\\SCURKART\\\\BigBen.mif"]}}'.to_utf8_buffer()
	payload.append(0)
	var chunk := Sc2Chunk.new()
	chunk.chunk_id = "XFIX"
	chunk.decoded_payload = payload
	chunk.is_dirty = true
	document.chunks.append(chunk)
	document.rebuild_chunk_cache()
	var path := OS.get_user_data_dir().path_join("xfix_tile_set_city.sc2")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(document.serialize().data)
	file.close()

	main.city_files._load_city_unchecked(path)
	assert(main.document_state.city != null)
	assert(main.asset_state.active_scurk_name == "BIGBEN.MIF", main.asset_state.active_scurk_name)
	assert(main.asset_state.large_sprites != main.asset_state.base_large_sprites)
	assert(main.status_label.text.contains("Loaded 1 of 1 sc2kfix tile sets."), main.status_label.text)

	main.scurk_workspace.restore_original_tile_set()
	main.city_files._load_city_unchecked(GeneratedCityFixture.path(128))
	assert(main.asset_state.active_scurk_name.is_empty(), "A city without XFIX keeps the original tile set")
	DirAccess.remove_absolute(path)
	main.queue_free()
	await process_frame
	print("PASS: sc2kfix XFIX tile sets load with their city")
	quit()
