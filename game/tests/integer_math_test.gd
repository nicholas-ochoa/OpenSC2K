extends SceneTree


func _init() -> void:
	# Explicit expected values keep this independent of the helper's operator.
	var cases := [
		[7, 3, 2], [-7, 3, -2], [7, -3, -2], [-7, -3, 2],
		[1, 3, 0], [-1, 3, 0], [0, 3, 0], [12, 3, 4],
		[9007199254740993, 1, 9007199254740993],
		[9223372036854775807, 3, 3074457345618258602],
		[-9223372036854775807, 3, -3074457345618258602],
		[-9223372036854775807 - 1, 2, -4611686018427387904],
	]
	for values in cases:
		assert(IntegerMath.div_trunc(values[0], values[1]) == values[2])

	# Preserve intermediate truncation and left-to-right division.
	assert(IntegerMath.div_trunc(7, 3) * 3 == 6)
	assert(IntegerMath.div_trunc(IntegerMath.div_trunc(17, 3), 2) == 2)
	assert(IntegerMath.div_trunc_vec2i(Vector2i(-7, 7), 3) == Vector2i(-2, 2))
	assert(IntegerMath.div_trunc_vec2i(Vector2i(-7, 7), -3) == Vector2i(2, -2))
	print("PASS: integer division signs, truncation, 64-bit precision and nesting")
	quit()
