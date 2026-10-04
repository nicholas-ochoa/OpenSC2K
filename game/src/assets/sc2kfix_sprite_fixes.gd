class_name Sc2kfixSpriteFixes
extends RefCounted
## The sprite corrections of sc2kfix, applied to the original sprites at load
## time. The data file holds pixel edits that were derived from the sc2kfix
## FIXEDTILES tile sets, not original art:
##
## - Four buildings move one pixel left and restore their clipped edge.
## - Some buildings, the dust clouds, the crane, and the loading bay use the
##   animated colours of the DOS and Macintosh versions.
## - Hangar 1 animates its door.
##
## A correction applies only to a sprite whose size and pixels match the
## original Windows sprite, so another graphics source keeps its own art.

const DATA_PATH := "res://assets/data/sc2kfix_sprite_fixes.json"
const TRANSPARENT := -1

static var _fixes: Array = []


# The archive with each matching sprite corrected, or `archive` itself when no
# sprite matches. `archive_name` is "large" or "small_medium".
static func apply(archive: Sc2SpriteArchive, archive_name: String) -> Sc2SpriteArchive:
	if archive == null or not archive.is_valid():
		return archive

	var overrides := Sc2SpriteArchive.new()

	for fix: Dictionary in fixes():
		if fix.archive != archive_name:
			continue

		var corrected := corrected_entry(archive.find_sprite(int(fix.id)), fix)

		if corrected != null:
			overrides.entries.append(corrected)
			overrides.entries_by_id[corrected.sprite_id] = corrected

	if overrides.entries.is_empty():
		return archive

	return Sc2SpriteArchive.combine([archive, overrides])


# The corrected sprite, or null when `entry` is not the original sprite.
static func corrected_entry(entry: Sc2SpriteArchive.SpriteEntry, fix: Dictionary) -> Sc2SpriteArchive.SpriteEntry:
	var width := int(fix.width)
	var height := int(fix.height)

	if entry == null or entry.width != width or entry.height != height:
		return null

	var decoded := entry.decode_indices()

	if not decoded.ok or NativeCrc32.calculate(decoded.pixels.to_byte_array()) != int(fix.crc32):
		return null

	var source := decoded.pixels
	var pixels := PackedInt32Array()
	pixels.resize(source.size())
	var shift := int(fix.shift_x)

	for y in height:
		for x in width:
			var source_x := x - shift
			pixels[y * width + x] = source[y * width + source_x] if source_x >= 0 and source_x < width else TRANSPARENT

	var edits: Array = fix.pixels

	for index in range(0, edits.size() - 2, 3):
		pixels[int(edits[index + 1]) * width + int(edits[index])] = int(edits[index + 2])

	return Sc2SpriteArchive.entry_from_indices(entry.sprite_id, width, height, pixels)


static func fixes() -> Array:
	if _fixes.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))

		if data is Dictionary and data.get("sprites") is Array:
			_fixes = data.sprites

	return _fixes
