class_name AboutDialog
extends AcceptDialog


func _ready() -> void:
	title = "About OpenSC2K"
	dialog_text = (
		"OpenSC2K is an open-source reimplementation of SimCity 2000 for Windows 95.\n\n"
		+ "It reads the original SC2 and SCN city formats. Original game data stays external to this project."
	)
	min_size = Vector2i(560, 250)
	exclusive = true
