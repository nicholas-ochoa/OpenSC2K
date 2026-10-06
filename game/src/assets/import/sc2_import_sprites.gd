class_name Sc2ImportSprites
extends RefCounted
## Decode source sprite sets while retaining valid records from partial sets.

var archive := Sc2SpriteArchive.new()
var warnings := PackedStringArray()
var error := ""


# The native formats library decodes the sets; see
# native/core/assets/src/import/sprites.rs
static func mac_tile_set(data: PackedByteArray) -> Sc2ImportSprites:
	return _from_native(NativeSpriteImport.mac_tile_set(data))


static func tiles_database(data: PackedByteArray) -> Sc2ImportSprites:
	return _from_native(NativeSpriteImport.tiles_database(data))


static func dos(header: PackedByteArray, data: PackedByteArray) -> Sc2ImportSprites:
	return _from_native(NativeSpriteImport.dos(header, data))


static func _from_native(fields: Dictionary) -> Sc2ImportSprites:
	var result := Sc2ImportSprites.new()
	result.error = fields.error
	result.warnings = fields.warnings

	for sprite: Dictionary in fields.sprites:
		var entry: Sc2SpriteArchive.SpriteEntry

		if (sprite.indices as PackedInt32Array).is_empty():
			entry = Sc2SpriteArchive.SpriteEntry.new()
			entry.sprite_id = sprite.sprite_id
			entry.width = sprite.width
			entry.height = sprite.height
			entry.encoded_pixels = sprite.encoded
			entry.allow_unpadded_odd_runs = sprite.allow_unpadded_odd_runs
		else:
			entry = Sc2SpriteArchive.entry_from_indices(sprite.sprite_id, sprite.width, sprite.height, sprite.indices)

		result.archive.entries.append(entry)
		result.archive.entries_by_id[sprite.sprite_id] = entry

	return result
