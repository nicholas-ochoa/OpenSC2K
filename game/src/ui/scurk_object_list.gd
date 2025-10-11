class_name ScurkObjectList
extends ItemList

signal objects_dropped(large_ids: PackedInt32Array)

var drag_source := false
var drop_target := false


func selected_large_ids() -> PackedInt32Array:
	var result := PackedInt32Array()
	for item_index in get_selected_items():
		result.append(int(get_item_metadata(item_index)))
	return result


func _get_drag_data(at_position: Vector2) -> Variant:
	if not drag_source:
		return null
	var item_index := get_item_at_position(at_position, true)
	if item_index < 0:
		return null
	if not is_selected(item_index):
		deselect_all()
		select(item_index)
	var large_ids := selected_large_ids()
	if large_ids.is_empty():
		return null
	var preview := PanelContainer.new()
	var preview_label := Label.new()
	preview_label.text = (
		"Copy object %d" % (large_ids[0] - 1000)
		if large_ids.size() == 1
		else "Copy %d objects" % large_ids.size()
	)
	preview.add_child(preview_label)
	set_drag_preview(preview)
	return {
		"kind": "scurk_pick_copy_objects",
		"source_instance": get_instance_id(),
		"large_ids": large_ids,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		drop_target
		and data is Dictionary
		and data.get("kind", "") == "scurk_pick_copy_objects"
		and data.get("large_ids", PackedInt32Array()) is PackedInt32Array
		and not data.large_ids.is_empty()
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	objects_dropped.emit(data.large_ids)
