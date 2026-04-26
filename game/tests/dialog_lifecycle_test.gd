extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main)
	root.add_child(main)
	await process_frame
	assert(main.scurk_editor == null and main.scurk_place_print == null and main.scurk_print == null)
	assert(main.main_overlays.scurk_workspace == null)
	for scene_name in ["scurk_editor_control", "scurk_place_print_control", "scurk_print_control"]:
		assert(not ResourceLoader.has_cached("res://src/ui/scurk/%s.tscn" % scene_name), "Unexpected cached scene: " + scene_name)
	main._open_new_city_dialog()
	assert(main.new_city_dialog.visible)
	assert(main.main_overlays.scurk_workspace == null)
	main.new_city_dialog.hide()
	main._ensure_scurk_place_print()
	assert(main.scurk_editor == null and main.scurk_print == null)
	assert(main.scurk_city_export_dialog.get_parent() == main.scurk_place_print)
	main._ensure_scurk_print()
	assert(main.scurk_print.get_parent() == main.scurk_place_print)
	assert(main.scurk_print_pdf_dialog.get_parent() == main.scurk_print)
	main._ensure_scurk_editor()
	var editor: ScurkEditorControl = main.scurk_editor
	assert(editor.get_parent() == main.main_overlays.scurk_workspace)
	assert(not editor.visible and not main.scurk_place_print.visible and not main.scurk_print.visible)
	main._ensure_scurk_editor()
	assert(main.scurk_editor == editor)
	main.queue_free()
	await process_frame
	print("PASS: New City excludes SCURK; lazy windows own their prompts and are reused")
	quit()
