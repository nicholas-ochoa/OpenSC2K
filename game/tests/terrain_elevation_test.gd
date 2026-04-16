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
			assert(heights[64 * 128 + 64] == heights[70 * 128 + 70])
			assert(heights[64 * 128 + 64] > heights[8 * 128 + 64] + 4)
		if feature == "ridge":
			assert(heights[64 * 128 + 64] > heights[8 * 128 + 64] + 4)
		if feature == "rolling":
			assert(Array(heights).max() - Array(heights).min() >= 4)
		if feature == "basin":
			assert(heights[64 * 128 + 64] + 4 < heights[8 * 128 + 64])
		if feature in ["valley", "canyon"]:
			assert(heights[66 * 128 + 64] < heights[96 * 128 + 64])
			assert(heights[64 * 128 + 64] == 2, "Preserve river water")
		if feature == "cliffs":
			assert(heights[66 * 128 + 64] > heights[110 * 128 + 64] + 3)
		assert(Array(heights).max() <= 31)
	print("Elevation profiles passed")
	quit()
