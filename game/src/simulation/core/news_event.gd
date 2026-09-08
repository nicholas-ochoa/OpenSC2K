class_name NewsEvent
extends RefCounted
# a story or runtime report sent to the saved news queue and status bar
# the queue continues to reject types outside the saved story range

var type: int
var argument: int


func _init(news_type: int, news_argument := 0) -> void:
	type = news_type
	argument = news_argument


static func copy_all(items: Array[NewsEvent]) -> Array[NewsEvent]:
	var result: Array[NewsEvent] = []

	for item in items:
		result.append(NewsEvent.new(item.type, item.argument))

	return result


static func same_arrays(first: Array[NewsEvent], second: Array[NewsEvent]) -> bool:
	if first.size() != second.size():
		return false

	for index in first.size():
		if first[index].type != second[index].type or first[index].argument != second[index].argument:
			return false

	return true


static func contains(items: Array[NewsEvent], news_type: int, news_argument := 0) -> bool:
	for item in items:
		if item.type == news_type and item.argument == news_argument:
			return true

	return false
