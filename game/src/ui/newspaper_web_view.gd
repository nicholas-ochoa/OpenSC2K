class_name NewspaperWebView
extends Node

signal action_requested(action: Dictionary)
var view: Control
var payload: Dictionary = {}
var ready_for_data := false
var diagnostics: Dictionary = {}

static func supported() -> bool:
	return DisplayServer.get_name() != "headless" and ClassDB.class_exists("WebView")

func open(data: Dictionary) -> void:
	payload = data
	if not supported():
		return
	if view == null:
		view = ClassDB.instantiate("WebView") as Control
		view.set("url", "")
		view.set("html", FileAccess.get_file_as_string("res://assets/newspaper/newspaper.html"))
		view.set("full_window_size", true)
		view.set("forward_input_events", false)
		view.set("incognito", true)
		view.set("devtools", false)
		view.connect("ipc_message", _on_message)
		add_child(view)
		view.call("zoom", DisplayServer.screen_get_scale())
	else:
		view.call("set_visible", true)
		_send_data()

func close() -> void:
	if view != null:
		view.call("set_visible", false)
		view.call("focus_parent")

func _send_data() -> void:
	if ready_for_data and view != null:
		view.call("post_message", JSON.stringify(payload))

func _on_message(message: String) -> void:
	var decoder := JSON.new()
	if decoder.parse(message) != OK:
		return
	var parsed: Variant = decoder.data
	if not parsed is Dictionary:
		return
	match str(parsed.get("action", "")):
		"ready":
			ready_for_data = true
			call_deferred("_send_data")
		"metrics":
			diagnostics = parsed
		_:
			action_requested.emit.call_deferred(parsed)
