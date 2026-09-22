extends SceneTree

const Project = preload("res://src/tools/scurk/scurk_project.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mif := ScurkMif.from_archives([])
	assert(mif.set_shape_indices(1, 2, 2, PackedInt32Array([1, 2, -1, 255])).ok)
	var original: PackedByteArray = mif.to_bytes().bytes
	var project := Project.new()
	assert(project.initialize(original).ok)
	assert(not project.initialize(PackedByteArray([1, 2, 3])).ok)
	assert(project.original_mif == original)
	var pixels := PackedInt32Array([0, 1, -1, 255])
	assert(project.ensure_document("1:0", pixels, 2, 2))
	assert(project.documents["1:0"].layers[0].name == "Root")
	pixels[0] = 9
	assert(project.active_pixels("1:0")[0] == 0)
	assert(project.ensure_document("1:0", pixels, 2, 2))
	assert(project.active_pixels("1:0")[0] == 0)
	assert(not project.ensure_document("1:0", pixels, 4, 1))
	assert(not project.ensure_document("bad", pixels, 129, 1))
	assert(not project.ensure_document("bad", PackedInt32Array([256]), 1, 1))
	assert(project.add_layer("1:0", "Roof") == 1)
	assert(project.set_active_pixels("1:0", PackedInt32Array([-1, 42, 5, -1])))
	assert(project.flatten("1:0") == PackedInt32Array([0, 42, 5, 255]))
	assert(project.set_layer_visible("1:0", 1, false))
	assert(project.flatten("1:0") == PackedInt32Array([0, 1, -1, 255]))
	assert(project.set_layer_visible("1:0", 1, true))
	assert(project.set_layer_locked("1:0", 1, true))
	assert(project.active_layer_locked("1:0"))
	assert(not project.set_active_pixels("1:0", pixels))
	assert(not project.delete_layer("1:0", 1))
	assert(project.set_layer_locked("1:0", 1, false))
	assert(project.move_layer("1:0", 1, 0))
	assert(project.documents["1:0"].active == 0)
	assert(project.flatten("1:0") == PackedInt32Array([0, 1, 5, 255]))
	assert(project.rename_layer("1:0", 0, "Details"))
	assert(project.select_layer("1:0", 1))
	assert(not project.select_layer("1:0", 2))
	assert(project.delete_layer("1:0", 0))
	assert(project.documents["1:0"].active == 0)
	assert(not project.delete_layer("1:0", 0))
	assert(project.rename_layer("1:0", 0, "Artwork"))
	assert(project.documents["1:0"].original_pixels == PackedInt32Array([0, 1, -1, 255]))
	assert(project.add_stamp("Window", 2, 1, PackedInt32Array([252, -1]), 3) == 0)
	assert(project.add_stamp("Bad", 2, 1, PackedInt32Array([42]), 1) == -1)
	assert(project.add_stamp("Bad", 1, 1, PackedInt32Array([42]), 0) == -1)
	project.metadata = {"author": "Author", "license": "CC0", "custom": {"enabled": true, "items": [null, 4, "roof"]}}
	project.resources["reference.bin"] = PackedByteArray([0, 1, 252, 255])
	project.extra_fields["future_extension"] = {"tag": "preserve"}
	project.documents["1:0"].custom = ["keep"]
	project.documents["1:0"].layers[0].custom = {"keep": true}
	project.stamps[0].custom = "keep"
	assert(project.add_checkpoint("Original") == 0)
	var checkpoint := project.snapshot()
	assert(mif.set_name(1, "New name").ok)
	assert(project.set_current_mif(mif.to_bytes().bytes))
	assert(project.set_active_pixels("1:0", PackedInt32Array([11, 12, 13, 14])))
	project.metadata.author = "New author"
	project.resources["reference.bin"] = PackedByteArray([4])
	assert(project.remove_stamp(0))
	var changed_revision: int = project.revision
	assert(project.restore_checkpoint(0))
	assert(project.revision > changed_revision)
	assert(project.snapshot() == checkpoint)
	assert(project.original_mif == original)
	assert(project.add_checkpoint("Alternate") == 1)
	var encoded := project.to_bytes()
	assert(encoded.ok, encoded.error)
	var decoded := Project.from_bytes(encoded.bytes)
	assert(decoded.ok, decoded.error)
	assert(decoded.project.original_mif == original)
	assert(decoded.project.documents["1:0"].layers[0].name == "Artwork")
	assert(_same_state(decoded.project.snapshot(), project.snapshot()))
	assert(decoded.project.checkpoints.size() == project.checkpoints.size())
	for index in project.checkpoints.size():
		assert(decoded.project.checkpoints[index].name == project.checkpoints[index].name)
		assert(_same_state(decoded.project.checkpoints[index].snapshot, project.checkpoints[index].snapshot))
	assert(decoded.project.extra_fields == project.extra_fields)
	assert(Project.from_bytes(decoded.project.to_bytes().bytes).ok)
	assert(decoded.project.set_active_pixels("1:0", PackedInt32Array([8, 8, 8, 8])))
	assert(project.active_pixels("1:0") != decoded.project.active_pixels("1:0"))
	_test_composition(original)
	_test_limits(original)
	_test_invalid(encoded.bytes)
	_test_storage(project, encoded.bytes)
	print("PASS: SCURK project layers, stamps, history, metadata, round trip, invalid data and recovery")
	quit()


func _test_composition(original: PackedByteArray) -> void:
	var project := Project.new()
	assert(project.initialize(original).ok)
	var layers: Array[PackedInt32Array] = [
		PackedInt32Array([0, 1, -1, 255, 252, -1]),
		PackedInt32Array([-1, 42, 5, -1, -1, -1]),
		PackedInt32Array([171, -1, -1, 0, 255, -1]),
		PackedInt32Array([-1, -1, 252, -1, 42, -1]),
	]
	assert(project.ensure_document("1:0", layers[0], 3, 2))
	for index in range(1, layers.size()):
		assert(project.add_layer("1:0", "Layer") == index)
		assert(project.set_active_pixels("1:0", layers[index]))

	for visibility in 1 << layers.size():
		for index in layers.size():
			assert(project.set_layer_visible("1:0", index, (visibility & (1 << index)) != 0))
		var before := project.snapshot()
		var revision := project.revision
		var expected := _expected_composition(layers, visibility, 0, layers.size())
		var flattened := project.flatten("1:0")
		assert(flattened == expected)
		flattened[0] = 128
		assert(project.flatten("1:0") == expected)
		for first in layers.size() + 1:
			for last in range(first, layers.size() + 1):
				expected = _expected_composition(layers, visibility, first, last)
				var range_pixels := project.flatten_range("1:0", first, last)
				assert(range_pixels == expected)
				range_pixels[0] = 128
				assert(project.flatten_range("1:0", first, last) == expected)
		assert(project.snapshot() == before and project.revision == revision)

	assert(project.flatten("missing").is_empty())
	assert(project.flatten_range("missing", 0, 0).is_empty())
	for bounds in [Vector2i(-1, 2), Vector2i(0, -1), Vector2i(3, 2), Vector2i(0, 5), Vector2i(5, 5)]:
		assert(project.flatten_range("1:0", bounds.x, bounds.y).is_empty())


func _expected_composition(layers: Array[PackedInt32Array], visibility: int, first: int, last: int) -> PackedInt32Array:
	var expected := PackedInt32Array()
	for offset in layers[0].size():
		var color := -1
		for index in range(last - 1, first - 1, -1):
			if (visibility & (1 << index)) != 0 and layers[index][offset] >= 0:
				color = layers[index][offset]
				break
		expected.append(color)
	return expected


func _test_limits(original: PackedByteArray) -> void:
	var project := Project.new()
	assert(project.initialize(original).ok)
	assert(project.ensure_document("1:0", PackedInt32Array([-1]), 1, 1))
	for index in range(1, Project.MAX_LAYERS):
		assert(project.add_layer("1:0", "Layer") == index)
	assert(project.add_layer("1:0") == -1)
	assert(project.select_layer("1:0", 20))
	assert(project.move_layer("1:0", 20, 1))
	assert(project.documents["1:0"].active == 1)
	assert(project.move_layer("1:0", 0, 30))
	assert(project.documents["1:0"].active == 0)
	assert(project.move_layer("1:0", 30, 0))
	assert(project.documents["1:0"].active == 1)
	for index in Project.MAX_CHECKPOINTS + 1:
		assert(project.add_checkpoint("Version %d" % index) >= 0)
	assert(project.checkpoints.size() == Project.MAX_CHECKPOINTS)
	assert(project.checkpoints[0].name == "Version 1")
	assert(not project.restore_checkpoint(-1))
	assert(not project.restore_checkpoint(Project.MAX_CHECKPOINTS))
	assert(not project.restore_snapshot({"current_mif": PackedByteArray()}))
	assert(Project.from_bytes(project.to_bytes().bytes).ok)
	project.documents["1:0"].layers[0].pixels[0] = 65536
	assert(not project.to_bytes().ok)


func _test_invalid(valid: PackedByteArray) -> void:
	assert(not Project.from_bytes(PackedByteArray([0])).ok)
	assert(not Project.from_bytes(Project.MAGIC.to_utf8_buffer() + "[]".to_utf8_buffer()).ok)
	assert(not Project.from_bytes(Project.MAGIC.to_utf8_buffer() + "{".to_utf8_buffer()).ok)
	var source: Dictionary = JSON.parse_string(valid.slice(Project.MAGIC.length()).get_string_from_utf8())
	for version: Variant in [0, 2, 1.5, "1", null]:
		var bad := source.duplicate(true)
		bad.version = version
		assert(not Project.from_bytes(_record_bytes(bad)).ok)
	for dimensions in [Vector2(-1, 2), Vector2(0, 2), Vector2(129, 2), Vector2(2, 257), Vector2(1.5, 2)]:
		var bad := source.duplicate(true)
		bad.documents["1:0"].width = dimensions.x
		bad.documents["1:0"].height = dimensions.y
		assert(not Project.from_bytes(_record_bytes(bad)).ok)
	for index in [-2, 256, 32767]:
		var bad := source.duplicate(true)
		var bytes := Marshalls.base64_to_raw(bad.documents["1:0"].layers[0].pixels)
		bytes.encode_s16(0, index)
		bad.documents["1:0"].layers[0].pixels = Marshalls.raw_to_base64(bytes)
		assert(not Project.from_bytes(_record_bytes(bad)).ok)
	var bad := source.duplicate(true)
	bad.documents["1:0"].layers[0].pixels = "AA=="
	assert(not Project.from_bytes(_record_bytes(bad)).ok)
	bad = source.duplicate(true)
	bad.documents["1:0"].layers[0].visible = 1
	assert(not Project.from_bytes(_record_bytes(bad)).ok)
	bad = source.duplicate(true)
	bad.documents["1:0"].active = 3
	assert(not Project.from_bytes(_record_bytes(bad)).ok)
	bad = source.duplicate(true)
	bad.documents["1:0"].layers = []
	assert(not Project.from_bytes(_record_bytes(bad)).ok)
	bad = source.duplicate(true)
	bad.current_mif = ""
	assert(not Project.from_bytes(_record_bytes(bad)).ok)
	bad = source.duplicate(true)
	bad.original_mif = "AQID"
	assert(not Project.from_bytes(_record_bytes(bad)).ok)
	bad = source.duplicate(true)
	bad.stamps[0].spacing = 0
	assert(not Project.from_bytes(_record_bytes(bad)).ok)
	bad = source.duplicate(true)
	bad.checkpoints[0].snapshot.documents["1:0"].width = 0
	assert(not Project.from_bytes(_record_bytes(bad)).ok)
	bad = source.duplicate(true)
	bad.resources["reference.bin"] = "invalid!"
	assert(not Project.from_bytes(_record_bytes(bad)).ok)


func _test_storage(project: ScurkProject, original: PackedByteArray) -> void:
	var folder := "user://scurk-project-%d" % OS.get_process_id()
	var path := folder.path_join("project.scurk")
	var recovery := folder.path_join("recovery.scurk")
	assert(project.save_path(path).ok)
	assert(FileAccess.get_file_as_bytes(path) == original)
	assert(not project.save_path(folder.path_join("original.mif")).ok)
	assert(not FileAccess.file_exists(folder.path_join("original.mif")))
	assert(project.set_active_pixels("1:0", PackedInt32Array([2, 2, 2, 2])))
	assert(project.autosave_path(recovery).ok)
	assert(FileAccess.get_file_as_bytes(path) == original)
	var restored := Project.recover_path(recovery)
	assert(restored.ok and _same_state(restored.project.snapshot(), project.snapshot()))
	var output: PackedByteArray = project.to_bytes().bytes
	assert(project.save_path(path).ok)
	assert(FileAccess.get_file_as_bytes(path) == output)
	project.metadata.invalid = Vector2.ONE
	assert(not project.save_path(path).ok)
	assert(FileAccess.get_file_as_bytes(path) == output)
	project.metadata.erase("invalid")
	assert(DirAccess.get_files_at(folder).size() == 2)
	var partial := folder.path_join("recovery.scurk.partial.tmp")
	var file := FileAccess.open(partial, FileAccess.WRITE)
	file.store_string("partial")
	file.close()
	assert(Project.recover_path(recovery).ok)
	assert(not Project.recover_path(partial).ok)
	DirAccess.remove_absolute(partial)
	var blocked := folder.path_join("blocked.scurk")
	assert(DirAccess.make_dir_absolute(blocked) == OK)
	assert(not project.save_path(blocked).ok)
	assert(FileAccess.get_file_as_bytes(path) == output)
	assert(DirAccess.get_files_at(folder).size() == 2)
	DirAccess.remove_absolute(blocked)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(recovery)
	DirAccess.remove_absolute(folder)
	assert(not Project.load_path(path).ok)


func _record_bytes(record: Dictionary) -> PackedByteArray:
	return Project.MAGIC.to_utf8_buffer() + JSON.stringify(record).to_utf8_buffer()


func _same_state(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(Project._encode_snapshot(left))) == JSON.parse_string(JSON.stringify(Project._encode_snapshot(right)))
