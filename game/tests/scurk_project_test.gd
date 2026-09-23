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
	_test_dictionary(project)
	_test_invalid(project.to_dictionary())
	_test_model_boundaries(original)
	_test_restore_failure(project)
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


func _test_dictionary(project: ScurkProject) -> void:
	var source := project.to_dictionary()
	var expected := source.duplicate(true)
	var palette := Sc2Palette.index_encoding().to_rgb_bytes()
	var expected_palette := palette.duplicate()
	var decoded := Project.from_dictionary(source, palette)
	assert(decoded.ok, decoded.error)
	assert(decoded.project.to_dictionary() == expected)
	assert(decoded.project.palette_rgb == expected_palette)
	_mutate_record(source)
	palette[0] = 255
	assert(decoded.project.to_dictionary() == expected, "Loading must own its dictionaries and packed arrays")
	assert(decoded.project.palette_rgb == expected_palette)
	var exported := decoded.project.to_dictionary()
	_mutate_record(exported)
	assert(decoded.project.to_dictionary() == expected, "Exporting must not expose mutable model state")
	assert(project.to_dictionary() == expected)


func _mutate_record(record: Dictionary) -> void:
	record.original_mif[0] = 0
	record.current_mif[0] = 0
	record.documents["1:0"].original_pixels[0] = 9
	record.documents["1:0"].layers[0].pixels[0] = 9
	record.documents["1:0"].custom[0] = "changed"
	record.documents["1:0"].layers[0].custom.keep = false
	record.metadata.custom.items[2] = "changed"
	record.resources["reference.bin"][0] = 9
	record.stamps[0].pixels[0] = 9
	record.checkpoints[0].snapshot.documents["1:0"].layers[0].pixels[0] = 9
	record.checkpoints[0].snapshot.current_mif[0] = 0
	record.extra_field = "changed"
	record.future_extension.tag = "changed"


func _test_invalid(source: Dictionary) -> void:
	assert(Project.from_dictionary(source).ok)
	assert(not Project.from_bytes(PackedByteArray([0])).ok)
	for dimensions in [Vector2(-1, 2), Vector2(0, 2), Vector2(129, 2), Vector2(2, 257), Vector2(1.5, 2)]:
		var bad := source.duplicate(true)
		bad.documents["1:0"].width = dimensions.x
		bad.documents["1:0"].height = dimensions.y
		_reject_record(bad)
	for index in [-2, 256, 32767]:
		var bad := source.duplicate(true)
		bad.documents["1:0"].layers[0].pixels[0] = index
		_reject_record(bad)
	for pixels: Variant in [PackedInt32Array([0]), PackedByteArray([0, 1, 2, 3]), [0, 1, 2, 3], "pixels"]:
		var bad := source.duplicate(true)
		bad.documents["1:0"].layers[0].pixels = pixels
		_reject_record(bad)
	for revision: Variant in [-1, 1.5, "1", null]:
		var bad := source.duplicate(true)
		bad.revision = revision
		_reject_record(bad)
	for flag: String in ["visible", "locked"]:
		var bad := source.duplicate(true)
		bad.documents["1:0"].layers[0][flag] = 1
		_reject_record(bad)
	var bad := source.duplicate(true)
	bad.documents["1:0"].original_pixels = PackedInt32Array([0])
	_reject_record(bad)
	bad = source.duplicate(true)
	bad.documents["1:0"].active = 3
	_reject_record(bad)
	bad = source.duplicate(true)
	bad.documents["1:0"].layers = []
	_reject_record(bad)
	for field: String in ["current_mif", "original_mif"]:
		for bytes: Variant in [PackedByteArray(), PackedByteArray([1, 2, 3]), [1, 2, 3], "MIF"]:
			bad = source.duplicate(true)
			bad[field] = bytes
			_reject_record(bad)
	bad = source.duplicate(true)
	bad.stamps[0].spacing = 0
	_reject_record(bad)
	bad = source.duplicate(true)
	bad.stamps[0].pixels = PackedInt32Array([0])
	_reject_record(bad)
	bad = source.duplicate(true)
	bad.checkpoints[0].snapshot.documents["1:0"].width = 0
	_reject_record(bad)
	bad = source.duplicate(true)
	bad.checkpoints[0].revision = -1
	_reject_record(bad)
	bad = source.duplicate(true)
	bad.checkpoints[0].created = 1
	_reject_record(bad)
	for resource: Variant in ["invalid", [0, 1], PackedInt32Array([0, 1])]:
		bad = source.duplicate(true)
		bad.resources["reference.bin"] = resource
		_reject_record(bad)
	for owner: String in ["project", "metadata", "document", "layer", "stamp", "checkpoint"]:
		bad = source.duplicate(true)
		match owner:
			"project":
				bad.invalid = Vector2.ONE
			"metadata":
				bad.metadata.invalid = Vector2.ONE
			"document":
				bad.documents["1:0"].invalid = Vector2.ONE
			"layer":
				bad.documents["1:0"].layers[0].invalid = Vector2.ONE
			"stamp":
				bad.stamps[0].invalid = Vector2.ONE
			"checkpoint":
				bad.checkpoints[0].invalid = Vector2.ONE
		_reject_record(bad)
	for size in [1, Sc2Palette.RGB_BYTES - 1, Sc2Palette.RGB_BYTES + 1]:
		var palette := PackedByteArray()
		palette.resize(size)
		assert(not Project.from_dictionary(source, palette).ok)


func _small_record(original: PackedByteArray) -> Dictionary:
	var project := Project.new()
	assert(project.initialize(original).ok)
	assert(project.ensure_document("1:0", PackedInt32Array([0]), 1, 1))
	assert(project.add_stamp("Dot", 1, 1, PackedInt32Array([-1])) == 0)
	assert(project.add_checkpoint("Before") == 0)
	return project.to_dictionary()


func _test_model_boundaries(original: PackedByteArray) -> void:
	var source := _small_record(original)
	var full := source.duplicate(true)
	for index in range(1, Project.MAX_DOCUMENTS):
		full.documents[str(index)] = source.documents["1:0"]
	for index in Project.MAX_RESOURCES:
		full.resources[str(index)] = PackedByteArray()
	full.stamps.resize(Project.MAX_STAMPS)
	full.stamps.fill(source.stamps[0])
	full.checkpoints.resize(Project.MAX_CHECKPOINTS)
	full.checkpoints.fill(source.checkpoints[0])
	assert(Project.from_dictionary(full).ok)
	for field: String in ["documents", "resources", "stamps", "checkpoints"]:
		var bad := full.duplicate(true)
		match field:
			"documents":
				bad.documents.extra = source.documents["1:0"]
			"resources":
				bad.resources.extra = PackedByteArray()
			"stamps":
				bad.stamps.append(source.stamps[0])
			"checkpoints":
				bad.checkpoints.append(source.checkpoints[0])
		_reject_record(bad)
	for field: String in ["documents", "resources"]:
		var key_limit := 128 if field == "documents" else 256
		var value: Variant = source.documents["1:0"] if field == "documents" else PackedByteArray()
		var valid := source.duplicate(true)
		valid[field]["a".repeat(key_limit)] = value
		assert(Project.from_dictionary(valid).ok)
		for key: Variant in ["", "a".repeat(key_limit + 1), 1]:
			var bad := source.duplicate(true)
			bad[field][key] = value
			_reject_record(bad)
	for owner: String in ["layer", "stamp", "checkpoint"]:
		for name: String in ["a".repeat(256), "a".repeat(257), " "]:
			var record := source.duplicate(true)
			match owner:
				"layer":
					record.documents["1:0"].layers[0].name = name
				"stamp":
					record.stamps[0].name = name
				"checkpoint":
					record.checkpoints[0].name = name
			assert(Project.from_dictionary(record).ok == (name.length() == 256))
	for value: Variant in [NAN, INF, {0: "invalid key"}]:
		var bad := source.duplicate(true)
		bad.custom = value
		_reject_record(bad)
	for owner: String in ["project", "checkpoint"]:
		var nesting := 31 if owner == "project" else 29
		var record := source.duplicate(true)
		var target: Dictionary = record if owner == "project" else record.checkpoints[0]
		target.custom = _nested_json(nesting)
		assert(Project.from_dictionary(record).ok)
		target.custom = _nested_json(nesting + 1)
		_reject_record(record)
	_test_data_budget(source)


func _nested_json(levels: int) -> Variant:
	var value: Variant = true
	for level in levels:
		value = [value]
	return value


func _test_data_budget(source: Dictionary) -> void:
	# One original MIF, two snapshot MIFs and six signed 16-bit pixel values.
	var overhead: int = source.original_mif.size() * 3 + 6 * 2
	var block := PackedByteArray()
	block.resize(Project.MAX_MIF_BYTES)
	var tail := PackedByteArray()
	tail.resize(Project.MAX_DATA_BYTES - Project.MAX_MIF_BYTES * 3 - overhead)
	var record := source.duplicate(true)
	record.resources = {"first": block, "second": block}
	record.checkpoints[0].snapshot.resources = {"third": block, "tail": tail}
	assert(Project.from_dictionary(record).ok, "The aggregate logical byte limit is inclusive")
	tail.append(0)
	record.checkpoints[0].snapshot.resources.tail = tail
	var current := Project.new()
	assert(current.restore_snapshot({"current_mif": record.current_mif, "documents": record.documents,
		"metadata": record.metadata, "resources": record.resources, "stamps": record.stamps}),
		"The current snapshot alone is below the limit")
	var historical := Project.new()
	assert(historical.restore_snapshot(record.checkpoints[0].snapshot), "The checkpoint alone is below the limit")
	_reject_record(record)


func _test_restore_failure(project: ScurkProject) -> void:
	var restored := Project.from_dictionary(project.to_dictionary(), Sc2Palette.index_encoding().to_rgb_bytes())
	assert(restored.ok)
	var target: ScurkProject = restored.project
	var before := target.to_dictionary()
	var palette := target.palette_rgb.duplicate()
	for field: String in ["resource", "stamp", "unknown"]:
		var state := target.snapshot()
		state.metadata.author = "Must not be published"
		state.documents["1:0"].layers[0].pixels[0] = 99
		match field:
			"resource":
				state.resources.invalid = "not bytes"
			"stamp":
				state.stamps[0].spacing = 0
			"unknown":
				state.stamps[0].invalid = Vector2.ONE
		assert(not target.restore_snapshot(state))
		assert(target.to_dictionary() == before and target.palette_rgb == palette,
			"Rejected snapshots keep all document, history, metadata, palette and revision state")


func _reject_record(record: Dictionary) -> void:
	var result := Project.from_dictionary(record)
	assert(not result.ok and not result.error.is_empty() and result.project == null)


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


func _same_state(left: Dictionary, right: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))
