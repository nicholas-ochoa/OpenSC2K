extends SceneTree

func _initialize() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 71
	noise.frequency = 7.0
	for feature in ["plateau", "ridge", "rolling", "basin", "valley", "canyon", "cliffs"]:
		var heights := PackedInt32Array()
		heights.resize(128 * 128)
		heights.fill(6)
		if feature in ["valley", "canyon", "cliffs"]:
			for y in 128:
				heights[64 * 128 + y] = 2
		TerrainElevation.apply(heights, 4, [feature], 0.0, 1.0, noise, 12)
		if feature == "plateau":
			assert(heights[0] == heights[6 * 128 + 6])
			assert(heights[0] > heights[64 * 128 + 64] + 4)
		if feature == "ridge":
			assert(heights[64 * 128 + 64] > heights[8 * 128 + 64] + 4)
		if feature == "rolling":
			assert(Array(heights).max() - Array(heights).min() >= 4)
		if feature == "basin":
			assert(heights[64 * 128 + 64] + 4 < heights[8 * 128 + 64])
		if feature == "valley":
			assert(heights[66 * 128 + 64] < heights[96 * 128 + 64])
			assert(heights[64 * 128 + 64] == 2, "Preserve river water")
		if feature == "canyon":
			assert(heights[78 * 128 + 64] <= 6, "Dry floor follows its own winding path")
			assert(heights[110 * 128 + 64] >= 13, "Retain steep canyon walls")
		if feature == "cliffs":
			assert(heights[110 * 128 + 64] >= 13, "Keep inland terrain high")
			assert(absi(heights[66 * 128 + 64] - heights[110 * 128 + 64]) <= 1)
			assert(heights[64 * 128 + 64] == 2, "Preserve coastal water")
		assert(Array(heights).max() <= 31)
	for feature in ["rolling", "basin"]:
		var outputs: Array[PackedInt32Array] = []
		for seed in [71, 912]:
			var heights := PackedInt32Array()
			heights.resize(128 * 128)
			heights.fill(6)
			noise.seed = seed
			TerrainElevation.apply(heights, 4, [feature], 0.0, 1.0, noise, 12)
			outputs.append(heights)
		var changed := 0
		for index in outputs[0].size():
			if outputs[0][index] != outputs[1][index]:
				changed += 1
		assert(changed > 500, "Seeded noise left the landform unchanged")
	print("Elevation profiles passed")
	quit()
