class_name CityBrightmaps
extends RefCounted
## Authored RGBA emission is separate from the original palette and sprite data.

const DEFAULT_FOLDER := "res://assets/brightmaps/standard"

static func fingerprint(entry: Sc2SpriteArchive.SpriteEntry) -> String:
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(entry.decode_indices().pixels.to_byte_array())
	return hash_context.finish().hex_encode()


static func load_archive(archive: Sc2SpriteArchive, folder: String, group: String) -> void:
	archive.visual_emission.clear()
	folder = DEFAULT_FOLDER if folder.is_empty() else resolve_folder(folder)
	var path := folder.path_join("catalog.json")
	if not FileAccess.file_exists(path):
		return
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not catalog is Dictionary or not catalog.get("sprites") is Dictionary:
		return
	for id: int in archive.entries_by_id:
		var entry := archive.find_sprite(id)
		var record: Variant = catalog.sprites.get("%s/%d" % [group, id])
		var filename := folder.path_join("brightmaps/%s/%d.png" % [group, id])
		if not record is Dictionary:
			continue
		if record.get("indices_sha256", "") != fingerprint(entry):
			continue
		var image: Image
		if filename.begins_with("res://"):
			if ResourceLoader.exists(filename, "Texture2D"):
				var texture := load(filename) as Texture2D
				if texture != null:
					image = texture.get_image()
		elif FileAccess.file_exists(filename):
			image = Image.load_from_file(filename)
		if image == null or image.get_size() != Vector2i(entry.width, entry.height):
			continue
		image.convert(Image.FORMAT_RGBA8)
		if not image.is_invisible():
			archive.visual_emission[id] = image


static func transform_mask(source: Image, silhouette: Image, flip: bool) -> Image:
	if source == null:
		return null
	var mask: Image = source.duplicate()
	if flip:
		mask.flip_x()
	if mask.get_size() != silhouette.get_size():
		mask.resize(silhouette.get_width(), silhouette.get_height(), Image.INTERPOLATE_NEAREST)
	return NativeSpriteCompositor.light_mask(mask, silhouette)


static func resolve_folder(folder: String) -> String:
	if folder.is_empty() or folder.is_absolute_path():
		return folder
	return AppPaths.path(folder).simplify_path()


static func export_originals(assets: OriginalGameAssets, folder: String) -> String:
	folder = resolve_folder(folder)
	if folder.is_empty():
		return "Choose a Brightmap folder first."
	var sprites := {}
	for pair in [[assets.large_sprites, "large"], [assets.small_medium_sprites, "small-medium"]]:
		var archive: Sc2SpriteArchive = pair[0]
		if archive == null:
			continue
		for id: int in archive.entries_by_id:
			var entry := archive.find_sprite(id)
			sprites["%s/%d" % [pair[1], id]] = {"indices_sha256": fingerprint(entry), "width": entry.width, "height": entry.height}
	var catalog_path := folder.path_join("catalog.json")
	if FileAccess.file_exists(catalog_path):
		var existing: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
		if not _catalog_matches(existing, sprites):
			return "This folder belongs to different artwork. Choose a new folder to preserve your edits."
	for pair in [[assets.large_sprites, "large"], [assets.small_medium_sprites, "small-medium"]]:
		var archive: Sc2SpriteArchive = pair[0]
		if archive == null:
			continue
		for category in ["originals", "brightmaps"]:
			var error := DirAccess.make_dir_recursive_absolute(folder.path_join(category).path_join(pair[1]))
			if error != OK:
				return "Cannot create the Brightmap folder: %s" % error_string(error)
		for id: int in archive.entries_by_id:
			var entry := archive.find_sprite(id)
			var original_path := folder.path_join("originals/%s/%d.png" % [pair[1], id])
			var mask_path := folder.path_join("brightmaps/%s/%d.png" % [pair[1], id])
			if not FileAccess.file_exists(original_path):
				var original := entry.create_image(assets.palette)
				if not original.ok or original.image.save_png(original_path) != OK:
					return "Cannot export original sprite %d." % id
			if not FileAccess.file_exists(mask_path):
				var mask := Image.create(entry.width, entry.height, false, Image.FORMAT_RGBA8)
				if mask.save_png(mask_path) != OK:
					return "Cannot export Brightmap template %d." % id
	var file := FileAccess.open(catalog_path, FileAccess.WRITE)
	if file == null:
		return "Cannot write the Brightmap catalog."
	file.store_string(JSON.stringify({"version": 1, "sprites": sprites}, "\t"))
	return ""


static func _catalog_matches(catalog: Variant, sprites: Dictionary) -> bool:
	if not catalog is Dictionary or not catalog.get("sprites") is Dictionary or catalog.sprites.size() != sprites.size():
		return false
	for key in sprites:
		var actual: Variant = catalog.sprites.get(key)
		var expected: Dictionary = sprites[key]
		if not actual is Dictionary or actual.get("indices_sha256") != expected.indices_sha256:
			return false
		if int(actual.get("width", -1)) != expected.width or int(actual.get("height", -1)) != expected.height:
			return false
	return true
