class_name OriginalCompatibility
extends RefCounted
# one policy for original-format loading, creation, and saving

const EXTENDED_ERROR := "Original SimCity 2000 compatibility is enabled. SC2X cities cannot be saved in this mode. Opening an SC2X city turns this option off automatically."

static func document_error(document: Sc2File, enabled: bool) -> String:
	if not enabled or document == null:
		return ""
	if document.is_extended():
		return EXTENDED_ERROR
	# An original container header can still hold an extended city. Check payload sizes too.
	for id in Sc2File.FULL_MAP_CHUNKS + Sc2File.HALF_MAP_CHUNKS + Sc2File.QUARTER_MAP_CHUNKS + ["XMIC", "XTHG", "XLAB"]:
		var chunk := document.find_chunk(id)
		if chunk != null and chunk.decoded_payload.size() != int(Sc2File.DECODED_SIZES.get(id, -1)):
			return "City data uses an extended %s layout. Turn off original compatibility to use this city." % id
	return ""

static func save_error(document: Sc2File, path: String, enabled: bool) -> String:
	var error := document_error(document, enabled)
	if not error.is_empty() or not enabled:
		return error
	var extension := path.get_extension().to_lower()
	if extension not in ["", "sc2"] and not (extension == "scn" and document != null and document.find_chunk("SCEN") != null):
		return "Original compatibility requires an SC2 city file or an SCN scenario file."
	return ""

static func terrain_options(options: Dictionary, enabled: bool) -> Dictionary:
	var result := options.duplicate()
	if enabled:
		result.size = 128
		result.native_maps = false
	return result
