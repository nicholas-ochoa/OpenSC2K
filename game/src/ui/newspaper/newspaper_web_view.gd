class_name NewspaperWebView
extends Node

signal action_requested(action: Dictionary)
var view: Control
var payload: Dictionary = {}
var ready_for_data := false
var diagnostics: Dictionary = {}


static func supported() -> bool:
	return DisplayServer.get_name() != "headless" and ClassDB.class_exists("WebView")


static func html_document() -> String:
	var html := FileAccess.get_file_as_string("res://assets/newspaper/newspaper.html")
	var font := load("res://assets/fonts/anton/Anton-Regular.ttf") as FontFile
	html = html.replace("__NEWSPAPER_HEADLINE_FONT__", Marshalls.raw_to_base64(font.data))
	var mastheads := {
		"CHOMSKY": "res://assets/fonts/chomsky/Chomsky.otf",
		"GRENZE": "res://assets/fonts/grenzegotisch/GrenzeGotisch[wght].ttf",
		"MAGUNTIA": "res://assets/fonts/unifrakturmaguntia/UnifrakturMaguntia-Book.ttf",
	}

	for name in mastheads:
		var masthead := load(mastheads[name]) as FontFile
		html = html.replace("__NEWSPAPER_%s_FONT__" % name, Marshalls.raw_to_base64(masthead.data))

	return html


func open(data: Dictionary) -> void:
	payload = data

	if not supported():
		return

	if view == null:
		view = ClassDB.instantiate("WebView") as Control
		view.set("url", "")
		view.set("html", html_document())
		view.set("full_window_size", true)
		view.set("transparent", true)
		view.set("forward_input_events", false)
		view.set("incognito", true)
		view.set("devtools", false)
		view.connect("ipc_message", _on_message)
		add_child(view)
		view.call("zoom", page_zoom())
	else:
		# the interface scale can change between openings
		view.call("zoom", page_zoom())
		view.call("set_visible", true)
		_send_data()


# the page follows the display scale, and the UI scale choice reduces it the
# same way as the interface
func page_zoom() -> float:
	return DisplayServer.screen_get_scale() * AppUiScale.relative


func close() -> void:
	if view != null:
		# clear the old page before the native surface is shown on the next opening
		view.call("post_message", JSON.stringify({"action": "hide"}))
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
