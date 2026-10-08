class_name CityNatureArtwork
extends RefCounted
## Compact mixed woodland sprites and terrain masks, composed once. City data stays read-only.

@warning_ignore_start("integer_division")

const FIRST := 6000
const SPAN := 1500
const VARIANTS := 8
const GROUND_VARIANT := 128
# Tree roots are local to the original 32x16 diamond. No tree is placed on an empty tile.
const ROOTS := [Vector2i(16, 25), Vector2i(8, 24), Vector2i(24, 24),
	Vector2i(16, 19), Vector2i(9, 19), Vector2i(23, 19), Vector2i(16, 30)]
static var _ground: ImageTexture


static func ground_texture() -> ImageTexture:
	if _ground == null:
		var pixels := Image.create(32, 32, false, Image.FORMAT_RGB8)
		for y in 32:
			for x in 32:
				var value := ((x * 374761393 + y * 668265263) ^ 1274126177) & 0x7fffffff
				value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
				pixels.set_pixel(x, y, Color(float(value & 255) / 255.0, float((value >> 8) & 255) / 255.0, float((value >> 16) & 255) / 255.0))
		_ground = ImageTexture.create_from_image(pixels)
	return _ground


static func sprite_id(view: int, density: int, neighbors: int, variant: int) -> int:
	return FIRST + (neighbors * VARIANTS + variant) * SPAN + view * 500 + 5 + density


static func prepare(archive: Sc2SpriteArchive, palette: Sc2Palette) -> void:
	if not archive.visual_nature.is_empty():
		return
	var colors: Array[int] = []
	for color in [Color(0.03, 0.21, 0), Color(0.03, 0.34, 0), Color(0.03, 0.46, 0), Color(0.03, 0.59, 0), Color(0.03, 0.72, 0), Color("655032"), Color("978466")]:
		colors.append(_nearest(palette, color))
	for view in 3:
		if not archive.entries_by_id.has(view * 500 + 6):
			continue
		for neighbors in 16:
			for variant in VARIANTS:
				for density in range(1, 8):
					var source := archive.find_sprite(view * 500 + 5 + density)
					if source == null:
						continue
					var size := Vector2i(32 >> (2 - view), 36 >> (2 - view))
					var group := _group(size, colors, density, neighbors, variant)
					var pixels: PackedInt32Array = group.pixels
					var mask := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
					# Red marks foliage; green 0.1/0.2/0.3 identifies pine/oak/birch.
					# Ground uses green 1; blue remains reserved for power warnings.
					for at in pixels.size():
						if group.species[at] > 0:
							mask.set_pixel(at % size.x, at / size.x, Color(1, float(group.species[at]) * 0.1, 0, 1))
					var id := sprite_id(view, density, neighbors, variant)
					archive.visual_nature[id] = Sc2SpriteArchive.entry_from_indices(id, size.x, size.y, pixels)
					archive.visual_nature_masks[id] = mask

		for offset in range(256, 269):
			var ground := archive.find_sprite(view * 500 + offset)
			if ground == null:
				continue
			var id := FIRST + GROUND_VARIANT * SPAN + view * 500 + offset
			var entry := ground
			archive.visual_nature[id] = Sc2SpriteArchive.entry_from_indices(id, entry.width, entry.height, entry.decode_indices().pixels)
			var mask := Image.create(entry.width, entry.height, false, Image.FORMAT_RGBA8)
			var pixels: PackedInt32Array = entry.decode_indices().pixels
			for at in pixels.size():
				if pixels[at] < 0:
					continue
				var color := palette.color(pixels[at])
				# Alpha distinguishes original rock faces from soil. Other mask
				# channels retain their shared foliage/ground/power contracts.
				var rock := offset != 256 and color.g < color.r * 0.76
				mask.set_pixel(at % entry.width, at / entry.width, Color(0, 1, 0, 0.55 if rock else (1.0 if offset == 256 else 0.92)))
			archive.visual_nature_masks[id] = mask


static func _nearest(palette: Sc2Palette, target: Color) -> int:
	var best := 0
	var distance := INF
	# Avoid the animated palette ranges and preserve the imported palette.
	for index in 170:
		var color := palette.color(index)
		var next := Vector3(color.r - target.r, color.g - target.g, color.b - target.b).length_squared()
		if next < distance:
			distance = next
			best = index
	return best


static func _group(size: Vector2i, colors: Array[int], density: int, neighbors: int, variant: int) -> Dictionary:
	var pixels := PackedInt32Array()
	pixels.resize(32 * 36)
	pixels.fill(-1)
	var species := PackedByteArray()
	species.resize(pixels.size())
	var roots: Array[Vector3i] = []
	for tree in density:
		var root: Vector2i = ROOTS[tree]
		if density == 1:
			root = Vector2i(16, 27)
		var seed := tree * 29 + variant * 47 + density * 13
		root.x += seed % 5 - 2
		root.y += (seed / 5) % 3 - 1
		var side := (0 if root.y < 25 else 1) if root.x > 16 else (3 if root.y < 25 else 2)
		var shared := density >= 4 and neighbors & (1 << side) != 0
		if shared:
			root.x += 1 if root.x > 16 else -1
		roots.append(Vector3i(root.x, root.y, seed + (1000 if shared else 0)))
	roots.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.y < b.y)
	for root in roots:
		_tree(pixels, species, root, colors)
	if size == Vector2i(32, 36):
		return {"pixels": pixels, "species": species}
	var reduced := PackedInt32Array()
	reduced.resize(size.x * size.y)
	var reduced_species := PackedByteArray()
	reduced_species.resize(reduced.size())
	for y in size.y:
		for x in size.x:
			var source := (y * 36 / size.y) * 32 + x * 32 / size.x
			reduced[y * size.x + x] = pixels[source]
			reduced_species[y * size.x + x] = species[source]
	return {"pixels": reduced, "species": reduced_species}


static func _tree(pixels: PackedInt32Array, foliage: PackedByteArray, root: Vector3i, colors: Array[int]) -> void:
	# Hand-shaped clusters at the original artwork's pixel scale. The conifer
	# uses stepped branch tiers; oak and birch have unequal leafy lobes.
	const CROWNS := [
		[".....3.....", ".....43....", "....432....", "....443....", "...34421...",
		 "....432....", "...44321...", "..344322...", "...44321...", "..3443321..",
		 "..4543321..", ".34432321..", "..343221...", ".344332211.", "34443322211", ".33322211.."],
		["....443....", "..344532...", ".34545332..", ".455343221.", "34543443221",
		 "34454333221", "45343432311", "34434323221", ".343223221.", "..3323211..", "...2211...."],
		["....43...", "...4542..", "..454432.", "..543332.", ".45434321", "345443321",
		 ".43453221", "344343321", ".34343221", "..433221.", ".343321..", "..33211..", "...21...."]]
	var seed := root.z % 1000
	var species := seed % 3
	var shape: Array = CROWNS[species]
	var width: int = shape[0].length()
	var height := shape.size() + seed % 3
	var spread := 1 if root.z >= 1000 and species != 2 else 0
	for y in range(root.y - 7, root.y + 1):
		_put(pixels, foliage, root.x, y, colors[6 if species == 2 and y % 3 != 0 else 5], 0)
	for y in height:
		var row: String = shape[mini(shape.size() - 1, y * shape.size() / height)]
		for x in range(width + spread):
			var sx := mini(width - 1, x * width / (width + spread))
			if seed & 1 != 0:
				sx = width - 1 - sx
			var value := row.substr(sx, 1)
			if value != ".":
				_put(pixels, foliage, root.x + x - (width + spread) / 2, root.y - height - 3 + y, colors[value.to_int() - 1], species + 1)


static func _put(pixels: PackedInt32Array, foliage: PackedByteArray, x: int, y: int, index: int, species: int) -> void:
	if x >= 0 and x < 32 and y >= 0 and y < 36:
		pixels[y * 32 + x] = index
		foliage[y * 32 + x] = species
