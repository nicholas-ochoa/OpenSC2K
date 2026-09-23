class_name FrostedTooltipPanel
extends Node

const GlassShader = preload("res://src/ui/shared/frosted_panel.gdshader")
const BINDING_META := &"_frosted_tooltip_panel"

var _panel: PanelContainer
var _background_copy: BackBufferCopy
var _glass: ShaderMaterial
var _original_material: Material


static func bind(panel: PanelContainer) -> void:
	if panel.has_meta(BINDING_META) and is_instance_valid(panel.get_meta(BINDING_META)):
		return
	var binding := FrostedTooltipPanel.new()
	panel.set_meta(BINDING_META, binding)
	panel.add_child(binding)


func _ready() -> void:
	_panel = get_parent() as PanelContainer
	_original_material = _panel.material
	_glass = ShaderMaterial.new()
	_glass.shader = GlassShader
	_background_copy = BackBufferCopy.new()
	_background_copy.show_behind_parent = true
	_background_copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	_panel.add_child(_background_copy)
	_panel.use_parent_material = false
	for child in _panel.get_children():
		if child is CanvasItem:
			child.use_parent_material = false
	_panel.visibility_changed.connect(_refresh)
	_panel.theme_changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if not is_instance_valid(_panel):
		return
	if _panel.material == _glass:
		_panel.material = _original_material
	if _panel.has_meta(BINDING_META) and _panel.get_meta(BINDING_META) == self:
		_panel.remove_meta(BINDING_META)
	for signal_value in [_panel.visibility_changed, _panel.theme_changed]:
		if signal_value.is_connected(_refresh):
			signal_value.disconnect(_refresh)
	if is_instance_valid(_background_copy):
		_background_copy.queue_free()


func _refresh() -> void:
	var enabled := _panel.is_visible_in_tree() and AppUiTheme.translucent_menus
	_panel.material = _glass if enabled else _original_material
	# copy the viewport so the blur mipmaps are valid
	_background_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if enabled else BackBufferCopy.COPY_MODE_DISABLED
