extends "res://tools/benchmarks/fixture_paths.gd"


func _benchmark_initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var resource = load(input_path("res://src/ui/settings/about_dialog.tscn"))
	var drain_frames := "--drain-frames" in arguments
	var iterations := 30 if drain_frames else 100
	var samples: Array[float] = []

	for batch in 12:
		var elapsed := 0

		for iteration in iterations:
			var start := Time.get_ticks_usec()
			var dialog = resource.instantiate() if resource is PackedScene else resource.new()
			root.add_child(dialog)
			elapsed += Time.get_ticks_usec() - start
			dialog.free()

			if drain_frames:
				# Flush deferred layout after freeing each large control tree.
				await process_frame

		if batch > 0:
			samples.append(float(elapsed) / float(iterations))

	samples.sort()
	print("Creation usec: ", samples, " median: ", samples[5])
	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		input_path("res://src/ui/settings/about_dialog.tscn"),
	])
