class_name ScriptingUiApi
extends ScriptingApiBase
## The `ui` functions of scripts: message windows and sounds. Each script
## runtime has its own `game.storage`; see ScriptStorage. See docs/scripting.md.

# the newest message window
var last_alert: AcceptDialog


func handlers() -> Dictionary[String, Callable]:
	return {
		"ui.alert": _alert,
		"ui.playSound": _play_sound,
	}


# a message window with an OK button. The game continues while it shows
func _alert(arguments: Array) -> Variant:
	var dialog := AcceptDialog.new()
	dialog.theme = AppUiTheme.current()
	dialog.title = str(argument(arguments, 1, "Script"))
	dialog.dialog_text = str(argument(arguments, 0, ""))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	dialog.popup_centered()
	last_alert = dialog

	return null


# plays a sound of the sound pack: the number of SOUNDS/<id>.WAV
func _play_sound(arguments: Array) -> Variant:
	var id: Variant = argument(arguments, 0)

	if not is_number(id) or int(id) < 0:
		return fail("The sound must be a number, such as 500 for SOUNDS/500.WAV.")

	var ids: Array[int] = [int(id)]
	app.effects_audio.play_sound_ids(ids)

	return null
