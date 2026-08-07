class_name NetworkDragCommand
extends RefCounted



static func apply(
	city: CityState, group: int, tool: int, start: Vector2i, finish: Vector2i,
	bridge: int, connection: int, free_mode: bool, highway: bool
) -> RouteEditResult:
	if city == null or not city.is_valid():
		return RouteEditResult.rejected("city is invalid")

	var working := CityState.copy_for_edit(city)
	var endpoint := HighwayGeometry.snap_anchor(finish) if highway else finish
	var cursor := HighwayGeometry.snap_anchor(start) if highway else start
	var bounds := Rect2i(cursor.min(endpoint), (endpoint - cursor).abs() + Vector2i.ONE)
	var visited := {}
	var combined: RouteEditResult = null

	while not visited.has(cursor):
		visited[cursor] = true
		var selected_bridge := bridge if combined == null else -1
		var selected_connection := -1
		var segment: RouteEditResult

		for attempt in 3:
			segment = HighwayEdit.apply_segment(working, group, tool, cursor, endpoint, selected_connection, selected_bridge, free_mode) if highway else NetworkEdit.apply_segment(working, group, tool, cursor, endpoint, selected_bridge, selected_connection, free_mode)

			if segment.bridge_selection_required and bridge != -1:
				selected_bridge = bridge
			elif segment.connection_selection_required and connection != -1:
				selected_connection = connection
			else:
				break

		if not segment.ok:
			if combined == null:
				return segment

			if segment.bridge_selection_required or segment.connection_selection_required:
				# Wait for confirmation before committing any segment, including earlier spans.
				if highway:
					segment.route_cost += combined.cost
				else:
					segment.dry_cost += combined.cost

				return segment

			combined.continuation_error = segment.error
			combined.stopped_early = true
			break

		if combined == null and connection == 1 and not segment.bridge_built and not segment.connection_built:
			return RouteEditResult.rejected("neighbor connection is not available")

		if combined == null:
			combined = segment
			combined.bridge_count = int(segment.bridge_built)
		else:
			combined.merge_segment(segment)

		if not segment.bridge_built:
			break

		var next := segment.bridge_exit

		# A bridge can end past the pointer over water. Stop there instead of routing back.
		if not bounds.has_point(next) or visited.has(next):
			break

		cursor = next

	if combined == null:
		return RouteEditResult.rejected("network route is empty")

	var changed := PackedStringArray()
	for id: String in combined.new_payloads:
		if combined.new_payloads[id] != combined.old_payloads[id]:
			changed.append(id)

	if not NetworkState._apply_payloads(city, changed, combined.new_payloads, combined.old_payloads):
		return RouteEditResult.rejected("cannot store network route")

	combined.changed_ids = changed

	return combined
