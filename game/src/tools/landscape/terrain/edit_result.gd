class_name TerrainEditResult
extends EditCommandResult
# level, raise, or lower terrain, and the terrain-editor landscape actions
# a paint-brush drag merges its strokes into one undo

var target_altitude := -1
var action_count := 0
# tiles left alone: structure conflicts, and tiles past the available funds
var skipped_conflicts := 0
var skipped_insufficient := 0
# undo checks and restores the tool random state only when it was drawn
var random_used := false


static func rejected(message: String, charged := 0) -> TerrainEditResult:
	var result := TerrainEditResult.new()
	result.error = message
	result.cost = charged

	return result


func _merge_counts(stroke: EditCommandResult) -> void:
	var terrain := stroke as TerrainEditResult
	action_count += terrain.action_count
	skipped_insufficient += terrain.skipped_insufficient
	random_used = random_used or terrain.random_used
