extends SceneTree
## The GPU build context paints common surface tiles with its own shortcut.
## Every tile that the shortcut accepts must record the same draws, in the same
## order, as the one tile painter. The other tiles must go to the painter.


func _initialize() -> void:
	var palette := Sc2Palette.index_encoding()
	var large := Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/LARGE.DAT")
	var small := Sc2SpriteArchive.combine([Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/SMALLMED.DAT"), Sc2SpriteArchive.load_path("res://../references/SIMCITY2000/DATA/SPECIAL.DAT")])
	var city := CityState.from_document(Sc2File.load_path("res://../references/SIMCITY2000/CITIES/SYDNEY.SC2"))
	assert(city.is_valid() and large.is_valid() and small.is_valid())
	var overrides := _generate(city)
	var covered := {}

	# Views, rotations, and hidden altitudes are independent of the tile content.
	var setups := [
		{"view": 2, "rotation": 0, "levels": 32, "overrides": true, "routing": true},
		{"view": 2, "rotation": 1, "levels": 32, "overrides": true},
		{"view": 2, "rotation": 2, "levels": 12, "overrides": true},
		{"view": 2, "rotation": 3, "levels": 32, "overrides": false},
		{"view": 1, "rotation": 1, "levels": 12, "overrides": true},
		{"view": 0, "rotation": 2, "levels": 32, "overrides": true},
	]

	for setup: Dictionary in setups:
		city.document.set_misc_u32(0x08, setup.rotation)
		city.visible_altitude_levels = setup.levels
		city.object_altitude_overrides = overrides if setup.overrides else PackedInt32Array()
		_compare(city, palette, large if setup.view == 2 else small, setup, covered)

	var required := ["rotation:0", "rotation:1", "rotation:2", "rotation:3", "view:0", "view:1", "view:2",
		"slow:edge", "slow:thing", "slow:hidden", "slow:building", "surface:substituted", "surface:kept",
		"water:true", "water:false", "salt:true", "salt:false", "zone:none", "zone:drawn", "small:0x0d",
		"object:override", "object:flag", "anchor:skipped", "power:marker", "power:none"]

	for terrain in range(0x00, 0x46):
		required.append("terrain:%d" % terrain)

	for building in range(0x01, 0x0e):
		required.append("building:%d" % building)

	for flip in [false, true]:
		for odd in [false, true]:
			required.append("large:flip=%s:odd=%s" % [flip, odd])
			required.append("small:flip=%s:odd=%s" % [flip, odd])

	for tag: String in required:
		assert(covered.has(tag), "Shortcut coverage is missing %s" % tag)

	print("PASS: GPU tile shortcut matches the tile painter on %d tile comparisons" % int(covered.compared))
	quit()


## Fill the map from a fixed seed. Water tiles often sit level with land, so the
## shoreline terrain ids take the 0x3e substitution on some tiles.
func _generate(city: CityState) -> PackedInt32Array:
	var random := RandomNumberGenerator.new()
	random.seed = 0x5c2000
	var count := city.map_size * city.map_size
	var buildings := PackedByteArray()
	var zones := PackedByteArray()
	var flags := PackedByteArray()
	var overlays := PackedByteArray()
	var overrides := PackedInt32Array()
	buildings.resize(count)
	zones.resize(count)
	flags.resize(count)
	overlays.resize(count)
	overrides.resize(count)

	for index in count:
		var x := int(index / float(city.map_size))
		var y := index % city.map_size
		var land := random.randi_range(0, 31)
		assert(city.set_terrain_id(x, y, random.randi_range(0x00, 0x45)))
		assert(city.set_land_altitude(x, y, land))
		assert(city.set_water_altitude(x, y, land if random.randf() < 0.5 else random.randi_range(0, 31)))
		buildings[index] = [0, random.randi_range(0x01, 0x0d), random.randi_range(0x0e, 0x6f), random.randi_range(0x70, 0xff)][random.randi_range(0, 3)]
		zones[index] = random.randi_range(0, 0xff) if random.randf() < 0.75 else random.randi_range(0, 0x0f)
		flags[index] = random.randi_range(0, 0xff)
		overlays[index] = random.randi_range(201, 240) if random.randf() < 0.05 else 0
		overrides[index] = random.randi_range(0, 31) if random.randf() < 0.3 else -1

	assert(city.replace_buildings(buildings) and city.replace_zones(zones))
	assert(city.replace_tile_flags(flags) and city.replace_text_overlays(overlays))

	return overrides


func _compare(city: CityState, palette: Sc2Palette, sprites: Sc2SpriteArchive, setup: Dictionary, covered: Dictionary) -> void:
	var configuration := CityIsometricRenderer.view_configuration(setup.view)
	var origin := int(configuration.side_margin) + city.map_size * int(configuration.half_width)
	var context := CityGpuBuildContext.new()
	context.rotation = city.compass_rotation()
	var odd := (city.compass_rotation() & 1) != 0
	var edge := city.map_size - 1

	for x in city.map_size:
		for y in city.map_size:
			# Keep the setup short: an inner block with the zero rows, plus both far edges.
			if x > 63 and y > 63 and x != edge and y != edge:
				continue

			var building := city.building_id(x, y)
			var slow := {"edge": x == edge or y == edge, "thing": OverlayData.is_thing(city.text_overlay_id(x, y)),
				"hidden": not city.tile_is_visible(x, y), "building": building >= 0x0e and building < 0x70}
			var reference := CityGpuDrawList.new()
			CityIsometricRenderer.draw_tile(reference, city, palette, sprites, context.images, configuration, origin, x, y, 0, false, false)
			var shortcut := CityGpuDrawList.new()
			var taken := context._fast_tile(shortcut, city, palette, sprites, configuration, origin, x, y)
			covered.compared = int(covered.get("compared", 0)) + 1

			if setup.has("routing"):
				assert(_same(context.tile(city, palette, sprites, configuration, x, y, "city", false, false).draws, reference.draws), "GPU tile (%d, %d) differs from the tile painter" % [x, y])

			if slow.values().has(true):
				assert(not taken, "Unexpected shortcut at tile (%d, %d)" % [x, y])

				for reason: String in slow:
					if slow[reason] and slow.values().count(true) == 1:
						covered["slow:" + reason] = true

				continue

			assert(taken, "Shortcut not used at tile (%d, %d)" % [x, y])
			assert(_same(shortcut.draws, reference.draws), "Shortcut differs at (%d, %d) view %d rotation %d: %s != %s" % [x, y, setup.view, city.compass_rotation(), _describe(shortcut.draws), _describe(reference.draws)])
			_record(city, x, y, odd, setup, covered)


func _record(city: CityState, x: int, y: int, odd: bool, setup: Dictionary, covered: Dictionary) -> void:
	var building := city.building_id(x, y)
	var terrain := city.terrain_id(x, y)
	var index := city.index_of(x, y)
	covered["rotation:%d" % city.compass_rotation()] = true
	covered["view:%d" % setup.view] = true
	covered["terrain:%d" % terrain] = true
	covered["water:%s" % city.is_water(x, y)] = true
	covered["salt:%s" % city.is_salt_water(x, y)] = true

	if terrain >= 0x30 and terrain <= 0x45 and terrain != 0x3e:
		covered["surface:substituted" if CityIsometricRenderer.surface_terrain_id(city, x, y) == 0x3e else "surface:kept"] = true

	if building == 0:
		covered["zone:drawn" if city.zone_id(x, y) > 0 else "zone:none"] = true

		return

	var overridden := city.object_altitude_overrides.size() == city.map_size * city.map_size and city.object_altitude_overrides[index] >= 0
	var anchored := (city.building_corners(x, y) & int([0x80, 0x10, 0x20, 0x40][city.compass_rotation()])) != 0

	if building < 0x70:
		covered["building:%d" % building] = true
		covered["small:flip=%s:odd=%s" % [city.is_flipped(x, y), odd]] = true

		if CityIsometricRenderer.surface_terrain_id(city, x, y) == 0x0d:
			covered["small:0x0d"] = true
	elif not anchored:
		covered["anchor:skipped"] = true

		return
	else:
		covered["large:flip=%s:odd=%s" % [city.is_flipped(x, y), odd]] = true
		covered["power:marker" if city.is_powerable(x, y) and not city.is_powered(x, y) else "power:none"] = true

	covered["object:override" if overridden else "object:flag"] = true


func _same(actual: Array[Dictionary], expected: Array[Dictionary]) -> bool:
	if actual.size() != expected.size():
		return false

	for index in actual.size():
		var a := actual[index]
		var b := expected[index]

		if a.image != b.image or a.source != b.source or a.position != b.position:
			return false

	return true


func _describe(draws: Array[Dictionary]) -> String:
	var parts := PackedStringArray()

	for draw in draws:
		parts.append("%d@%s%s" % [draw.image.get_instance_id(), draw.position, draw.source])

	return "[" + ", ".join(parts) + "]"
