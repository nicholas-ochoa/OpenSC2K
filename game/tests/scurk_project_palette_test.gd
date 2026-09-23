extends SceneTree
## Project colors must survive a different configured asset palette.

const EditorScene = preload("res://src/ui/scurk/scurk_editor_control.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var first := _palette(0)
	var second := _palette(71)
	var third := _palette(139)
	assert(first.to_rgb_bytes().size() == Sc2Palette.RGB_BYTES)
	assert(Sc2Palette.from_rgb_bytes(first.to_rgb_bytes()).to_rgb_bytes() == first.to_rgb_bytes())
	assert(not Sc2Palette.from_rgb_bytes(first.to_rgb_bytes().slice(1)).is_valid())
	assert(not Sc2Palette.from_rgb_bytes(first.to_rgb_bytes() + PackedByteArray([0])).is_valid())
	var mif := ScurkMif.from_archives([])
	for view in ScurkSpriteIds.VIEW_COUNT:
		assert(mif.set_shape_indices(ScurkEditorRules.view_sprite_id(ScurkSpriteIds.LARGE_FIRST, view), 2, 1, PackedInt32Array([17, 23])).ok)
	var bytes := mif.to_bytes().bytes
	var editor := EditorScene.instantiate() as ScurkEditorControl
	root.add_child(editor)
	editor.configure(first, mif.archive, mif.archive, "")
	assert(editor.load_tile_set(mif).ok)
	await process_frame
	_check_palette(editor, first)
	assert(editor.session.project.palette_rgb == first.to_rgb_bytes())
	var path := "user://scurk-palette/actual.scurk"
	assert(editor.studio.save_project(path))

	editor.configure(second, mif.archive, mif.archive, "")
	assert(editor.studio.load_project(path))
	_check_palette(editor, first)
	assert(editor.configured_palette == second)
	assert(not editor.studio.modified and not editor.dirty)
	var loaded := ScurkProject.load_path(path)
	assert(loaded.ok and loaded.project.palette_rgb == first.to_rgb_bytes())

	# Reconfiguring assets does not recolor an embedded project.
	editor.configure(third, mif.archive, mif.archive, "")
	_check_palette(editor, first)
	var fresh := ScurkMif.new()
	assert(fresh.parse(bytes))
	assert(editor.load_tile_set(fresh).ok)
	_check_palette(editor, third)
	assert(editor.session.project.palette_rgb == third.to_rgb_bytes())

	# Version one has no RGB data. Its next save uses the configured colors.
	var legacy := {
		"version": 1, "revision": 0,
		"original_mif": Marshalls.raw_to_base64(bytes),
		"current_mif": Marshalls.raw_to_base64(bytes),
	}
	var legacy_path := "user://scurk-palette/legacy.scurk"
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string("SCURK-PROJECT\n" + JSON.stringify(legacy))
	file.close()
	assert(editor.studio.load_project(legacy_path))
	_check_palette(editor, third)
	assert(editor.studio.save_project("user://scurk-palette/converted.scurk"))
	assert(ScurkProject.load_path("user://scurk-palette/converted.scurk").project.palette_rgb == third.to_rgb_bytes())

	# Non-UI projects can retain an explicit index-only palette fallback.
	var index_only := ScurkProject.new()
	assert(index_only.initialize(bytes).ok)
	var index_path := "user://scurk-palette/indices.scurk"
	assert(index_only.save_path(index_path).ok)
	assert(ScurkProject.load_path(index_path).project.palette_rgb.is_empty())
	assert(editor.studio.load_project(index_path))
	_check_palette(editor, third)
	assert(editor.session.project.palette_rgb == third.to_rgb_bytes())

	var index_palette := Sc2Palette.index_encoding()
	editor.configure(index_palette, mif.archive, mif.archive, "")
	assert(editor.load_tile_set(fresh).ok)
	_check_palette(editor, index_palette)
	assert(editor.session.project.palette_rgb.is_empty())
	assert(editor.studio.save_project("user://scurk-palette/indices-again.scurk"))
	assert(ScurkProject.load_path("user://scurk-palette/indices-again.scurk").project.palette_rgb.is_empty())

	editor.free()
	await process_frame
	print("PASS: embedded project colors, asset palette isolation, legacy conversion and index fallback")
	quit()


func _palette(offset: int) -> Sc2Palette:
	var palette := Sc2Palette.new()
	for index in Sc2Palette.COLOR_COUNT:
		palette.colors.append(Color8((index + offset) % Sc2Palette.COLOR_COUNT, (255 - index + offset) % Sc2Palette.COLOR_COUNT, (index * 7 + offset) % Sc2Palette.COLOR_COUNT))
	palette.colors[23] = palette.colors[17]
	return palette


func _check_palette(editor: ScurkEditorControl, expected: Sc2Palette) -> void:
	var rgb := expected.to_rgb_bytes()
	assert(editor.palette.to_rgb_bytes() == rgb)
	assert(editor.pixel_canvas.palette.to_rgb_bytes() == rgb)
	assert(editor.palette_panel.palette.to_rgb_bytes() == rgb)
	assert(editor.palette_panel.palette_control.palette.to_rgb_bytes() == rgb)
	assert(editor.palette_panel.texture_control.palette.to_rgb_bytes() == rgb)
	assert(editor.pick_copy_control.palette.to_rgb_bytes() == rgb)
