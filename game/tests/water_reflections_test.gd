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
	print("PASS: indexed native water geometry at all artwork sizes, water-only clipping, deterministic cache output and Off/Subtle preferences")
	quit()
