class_name ScurkSessionState
extends RefCounted


const ScurkHistory = preload("res://src/tools/scurk/scurk_edit_history.gd")

var edit_history := ScurkHistory.new()
var pending_print_options: Dictionary = {}
