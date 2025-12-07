extends SceneTree
## Compare the Godot reader with independent Python source-index hashes.


func _initialize() -> void:
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../data/formats/check-control-audit.json"))
	assert(FileAccess.get_sha256("res://../references/SIMCITY.EXE") == audit.source_sha256)
	var loaded := PeBitmapResource.load_named_dib("res://../references/SIMCITY.EXE", "CTL3D_3DCHECK")
	assert(loaded.ok and _sha256(loaded.bytes) == audit.dib_sha256)
	var source := CityUiGraphics.load_original("res://../references")
	assert(source.check_sheet.get_size() == Vector2i(70, 39) and source.check_system_colors)
	var original_colors := [Color.BLACK, Color8(128, 0, 0), Color8(0, 128, 0), Color8(128, 128, 0), Color8(0, 0, 128), Color8(128, 0, 128), Color8(0, 128, 128), Color8(128, 128, 128), Color8(192, 192, 192), Color.RED, Color.GREEN, Color.YELLOW, Color.BLUE, Color.MAGENTA, Color.CYAN, Color.WHITE]
	for cell in audit.cells:
		var point := Vector2i(int(cell.column), int(cell.row))
		var image := CheckControlGraphics.cell_image(source.check_sheet, point)
		var indices := PackedByteArray()
		for y in 13:
			for x in 14:
				var index := original_colors.find(image.get_pixel(x, y))
				assert(index >= 0)
				indices.append(index)
		assert(_sha256(indices) == cell.sha256)
	var directory := PeBitmapResource._load_resource_directory("res://../references/SIMCITY.EXE")
	var address := PeBitmapResource._rva_to_offset(directory.bytes, 0x4eac8c - 0x400000, directory.section_offset, directory.section_count)
	assert(directory.bytes.slice(address, address + 11).get_string_from_ascii() == "CTL3D32.DLL")
	print("PASS: supplied executable/DIB hashes, named 4-bit sheet, padded bottom-up rows, all 15 independent-decoder cell hashes and CTL3D library path; no raster export")
	quit()


func _sha256(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	assert(hash.start(HashingContext.HASH_SHA256) == OK and hash.update(bytes) == OK)
	return hash.finish().hex_encode()
