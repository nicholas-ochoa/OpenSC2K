extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var resource = load(OS.get_cmdline_user_args()[0])
	var samples: Array[float] = []
	for batch in 12:
		var elapsed := 0

		for iteration in 100:
			var start := Time.get_ticks_usec()
			var dialog = resource.instantiate() if resource is PackedScene else resource.new()
			root.add_child(dialog)
			elapsed += Time.get_ticks_usec() - start
			dialog.free()

		if batch > 0:
			samples.append(float(elapsed) / 100.0)

	samples.sort()
	print("Creation usec: ", samples, " median: ", samples[5])
	quit()
