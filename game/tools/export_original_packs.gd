extends SceneTree
## Export original media in archive order, without changing the source.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var source := ProjectSettings.globalize_path("res://../references/SIMCITY2000") if args.is_empty() else args[0]
	var destination := ProjectSettings.globalize_path("res://../ext") if args.size() < 2 else args[1]
	var result := OriginalPackExporter.new().export_packs(source, destination)
	if not result.ok:
		printerr(result.error)
	else:
		print("PASS: original graphics, 30 WAV sounds, and 19 MIDI tracks exported to " + destination)
	quit(0 if result.ok else 1)
