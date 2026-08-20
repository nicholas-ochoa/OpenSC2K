class_name NewCityState
extends RefCounted


const NewCitySession = preload("res://src/model/new_city_terrain_session.gd")

var session := NewCitySession.new()
var preview_job: NewCityPreviewJob
# cancel returns to the main menu instead of the active city
var return_to_main_menu := false
