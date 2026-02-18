extends SceneTree

const Fixture = preload("res://tests/indexed_png_test.gd")
var folder := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	folder = "user://scurk-png-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("import.PNG")
	_write(path, Fixture.FIXTURE.hex_decode())
	var palette: Sc2Palette = IndexedPng.decode(Fixture.FIXTURE.hex_decode()).palette
	var imported := ScurkImageImport.load_path(path, palette)
	assert(imported.ok and imported.pixels == PackedInt32Array([-1, 1, 171, 172]))
	assert(imported.remapped_color_count == 0)
	# PNG transparency comes from tRNS; an opaque index zero stays opaque.
	var pixels := PackedInt32Array([0, -1, 171, 172])
	_write(path, IndexedPng.encode(4, 1, pixels, palette).bytes)
	assert(ScurkImageImport.load_path(path, palette).pixels == pixels)
	var target := Sc2Palette.index_encoding()
	var mapped := ScurkImageImport.load_path(path, target)
	assert(mapped.ok and mapped.remapped_color_count > 0 and mapped.pixels[1] == -1)
	_test_small_palettes()
	var assets := OriginalGameAssets.load_root(ProjectSettings.globalize_path("res://../references"))
	var editor := ScurkEditorControl.new()
	root.add_child(editor)
	editor.configure(assets.palette, assets.large_sprites, assets.small_medium_sprites, ProjectSettings.globalize_path("res://../references"), assets.scurk_graphics)
	assert(editor.load_path("res://../references/SCURKART/ORIGINAL.MIF").ok)
	assert(editor.import_bmp_dialog.filters[0].contains("*.PNG"))
	pixels.resize(32 * 8)
	for index in pixels.size():
		pixels[index] = 171 if index % 2 == 0 else 172
	_write(path, IndexedPng.encode(32, 8, pixels, assets.palette).bytes)
	var source_hash := FileAccess.get_sha256(path)
	for view in 3:
		editor.current_view = view
		editor._refresh_sprite()
		var before: PackedByteArray = editor.tile_set.to_bytes().bytes
		assert(editor.import_image_path(path).ok)
		var after: PackedByteArray = editor.tile_set.to_bytes().bytes
		assert(after != before and editor.dirty)
		assert(editor._active_output_shape().pixels.has(171))
		editor.undo()
		assert(editor.tile_set.to_bytes().bytes == before)
		editor.redo()
		assert(editor.tile_set.to_bytes().bytes == after)
		editor.undo()
	assert(FileAccess.get_sha256(path) == source_hash)
	var before_bad: PackedByteArray = editor.tile_set.to_bytes().bytes
	pixels.resize(129)
	pixels.fill(1)
	_write(path, IndexedPng.encode(129, 1, pixels, assets.palette).bytes)
	assert(not editor.import_image_path(path).ok)
	var rgb := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	rgb.fill(Color.RED)
	assert(rgb.save_png(path) == OK)
	assert(not editor.import_image_path(path).ok)
	assert(editor.tile_set.to_bytes().bytes == before_bad)
	editor.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)
	print("PASS: indexed PNG depths, transparency, duplicate indices, remapping, all SCURK views, exact Undo/Redo and invalid imports")
	quit()

func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

# Independent Python struct/zlib fixtures with two palette entries.
func _test_small_palettes() -> void:
	var bytes_1 := "89504e470d0a1a0a0000000d4948445200000004000000010103000000c3f29d8e00000006504c5445000000ffffffa5d99fdd0000000274524e53ff00e5b7304a0000000a49444154789c6308000000520051f721d9b70000000049454e44ae426082".hex_decode()
	assert(not IndexedPng.decode(bytes_1).ok)
	var decoded_1 := IndexedPng.decode(bytes_1, false)
	assert(decoded_1.ok and decoded_1.pixels == PackedInt32Array([0, -1, 0, -1]))
	var bytes_2 := "89504e470d0a1a0a0000000d49484452000000040000000102030000008452e75e00000006504c5445000000ffffffa5d99fdd0000000274524e53ff00e5b7304a0000000a49444154789c6310040000130012a60cbed50000000049454e44ae426082".hex_decode()
	assert(not IndexedPng.decode(bytes_2).ok)
	var decoded_2 := IndexedPng.decode(bytes_2, false)
	assert(decoded_2.ok and decoded_2.pixels == PackedInt32Array([0, -1, 0, -1]))
	var bytes_4 := "89504e470d0a1a0a0000000d49484452000000040000000104030000000b1212fe00000006504c5445000000ffffffa5d99fdd0000000274524e53ff00e5b7304a0000000b49444154789c6360640400000600033fb6ffa10000000049454e44ae426082".hex_decode()
	assert(not IndexedPng.decode(bytes_4).ok)
	var decoded_4 := IndexedPng.decode(bytes_4, false)
	assert(decoded_4.ok and decoded_4.pixels == PackedInt32Array([0, -1, 0, -1]))
	var bytes_8 := "89504e470d0a1a0a0000000d4948445200000004000000010803000000cee2ffff00000006504c5445000000ffffffa5d99fdd0000000274524e53ff00e5b7304a0000000d49444154789c63606064600400000900035d3991e40000000049454e44ae426082".hex_decode()
	assert(not IndexedPng.decode(bytes_8).ok)
	var decoded_8 := IndexedPng.decode(bytes_8, false)
	assert(decoded_8.ok and decoded_8.pixels == PackedInt32Array([0, -1, 0, -1]))
