class_name Sc2SpriteArchive
extends RefCounted

var entries: Array[SpriteEntry] = []
var entries_by_id: Dictionary[int, SpriteEntry] = {}
var visual_emission: Dictionary[int, Image] = {}
var visual_seasons: Dictionary[int, Image] = {}
var visual_nature: Dictionary[int, SpriteEntry] = {}
var visual_nature_masks: Dictionary[int, Image] = {}
var visual_nature_enabled := false
var visual_terrain_enabled := false
var visual_revision := 0
var water_reflections := false
var water_indices := PackedByteArray()
var visual_city_life_traffic := false
var parse_error := ""
# alternate art can leave the ground visible below its small highway pieces
var redraw_small_highway_ground := false


static func load_path(path: String) -> Sc2SpriteArchive:
	var archive := Sc2SpriteArchive.new()

	if not FileAccess.file_exists(path):
		archive.parse_error = "Sprite archive does not exist: %s" % path

		return archive

	archive.parse(FileAccess.get_file_as_bytes(path))

	return archive


static func entry_from_indices(
	sprite_id: int, width: int, height: int, pixels: PackedInt32Array
) -> SpriteEntry:
	if width < 1 or height < 1 or pixels.size() != width * height or not NativeSpriteCodec.valid_indices(pixels):
		return null

	var entry := SpriteEntry.new()
	entry.sprite_id = sprite_id
	entry.width = width
	entry.height = height
	entry._direct_indices = pixels.duplicate()

	return entry


static func combine(archives: Array[Sc2SpriteArchive]) -> Sc2SpriteArchive:
	var result := Sc2SpriteArchive.new()

	for archive in archives:
		if archive == null or not archive.is_valid():
			result.parse_error = "cannot combine an invalid sprite archive"
			result.entries.clear()
			result.entries_by_id.clear()

			return result

		result.redraw_small_highway_ground = result.redraw_small_highway_ground or archive.redraw_small_highway_ground

		for entry in archive.entries:
			result.entries.append(entry)
			result.entries_by_id[entry.sprite_id] = entry

	return result


func parse(bytes: PackedByteArray) -> bool:
	entries.clear()
	entries_by_id.clear()
	visual_nature.clear()
	visual_nature_masks.clear()
	parse_error = ""
	redraw_small_highway_ground = false

	if bytes.size() < 2:
		return _fail("archive is shorter than its count field")

	var count := BinaryData.read_u16_be(bytes, 0)
	var header_end := 2 + count * 10

	if header_end > bytes.size():
		return _fail("metadata table extends past the file")

	var duplicate_counts: Dictionary[int, int] = {}

	for index in count:
		var metadata_offset := 2 + index * 10
		var entry := SpriteEntry.new()
		entry.sprite_id = BinaryData.read_u16_be(bytes, metadata_offset)
		entry.offset = BinaryData.read_u32_be(bytes, metadata_offset + 2)
		entry.height = BinaryData.read_u16_be(bytes, metadata_offset + 6)
		entry.width = BinaryData.read_u16_be(bytes, metadata_offset + 8)
		entry.duplicate_index = int(duplicate_counts.get(entry.sprite_id, 0))
		duplicate_counts[entry.sprite_id] = entry.duplicate_index + 1

		if entry.width <= 0 or entry.height <= 0:
			return _fail("sprite %d has an empty dimension" % entry.sprite_id)

		if entry.offset < header_end or entry.offset > bytes.size():
			return _fail("sprite %d has an invalid data offset" % entry.sprite_id)

		entries.append(entry)

	for index in entries.size():
		var entry := entries[index]
		var end := bytes.size()

		if index + 1 < entries.size():
			end = entries[index + 1].offset

		if end < entry.offset:
			return _fail("sprite offsets are not in ascending order")

		entry.encoded_pixels = bytes.slice(entry.offset, end)
		# Use the last duplicate sprite for lookup. Keep the others for archive round trips.
		entries_by_id[entry.sprite_id] = entry

	return true


func is_valid() -> bool:
	return parse_error.is_empty()


func find_sprite(sprite_id: int) -> SpriteEntry:
	return visual_nature.get(sprite_id, entries_by_id.get(sprite_id)) as SpriteEntry


func _fail(message: String) -> bool:
	parse_error = message

	return false


class SpriteEntry extends RefCounted:
	var sprite_id := 0
	var offset := 0
	var width := 0
	var height := 0
	var duplicate_index := 0
	var encoded_pixels := PackedByteArray()
	var allow_unpadded_odd_runs := false
	var _direct_indices := PackedInt32Array()
	var _index_image: Image
	var _index_image_mutex := Mutex.new()


	func decode_indices() -> IndexedImageResult:
		if not _direct_indices.is_empty():
			var direct_result := IndexedImageResult.new()
			direct_result.ok = true
			direct_result.pixels = _direct_indices.duplicate()
			direct_result.rows = height
			direct_result.error = ""

			return direct_result

		# -1 is transparent, zero is a perfectly good pixel
		var decoded := NativeSpriteCodec.decode(encoded_pixels, width, height, allow_unpadded_odd_runs)

		if not decoded.ok:
			return IndexedImageResult.failure(_sprite_error(decoded.error))

		var outcome := IndexedImageResult.new()
		outcome.ok = true
		outcome.pixels = decoded.pixels
		outcome.rows = decoded.rows
		outcome.error = ""

		return outcome


	func pixel_hash() -> int:
		return hash(_direct_indices) if not _direct_indices.is_empty() else hash(encoded_pixels)


	func create_image(palette: Sc2Palette) -> AssetImageResult:
		if not palette.is_valid():
			return AssetImageResult.failure(_sprite_error("palette is invalid"))

		if palette.is_index_encoding:
			return _create_index_image()

		var decoded := decode_indices()

		if not decoded.ok:
			return AssetImageResult.failure(decoded.error)

		var image := NativeSpriteCodec.color_image(decoded.pixels, width, height, palette.to_rgba_bytes())
		var outcome := AssetImageResult.new()
		outcome.ok = true
		outcome.image = image
		outcome.error = ""

		return outcome


	func _create_index_image() -> AssetImageResult:
		_index_image_mutex.lock()

		if _index_image != null:
			var cached := AssetImageResult.new()
			cached.ok = true
			cached.image = _index_image
			_index_image_mutex.unlock()

			return cached

		var decoded := decode_indices()

		if not decoded.ok:
			_index_image_mutex.unlock()

			return AssetImageResult.failure(decoded.error)

		var image := NativeSpriteCodec.index_image(decoded.pixels, width, height)
		_index_image = image
		_index_image_mutex.unlock()

		var outcome := AssetImageResult.new()
		outcome.ok = true
		outcome.image = image
		outcome.error = ""

		return outcome


	func _sprite_error(message: String) -> String:
		return "sprite %d at 0x%x: %s" % [sprite_id, offset, message]
