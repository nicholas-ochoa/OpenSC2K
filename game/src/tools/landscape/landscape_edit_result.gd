class_name LandscapeEditResult
extends EditCommandResult
# trees, forest, water, and stream paths. a paint-brush drag merges its
# strokes into one undo


var skipped_insufficient := 0


static func rejected(message: String, charged := 0) -> LandscapeEditResult:
	var result := LandscapeEditResult.new()
	result.error = message
	result.cost = charged

	return result


func _merge_counts(stroke: EditCommandResult) -> void:
	skipped_insufficient += (stroke as LandscapeEditResult).skipped_insufficient
