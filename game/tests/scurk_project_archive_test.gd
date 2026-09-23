extends SceneTree
## Generated project archive fixtures. No original game data is required.

const Project = preload("res://src/tools/scurk/scurk_project.gd")
const Zip = preload("res://src/tools/scurk/scurk_zip.gd")
const DOCUMENT_KEY := "../palette:雪"
const RESOURCE_KEY := "../reference/雪.bin"

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var project := _fixture()
	_test_index_encoding(project)
	var before: Variant = _project_state(project)
	var encoded := project.to_bytes()
	assert(encoded.ok, encoded.error)
	_check(encoded.bytes.slice(0, 4) == "504b0304".hex_decode(), "New projects use a ZIP container")
	_check(project.to_bytes().bytes == encoded.bytes, "Archive output is deterministic")
	_check(_project_state(project) == before, "Writing leaves the project unchanged")
	var unpacked := Zip.decode(encoded.bytes)
	assert(unpacked.ok, unpacked.error)
	var members: Dictionary[String, PackedByteArray] = unpacked.members
	var manifest := _manifest(members)
	_test_members(project, members, manifest)
	var restored := Project.from_bytes(encoded.bytes)
	assert(restored.ok, restored.error)
	_check(_project_state(restored.project) == before, "Archive round trip retains every project field")
	_test_checkpoints(restored.project, project)
	_test_invalid(members, manifest)
	_test_storage(project, encoded.bytes)
	print("SCURK project archive: %d checks, %d failures; ZIP-only input, indexed layers, masks, palette, checkpoints, malformed members and atomic saves" % [checks, failures])
	quit(1 if failures else 0)


func _test_index_encoding(project: ScurkProject) -> void:
	var rgb := project.palette_rgb
	project.palette_rgb = PackedByteArray()
	var before: Variant = _project_state(project)
	var encoded := project.to_bytes()
	assert(encoded.ok, encoded.error)
	var members: Dictionary[String, PackedByteArray] = Zip.decode(encoded.bytes).members
	var palette: Dictionary = JSON.parse_string(members["palette.json"].get_string_from_utf8())
	_check(palette.kind == "index-encoding" and palette.colors.size() == 256, "Projects without RGB colors declare an index-encoding palette")
	for index in 256:
		_check(palette.colors[index] == _canonical([index, index, index]), "The fallback palette encodes each index")
	var restored := Project.from_bytes(encoded.bytes)
	_check(restored.ok and _project_state(restored.project) == before, "An index-encoding project round trip is lossless")
	_check(restored.project.palette_rgb.is_empty(), "Index encoding does not invent an RGB palette")
	project.palette_rgb = rgb


func _fixture() -> ScurkProject:
	var mif := ScurkMif.from_archives([])
	var project := Project.new()
	assert(project.initialize(mif.to_bytes().bytes).ok)
	assert(project.ensure_document("1:0", PackedInt32Array([0, 1, -1, 255]), 2, 2))
	assert(project.set_layer_locked("1:0", 0, true))
	assert(project.add_layer("1:0", "Details") == 1)
	assert(project.set_active_pixels("1:0", PackedInt32Array([-1, 42, 5, -1])))
	assert(project.set_layer_visible("1:0", 1, false))
	project.documents["1:0"].custom = ["document"]
	project.documents["1:0"].layers[0].custom = {"layer": 1}
	assert(project.add_stamp("Window", 2, 1, PackedInt32Array([252, -1]), 3) == 0)
	project.stamps[0].custom = "stamp"
	project.metadata = {"author": "Original author", "palette": {"favorites": [171, 172], "ramp": [1, 42]},
		"custom": {"enabled": true, "items": [null, 4, "roof"]}}
	project.resources["reference.bin"] = PackedByteArray([0, 1, 252, 255])
	project.extra_fields = {"format": "future project field", "palette": {"future": true},
		"future_extension": {"tag": "preserve"}}
	assert(project.add_checkpoint("Before") == 0)
	project.checkpoints[0].created = "2000-01-01T00:00:00"
	project.checkpoints[0].custom = "checkpoint"
	project.palette_rgb = _palette_bytes()
	var pixels := _all_states()
	assert(project.ensure_document(DOCUMENT_KEY, pixels, 128, 3))
	assert(project.set_layer_visible(DOCUMENT_KEY, 0, false))
	assert(project.set_layer_locked(DOCUMENT_KEY, 0, true))
	assert(project.add_layer(DOCUMENT_KEY, "Visible cover") == 1)
	var cover := pixels.duplicate()
	cover.fill(42)
	assert(project.set_active_pixels(DOCUMENT_KEY, cover))
	project.documents[DOCUMENT_KEY].custom = {"document": [1, true, null]}
	project.documents[DOCUMENT_KEY].layers[0].custom = "hidden detail"
	project.documents[DOCUMENT_KEY].layers[1].custom = "visible detail"
	assert(project.add_stamp("All indexed states", 128, 3, pixels, 256) == 1)
	project.stamps[1].custom = ["stamp", 7]
	project.resources[RESOURCE_KEY] = PackedByteArray([0, 1, 252, 255])
	project.resources["empty.bin"] = PackedByteArray()
	project.metadata.custom = {"list": [null, true, 7.5, "雪"], "nested": {"keep": false}}
	assert(project.add_checkpoint("First archive") == 1)
	project.checkpoints[1].created = "2000-01-02T00:00:00"
	project.checkpoints[1].custom = {"checkpoint": 1}
	assert(mif.parse(project.current_mif))
	mif.info_payload[17] = 77
	assert(mif.set_name(1, "Current tile").ok)
	assert(project.set_current_mif(mif.to_bytes().bytes))
	cover[0] = 43
	assert(project.set_active_pixels(DOCUMENT_KEY, cover))
	project.resources[RESOURCE_KEY] = PackedByteArray([255, 252, 1, 0])
	project.metadata.author = "Archive author"
	assert(project.add_checkpoint("Second archive") == 2)
	project.checkpoints[2].created = "2000-01-03T00:00:00"
	project.checkpoints[2].custom = {"checkpoint": 2}
	return project


func _test_members(project: ScurkProject, members: Dictionary[String, PackedByteArray], manifest: Dictionary) -> void:
	_check(manifest.format == "opensc2k-scurk" and manifest.version == 2 and manifest.palette == "palette.json", "The manifest identifies version two")
	_check(members["original.mif"] == project.original_mif, "Original MIF is a byte-exact member")
	_check(members["current/current.mif"] == project.current_mif, "Current MIF is a byte-exact member")
	_check(manifest.project.format == "future project field" and manifest.project.palette == {"future": true},
		"The archive envelope preserves colliding unknown project fields")
	var record: Dictionary = manifest.project
	var document: Dictionary = record.documents[DOCUMENT_KEY]
	var descriptor: Dictionary = document.layers[0].pixels
	_check(descriptor.image.begins_with("current/documents/") and descriptor.image.ends_with("/layers/0000.png"),
		"Layer member paths use ordinal names")
	for path: String in members:
		_check(not path.contains("..") and not path.contains("雪"), "Logical names do not become archive paths")
	var png := IndexedPng.decode(members[descriptor.image])
	_check(png.ok and png.width == 128 and png.height == 3, "The layer is an indexed PNG with its full dimensions")
	_check(png.pixels.slice(0, 256) == _all_states().slice(0, 256), "All opaque palette indices stay exact")
	_check(png.palette.colors[171] == png.palette.colors[172], "Duplicate RGB colors keep distinct indices")
	_check(descriptor.has("transparency_mask"), "All 257 pixel states use a separate mask")
	var mask := IndexedPng.decode(members[descriptor.transparency_mask])
	_check(mask.ok and mask.width == 128 and mask.height == 3, "The transparency mask has matching dimensions")
	var original_pixels := _all_states()
	for index in mask.pixels.size():
		_check(mask.pixels[index] == (0 if original_pixels[index] == -1 else 255), "The mask keeps exact opacity")
	_check(record.stamps[1].pixels.has("transparency_mask"), "A stamp with all 257 states also has a mask")
	var palette: Dictionary = JSON.parse_string(members["palette.json"].get_string_from_utf8())
	_check(palette.kind == "rgb" and palette.colors.size() == 256, "Actual RGB colors are declared separately from UI preferences")
	for index in 256:
		_check(palette.colors[index] == _canonical(Array(project.palette_rgb.slice(index * 3, index * 3 + 3))), "All palette RGB bytes survive")
	_check(record.metadata.palette == _canonical({"favorites": [171, 172], "ramp": [1, 42]}), "Palette navigation preferences stay in metadata")


func _test_checkpoints(restored: ScurkProject, original: ScurkProject) -> void:
	for index in original.checkpoints.size():
		_check(restored.restore_checkpoint(index), "Each archived checkpoint can be restored")
		_check(_canonical(restored.snapshot()) == _canonical(original.checkpoints[index].snapshot), "Checkpoint restoration keeps every snapshot field")
		_check(restored.original_mif == original.original_mif, "Checkpoint restoration keeps original MIF bytes")
	var expected: Dictionary = original.checkpoints[1].snapshot.duplicate(true)
	assert(restored.restore_checkpoint(1))
	assert(restored.set_active_pixels(DOCUMENT_KEY, _all_states()))
	_check(_canonical(restored.checkpoints[1].snapshot) == _canonical(expected), "Restored layer edits do not alias checkpoint pixels")
	_check(original.documents[DOCUMENT_KEY].layers[1].pixels[0] == 43, "Loaded edits do not alias the source project")


func _test_invalid(members: Dictionary[String, PackedByteArray], manifest: Dictionary) -> void:
	var mif := Marshalls.raw_to_base64(ScurkMif.from_archives([]).to_bytes().bytes)
	var text := Project.from_bytes(("SCURK-PROJECT\n" + JSON.stringify({
		"version": 1, "revision": 0, "original_mif": mif, "current_mif": mif})).to_utf8_buffer())
	_check(not text.ok and not text.error.is_empty() and text.project == null, "The old text container is rejected")
	var descriptor: Dictionary = manifest.project.documents[DOCUMENT_KEY].layers[0].pixels
	for path: String in ["project.json", "palette.json", "original.mif", "current/current.mif", descriptor.image, descriptor.transparency_mask]:
		var bad := members.duplicate()
		bad.erase(path)
		_reject(bad, "Missing required archive member")
	for path: String in ["project.json", "palette.json", "original.mif", "current/current.mif", descriptor.image, descriptor.transparency_mask]:
		var bad := members.duplicate()
		bad[path] = PackedByteArray([0])
		_reject(bad, "Invalid required archive member")
	for version: Variant in [0, 1, 3, 2.5, "2", null]:
		var bad := manifest.duplicate(true)
		bad.version = version
		_reject_manifest(members, bad, "Unsupported archive version")
	var unknown := members.duplicate()
	unknown["unused.bin"] = PackedByteArray([1])
	_reject(unknown, "Unreferenced archive members are rejected")
	var bad := manifest.duplicate(true)
	bad.extra = true
	_reject_manifest(members, bad, "Unknown manifest fields are rejected")
	bad = manifest.duplicate(true)
	bad.project.documents[DOCUMENT_KEY].layers[0].pixels.extra = true
	_reject_manifest(members, bad, "Unknown pixel descriptor fields are rejected")
	bad = manifest.duplicate(true)
	bad.format = "other-format"
	_reject_manifest(members, bad, "Wrong archive format")
	bad = manifest.duplicate(true)
	bad.project = []
	_reject_manifest(members, bad, "Invalid project record")
	bad = manifest.duplicate(true)
	bad.project.documents[DOCUMENT_KEY].width = 0
	_reject_manifest(members, bad, "Invalid archive document size")
	bad = manifest.duplicate(true)
	bad.project.documents[DOCUMENT_KEY].layers[0].pixels.image = "../outside.png"
	_reject_manifest(members, bad, "An image reference cannot leave the archive")
	var palette := _palette()
	var small := IndexedPng.encode(1, 1, PackedInt32Array([0]), palette)
	assert(small.ok)
	var altered := members.duplicate()
	altered[descriptor.image] = small.bytes
	_reject(altered, "Image dimensions must match the document")
	altered = members.duplicate()
	altered[descriptor.transparency_mask] = small.bytes
	_reject(altered, "Mask dimensions must match the document")
	var invalid_mask := _all_states()
	invalid_mask.fill(127)
	var mask := IndexedPng.encode(128, 3, invalid_mask, Sc2Palette.index_encoding())
	assert(mask.ok)
	altered = members.duplicate()
	altered[descriptor.transparency_mask] = mask.bytes
	_reject(altered, "Mask indices must be binary")
	invalid_mask.fill(-1)
	mask = IndexedPng.encode(128, 3, invalid_mask, Sc2Palette.index_encoding())
	assert(mask.ok)
	altered[descriptor.transparency_mask] = mask.bytes
	_reject(altered, "Mask indices must be opaque")
	var wrong_colors := IndexedPng.encode(128, 3, _png_indices(), Sc2Palette.index_encoding())
	assert(wrong_colors.ok)
	altered = members.duplicate()
	altered[descriptor.image] = wrong_colors.bytes
	_reject(altered, "Image palettes must match the project palette")
	invalid_mask.fill(255)
	mask = IndexedPng.encode(128, 3, invalid_mask, palette)
	assert(mask.ok)
	altered = members.duplicate()
	altered[descriptor.transparency_mask] = mask.bytes
	_reject(altered, "Mask palettes must encode gray indices")
	for field: String in ["active", "visible", "pixels", "spacing", "checkpoint"]:
		bad = manifest.duplicate(true)
		match field:
			"active":
				bad.project.documents[DOCUMENT_KEY].active = 3
			"visible":
				bad.project.documents[DOCUMENT_KEY].layers[0].visible = 1
			"pixels":
				bad.project.documents[DOCUMENT_KEY].original_pixels = "invalid-pixels"
			"spacing":
				bad.project.stamps[0].spacing = 0
			"checkpoint":
				bad.project.checkpoints[0].snapshot.documents["1:0"].width = 129
		_reject_manifest(members, bad, "Invalid archived " + field)
	_test_invalid_palette(members)


func _test_invalid_palette(members: Dictionary[String, PackedByteArray]) -> void:
	var palette: Dictionary = JSON.parse_string(members["palette.json"].get_string_from_utf8())
	var bad := palette.duplicate(true)
	bad.extra = true
	_reject_palette(members, bad)
	bad = palette.duplicate(true)
	bad.kind = "unknown"
	_reject_palette(members, bad)
	bad = palette.duplicate(true)
	bad.colors.pop_back()
	_reject_palette(members, bad)
	for invalid: Variant in [-1, 256, 1.5, "0", null]:
		bad = palette.duplicate(true)
		bad.colors[0][0] = invalid
		_reject_palette(members, bad)
	bad = palette.duplicate(true)
	bad.colors[0].append(255)
	_reject_palette(members, bad)
	bad = palette.duplicate(true)
	bad.kind = "index-encoding"
	_reject_palette(members, bad)


func _test_storage(project: ScurkProject, bytes: PackedByteArray) -> void:
	var folder := "user://scurk-archive-%d" % OS.get_process_id()
	var path := folder.path_join("project.scurk")
	var recovery := folder.path_join("recovery.scurk")
	_check(project.save_path(path).ok, "Archive saves to a project path")
	_check(FileAccess.get_file_as_bytes(path) == bytes, "Saved archive bytes equal the deterministic encoding")
	_check(project.autosave_path(recovery).ok, "Autosave writes the same archive format")
	_check(_project_state(Project.recover_path(recovery).project) == _project_state(project), "Recovery keeps every project field")
	project.metadata.invalid = Vector2.ONE
	_check(not project.save_path(path).ok and FileAccess.get_file_as_bytes(path) == bytes, "Failed serialization keeps destination bytes")
	project.metadata.erase("invalid")
	var blocked := folder.path_join("blocked.scurk")
	assert(DirAccess.make_dir_absolute(blocked) == OK)
	_check(not project.save_path(blocked).ok, "A blocked replacement fails")
	_check(FileAccess.get_file_as_bytes(path) == bytes and DirAccess.get_files_at(folder).size() == 2,
		"Failed replacement leaves prior output and removes temporary files")
	assert(DirAccess.remove_absolute(blocked) == OK)
	for name in DirAccess.get_files_at(folder):
		assert(DirAccess.remove_absolute(folder.path_join(name)) == OK)
	assert(DirAccess.remove_absolute(folder) == OK)


func _manifest(members: Dictionary[String, PackedByteArray]) -> Dictionary:
	return JSON.parse_string(members["project.json"].get_string_from_utf8())


func _reject_manifest(members: Dictionary[String, PackedByteArray], manifest: Dictionary, label: String) -> void:
	var bad := members.duplicate()
	bad["project.json"] = JSON.stringify(manifest).to_utf8_buffer()
	_reject(bad, label)


func _reject_palette(members: Dictionary[String, PackedByteArray], palette: Dictionary) -> void:
	var bad := members.duplicate()
	bad["palette.json"] = JSON.stringify(palette).to_utf8_buffer()
	_reject(bad, "Invalid archive palette")


func _reject(members: Dictionary[String, PackedByteArray], label: String) -> void:
	var encoded := Zip.encode(members)
	assert(encoded.ok, encoded.error)
	var result := Project.from_bytes(encoded.bytes)
	_check(not result.ok and not result.error.is_empty() and result.project == null, label)


func _project_state(project: ScurkProject) -> Variant:
	return _canonical({"original_mif": project.original_mif, "snapshot": project.snapshot(),
		"checkpoints": project.checkpoints, "extra_fields": project.extra_fields,
		"revision": project.revision, "palette_rgb": project.palette_rgb})


func _canonical(value: Variant) -> Variant:
	# Normalize JSON numeric types without using either project serializer.
	return JSON.parse_string(JSON.stringify(value))


func _all_states() -> PackedInt32Array:
	var pixels := PackedInt32Array()
	pixels.resize(128 * 3)
	for index in 256:
		pixels[index] = index
	for x in 128:
		pixels[256 + x] = 42 if x % 2 == 0 else -1
	return pixels


func _png_indices() -> PackedInt32Array:
	var pixels := _all_states()
	for index in pixels.size():
		if pixels[index] == -1:
			pixels[index] = 0
	return pixels


func _palette_bytes() -> PackedByteArray:
	var bytes := PackedByteArray()
	for index in 256:
		bytes.append_array(PackedByteArray([(index * 3) % 256, index, 255 - index]))
	for offset in 3:
		bytes[172 * 3 + offset] = bytes[171 * 3 + offset]
	return bytes


func _palette() -> Sc2Palette:
	var result := Sc2Palette.new()
	var bytes := _palette_bytes()
	for index in 256:
		result.colors.append(Color8(bytes[index * 3], bytes[index * 3 + 1], bytes[index * 3 + 2]))
	return result


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
