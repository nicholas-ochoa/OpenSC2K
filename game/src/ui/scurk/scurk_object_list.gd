class_name ScurkObjectList
extends ItemList

signal objects_dropped(large_ids: PackedInt32Array, destination_id: int)

var drag_source := false
var drop_target := false
var remap_drops := false


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
		multi_selected.emit(item_index, true)

	var large_ids := selected_large_ids()

	if large_ids.is_empty():
		return null

	var preview := PanelContainer.new()
	var content := VBoxContainer.new()
	var artwork := TextureRect.new()
	artwork.custom_minimum_size = Vector2(88, 88)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	artwork.texture = get_item_icon(item_index)
	var preview_label := Label.new()
	preview_label.text = (
		"Copy object %d" % ScurkEditorRules.object_tile_id(large_ids[0])
		if large_ids.size() == 1
		else "Copy %d objects" % large_ids.size()
	)
	preview.add_child(content)
	content.add_child(artwork)
	content.add_child(preview_label)
	set_drag_preview(preview)

	return CopyObjectsDrag.new(get_instance_id(), large_ids)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not drop_target or not data is CopyObjectsDrag or data.large_ids.is_empty():
		return false
	if not remap_drops:
		return true
	var index := get_item_at_position(at_position, true)
	return (data.large_ids.size() == 1 and index >= 0
		and ScurkPickCopy.can_copy_to(data.large_ids[0], int(get_item_metadata(index))))


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return

	var destination_id := int(get_item_metadata(get_item_at_position(at_position, true))) if remap_drops else -1
	objects_dropped.emit(data.large_ids, destination_id)


class CopyObjectsDrag extends RefCounted:
	var source_instance: int
	var large_ids: PackedInt32Array

	func _init(source: int, ids: PackedInt32Array) -> void:
		source_instance = source
		large_ids = ids
