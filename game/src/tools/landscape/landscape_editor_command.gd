class_name LandscapeEditorCommand
extends RefCounted
# Terrain editor actions: stretch, sea level, forest, and stream. Each is one
# undo unit. The native simulation library runs them; see
# native/simulation/src/sim/tools/commands/landscape_editor.rs.


static func supports_tool(group: int, subtool: int) -> bool:
	return ((group == CityToolIds.Group.BULLDOZER
		and subtool in [CityToolIds.Bulldozer.STRETCH, CityToolIds.Bulldozer.RAISE_SEA, CityToolIds.Bulldozer.LOWER_SEA])
		or (group == CityToolIds.Group.LANDSCAPE and subtool in [CityToolIds.Landscape.STREAM, CityToolIds.Landscape.FOREST]))


static func apply(city: CityState, group: int, subtool: int, point: Vector2i, random: SimRandom, stretch_levels := 1) -> TerrainEditResult:
	if city == null or not supports_tool(group, subtool) or city.index_of(point.x, point.y) < 0:
		return TerrainEditResult.rejected("invalid landscape edit")

	var args := {"group": group, "subtool": subtool, "point": point, "stretch_levels": stretch_levels}
	var ids := PackedStringArray()

	# the edit may change any chunk; the result keeps the ones that changed
	for chunk in city.document.chunks:
		if chunk.chunk_id in NativeSimulationBridge.CHUNK_IDS:
			ids.append(chunk.chunk_id)

	var result: TerrainEditResult = NativeToolEdit.run("tool.landscape_editor", city, args, ids, random)

	if result.ok:
		result.retain_changed_payloads()

	return result
