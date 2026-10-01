class_name DebugViewState
extends RefCounted
## The debug views that the Debug menu selects. Display state only: the city
## and its save file do not keep it.

enum ChangeBaseline { LOAD, SNAPSHOT, PREVIOUS_DAY }

var tile_layer := DebugTileLayers.Layer.NONE
var tile_values := false
var change_baseline := ChangeBaseline.LOAD
var region_bounds := false
var region_repaints := false
var occluders := false
var sprite_bounds := false
var thing_paths := false
var performance_hud := false


# true when a view needs per-frame or per-change work
func any_active() -> bool:
	return (tile_layer != DebugTileLayers.Layer.NONE or tile_values or region_bounds or region_repaints or occluders
		or sprite_bounds or thing_paths or performance_hud)


func reset() -> void:
	tile_layer = DebugTileLayers.Layer.NONE
	tile_values = false
	change_baseline = ChangeBaseline.LOAD
	region_bounds = false
	region_repaints = false
	occluders = false
	sprite_bounds = false
	thing_paths = false
	performance_hud = false
