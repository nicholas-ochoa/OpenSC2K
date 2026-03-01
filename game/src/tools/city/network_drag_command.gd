class_name NetworkDragCommand
extends RefCounted



static func apply(
	city: CityState, group: int, tool: int, start: Vector2i, finish: Vector2i,
	bridge: int, connection: int, free_mode: bool, highway: bool
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}

	var working := CityState.copy_for_edit(city)
	var endpoint := HighwayCommand.snap_anchor(finish) if highway else finish
	var cursor := HighwayCommand.snap_anchor(start) if highway else start
	var bounds := Rect2i(cursor.min(endpoint), (endpoint - cursor).abs() + Vector2i.ONE)
	var visited := {}
	var combined := {}

	while not visited.has(cursor):
		visited[cursor] = true
		var selected_bridge := bridge if combined.is_empty() else -1
		var selected_connection := -1
		var segment: Dictionary

		for attempt in 3:
			segment = HighwayCommand.apply_segment(working, group, tool, cursor, endpoint, selected_connection, selected_bridge, free_mode) if highway else NetworkCommand.apply_segment(working, group, tool, cursor, endpoint, selected_bridge, selected_connection, free_mode)

			if segment.get("bridge_selection_required", false) and bridge != -1:
				selected_bridge = bridge
			elif segment.get("connection_selection_required", false) and connection != -1:
				selected_connection = connection
			else:
				break

		if not segment.get("ok", false):
			if combined.is_empty():
				return segment

			if segment.get("bridge_selection_required", false) or segment.get("connection_selection_required", false):
				# Wait for confirmation before committing any segment, including earlier spans.
				var price_key := "route_cost" if highway else "dry_cost"
				segment[price_key] = int(segment.get(price_key, 0)) + int(combined.cost)

				return segment

			combined["continuation_error"] = segment.get("error", "route is blocked")
			combined["stopped_early"] = true
			break

		if combined.is_empty() and connection == 1 and not segment.get("bridge_built", false) and not segment.get("connection_built", false):
			return {"ok": false, "error": "neighbor connection is not available"}

		_merge(combined, segment)

		if not segment.get("bridge_built", false):
			break

		var next: Vector2i = segment.bridge_exit

		# A bridge can end past the pointer over water. Stop there instead of routing back.
		if not bounds.has_point(next) or visited.has(next):
			break

		cursor = next

	if combined.is_empty():
		return {"ok": false, "error": "network route is empty"}

	var changed := PackedStringArray()
	for id: String in combined.new_payloads:
		if combined.new_payloads[id] != combined.old_payloads[id]:
			changed.append(id)

	if not NetworkCommand._apply_payloads(city, changed, combined.new_payloads, combined.old_payloads):
		return {"ok": false, "error": "cannot store network route"}

	combined.changed_ids = changed

	return combined


static func _merge(combined: Dictionary, segment: Dictionary) -> void:
	if combined.is_empty():
		combined.merge(segment)
		combined["bridge_count"] = int(segment.get("bridge_built", false))

		return

	for key in ["cost", "listed_cost", "dry_cost", "listed_dry_cost", "route_cost", "listed_route_cost", "bridge_cost", "listed_bridge_cost", "bridge_span_length", "graded_tiles", "graded_sections", "connection_cost", "listed_connection_cost"]:
		combined[key] = int(combined.get(key, 0)) + int(segment.get(key, 0))

	for key in ["points", "dry_points", "bridge_points", "sections", "tile_indices", "bridge_sections", "bridge_endpoint_sections"]:
		if not segment.has(key):
			continue

		for point in segment[key]:
			if not combined[key].has(point):
				combined[key].append(point)

	for key in ["bridge_built", "bridge_cancelled", "connection_built", "connection_cancelled"]:
		combined[key] = bool(combined.get(key, false)) or bool(segment.get(key, false))

	for key in ["connection_anchor", "connection_error", "stopped_early"]:
		combined[key] = segment.get(key, combined.get(key))

	if not String(segment.get("bridge_error", "")).is_empty():
		combined["continuation_error"] = segment.bridge_error

	combined.bridge_count += int(segment.get("bridge_built", false))
	combined.new_payloads = segment.new_payloads
