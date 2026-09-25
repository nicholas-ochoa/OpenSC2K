class_name OriginalCompatibility
extends RefCounted
# one policy for original-format saving and creation. the city file format
# selects the rules: SC2 and SCN cities keep the original format and timing,
# and SC2X cities use the extensions


static func uses_original_format(document: Sc2File) -> bool:
	return document != null and not document.is_extended()


static func document_error(document: Sc2File) -> String:
	if not uses_original_format(document):
		return ""

	# An original container header can still hold an extended city. Check payload sizes too.
	for id in Sc2File.FULL_MAP_CHUNKS + Sc2File.HALF_MAP_CHUNKS + Sc2File.QUARTER_MAP_CHUNKS + ["XMIC", "XTHG", "XLAB"]:
		var chunk := document.find_chunk(id)

		if chunk != null and chunk.decoded_payload.size() != int(Sc2File.DECODED_SIZES.get(id, -1)):
			return "City data uses an extended %s layout that an SC2 file cannot hold." % id

	return ""


static func save_error(document: Sc2File, path: String) -> String:
	var error := document_error(document)

	if not error.is_empty() or not uses_original_format(document):
		return error

	var extension := path.get_extension().to_lower()

	if extension not in ["", "sc2"] and not (extension == "scn" and document.find_chunk("SCEN") != null):
		return "An SC2 city must use an SC2 file, or an SCN file for a scenario."

	return ""


# an original city uses the 128 × 128 map and original data maps. other cities
# use per-tile data maps and the SC2X format
static func terrain_options(options: NewCityTerrain.Options, original: bool) -> NewCityTerrain.Options:
	var result := options.copy()
	result.native_maps = not original

	if original:
		result.size = 128

	return result
