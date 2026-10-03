class_name ScurkSessionState
extends RefCounted

const ScurkHistory = preload("res://src/tools/scurk/scurk_edit_history.gd")

var edit_history := ScurkHistory.new()
var pending_print_options: ScurkCityOutput.Options
# the sidebar tool before Place & Print selected its edit tools, or -1, -1
var tool_before_place_print := Vector2i(-1, -1)
# translucent placement previews by tile ID and flip
var ghost_textures: Dictionary[Vector2i, Texture2D] = {}
# the history entry of the brush stroke in progress, or null
var brush_stroke: EditCommandResult
