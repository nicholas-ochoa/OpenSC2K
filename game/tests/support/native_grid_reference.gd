
@warning_ignore_start("integer_division")

# Frozen pre-optimization oracle from e5f6abd9; used only by regression tests.
extends RefCounted
## Integer spatial filters for the independent SC2X per-tile simulation.


static func neighborhood(values: PackedInt32Array, edge: int, radius: int, scale: int,
	budget: SimulationSliceBudget = null) -> PackedInt32Array:
	var stride := edge + 1
	var integral := PackedInt64Array()
	integral.resize(stride * stride)

	for x in edge:
		if budget != null:
			budget.checkpoint()

		var row_sum := 0

		for y in edge:
			row_sum += values[x * edge + y]
			integral[(x + 1) * stride + y + 1] = integral[x * stride + y + 1] + row_sum

	var result := PackedInt32Array()
	result.resize(values.size())

	for x in edge:
		if budget != null:
			budget.checkpoint()

		var left := maxi(x - radius, 0)
		var right := mini(x + radius + 1, edge)

		for y in edge:
			var top := maxi(y - radius, 0)
			var bottom := mini(y + radius + 1, edge)
			var total := integral[right * stride + bottom] - integral[left * stride + bottom]
			total -= integral[right * stride + top] - integral[left * stride + top]
			result[x * edge + y] = int((total * scale) / ((right - left) * (bottom - top)))

	return result


static func smooth(values: PackedInt32Array, edge: int, center_weight: int, base_divisor: int,
	step: int = 1, rings: int = 2, budget: SimulationSliceBudget = null) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(values.size())

	for x in edge:
		if budget != null:
			budget.checkpoint()

		for y in edge:
			var index := x * edge + y
			var total := values[index] * center_weight
			var divisor := base_divisor

			for ring in range(1, rings + 1):
				var distance := ring * step

				if x >= distance:
					total += values[index - distance * edge]
					divisor += 1

				if x + distance < edge:
					total += values[index + distance * edge]
					divisor += 1

				if y >= distance:
					total += values[index - distance]
					divisor += 1

				if y + distance < edge:
					total += values[index + distance]
					divisor += 1

			result[index] = int(total / divisor)

	return result


static func bytes(values: PackedInt32Array, budget: SimulationSliceBudget = null) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(values.size())

	for index in values.size():
		if budget != null and (index & 1023) == 0:
			budget.checkpoint()

		result[index] = clampi(values[index], 0, 255)

	return result


static func add_service(values: PackedByteArray, edge: int, origin: Vector2i, strength: int) -> void:
	# Sample the original service kernel at quarter-cell offsets around the
	# actual station tile. Four tiles still equal one original service cell.
	var kernel := PackedByteArray()
	kernel.resize(49)
	PollutionPhase._add_service(kernel, 3, 3, strength, 28)

	for dx in range(-15, 16):
		var x := origin.x + dx

		if x < 0 or x >= edge:
			continue

		var kx := floori(float(dx) / 4.0) + 3
		var fx := posmod(dx, 4)

		for dy in range(-15, 16):
			var y := origin.y + dy

			if y < 0 or y >= edge:
				continue

			var ky := floori(float(dy) / 4.0) + 3
			var fy := posmod(dy, 4)
			var weighted := _sample(kernel, kx, ky) * (4 - fx) * (4 - fy)
			weighted += _sample(kernel, kx + 1, ky) * fx * (4 - fy)
			weighted += _sample(kernel, kx, ky + 1) * (4 - fx) * fy
			weighted += _sample(kernel, kx + 1, ky + 1) * fx * fy
			var index := x * edge + y
			values[index] = clampi(int(values[index]) + (weighted / 16), 0, 255)


static func _sample(kernel: PackedByteArray, x: int, y: int) -> int:
	return kernel[x * 7 + y] if x >= 0 and x < 7 and y >= 0 and y < 7 else 0
