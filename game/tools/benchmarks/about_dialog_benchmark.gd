extends "res://tools/benchmarks/fixture_paths.gd"

func _benchmark_initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var resource = load("res://src/ui/settings/about_dialog.tscn")
	var samples: Array[float] = []
	for batch in 12:
		var elapsed := 0

		for iteration in 100:
			var start := Time.get_ticks_usec()
			var dialog = resource.instantiate()
			root.add_child(dialog)
			elapsed += Time.get_ticks_usec() - start
			dialog.free()

		if batch > 0:
			samples.append(float(elapsed) / 100.0)

	samples.sort()
	print("About creation usec: ", samples, " median: ", samples[5])
	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		"res://src/ui/settings/about_dialog.tscn",
	])
