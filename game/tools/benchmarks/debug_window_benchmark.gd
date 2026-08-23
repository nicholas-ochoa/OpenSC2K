extends "res://tools/benchmarks/fixture_paths.gd"

func _benchmark_initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var samples: Array[float] = []
	for batch in 12:
		var elapsed := 0

		for iteration in 30:
			var start := Time.get_ticks_usec()
			var overlay = load("res://src/debug/debug_overlay.tscn").instantiate()
			root.add_child(overlay)
			elapsed += Time.get_ticks_usec() - start
			overlay.free()

		if batch > 0:
			samples.append(float(elapsed) / 30.0)

	samples.sort()
	print("Debug creation usec batches: ", samples, " median: ", samples[5])
	quit()


static func fixture_paths() -> PackedStringArray:
	return PackedStringArray([
		"res://src/debug/debug_overlay.tscn",
	])
