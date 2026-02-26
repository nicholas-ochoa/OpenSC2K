class_name NativeGridMath
extends RefCounted
# integer spatial filters for the independent sc2x per-tile simulation


static func neighborhood(values: PackedInt32Array, edge: int, radius: int, scale: int,
	budget: SimulationSliceBudget = null) -> PackedInt32Array:
	var stride := edge + 1
	var integral := PackedInt64Array()
	integral.resize(stride * stride)

	for x in edge:
		if budget != null:
			budget.checkpoint()

		var row_sum := 0
		var row := x * edge
		var above := x * stride
		var below := above + stride

		for y in edge:
			row_sum += values[row + y]
			integral[below + y + 1] = integral[above + y + 1] + row_sum

	# column bounds repeat in every row. compute them once per filter
	var tops := PackedInt32Array()
	var bottoms := PackedInt32Array()
	var widths := PackedInt32Array()

	for y in edge:
		tops.append(maxi(y - radius, 0))
		bottoms.append(mini(y + radius + 1, edge))
		widths.append(bottoms[y] - tops[y])

	var result := PackedInt32Array()
	result.resize(values.size())

	for x in edge:
		if budget != null:
			budget.checkpoint()

		var left := maxi(x - radius, 0)
		var right := mini(x + radius + 1, edge)
		var row := x * edge
		var left_row := left * stride
		var right_row := right * stride
		var height := right - left

		for y in edge:
			var top := tops[y]
			var bottom := bottoms[y]
			var total := integral[right_row + bottom] - integral[left_row + bottom]
			total -= integral[right_row + top] - integral[left_row + top]
			result[row + y] = int(total * scale / (height * widths[y]))

	return result


static func neighborhood_bytes(values: PackedInt32Array, edge: int, radius: int, scale: int,
	budget: SimulationSliceBudget = null) -> PackedByteArray:
	var stride := edge + 1
	var integral := PackedInt64Array()
	integral.resize(stride * stride)

	for x in edge:
		if budget != null:
			budget.checkpoint()

		var row_sum := 0
		var row := x * edge
		var above := x * stride
		var below := above + stride

		for y in edge:
			row_sum += values[row + y]
			integral[below + y + 1] = integral[above + y + 1] + row_sum

	# column bounds repeat in every row. compute them once per filter
	var tops := PackedInt32Array()
	var bottoms := PackedInt32Array()
	var widths := PackedInt32Array()

	for y in edge:
		tops.append(maxi(y - radius, 0))
		bottoms.append(mini(y + radius + 1, edge))
		widths.append(bottoms[y] - tops[y])

	var result := PackedByteArray()
	result.resize(values.size())

	for x in edge:
		if budget != null:
			budget.checkpoint()

		var left := maxi(x - radius, 0)
		var right := mini(x + radius + 1, edge)
		var row := x * edge
		var left_row := left * stride
		var right_row := right * stride
		var height := right - left

		for y in edge:
			var top := tops[y]
			var bottom := bottoms[y]
			var total := integral[right_row + bottom] - integral[left_row + bottom]
			total -= integral[right_row + top] - integral[left_row + top]
			result[row + y] = clampi(int(total * scale / (height * widths[y])), 0, 255)

	return result


static func smooth(values: PackedInt32Array, edge: int, center_weight: int, base_divisor: int,
	step: int = 1, rings: int = 2, budget: SimulationSliceBudget = null) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(values.size())

	for x in edge:
		if budget != null:
			budget.checkpoint()

		var row := x * edge
		var margin := step * rings
		var interior_row := x >= margin and x < edge - margin and rings in [1, 2]

		for y in edge:
			var index := row + y

			if interior_row and y >= margin and y < edge - margin:
				var total := values[index] * center_weight
				total += values[index - step * edge] + values[index + step * edge]
				total += values[index - step] + values[index + step]

				if rings == 2:
					total += values[index - 2 * step * edge] + values[index + 2 * step * edge]
					total += values[index - 2 * step] + values[index + 2 * step]

				result[index] = int(total / (base_divisor + 4 * rings))
				continue

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


static func smooth_bytes(values: PackedInt32Array, edge: int, center_weight: int, base_divisor: int,
	step: int = 1, rings: int = 2, budget: SimulationSliceBudget = null) -> Dictionary:
	var result := PackedByteArray()
	var sum := 0
	result.resize(values.size())

	for x in edge:
		if budget != null:
			budget.checkpoint()

		var row := x * edge
		var margin := step * rings
		var interior_row := x >= margin and x < edge - margin and rings in [1, 2]

		for y in edge:
			var index := row + y

			if interior_row and y >= margin and y < edge - margin:
				var total := values[index] * center_weight
				total += values[index - step * edge] + values[index + step * edge]
				total += values[index - step] + values[index + step]

				if rings == 2:
					total += values[index - 2 * step * edge] + values[index + 2 * step * edge]
					total += values[index - 2 * step] + values[index + 2 * step]

				result[index] = clampi(int(total / (base_divisor + 4 * rings)), 0, 255)
				sum += result[index]
				continue

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

			result[index] = clampi(int(total / divisor), 0, 255)
			sum += result[index]

	return {"values": result, "total": sum}


static func bytes(values: PackedInt32Array, budget: SimulationSliceBudget = null) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(values.size())

	for index in values.size():
		if budget != null and (index & 1023) == 0:
			budget.checkpoint()

		result[index] = clampi(values[index], 0, 255)

	return result


static func service_pattern(strength: int) -> PackedInt32Array:
	var kernel := PackedByteArray()
	kernel.resize(49)
	PollutionPhase._add_service(kernel, 3, 3, strength, 28)
	var pattern := PackedInt32Array()
	pattern.resize(31 * 31)

	for dx in range(-15, 16):
		var kx := floori(float(dx) / 4.0) + 3
		var fx := posmod(dx, 4)

		for dy in range(-15, 16):
			var ky := floori(float(dy) / 4.0) + 3
			var fy := posmod(dy, 4)
			var weighted := _sample(kernel, kx, ky) * (4 - fx) * (4 - fy)
			weighted += _sample(kernel, kx + 1, ky) * fx * (4 - fy)
			weighted += _sample(kernel, kx, ky + 1) * (4 - fx) * fy
			weighted += _sample(kernel, kx + 1, ky + 1) * fx * fy
			pattern[(dx + 15) * 31 + dy + 15] = weighted / 16

	return pattern


static func add_service(values: PackedByteArray, edge: int, origin: Vector2i, strength: int) -> void:
	apply_service_pattern(values, edge, origin, service_pattern(strength))


static func apply_service_pattern(values: PackedByteArray, edge: int, origin: Vector2i,
	pattern: PackedInt32Array) -> void:
	for dx in range(maxi(-15, -origin.x), mini(16, edge - origin.x)):
		var row := (origin.x + dx) * edge
		var source_row := (dx + 15) * 31

		for dy in range(maxi(-15, -origin.y), mini(16, edge - origin.y)):
			var index := row + origin.y + dy
			values[index] = clampi(int(values[index]) + pattern[source_row + dy + 15], 0, 255)


static func _sample(kernel: PackedByteArray, x: int, y: int) -> int:
	return kernel[x * 7 + y] if x >= 0 and x < 7 and y >= 0 and y < 7 else 0
