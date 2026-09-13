class_name Sc2ImportGraphics
extends RefCounted
## Build indexed graphics packs from available source records, without playback.

var error := ""
var warnings := PackedStringArray()
var count := 0
var _folder := ""
var _palette: Sc2Palette
var _scenario_palette: Sc2Palette
var _files: Dictionary[String, Sc2ImportResource] = {}
var _typed: Dictionary[String, Sc2ImportResource] = {}
var _ui: Dictionary[String, IndexedImageResult] = {}
var _large := Sc2SpriteArchive.new()
var _small := Sc2SpriteArchive.new()


static func export_pack(source: Sc2ImportSource, folder: String, label: String) -> Sc2ImportGraphics:
	var importer := Sc2ImportGraphics.new()
	importer._folder = folder
	importer._read(source)

	if importer.error.is_empty():
		importer._export(source.platform, label)

	if not importer.error.is_empty():
		OriginalGameInstaller.remove_tree(folder)

	return importer


func _read(source: Sc2ImportSource) -> void:
	for resource in source.resources:
		if resource.type.is_empty():
			var name := resource.name.to_upper()

			if not _files.has(name):
				_files[name] = resource
		else:
			if resource.source.get_file().to_upper().contains("SCURK"):
				continue

			var key := "%s/%d" % [resource.type, resource.id]

			if not _typed.has(key):
				_typed[key] = resource

	_palette = _bmp_palette("PAL_MSTR.BMP")
	_scenario_palette = _bmp_palette("PAL_MAC.BMP")

	if _palette == null and _files.has("MINE.PAL"):
		var bytes := _files["MINE.PAL"].bytes

		if bytes.size() == 768:
			_palette = Sc2Palette.new()

			for index in 256:
				_palette.colors.append(Color8(bytes[index * 3], bytes[index * 3 + 1], bytes[index * 3 + 2]))

	if _palette == null and _typed.has("pltt/0"):
		_palette = mac_palette(_typed["pltt/0"].bytes)

	if _palette == null and _files.has("SC2K.PAL"):
		var bytes := _files["SC2K.PAL"].bytes

		if bytes.size() in [1024, 1025]:
			_palette = Sc2Palette.new()

			for index in 256:
				_palette.colors.append(Color8(bytes[index * 4 + 2], bytes[index * 4 + 1], bytes[index * 4]))

	for field: String in {"toolbar_art": 2, "industry_icons": 178, "city_map_icons": 247}:
		if source.platform == "Windows Network Edition":
			continue

		var id: int = {"toolbar_art": 2, "industry_icons": 178, "city_map_icons": 247}[field]
		var key := "2/%d" % id

		if _typed.has(key):
			_add_ui(field, _typed[key], false)

	for pair in [["simnation_sprites", "NEIGHBOR.BMP"], ["forest_protest_image", "403.BMP"]]:
		if _files.has(pair[1]):
			_add_ui(pair[0], _files[pair[1]], true)

	if _palette == null and not _ui.is_empty():
		# UI-only packs never replace the active city palette.
		_palette = (_ui.values()[0] as IndexedImageResult).palette
		warnings.append("No city palette was found. Only interface images can be imported.")
	else:
		for pair in [["LARGE", 129], ["SMALLMED", 128], ["SPECIAL", 130]]:
			var name: String = pair[0]
			var resource: Sc2ImportResource = _files.get(name + ".DAT")

			if resource == null:
				resource = _typed.get("SPRT/%d" % pair[1])

			if resource != null and not _files.has(name + ".HED"):
				_add_desktop(resource, _large if name == "LARGE" else _small)

		for name in ["LARGE", "SMALL", "OTHER"]:
			if _files.has(name + ".DAT") and _files.has(name + ".HED"):
				var decoded := Sc2ImportSprites.dos(_files[name + ".HED"].bytes, _files[name + ".DAT"].bytes)
				warnings.append_array(decoded.warnings)

				if not decoded.error.is_empty():
					warnings.append(name + ": " + decoded.error)
				else:
					_append(decoded.archive, _large if name == "LARGE" else _small)

		if _typed.has("TSET/1") and (_large.entries.is_empty() or _small.entries.is_empty()):
			var tiles := Sc2ImportSprites.mac_tile_set(_typed["TSET/1"].bytes)
			_add_tile_groups(tiles)

		if _files.has("TILES.DB") and (_large.entries.is_empty() or _small.entries.is_empty()):
			var tiles := Sc2ImportSprites.tiles_database(_files["TILES.DB"].bytes)
			_add_tile_groups(tiles)

	if _palette == null:
		error = "No readable city palette or interface bitmap was found."
	elif _large.entries.is_empty() and _small.entries.is_empty() and _ui.is_empty():
		error = "No convertible graphics were found."


func _add_tile_groups(tiles: Sc2ImportSprites) -> void:
	var need_large := _large.entries.is_empty()
	var need_small := _small.entries.is_empty()
	warnings.append_array(tiles.warnings)

	if not tiles.error.is_empty():
		warnings.append(tiles.error)

	for entry in tiles.archive.entries:
		if (entry.sprite_id >= 1000 and not need_large) or (entry.sprite_id < 1000 and not need_small):
			continue

		var target := _large if entry.sprite_id >= 1000 else _small
		target.entries.append(entry)
		target.entries_by_id[entry.sprite_id] = entry


static func mac_palette(bytes: PackedByteArray) -> Sc2Palette:
	if bytes.size() < 16 or Sc2ImportContainer.be16(bytes, 0) != 256 or bytes.size() < 16 + 256 * 16:
		return null

	var palette := Sc2Palette.new()

	for index in 256:
		var offset := 16 + index * 16
		palette.colors.append(Color8(bytes[offset], bytes[offset + 2], bytes[offset + 4]))

	return palette


func _bmp_palette(name: String) -> Sc2Palette:
	if not _files.has(name):
		return null

	var bytes := _files[name].bytes

	if bytes.size() < 54 or bytes.decode_u16(28) != 8 or bytes.decode_u32(46) not in [0, 256]:
		return null

	var decoded := Sc2ImportBitmap.decode(bytes, true)
	return decoded.palette if decoded.ok else null


func _add_ui(field: String, resource: Sc2ImportResource, file_header: bool) -> void:
	var decoded := Sc2ImportBitmap.decode(resource.bytes, file_header)

	if decoded.ok:
		_ui[field] = decoded
	else:
		warnings.append(field + ": " + decoded.error)


func _add_desktop(resource: Sc2ImportResource, target: Sc2SpriteArchive) -> void:
	var archive := Sc2SpriteArchive.new()

	if not archive.parse(resource.bytes):
		warnings.append(resource.name + ": " + archive.parse_error)
		return

	for entry in archive.entries:
		if entry.width > 4096 or entry.height > 4096:
			warnings.append("Sprite %d has excessive dimensions." % entry.sprite_id)
			continue

		var decoded := entry.decode_indices()

		if not decoded.ok:
			warnings.append(resource.name + ": " + decoded.error)
			continue

		target.entries.append(entry)
		target.entries_by_id[entry.sprite_id] = entry


func _append(source: Sc2SpriteArchive, target: Sc2SpriteArchive) -> void:
	for entry in source.entries:
		target.entries.append(entry)
		target.entries_by_id[entry.sprite_id] = entry


func _export(platform: String, label: String) -> void:
	var manifest := {"format": "opensc2k-graphics", "version": 1, "name": label + " Graphics", "source_platform": platform,
		"partial": true, "palette": "palette.png", "large_sprites": [], "small_medium_sprites": [], "ui": {}}
	var indices := PackedInt32Array()

	for index in 256:
		indices.append(index)

	_png("palette.png", 16, 16, indices, _palette)

	if _scenario_palette != null:
		_png("scenario-palette.png", 16, 16, indices, _scenario_palette)
		manifest.scenario_palette = "scenario-palette.png"

	for pair in [["large_sprites", _large], ["small_medium_sprites", _small]]:
		var archive: Sc2SpriteArchive = pair[1]
		var records: Array = []

		for index in archive.entries.size():
			if not error.is_empty():
				return

			var entry := archive.entries[index]
			var decoded := entry.decode_indices()
			var relative := "%s/%04d-%d.png" % [pair[0], index, entry.sprite_id]
			_png(relative, entry.width, entry.height, decoded.pixels, _palette)
			records.append({"id": entry.sprite_id, "png": relative})
			count += 1

		manifest[pair[0]] = records

	for field in _ui:
		var decoded := _ui[field]
		var relative := "ui/" + field + ".png"
		_png(relative, decoded.width, decoded.height, decoded.pixels, decoded.palette)
		manifest.ui[field] = relative
		count += 1

	if _large.entries.is_empty() or _small.entries.is_empty():
		warnings.append("Graphics are missing a city sprite size group. The pack needs a compatible base set for that group.")
	else:
		var missing := 0

		for id in range(1001, 1500):
			if not _large.entries_by_id.has(id):
				missing += 1

		if missing > 0:
			warnings.append("Graphics are missing %d standard large sprite IDs. This can occur in demos or incomplete copies." % missing)

	if _ui.size() < GraphicsPack.UI_FIELDS.size():
		warnings.append("Graphics include %d of %d core interface images. Missing interface artwork uses the available base images or built-in controls." % [_ui.size(), GraphicsPack.UI_FIELDS.size()])

	_write("pack.json", JSON.stringify(manifest, "\t").to_utf8_buffer())

	if error.is_empty():
		error = GraphicsPack.load_root(_folder).error


func _png(path: String, width: int, height: int, pixels: PackedInt32Array, palette: Sc2Palette) -> void:
	if not error.is_empty():
		return

	var encoded := IndexedPng.encode(width, height, pixels, palette)

	if not encoded.ok:
		error = encoded.error
		return

	_write(path, encoded.bytes)


func _write(relative: String, bytes: PackedByteArray) -> void:
	if not error.is_empty():
		return

	var path := _folder.path_join(relative)

	if FileAccess.file_exists(path) or DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		error = "Cannot create graphics pack file: " + relative
		return

	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		error = "Cannot write graphics pack file: " + relative
		return

	file.store_buffer(bytes)
	file.flush()

	if file.get_error() != OK:
		error = "Cannot finish graphics pack file: " + relative
