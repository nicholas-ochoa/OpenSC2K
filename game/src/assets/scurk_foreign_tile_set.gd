class_name ScurkForeignTileSet
extends RefCounted
## DOS and Macintosh SCURK tile sets for the city view, as sc2kfix loads them.
##
## A DOS .TIL file is a small archive of LARGE, OTHER, and SMALL sprite files
## and their .HED directories. A Macintosh tile set is a MIFF file with the
## _MAC INFO tag, which SCURK keeps in a TSET resource. Their sprites use the
## DOS and Macintosh palette, so each pixel converts to the Windows palette
## with the sc2kfix table. Twenty DOS colours have no Windows entry; they use
## the entries that sc2kfix fills with them, so the tile set uses the DOS
## colours (ScurkMif.uses_dos_colors).
##
## A Windows or sc2kfix MIF file, and the Macintosh data fork copy of one, load
## as ScurkMif.

const DOS_DIRECTORY_ENTRY := 16
const DOS_NAME_LENGTH := 12
const DOS_SIGNATURE := "LARGE.DAT"
const MAC_TAG := "_MAC"
# a sprite of one row is a placeholder, as sc2kfix reads it
const MIN_HEIGHT := 2
const SECTIONS := [
	["LARGE", ScurkSpriteIds.LARGE_FIRST, ScurkSpriteIds.SPRITE_COUNT],
	["OTHER", ScurkSpriteIds.MEDIUM_FIRST, ScurkSpriteIds.LARGE_FIRST],
	["SMALL", ScurkSpriteIds.SMALL_FIRST, ScurkSpriteIds.LARGE_FIRST],
]


# Any tile set file: DOS, Macintosh, Windows, or sc2kfix.
static func load_path(path: String) -> ScurkMif:
	if not FileAccess.file_exists(path):
		var missing := ScurkMif.new()
		missing.parse_error = "SCURK tile set does not exist: %s" % path

		return missing

	var bytes := FileAccess.get_file_as_bytes(path)

	if is_dos(bytes):
		return dos(bytes)

	if is_mac(bytes):
		return mac(bytes)

	var parsed := ScurkMif.new()

	if parsed.parse(bytes):
		return parsed

	# a Macintosh resource fork that holds the tile set
	var container := Sc2ImportContainer.macintosh(bytes, path)

	for resource in container.resources:
		if resource.type == "TSET" and is_mac(resource.bytes):
			return mac(resource.bytes)

	return parsed


static func is_dos(bytes: PackedByteArray) -> bool:
	return bytes.size() > DOS_DIRECTORY_ENTRY and bytes.slice(0, DOS_SIGNATURE.length()).get_string_from_ascii() == DOS_SIGNATURE


static func is_mac(bytes: PackedByteArray) -> bool:
	return (bytes.size() > 24 and bytes.slice(0, 4).get_string_from_ascii() == "MIFF"
		and bytes.slice(20, 24).get_string_from_ascii() == MAC_TAG)


static func dos(bytes: PackedByteArray) -> ScurkMif:
	var files := _dos_files(bytes)
	var archive := Sc2SpriteArchive.new()

	for section: Array in SECTIONS:
		var name: String = section[0]

		if not files.has(name + ".HED") or not files.has(name + ".DAT"):
			continue

		var decoded := Sc2ImportSprites.dos(files[name + ".HED"], files[name + ".DAT"])

		for entry in decoded.archive.entries:
			# SMALL also holds medium sprites; OTHER replaces them first
			if entry.sprite_id < section[1] or entry.sprite_id >= section[2] or archive.entries_by_id.has(entry.sprite_id):
				continue

			_add(archive, entry, false)

	return _tile_set(archive, "No DOS tile set sprites were found.")


static func mac(bytes: PackedByteArray) -> ScurkMif:
	var decoded := Sc2ImportSprites.mac_tile_set(bytes)
	var archive := Sc2SpriteArchive.new()

	for entry in decoded.archive.entries:
		_add(archive, entry, true)

	return _tile_set(archive, decoded.error if not decoded.error.is_empty() else "No Macintosh tile set sprites were found.")


# The sc2kfix DOS and Macintosh palette table (L_InitDOSMacPaletteIdxTable)
# for DOS pixels. Index 232 uses the static colour 0x34, as sc2kfix does for
# a sprite other than Hangar 1. sc2kfix maps index 1 to 0; the Windows copies
# of the DOS tile sets use 17, as for the other indices below 204.
static func dos_index(index: int) -> int:
	if index < 0:
		return index

	if index < 204:
		return index + 16

	if index < 210:
		return 0x0a + index - 204

	if index < 224:
		return 0xe8 + index - 210

	if index < 232:
		return index

	if index == 232:
		return 0x34

	if index < 240:
		return 0xb3 + index - 232

	return 0xff if index == 255 else 0


# Macintosh pixels: 0xfc is the transparent-looking 0x61, and 0xff is black.
static func mac_index(index: int) -> int:
	if index == 0xfc:
		return 0x61

	if index == 0xff:
		return 0

	return dos_index(index)


# The sprite files of a DOS tile set, by name. Each directory entry holds a
# 12-byte name and a little-endian offset; a file ends at the next offset.
static func _dos_files(bytes: PackedByteArray) -> Dictionary[String, PackedByteArray]:
	var entries: Array[Array] = []
	var position := 0
	var data_start := bytes.size()

	while position + DOS_DIRECTORY_ENTRY <= mini(data_start, bytes.size()):
		var name := bytes.slice(position, position + DOS_NAME_LENGTH).get_string_from_ascii()
		var offset := int(bytes.decode_u32(position + DOS_NAME_LENGTH))

		if name.is_empty() or offset > bytes.size():
			break

		entries.append([name.to_upper(), offset])
		data_start = mini(data_start, offset)
		position += DOS_DIRECTORY_ENTRY

	var files: Dictionary[String, PackedByteArray] = {}

	for index in entries.size():
		var end: int = entries[index + 1][1] if index + 1 < entries.size() else bytes.size()
		files[entries[index][0]] = bytes.slice(entries[index][1], maxi(entries[index][1], end))

	return files


static func _add(archive: Sc2SpriteArchive, entry: Sc2SpriteArchive.SpriteEntry, macintosh: bool) -> void:
	if entry.height < MIN_HEIGHT:
		return

	var decoded := entry.decode_indices()

	if not decoded.ok:
		return

	var pixels := decoded.pixels

	for index in pixels.size():
		pixels[index] = mac_index(pixels[index]) if macintosh else dos_index(pixels[index])

	var converted := Sc2SpriteArchive.entry_from_indices(entry.sprite_id, entry.width, entry.height, pixels)

	if converted != null:
		archive.entries.append(converted)
		archive.entries_by_id[converted.sprite_id] = converted


# A tile set for the city view. Its INFO tag selects the sc2kfix DOS colours.
static func _tile_set(archive: Sc2SpriteArchive, error: String) -> ScurkMif:
	var tile_set := ScurkMif.new()

	if archive.entries.is_empty():
		tile_set.parse_error = error

		return tile_set

	tile_set.info_payload.resize(ScurkMif.INFO_LENGTH)
	tile_set.info_payload.encode_u32(0, ScurkMif.SC2KFIX_REVISION.to_ascii_buffer().decode_u32(0))
	tile_set.archive = archive
	tile_set.overrides = archive
	tile_set.shapes.assign(archive.entries)

	return tile_set
