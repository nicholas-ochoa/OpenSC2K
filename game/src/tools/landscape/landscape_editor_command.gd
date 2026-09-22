class_name LandscapeEditorCommand
extends RefCounted

@warning_ignore_start("integer_division")


# editor-only operations. work on a private document and publish one undo unit
static func supports_tool(group: int, subtool: int) -> bool:
	return (group == CityToolIds.Group.BULLDOZER and subtool in [CityToolIds.Bulldozer.STRETCH, CityToolIds.Bulldozer.RAISE_SEA, CityToolIds.Bulldozer.LOWER_SEA]) or (group == CityToolIds.Group.LANDSCAPE and subtool in [CityToolIds.Landscape.STREAM, CityToolIds.Landscape.FOREST])


static func apply(city: CityState, group: int, subtool: int, point: Vector2i, random: SimRandom, stretch_levels := 1) -> TerrainEditResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not supports_tool(group, subtool) or city.index_of(point.x, point.y) < 0:
		return TerrainEditResult.rejected("invalid landscape edit")

	var staged := CityState.from_document(city.document.duplicate_document())
	var staged_random := SimRandom.new(random.state)
	var before := random.state

	if group == CityToolIds.Group.BULLDOZER and subtool == CityToolIds.Bulldozer.STRETCH:
		for step in mini(31, absi(stretch_levels)):
			var result := TerrainCommand.apply_path(staged, CityToolIds.Group.BULLDOZER, CityToolIds.Bulldozer.RAISE if stretch_levels > 0 else CityToolIds.Bulldozer.LOWER, point, [point], staged_random, true)

			if not result.ok:
				break
	elif group == CityToolIds.Group.LANDSCAPE and subtool == CityToolIds.Landscape.FOREST:
		var points: Array[Vector2i] = []

		for x in range(-3, 4):
			for y in range(-3, 4):
				if x * x + y * y <= 10:
					points.append(point + Vector2i(x + 3, y + 3))

		for pass_index in 3:
			LandscapeCommand.apply_path(staged, CityToolIds.Group.LANDSCAPE, CityToolIds.Landscape.TREES, points, staged_random, true)
	else:
		var payloads := {}

		for id in ["ALTM", "XBLD", "XTER", "XZON", "XBIT", "XTXT", "MISC"]:
			payloads[id] = staged.document.find_chunk(id).decoded_payload.duplicate()

		if group == CityToolIds.Group.LANDSCAPE:
			var previous_terrain: PackedByteArray = payloads.XTER.duplicate()
			var previous_flags: PackedByteArray = payloads.XBIT.duplicate()
			NewTerrainSurface._make_stream(payloads.ALTM, payloads.XBLD, payloads.XTER, payloads.XZON, payloads.XBIT, payloads.XTXT, payloads.MISC,
					point, 128, staged_random, map_edge)
			_finish_stream_slopes(payloads, previous_terrain, previous_flags, map_edge)
		else:
			var sea := clampi(staged.document.misc_u32(Sc2MiscLayout.WATER_LEVEL) + (1 if subtool == CityToolIds.Bulldozer.RAISE_SEA else -1), 0, 31)
			BinaryData.write_u32_be(payloads.MISC, Sc2MiscLayout.WATER_LEVEL, sea)
			var indices := PackedInt32Array()

			for index in (map_edge * map_edge):
				indices.append(index)

			TerrainRetile.retile_region(payloads.ALTM, payloads.XBLD, payloads.XTER, payloads.XZON, payloads.XBIT, payloads.MISC, indices, sea, map_edge)

		for id in payloads:
			staged.document.find_chunk(id).set_decoded_payload(payloads[id])

	var old_payloads: Dictionary[String, PackedByteArray] = {}
	var new_payloads: Dictionary[String, PackedByteArray] = {}
	var changed := PackedStringArray()

	for chunk in city.document.chunks:
		var next := staged.document.find_chunk(chunk.chunk_id)

		if next != null and chunk.decoded_payload != next.decoded_payload:
			changed.append(chunk.chunk_id)
			old_payloads[chunk.chunk_id] = chunk.decoded_payload.duplicate()
			new_payloads[chunk.chunk_id] = next.decoded_payload.duplicate()

	if changed.is_empty():
		return TerrainEditResult.rejected("no eligible terrain changed")

	if not NetworkState._apply_payloads(city, changed, new_payloads, old_payloads):
		return TerrainEditResult.rejected("cannot store landscape edit")

	random.state = staged_random.state
	var indices := PackedInt32Array()

	for index in (map_edge * map_edge):
		indices.append(index)

	var command := TerrainEditResult.new()
	command.ok = true
	command.command_type = "terrain"
	command.group_index = group
	command.subtool_index = subtool
	command.tile_indices = indices
	command.action_count = 1
	command.free_mode = true
	command.changed_ids = changed
	command.old_payloads = old_payloads
	command.new_payloads = new_payloads
	command.random_used = before != random.state
	command.tracks_random = true
	command.random_state_before = before
	command.random_state_after = random.state

	return command


static func _finish_stream_slopes(payloads: Dictionary, previous_terrain: PackedByteArray, previous_flags: PackedByteArray, map_edge: int = 128) -> void:
	# editor repair only: preserve the recovered generator's path and rng order
	var terrain: PackedByteArray = payloads.XTER
	var flags: PackedByteArray = payloads.XBIT
	var altitude: PackedByteArray = payloads.ALTM

	for index in (map_edge * map_edge):
		if terrain[index] == previous_terrain[index] and flags[index] == previous_flags[index]:
			continue

		if terrain[index] < TerrainTileIds.SURFACE_WATER_FIRST or terrain[index] > TerrainTileIds.CHANNEL_LAST or not flags[index] & 4:
			continue

		var point := Vector2i(index / map_edge, index % map_edge)
		var height := TerrainEditHeights.land_altitude(altitude, index)

		for delta in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var near: Vector2i = point + delta

			if TerrainEditHeights._point_is_in_bounds(near, map_edge) and TerrainEditHeights.land_altitude(altitude, near.x * map_edge + near.y) > height:
				terrain[index] = TerrainTileIds.WATERFALL
				break
