class_name AppTooltips
extends Node


func _ready() -> void:
	get_tree().node_added.connect(_node_added)


func _node_added(node: Node) -> void:
	if node is PopupPanel and node.theme_type_variation == &"TooltipPanel":
		_bind_popup.call_deferred(weakref(node))
	elif node is PanelContainer and node.theme_type_variation == &"TooltipPanel":
		_bind_panel.call_deferred(weakref(node))


func _bind_popup(reference: WeakRef) -> void:
	var popup := reference.get_ref() as PopupPanel
	if popup == null or not popup.is_inside_tree():
		return
	var effect := preload("res://src/ui/shared/frosted_tooltip.gd").new()
	popup.add_child(effect)


func _bind_panel(reference: WeakRef) -> void:
	var panel := reference.get_ref() as PanelContainer
	if panel != null and panel.is_inside_tree():
		FrostedTooltipPanel.bind(panel)
