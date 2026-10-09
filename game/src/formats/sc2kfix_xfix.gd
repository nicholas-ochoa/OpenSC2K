class_name Sc2kfixXfix
extends RefCounted
## The XFIX chunk that sc2kfix writes into SC2 files and sc2kfix archives. It
## is JSON text with a terminating null byte. The city keeps it unchanged as an
## unknown chunk. `map.tilesets` lists the SCURK tile sets that sc2kfix loads,
## in order, with the city.


# The parsed XFIX chunk of `document`, or an empty dictionary.
static func read(document: Sc2File) -> Dictionary:
	var chunk := document.find_chunk("XFIX") if document != null else null

	if chunk == null:
		return {}

	var bytes := chunk.decoded_payload
	var end := bytes.size()

	while end > 0 and bytes[end - 1] == 0:
		end -= 1

	var parsed: Variant = JSON.parse_string(bytes.slice(0, end).get_string_from_utf8())

	return parsed if parsed is Dictionary else {}


# The tile set paths of the XFIX chunk, in load order.
static func tile_set_paths(document: Sc2File) -> PackedStringArray:
	var result := PackedStringArray()
	var map: Variant = read(document).get("map")

	if not map is Dictionary or not map.get("tilesets") is Array:
		return result

	for path: Variant in map.tilesets:
		if path is String and not path.is_empty():
			result.append(path)

	return result


# A saved Windows path names a file on another computer. Use it when it
# exists, else find its file name, in any letter case, in `directories`.
static func resolve_tile_set(saved_path: String, directories: PackedStringArray) -> String:
	if FileAccess.file_exists(saved_path):
		return saved_path

	var file_name := saved_path.replace("\\", "/").get_file().to_lower()

	if file_name.is_empty():
		return ""

	for directory in directories:
		if directory.is_empty() or not DirAccess.dir_exists_absolute(directory):
			continue

		for candidate in DirAccess.get_files_at(directory):
			if candidate.to_lower() == file_name:
				return directory.path_join(candidate)

	return ""
