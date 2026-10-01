class_name DebugFileInfo
extends RefCounted
## The file format of the open city and the facts about its file, for the Debug
## window, the debug metrics and the city name tooltip.


# a short name of the file format
static func format_name(document: Sc2File) -> String:
	if document == null:
		return "No city"

	if document.is_sc2x():
		return "SC2X version 4"

	if document.is_extended():
		return "SCLG (SC2X version %d)" % document.large_version

	return "SC2 scenario" if document.find_chunk("SCEN") != null else "SC2"


# one line that says what the format means for saves
static func format_detail(document: Sc2File) -> String:
	if document == null:
		return ""

	if document.is_sc2x():
		return "OpenSC2K format. The original game cannot open it."

	if document.is_extended():
		return "Experimental format. A save writes SC2X version 4."

	return "Original game format. The original game can open a save."


static func fields(document: Sc2File, save_path := "") -> Dictionary:
	if document == null:
		return { "format": format_name(null) }

	var unknown := PackedStringArray()

	for chunk in document.chunks:
		if not NativeSimulationBridge.CHUNK_IDS.has(chunk.chunk_id) and not unknown.has(chunk.chunk_id):
			unknown.append(chunk.chunk_id)

	return {
		"format": format_name(document),
		"format_detail": format_detail(document),
		"map_size": document.map_size,
		"extended_limits": document.is_extended(),
		"full_resolution_maps": document.full_resolution_maps(),
		"chunks": document.chunks.size(),
		"unknown_chunks": ", ".join(unknown) if not unknown.is_empty() else "None",
		"preserved_sc2x_entries": document.sc2x_preserved.size() + document.sc2x_extra_entries.size(),
		"source_path": document.source_path if not document.source_path.is_empty() else "Not saved",
		"save_path": save_path if not save_path.is_empty() else "Not saved",
		"converted_from": document.sc2x_converted_from if not document.sc2x_converted_from.is_empty() else "None",
	}


# the city name tooltip of the menu bar
static func city_tooltip(display_name: String, document: Sc2File) -> String:
	if document == null:
		return display_name

	return "%s\nFile format: %s. %s" % [display_name, format_name(document), format_detail(document)]
