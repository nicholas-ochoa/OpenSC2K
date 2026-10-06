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

## The native assets library decodes the sprites; see
## native/core/assets/src/scurk/foreign.rs.

# a sprite of one row is a placeholder, as sc2kfix reads it
const MIN_HEIGHT := 2


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
	return NativeScurkMif.is_foreign_dos(bytes)


static func is_mac(bytes: PackedByteArray) -> bool:
	return NativeScurkMif.is_foreign_mac(bytes)


static func dos(bytes: PackedByteArray) -> ScurkMif:
	return _tile_set(NativeScurkMif.foreign_sprites(bytes, false))


static func mac(bytes: PackedByteArray) -> ScurkMif:
	return _tile_set(NativeScurkMif.foreign_sprites(bytes, true))


static func dos_index(index: int) -> int:
	return NativeScurkMif.foreign_dos_index(index)


static func mac_index(index: int) -> int:
	return NativeScurkMif.foreign_mac_index(index)


# A tile set for the city view. Its INFO tag selects the sc2kfix DOS colours.
static func _tile_set(decoded: Dictionary) -> ScurkMif:
	var tile_set := ScurkMif.new()

	if not str(decoded.error).is_empty():
		tile_set.parse_error = decoded.error

		return tile_set

	var archive := Sc2SpriteArchive.new()

	for sprite: Dictionary in decoded.sprites:
		var entry := Sc2SpriteArchive.entry_from_indices(sprite.sprite_id, sprite.width, sprite.height, sprite.pixels)
		archive.entries.append(entry)
		archive.entries_by_id[entry.sprite_id] = entry

	tile_set.info_payload.resize(ScurkMif.INFO_LENGTH)
	tile_set.info_payload.encode_u32(0, ScurkMif.SC2KFIX_REVISION.to_ascii_buffer().decode_u32(0))
	tile_set.archive = archive
	tile_set.overrides = archive
	tile_set.shapes.assign(archive.entries)

	return tile_set
