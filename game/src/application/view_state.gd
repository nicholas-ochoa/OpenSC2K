class_name ViewState
extends RefCounted


var overlay_mode := CityViewMode.Mode.CITY
var surface_visibility := {
	"buildings": true,
	"networks": true,
	"water": true,
	"trees": true,
	"zones": true,
	"signs": true,
}
# display layer for vehicles. hidden vehicles also make no sound and cannot crash
var show_vehicles := true
var show_underground_water_mains := true
var show_underground_pipes := true
var show_underground_subways := true
# keyboard camera motion
var camera_tap := Vector2.ZERO
var camera_motion := preload("res://src/view/city_camera_motion.gd").new()
