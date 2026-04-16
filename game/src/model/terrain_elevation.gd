class_name TerrainElevation
extends RefCounted


const FEATURES := ["plateau", "ridge", "valley", "rolling", "basin", "canyon", "cliffs"]


static func apply(heights: PackedInt32Array, sea: int, selected: Array,
	angle: float, phase: float, noise: FastNoiseLite, hills: int) -> void:
	var active := false
	for key in FEATURES:
		active = active or key in selected
	if not active:
		return
	var distances := _water_distances(heights, sea)
	var relief := 7.0 + float(hills) / 5.0
	for x in 128:
		for y in 128:
			var index := x * 128 + y
			if heights[index] < sea:
				continue
			var point := (Vector2(x, y) / 127.0 - Vector2(0.5, 0.5)).rotated(-angle)
			var rough := noise.get_noise_2d(point.x, point.y)
			var value := float(heights[index])
			if "plateau" in selected:
				var radius := (point / Vector2(0.36, 0.29)).length() + rough * 0.15
				var top := 1.0 - smoothstep(0.72, 1.12, radius)
				value = lerpf(value, sea + relief + 2.0, top)
			if "ridge" in selected:
				var axis := 0.06 * sin(point.y * 8.0 + phase)
				var across := (point.x - axis) / 0.13
				var peaks := 0.80 + 0.20 * sin(point.y * 17.0 + phase)
				value += relief * exp(-across * across) * peaks
			if "rolling" in selected:
				var waves := 0.5 + 0.25 * sin(point.x * 14.0 + phase) + 0.25 * cos(point.y * 12.0 - phase)
				value = sea + 2.0 + waves * relief * 0.65
			if "basin" in selected:
				var radius := point.length() + rough * 0.025
				value = sea + 1.0 + relief * smoothstep(0.08, 0.48, radius)
			if "valley" in selected or "canyon" in selected:
				var distance := float(distances[index]) / 127.0
				var bank := 0.065 if "canyon" in selected else 0.23
				var rise := smoothstep(0.0, bank, distance)
				value = lerpf(sea + 1.0, maxf(value, sea + relief), rise)
			if "cliffs" in selected:
				var coastal := 1.0 - smoothstep(12.0, 32.0, float(distances[index]))
				value = maxf(value, sea + relief * coastal)
			heights[index] = clampi(roundi(value), sea + 1, 31)


static func _water_distances(heights: PackedInt32Array, sea: int) -> PackedInt32Array:
	var distances := PackedInt32Array()
	distances.resize(heights.size())
	distances.fill(256)
	var queue := PackedInt32Array()
	for index in heights.size():
		if heights[index] < sea:
			distances[index] = 0
			queue.append(index)
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		var x := IntegerMath.div_trunc(index, 128)
		var y := index % 128
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var near: Vector2i = Vector2i(x, y) + offset
			if near.x < 0 or near.y < 0 or near.x >= 128 or near.y >= 128:
				continue
			var next := near.x * 128 + near.y
			if distances[next] > distances[index] + 1:
				distances[next] = distances[index] + 1
				queue.append(next)
	return distances
