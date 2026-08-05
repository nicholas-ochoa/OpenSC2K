class_name RouteEditResult
extends EditCommandResult
# road, rail, power line, subway, pipe, or highway route. networkdragcommand
# joins bridge-separated segments into one result and one undo. network
# routes use the tile fields; highways use the 2 by 2 section fields

# network tool mode, or -1 for a highway
var mode := -1
# snapped highway anchors
var start := Vector2i(-1, -1)
var finish := Vector2i(-1, -1)

# route tiles or highway sections, without and with bridge spans
var dry_points: Array[Vector2i] = []
var sections: Array[Vector2i] = []
var bridge_points: Array[Vector2i] = []
var bridge_sections: Array[Vector2i] = []
var bridge_endpoint_sections: Array[Vector2i] = []

# route cost without bridges or connections. network routes price tiles;
# highways price sections
var dry_cost := 0
var listed_dry_cost := 0
var route_cost := 0
var listed_route_cost := 0
var graded_tiles := 0
var graded_sections := 0

var bridge_built := false
var bridge_count := 0
var bridge_exit := Vector2i(-1, -1)
var bridge_type := -1
var bridge_name := ""
var bridge_cancelled := false
var bridge_span_length := 0
var bridge_cost := 0
var listed_bridge_cost := 0
var bridge_error := ""

# a route that leaves the map can connect to a neighboring city
var connection_anchor := Vector2i(-1, -1)
var connection_built := false
var connection_cancelled := false
var connection_cost := 0
var listed_connection_cost := 0
var connection_error := ""

var stopped_early := false
var continuation_error := ""

# the route waits for a player choice. the city is unchanged
var bridge_selection_required := false
var bridge_choices: Array[Dictionary] = []
var connection_selection_required := false
var cancelled := false


static func rejected(message: String, charged := 0) -> RouteEditResult:
	var result := RouteEditResult.new()
	result.error = message
	result.cost = charged

	return result


# add the next bridge-separated segment. the first segment starts the route
func merge_segment(segment: RouteEditResult) -> void:
	for field in ["cost", "listed_cost", "dry_cost", "listed_dry_cost", "route_cost", "listed_route_cost", "bridge_cost", "listed_bridge_cost", "bridge_span_length", "graded_tiles", "graded_sections", "connection_cost", "listed_connection_cost"]:
		set(field, int(get(field)) + int(segment.get(field)))

	for field in ["points", "dry_points", "bridge_points", "sections", "tile_indices", "bridge_sections", "bridge_endpoint_sections"]:
		var merged: Variant = get(field)

		for point: Variant in segment.get(field):
			if not merged.has(point):
				merged.append(point)

	bridge_built = bridge_built or segment.bridge_built
	bridge_cancelled = bridge_cancelled or segment.bridge_cancelled
	connection_built = connection_built or segment.connection_built
	connection_cancelled = connection_cancelled or segment.connection_cancelled
	connection_anchor = segment.connection_anchor
	connection_error = segment.connection_error
	stopped_early = segment.stopped_early

	if not segment.bridge_error.is_empty():
		continuation_error = segment.bridge_error

	bridge_count += int(segment.bridge_built)
	new_payloads = segment.new_payloads
