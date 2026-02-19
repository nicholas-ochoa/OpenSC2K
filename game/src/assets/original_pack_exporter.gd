class_name OriginalPackExporter
extends RefCounted

var destination := ""
var error := ""

func export_packs(source: String, target: String, original_data := "") -> Dictionary:
	destination = target
	error = ""
	for kind in ["graphics", "sound", "music"]:
		var folder := destination.path_join(kind)
		if DirAccess.dir_exists_absolute(folder) and (not DirAccess.get_files_at(folder).is_empty() or not DirAccess.get_directories_at(folder).is_empty()):
			return {"ok": false, "error": "Refusing to overwrite an existing pack: " + folder}
	var assets := OriginalGameAssets.load_root(source)
	if not assets.error.is_empty():
		return {"ok": false, "error": assets.error}
	var manifest := {"format": "opensc2k-graphics", "version": 1, "name": "Original SimCity 2000", "palette": "palette.png", "scenario_palette": "scenario-palette.png", "ui": {}}
	if not original_data.is_empty():
		manifest.original_data = original_data
	var indices := PackedInt32Array()
	for index in 256:
		indices.append(index)
	_write_png("graphics/palette.png", 16, 16, indices, assets.palette)
	_write_png("graphics/scenario-palette.png", 16, 16, indices, assets.scenario_palette)
	for pair in [["large_sprites", assets.large_sprites], ["small_medium_sprites", assets.small_medium_sprites]]:
		var records: Array = []
		var index := 0
		for entry in pair[1].entries:
			var pixels: Dictionary = entry.decode_indices()
			if not pixels.ok:
				return {"ok": false, "error": "Cannot decode sprite"}
			var size_folder := "large" if pair[0] == "large_sprites" else ("small" if entry.sprite_id < 500 else "medium")
			var relative := "%s/%04d-%d.png" % [size_folder, index, entry.sprite_id]
			_write_png("graphics/" + relative, entry.width, entry.height, pixels.pixels, assets.palette)
			records.append({"id": entry.sprite_id, "png": relative})
			index += 1
		manifest[pair[0]] = records
	for pair in [["toolbar_art", 2], ["industry_icons", 178], ["city_map_icons", 247]]:
		var dib := PeBitmapResource.load_numeric_dib(source.path_join("SIMCITY.EXE"), pair[1])
		if not dib.ok:
			return {"ok": false, "error": "Cannot decode toolbar bitmap"}
		var bytes: PackedByteArray = dib.bytes
		var palette := Sc2Palette.new()
		var count: int = dib.color_count if dib.color_count else (1 << int(dib.bits_per_pixel))
		for index in 256:
			var offset := int(bytes.decode_u32(0)) + mini(index, count - 1) * 4
			palette.colors.append(Color8(bytes[offset + 2], bytes[offset + 1], bytes[offset]))
		var decoded: Dictionary
		if dib.bits_per_pixel == 8:
			decoded = PeBitmapResource.load_numeric_indexed8(source.path_join("SIMCITY.EXE"), pair[1])
		else:
			if dib.bits_per_pixel != 4 or dib.compression != 0:
				return {"ok": false, "error": "Unsupported original bitmap"}
			var pixels := PackedInt32Array()
			var stride := ((int(dib.width) * 4 + 31) / 32) * 4
			var start := int(bytes.decode_u32(0)) + count * 4
			for y in int(dib.height):
				for x in int(dib.width):
					var value := bytes[start + (int(dib.height) - 1 - y) * stride + x / 2]
					pixels.append((value >> 4) if x % 2 == 0 else (value & 15))
			decoded = {"ok": true, "width": dib.width, "height": dib.height, "pixels": pixels}
		if not decoded.ok:
			return {"ok": false, "error": "Cannot decode original bitmap"}
		var relative := "ui/%s.png" % pair[0]
		_write_png("graphics/" + relative, decoded.width, decoded.height, decoded.pixels, palette)
		manifest.ui[pair[0]] = relative
	for pair in [["simnation_sprites", "NEIGHBOR"], ["forest_protest_image", "403"]]:
		var decoded := IndexedBmp.decode(FileAccess.get_file_as_bytes(source.path_join("BITMAPS/%s.BMP" % pair[1])))
		if not decoded.ok:
			return {"ok": false, "error": "Cannot decode original bitmap"}
		var palette := Sc2Palette.new()
		palette.colors = decoded.colors
		var relative := "ui/%s.png" % pair[0]
		_write_png("graphics/" + relative, decoded.width, decoded.height, decoded.pixels, palette)
		manifest.ui[pair[0]] = relative
	_write("graphics/pack.json", JSON.stringify(manifest, "\t").to_utf8_buffer())
	var loaded := GraphicsPack.load_root(destination.path_join("graphics"))
	if not loaded.error.is_empty():
		return {"ok": false, "error": loaded.error}
	for kind in ["sound", "music"]:
		var media := {"format": "opensc2k-" + kind, "version": 1, "name": "Original SimCity 2000 " + kind, "files": {}}
		var first := 500 if kind == "sound" else 10000
		var count := 30 if kind == "sound" else 19
		var extension := "WAV" if kind == "sound" else "MID"
		for id in range(first, first + count):
			var file := "%d.%s" % [id, extension]
			_write(kind + "/" + file, FileAccess.get_file_as_bytes(source.path_join("SOUNDS/" + file)))
			media.files[str(id)] = file
		_write(kind + "/pack.json", JSON.stringify(media, "\t").to_utf8_buffer())
		var media_error := MediaPack.load_folder(destination.path_join(kind), kind).error
		if not media_error.is_empty():
			return {"ok": false, "error": media_error}
	return {"ok": error.is_empty(), "error": error}

func _write_png(path: String, width: int, height: int, pixels: PackedInt32Array, palette: Sc2Palette) -> void:
	var encoded := IndexedPng.encode(width, height, pixels, palette)
	if not encoded.ok:
		error = encoded.error
		return
	_write(path, encoded.bytes)

func _write(relative: String, bytes: PackedByteArray) -> void:
	if not error.is_empty():
		return
	var path := destination.path_join(relative)
	if FileAccess.file_exists(path) or DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		error = "Cannot create pack file: " + path
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		error = "Cannot write pack file: " + path
		return
	file.store_buffer(bytes)
	file.flush()
	if file.get_error() != OK:
		error = "Cannot finish pack file: " + path
