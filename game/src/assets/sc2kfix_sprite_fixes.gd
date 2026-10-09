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
##
## The animated colours are DOS colours that sc2kfix puts in 20 palette
## entries that the Windows palette leaves black. Nine original sprites draw
## those entries; with the DOS colours present they keep them black.

const DATA_PATH := "res://assets/data/sc2kfix_sprite_fixes.json"
const RESERVED_BLACK := "reserved_black"
# the DOS colours of sc2kfix game_graphics.cpp, by Windows palette entry
const DOS_COLORS := {
	0x0a: Color8(79, 53, 0), 0x0b: Color8(79, 79, 0), 0x0c: Color8(79, 104, 0), 0x0d: Color8(79, 130, 0),
	0x0e: Color8(79, 156, 0), 0x0f: Color8(79, 181, 0), 0xe8: Color8(79, 207, 0), 0xe9: Color8(104, 28, 0),
	0xea: Color8(104, 53, 0), 0xeb: Color8(104, 79, 0), 0xec: Color8(104, 104, 0), 0xed: Color8(104, 130, 0),
	0xee: Color8(104, 156, 0), 0xef: Color8(104, 181, 0), 0xf0: Color8(104, 207, 0), 0xf1: Color8(130, 28, 0),
	0xf2: Color8(130, 53, 0), 0xf3: Color8(130, 79, 0), 0xf4: Color8(130, 104, 0), 0xf5: Color8(130, 130, 0),
}

static var _fixes: Array = []


# A copy of `palette` with the DOS colours in its empty entries.
static func extended_palette(palette: Sc2Palette) -> Sc2Palette:
	if palette == null or not palette.is_valid():
		return palette

	var result := Sc2Palette.new()
	result.colors = palette.colors.duplicate()
	result.is_index_encoding = palette.is_index_encoding

	for index: int in DOS_COLORS:
		result.colors[index] = DOS_COLORS[index]

	return result


# The archive with each matching original sprite changed, or `archive` itself
# when no sprite matches. `archive_name` is "large" or "small_medium". With
# `with_corrections`, the sc2kfix corrections apply; otherwise only the sprites that
# draw the DOS colour entries keep them black.
static func apply(archive: Sc2SpriteArchive, archive_name: String, with_corrections := true) -> Sc2SpriteArchive:
	if archive == null or not archive.is_valid():
		return archive

	var changed: Dictionary[int, Sc2SpriteArchive.SpriteEntry] = {}

	# a correction replaces the black-only change of its sprite
	for fix: Dictionary in fixes():
		var reserved: bool = fix.fix == RESERVED_BLACK

		if fix.archive != archive_name or (not reserved and not with_corrections):
			continue

		var corrected := corrected_entry(archive.find_sprite(int(fix.id)), fix)

		if corrected != null:
			changed[corrected.sprite_id] = corrected

	if changed.is_empty():
		return archive

	var overrides := Sc2SpriteArchive.new()

	for entry: Sc2SpriteArchive.SpriteEntry in changed.values():
		overrides.entries.append(entry)
		overrides.entries_by_id[entry.sprite_id] = entry

	return Sc2SpriteArchive.combine([archive, overrides])


# The sc2kfix corrections, without the black-only changes.
static func corrections() -> Array:
	return fixes().filter(func(fix: Dictionary) -> bool: return fix.fix != RESERVED_BLACK)


# The corrected sprite, or null when `entry` is not the original sprite. The
# native formats library holds the rule; see native/core/assets/src/sprite_fixes.rs
static func corrected_entry(entry: Sc2SpriteArchive.SpriteEntry, fix: Dictionary) -> Sc2SpriteArchive.SpriteEntry:
	var width := int(fix.width)
	var height := int(fix.height)

	if entry == null or entry.width != width or entry.height != height:
		return null

	var decoded := entry.decode_indices()

	if not decoded.ok:
		return null

	var pixels := NativeSpriteFixes.corrected(
		decoded.pixels, width, height, int(fix.crc32), int(fix.shift_x), PackedInt64Array(fix.pixels)
	)

	if pixels.is_empty():
		return null

	return Sc2SpriteArchive.entry_from_indices(entry.sprite_id, width, height, pixels)


static func fixes() -> Array:
	if _fixes.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))

		if data is Dictionary and data.get("sprites") is Array:
			_fixes = data.sprites

	return _fixes
