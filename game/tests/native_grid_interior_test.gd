extends SceneTree
const Reference = preload("res://tests/support/native_grid_reference.gd")


func _initialize() -> void:
	for edge in [1, 3, 8, 17, 128, 256, 384, 512]:
		var values := PackedInt32Array()
		values.resize(edge * edge)

		for index in values.size():
			values[index] = [-2147483648, 2147483647, -991, 0, 1024, 127][index % 6]

		# One/two-ring interiors, clipped rims, overlapping rims and fallback rings.
		for parameters in [[1, 1], [1, 2], [4, 1], [2, 2], [2, 3], [0, 2]]:
			var step: int = parameters[0]
			var rings: int = parameters[1]
			var expected := Reference.smooth(values, edge, 3, 3, step, rings)
			assert(NativeGridMath.smooth(values, edge, 3, 3, step, rings) == expected)
			var actual := NativeGridMath.smooth_bytes(values, edge, 3, 3, step, rings)
			var expected_bytes := Reference.bytes(expected)
			assert(actual.values == expected_bytes)
			var total := 0

			for value in expected_bytes:
				total += value

			assert(actual.total == total, "Byte total differs after clipping and signed division")

		print("PASS: signed smoothing, borders and byte totals at %d" % edge)

	quit()
