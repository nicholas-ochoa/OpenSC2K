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
	var plateau_anchor := _plateau_anchor(heights, sea, angle).rotated(-angle)
	for x in 128:
		for y in 128:
			var index := x * 128 + y
			if heights[index] < sea:
				continue
			var point := (Vector2(x, y) / 127.0 - Vector2(0.5, 0.5)).rotated(-angle)
			var rough := noise.get_noise_2d(point.x, point.y)
			var value := float(heights[index])
			if "plateau" in selected:
				var radius := ((point - plateau_anchor) / Vector2(0.42, 0.36)).length() + rough * 0.22
				var top := 1.0 - smoothstep(0.72, 1.12, radius)
				value = lerpf(value, sea + relief + 2.0, top)
			if "ridge" in selected:
				var axis := 0.06 * sin(point.y * 8.0 + phase)
				var across := (point.x - axis) / 0.13
				var peaks := 0.80 + 0.20 * sin(point.y * 17.0 + phase)
				value += relief * exp(-across * across) * peaks
			if "rolling" in selected:
				var warp := Vector2(noise.get_noise_2d(point.x + 13.0, point.y),
					noise.get_noise_2d(point.x, point.y - 17.0)) * 0.16
				var broad := noise.get_noise_2d((point.x + warp.x) * 0.45 + 21.3, (point.y + warp.y) * 0.45 - 9.7)
				var waves := clampf(0.5 + broad * 1.3 + rough * 0.08, 0.0, 1.0)
				value = sea + 2.0 + waves * relief * 0.85
			if "basin" in selected:
				var local := point - Vector2(0.06 * sin(phase), 0.05 * cos(phase))
				local += Vector2(rough, noise.get_noise_2d(point.x + 7.0, point.y - 11.0)) * 0.14
				var edge := 1.0 + 0.16 * sin(local.angle() * 3.0 + phase) + 0.10 * sin(local.angle() * 5.0 - phase)
				var radius := (local / Vector2(1.0, 0.87)).length() / edge + rough * 0.04
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


static func _plateau_anchor(heights: PackedInt32Array, sea: int, angle: float) -> Vector2:
	var start := posmod(roundi(angle / TAU * 508.0), 508)
	for step in 508:
		var along := (start + step) % 508
		var side := IntegerMath.div_trunc(along, 127)
		var offset := along % 127
		var tile: Vector2i = [Vector2i(offset, 0), Vector2i(127, offset),
			Vector2i(127 - offset, 127), Vector2i(0, 127 - offset)][side]
		if heights[tile.x * 128 + tile.y] >= sea:
			return Vector2(tile) / 127.0 - Vector2(0.5, 0.5)
	return Vector2(0.0, -0.5)
