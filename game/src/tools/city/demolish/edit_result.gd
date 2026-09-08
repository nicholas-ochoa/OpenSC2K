class_name DemolishEditResult
extends EditCommandResult


var underground_view := false
var scurk_mode := false
var action_count := 0

var skipped_specialized := 0
var skipped_insufficient := 0
# forest protests keep the tree and add a saved news story
var easter_events := 0
var news_items: Array[NewsEvent] = []
var news_queue_updated := false


func copy() -> EditCommandResult:
	var result := super.copy() as DemolishEditResult
	result.news_items = NewsEvent.copy_all(news_items)

	return result


static func rejected(message: String, charged := 0) -> DemolishEditResult:
	var result := DemolishEditResult.new()
	result.error = message
	result.cost = charged

	return result


func _merge_counts(stroke: EditCommandResult) -> void:
	var demolition := stroke as DemolishEditResult
	action_count += demolition.action_count
	easter_events += demolition.easter_events
	skipped_specialized += demolition.skipped_specialized
	skipped_insufficient += demolition.skipped_insufficient
