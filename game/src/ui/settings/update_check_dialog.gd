class_name UpdateCheckDialog
extends AcceptDialog
## Shows the result of a check for a newer stable release.

signal download_requested(version: String, url: String)
signal skip_requested(version: String)

var skip_button: Button
var release_version := ""
var release_url := ""
var home: Node


func _ready() -> void:
	hide()
	theme = AppUiTheme.current()
	min_size = Vector2i(440, 150)
	exclusive = true
	dialog_autowrap = true
	home = get_parent()
	visibility_changed.connect(_return_home)
	skip_button = add_button("Skip this version", false, "skip")
	confirmed.connect(_on_confirmed)
	custom_action.connect(_on_custom_action)


func show_update(version: String, current_version: String, url: String) -> void:
	release_version = version
	release_url = url
	title = "Update Available"
	dialog_text = ("OpenSC2K %s is available. You have version %s.\n\n" +
		"Download the new release from GitHub, then install it.") % [version, current_version]
	get_ok_button().text = "Download"
	skip_button.show()
	_popup_above_modal()


func show_latest(current_version: String) -> void:
	_show_notice("No Update Available", "OpenSC2K %s is the latest release." % current_version)


func show_failure(message: String) -> void:
	_show_notice("Cannot Check for Updates", message)


func _show_notice(notice_title: String, message: String) -> void:
	release_version = ""
	release_url = ""
	title = notice_title
	dialog_text = message
	get_ok_button().text = "OK"
	skip_button.hide()
	_popup_above_modal()


# a check can finish while another modal window, such as settings, is open.
# a window can have only one exclusive child, so show this dialog as a child
# of the top modal window
func _popup_above_modal() -> void:
	var parent_window: Node = home
	var windows := get_tree().root.get_embedded_subwindows()

	for index in range(windows.size() - 1, -1, -1):
		if windows[index] != self and windows[index].exclusive:
			parent_window = windows[index]

			break

	if get_parent() != parent_window:
		reparent(parent_window, false)

	popup_centered()


# keep the dialog when a temporary parent window closes
func _return_home() -> void:
	if not visible and home != null and get_parent() != home:
		reparent.call_deferred(home, false)


func _on_confirmed() -> void:
	if not release_version.is_empty():
		download_requested.emit(release_version, release_url)


func _on_custom_action(action: StringName) -> void:
	if action == &"skip":
		hide()
		skip_requested.emit(release_version)
