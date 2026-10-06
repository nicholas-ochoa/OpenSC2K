extends SceneTree
## Native water projection, independent of the simulation.
@warning_ignore_start("integer_division")


static func fixture(view := 2) -> Dictionary:
	var divisor := 4 >> view
	var width: int = 32 / divisor
	var height: int = 16 / divisor + 1
	var half: int = 8 / divisor
	var water := Image.create(width, height, false, Image.FORMAT_RGBA8)
	water.fill(Color.TRANSPARENT)
	for y in height:
		for x in width:
			if absi(2 * x + 1 - width) + 2 * absi(y - half) <= width:
				water.set_pixel(x, y, Color(96.0 / 255.0, 96.0 / 255.0, 96.0 / 255.0, 1))
	var building := Image.create(width, height + 24 / divisor, false, Image.FORMAT_RGBA8)
	for y in building.get_height():
		for x in width:
			var index := float(40 + y % 20 + x % 5) / 255.0
			building.set_pixel(x, y, Color(index, index, index, 1))
	var base: int = 500 * view
	var artwork := {base + 270: water, base + 256: water, base + 284: water, base + 112: building}
	var altitude := PackedInt32Array()
	var terrain := PackedByteArray()
	var buildings := PackedByteArray()
	var flags := PackedByteArray()
	var zones := PackedByteArray()
	var empty := PackedByteArray()
	altitude.resize(16)
	terrain.resize(16)
	terrain.fill(0x10)
	buildings.resize(16)
	flags.resize(16)
	flags.fill(4)
	empty.resize(16)
	zones.resize(16)
	zones[0] = 0x80
	terrain[0] = 0
	buildings[0] = 112
	flags[0] = 0
	var request := {"edge": 4, "visible": 32, "view": view, "altitude": altitude, "terrain": terrain,
		"buildings": buildings, "zones": zones, "flags": flags, "overlays": empty, "underground": empty, "atlas": 0}
	var builder := NativeCityRegionBuilder.new()
	assert(str(builder.configure(request, artwork, Color(161.0 / 255.0, 161.0 / 255.0, 161.0 / 255.0, 1).to_rgba32())).is_empty())
	var indices := PackedByteArray()
	indices.resize(256)
	indices[96] = 1
	var bounds := Rect2i(32 / divisor, 480 / divisor, 160 / divisor, 160 / divisor)
	return {"builder": builder, "indices": indices, "bounds": bounds, "request": request, "artwork": artwork}


func _initialize() -> void:
	for view in 3:
		var data := fixture(view)
		var builder: NativeCityRegionBuilder = data.builder
		var first: Dictionary = builder.water_reflections(data.bounds, data.indices, {}, {})
		assert(not first.is_empty() and not first.has("error"))
		var surface: Image = first.surface
		var reflected: Image = first.reflected
		var count := 0
		for y in surface.get_height():
			for x in surface.get_width():
				if reflected.get_pixel(x, y).a > 0:
					count += 1
					assert(surface.get_pixel(x, y).a == 1.0, "Reflection leaked onto land")
		assert(count > 0, "Missing reflected source")
		var second: Dictionary = builder.water_reflections(data.bounds, data.indices, {}, {})
		assert(first.reflected.get_data() == second.reflected.get_data(), "Cosmetic geometry is not deterministic")
		data.indices.fill(0)
		assert(builder.water_reflections(data.bounds, data.indices, {}, {}).is_empty())
	var palette := Sc2Palette.new()
	for index in 256:
		palette.colors.append(Color.BLUE if index == 96 else Color(0.5, 0.5, 0.5))
	assert(CityWaterLayer.blue_indices(palette)[96] == 1)
	assert(CityWaterLayer.blue_indices(palette)[95] == 0)
	var options := VisualEnhancementOptions.normalize({"water_reflections": 30})
	assert(options.water_reflections == 1)
	assert(VisualEnhancementOptions.normalize({"water_reflections": 0}).water_reflections == 0)
	var ship := Image.create(2, 3, false, Image.FORMAT_RGBA8)
	ship.set_pixel(0, 0, Color(0.2, 0, 0, 1))
	ship.set_pixel(0, 2, Color(0.4, 0, 0, 1))
	ship.set_pixel(1, 0, Color(0.6, 0, 0, 1))
	var lights := Image.create(2, 3, false, Image.FORMAT_RGBA8)
	lights.set_pixel(0, 0, Color(0.9, 0.3, 0.1, 0.75))
	var boat := WaterReflectionSprite.create(ship, lights, Vector2i(10, 20), 4)
	assert(is_equal_approx(boat.image.get_pixel(0, 5).r, ship.get_pixel(0, 0).r))
	assert(is_equal_approx(boat.image.get_pixel(0, 3).r, ship.get_pixel(0, 2).r))
	assert(is_equal_approx(boat.image.get_pixel(1, 1).r, ship.get_pixel(1, 0).r))
	assert(boat.emission.get_pixel(0, 5) == lights.get_pixel(0, 0))
	assert(boat.image.get_pixel(0, 0).a == 0)
	_check_ship_wakes()
	_check_moving_composition()
	print("PASS: indexed native water geometry at all artwork sizes, water-only clipping, deterministic cache output and Off/Subtle preferences")
	quit()


func _check_moving_composition() -> void:
	var surface := Image.create(24, 18, false, Image.FORMAT_RGBA8)
	var base := Image.create(24, 18, false, Image.FORMAT_RGBA8)
	base.fill(Color(0.1, 0.3, 0.7, 0.5))
	for y in 18:
		for x in 24:
			surface.set_pixel(x, y, Color8(1 + x % 3, 0, 0, 0 if y % 4 == 0 else 255))
	var sprite := Image.create(11, 13, false, Image.FORMAT_RGBA8)
	var light := Image.create(11, 13, false, Image.FORMAT_RGBA8)
	for y in 13:
		for x in 11:
			sprite.set_pixel(x, y, Color8(x * 19, y * 17, 73, (x * y * 29) % 256))
			light.set_pixel(x, y, Color8(211, 137, 43, (x * y * 17) % 256))
	for divisor in [1, 2, 4]:
		var origin := Vector2i(-19, 31)
		var area := Rect2i(origin, surface.get_size() * divisor)
		var images: Array[Image] = []
		var placements := PackedInt32Array()
		var expected := {"reflected": base.duplicate(), "emission": base.duplicate(), "seasons": base.duplicate()}
		for offset in [Vector2i(-4, -7), Vector2i(7, 5), Vector2i(9, 6), area.size - Vector2i(3, 2), Vector2i(200, 200)]:
			for level in [0, 1, 2]:
				var position: Vector2i = origin + offset
				images.append_array([sprite, light])
				placements.append_array(PackedInt32Array([position.x, position.y, level]))
				var overlap := area.intersection(Rect2i(position, sprite.get_size()))
				if not overlap.has_area():
					continue
				var first := Vector2i((Vector2(overlap.position - area.position) / divisor).floor())
				var last := Vector2i((Vector2(overlap.end - area.position) / divisor).ceil())
				for y in range(first.y, last.y):
					for x in range(first.x, last.x):
						var mask := surface.get_pixel(x, y)
						if mask.a == 0 or roundi(mask.r * 255.0) != level + 1:
							continue
						var point: Vector2i = area.position + Vector2i(x, y) * divisor - position
						if not Rect2i(Vector2i.ZERO, sprite.get_size()).has_point(point):
							continue
						var pixel := sprite.get_pixelv(point)
						if pixel.a == 0:
							continue
						expected.reflected.set_pixel(x, y, pixel)
						expected.emission.set_pixel(x, y, light.get_pixelv(point))
						expected.seasons.set_pixel(x, y, Color.TRANSPARENT)
		var actual := NativeSpriteCompositor.water_moving(surface, base, base, base, images, placements, Vector3i(origin.x, origin.y, divisor))
		for key in expected:
			assert(actual[key].get_data() == expected[key].get_data(), "Moving water composition changed clipping, height, painter order or pixels")
		assert(base.get_pixel(0, 0) == Color8(25, 76, 178, 127), "Composition modified immutable region pixels")


func _check_ship_wakes() -> void:
	var palette := Sc2Palette.new()
	palette.colors.resize(256)
	palette.colors.fill(Color(0.5, 0.5, 0.5))
	palette.colors[40] = Color(0.7, 0.05, 0.02)
	palette.colors[96] = Color.BLUE
	palette.colors[80] = Color(0.1, 0.8, 0.8)
	# Three art sizes, both diagonal hulls, horizontal hull and flipped artwork.
	for width: int in [8, 16, 32]:
		for slope: int in [-1, 0, 1]:
			var source := Image.create(width, width + 14, false, Image.FORMAT_RGBA8)
			var lights := Image.create(width, width + 14, false, Image.FORMAT_RGBA8)
			var contacts := PackedInt32Array()
			for x in width:
				var contact := 4 + (x / 2 if slope > 0 else ((width - 1 - x) / 2 if slope < 0 else 0))
				contacts.append(contact)
				for y in range(contact - 3, contact):
					source.set_pixel(x, y, Color(40.0 / 255.0, 0, 0, 1))
				# A blue deck detail inside the hull must retain its reflection.
				if x > 0 and x < width - 1:
					source.set_pixel(x, contact - 2, Color(96.0 / 255.0, 0, 0, 1))
				lights.set_pixel(x, contact - 1, Color(1, 0.4, 0.1, 0.75))
				for y in range(contact, contact + 5):
					source.set_pixel(x, y, Color((80.0 if y % 2 else 96.0) / 255.0, 0, 0, 1))
			# An isolated gray foam pixel cannot move the waterline either.
			source.set_pixel(0, source.get_height() - 1, Color(160.0 / 255.0, 0, 0, 1))
			var before := source.get_data()
			for flipped in [false, true]:
				var reflection := WaterReflectionSprite.create(source, lights, Vector2i(13, 29), 5, palette)
				for x in width:
					var contact := contacts[width - 1 - x if flipped else x]
					assert(reflection.image.get_pixel(x, contact).r == source.get_pixel(x, contact - 1).r,
						"Reflected hull does not meet its waterline")
					if x > 0 and x < width - 1:
						assert(roundi(reflection.image.get_pixel(x, contact + 1).r * 255.0) == 96,
							"Blue deck paint was removed together with the wake")
					assert(reflection.emission.get_pixel(x, contact) == lights.get_pixel(x, contact - 1))
					for y in range(contact + 3, reflection.image.get_height()):
						assert(reflection.image.get_pixel(x, y).a == 0, "Wake or foam entered the mirror")
				assert(reflection.position == Vector2i(13, 29) and reflection.level == 5)
				source.flip_x()
				lights.flip_x()
			assert(source.get_data() == before, "Reflection extraction changed source artwork")
