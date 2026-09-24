extends SceneTree

@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

class FixedRandom extends SimRandom:


	func next_u15() -> int:
		return 0

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(message)


func fixture(edge: int, version: int) -> Sc2File:
	var doc := EmptyCityTemplate.create(edge)

	if version == 3:
		check(doc.enable_full_resolution_maps(), "Enable per-tile maps")
	elif version == 1:
		doc.large_version = 1

		for id in ["XTXT", "XMIC", "XLAB", "XTHG"]:
			var data := doc.find_chunk(id).decoded_payload.duplicate()
			data.resize(doc.decoded_size(id))
			doc.find_chunk(id).set_decoded_payload(data)

	return doc


func _run() -> void:
	check_scan_helpers()

	for edge in [128, 256, 384, 512]:
		# Retain legacy widths and every SC2X version at the original and large sizes.
		var versions: Array = {128: [2, 3], 256: [1], 384: [2], 512: [3]}[edge]

		for version in versions:
			check_power(edge, version)
			check_power_trace_order(edge, version)
			check_water_source_order(edge, version)

			if edge == 128:
				check_power_queue_limit(version)
				check_water_queue_limit(version)

			check_water(edge, version)
			check_prisons(edge, version)
			print("PASS: utility capacities edge %d version %d" % [edge, version])

	print("Utility capacity regression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_power(edge: int, version: int) -> void:
	var doc := fixture(edge, version)
	var city := CityState.from_document(doc)
	var point := Vector2i(edge - 16, edge - 16)
	# One coal tile, police tile, arcology tile, and residential tile, connected.
	var buildings := [Tiles.COAL_POWER, Tiles.POLICE_STATION, Tiles.PLYMOUTH_ARCOLOGY, Tiles.LOWER_CLASS_HOMES_1X1_1]

	for index in buildings.size():
		city.set_building_id(point.x, point.y + index, buildings[index])
		city.set_tile_flag(point.x, point.y + index, PowerPhase.FLAG_POWERABLE, true)

	# The original counts every building from 0x70 up, except power plants.
	var expected := 3
	var result := PowerPhase.run(city, SimRandom.new(1))
	check(result.ok and result.generation == 44, "Plant generation stays unchanged")
	check(result.consumers == expected and result.supplied_consumers == expected, "Power consumers include civic buildings and arcologies")
	check(result.usage_percent == (expected * 100) / 44, "Power usage counts every consumer")

	for index in buildings.size():
		check(city.tile_flags[city.index_of(point.x, point.y + index)] & PowerPhase.FLAG_POWERED != 0, "Consumer statistics do not change power distribution")

	var bytes: PackedByteArray = doc.serialize().data
	var loaded := Sc2File.new()
	check(loaded.parse(bytes) and loaded.serialize(true).data == bytes, "Power update exact save round trip")
	check(PowerPhase.run(CityState.from_document(loaded), SimRandom.new(1)).consumers == expected, "Power rules survive reload")


# The bulk flag clear and the building search match a loop over single tiles.
func check_scan_helpers() -> void:
	for size in [13, 16384]:
		var flags := PackedByteArray()

		for index in size:
			flags.append((index * 71 + 5) % 256)

		var expected := flags.duplicate()

		for index in size:
			expected[index] &= ~(Sc2TileFlags.MARK | Sc2TileFlags.POWERED) & 0xff

		check(Sc2TileFlags.without(flags, Sc2TileFlags.MARK | Sc2TileFlags.POWERED) == expected, "Bulk flag clear matches a per-tile clear")

	var city := CityState.from_document(fixture(128, 2))
	var ids := PackedInt32Array([Tiles.GAS_POWER, Tiles.COAL_POWER])
	var expected_indices := PackedInt32Array()

	for index in [5, 700, 701, 9000, 16383]:
		city.set_building_id(index / 128, index % 128, ids[index % 2])
		expected_indices.append(index)

	check(city.building_indices(ids) == expected_indices, "Building search returns tiles in scan order")


# With too little capacity, power reaches tiles in the original trace order:
# the plant, then its y - 1, x - 1, y + 1 and x + 1 neighbors
func check_power_trace_order(edge: int, version: int) -> void:
	var city := CityState.from_document(fixture(edge, version))
	var point := Vector2i(edge / 2, edge / 2)

	for offset in range(-8, 9):
		city.set_building_id(point.x, point.y + offset, Tiles.GAS_POWER if offset == 0 else Tiles.LOWER_CLASS_HOMES_1X1_1)
		city.set_tile_flag(point.x, point.y + offset, PowerPhase.FLAG_POWERABLE, true)

	var result := PowerPhase.run(city, SimRandom.new(1))
	check(result.ok and result.generation == 11, "Gas plant supplies 11 units")

	# the plant uses one unit. the other ten go to the five nearest homes on each side
	for offset in range(-8, 9):
		var powered := city.tile_flags[city.index_of(point.x, point.y + offset)] & PowerPhase.FLAG_POWERED != 0
		check(powered == (absi(offset) <= 5), "Limited power follows the trace order at offset %d" % offset)


# Pumps start their networks in a scan order that depends on the compass rotation
func check_water_source_order(edge: int, version: int) -> void:
	var city := CityState.from_document(fixture(edge, version))
	var last := edge - 1

	for point in [Vector2i(0, 0), Vector2i(3, last), Vector2i(last, 2), Vector2i(7, 7), Vector2i(7, 9), Vector2i(9, 7), Vector2i(last, last)]:
		city.set_building_id(point.x, point.y, Tiles.DESALINIZATION if point.x == 7 else Tiles.WATER_PUMP)

	for rotation in 4:
		var expected := PackedInt32Array()

		for major in edge:
			for minor in edge:
				var x: int = [minor, major, last - minor, last - major][rotation]
				var y: int = [major, last - minor, last - major, minor][rotation]
				var building := city.buildings[x * edge + y]

				if building == Tiles.WATER_PUMP or building == Tiles.DESALINIZATION:
					expected.append(x * edge + y)

		check(WaterPhase._sources_in_scan_order(city, rotation) == expected, "Water sources follow the rotation %d scan order" % rotation)


# A very wide network overflows the original 512-entry trace queue.
func check_power_queue_limit(version: int) -> void:
	var doc := fixture(128, version)
	var city := CityState.from_document(doc)
	var powerable := 0

	for x in 128:
		for y in 128:
			var hole := x % 2 == 1 and y % 2 == 1
			city.set_building_id(x, y, Tiles.EMPTY if hole else Tiles.LOWER_CLASS_HOMES_1X1_1)
			city.set_tile_flag(x, y, PowerPhase.FLAG_POWERABLE, not hole)

			if not hole:
				powerable += 1

	for index in 30:
		city.set_building_id(58 + (index % 6) * 2, 58 + (index / 6) * 2, Tiles.FUSION_POWER)

	var result := PowerPhase.run(city, SimRandom.new(1))
	var powered := 0

	for flags in city.tile_flags:
		if flags & PowerPhase.FLAG_POWERED:
			powered += 1

	check(result.ok and result.generation > powerable, "Queue fixture has enough generation for every tile")

	if doc.is_extended():
		check(powered == powerable and result.consumers == powerable - 30, "SC2X power reaches every tile of a wide network")
	else:
		# Values from the original trace, with its dropped queue entries.
		check(powered == 11915 and result.consumers == 11885 and result.usage_percent == 71, "SC2 power keeps the original trace queue limit")


# A very wide pipe network overflows the same 512-entry trace queue.
func check_water_queue_limit(version: int) -> void:
	var doc := fixture(128, version)
	var city := CityState.from_document(doc)
	var consumers := 0
	doc.set_misc_u32(Sc2MiscLayout.WATER_LEVEL, 100)

	for x in 128:
		for y in 128:
			var hole := x % 2 == 1 and y % 2 == 1
			city.set_building_id(x, y, Tiles.EMPTY if hole else Tiles.LOWER_CLASS_HOMES_1X1_1)
			city.set_tile_flag(x, y, Sc2TileFlags.PIPED, not hole)

	for index in 30:
		var pump := Vector2i(58 + (index % 6) * 2, 58 + (index / 6) * 2)
		city.set_building_id(pump.x, pump.y, Tiles.WATER_PUMP)
		city.set_tile_flag(pump.x, pump.y, Sc2TileFlags.POWERED, true)

	for building in city.buildings:
		if building == Tiles.LOWER_CLASS_HOMES_1X1_1:
			consumers += 1

	var expected := _original_water(city)
	var result := WaterPhase.run(city)
	var watered := 0

	for flags in city.tile_flags:
		if flags & Sc2TileFlags.WATERED:
			watered += 1

	check(result.ok and result.supply > consumers, "Water queue fixture has enough supply for every tile")

	if doc.is_extended():
		check(watered == consumers + 30 and result.watered_consumers == consumers, "SC2X water reaches every tile of a wide network")
	else:
		check(city.tile_flags == expected.flags, "SC2 water keeps the original trace queue limit")
		check(result.watered_consumers == expected.used and result.supply == expected.supply, "SC2 water totals match the original trace")
		check(watered < consumers, "SC2 water drops tiles of a very wide network")


class OriginalWater extends RefCounted:
	var flags := PackedByteArray()
	var used := 0
	var supply := 0


# A direct model of the original water scan for a 128 map at rotation 0:
# a 512-entry ring queue that drops its oldest entry when full.
func _original_water(city: CityState) -> OriginalWater:
	var out := OriginalWater.new()
	var flags := city.tile_flags.duplicate()
	var buildings := city.buildings
	var base := int((city.document.misc_u32(Sc2MiscLayout.WEATHER_RAIN) & 0xff) / 2) + city.document.misc_u32(Sc2MiscLayout.WATER_LEVEL) * 5

	for index in flags.size():
		flags[index] &= ~(Sc2TileFlags.MARK if buildings[index] == Tiles.WATER_TOWER else Sc2TileFlags.MARK | Sc2TileFlags.WATERED) & 0xff

	for y in 128:
		for x in 128:
			var start := x * 128 + y
			var source := buildings[start] == Tiles.WATER_PUMP or buildings[start] == Tiles.DESALINIZATION

			if source and not flags[start] & Sc2TileFlags.WATERED and flags[start] & Sc2TileFlags.POWERED:
				var supply := 0
				var consumers := 0
				var storage := 0
				var ring := [PackedInt32Array(), 0, 0]
				ring[0].resize(512)
				_ring_push(ring, start)

				while ring[1] != ring[2]:
					var index := _ring_pop(ring)

					if flags[index] & Sc2TileFlags.MARK or not flags[index] & Sc2TileFlags.PIPED:
						continue

					var building := buildings[index]

					if building == Tiles.WATER_PUMP:
						if flags[index] & Sc2TileFlags.POWERED:
							supply += base

							for nx in range(index / 128 - 1, index / 128 + 2):
								for ny in range(index % 128 - 1, index % 128 + 2):
									if nx >= 0 and nx < 128 and ny >= 0 and ny < 128 and flags[nx * 128 + ny] & 5 == 4:
										supply += 10
					elif building == Tiles.WATER_TOWER:
						storage += 100

						if flags[index] & Sc2TileFlags.WATERED:
							supply += 100

						flags[index] &= ~Sc2TileFlags.WATERED & 0xff
					elif building > 0x6f and building != Tiles.WATER_TREATMENT and building != Tiles.DESALINIZATION:
						consumers += 1

					flags[index] |= Sc2TileFlags.MARK
					_ring_neighbors(ring, flags, index, 0)

				consumers = mini(consumers, supply)
				storage = int((mini(storage, supply - consumers) + 50) / 100)
				out.used += consumers
				out.supply += supply
				_ring_push(ring, start)

				while ring[1] != ring[2]:
					var index := _ring_pop(ring)

					if not flags[index] & Sc2TileFlags.MARK:
						continue

					var building := buildings[index]

					if building == Tiles.WATER_PUMP or building == Tiles.WATER_TREATMENT or building == Tiles.DESALINIZATION:
						if flags[index] & Sc2TileFlags.POWERED:
							flags[index] |= Sc2TileFlags.WATERED
					elif building == Tiles.WATER_TOWER:
						if flags[index] & Sc2TileFlags.POWERED and storage != 0:
							flags[index] |= Sc2TileFlags.WATERED
							storage -= 1
					elif consumers != 0:
						flags[index] |= Sc2TileFlags.WATERED

						if building > 0x6f:
							consumers -= 1

					flags[index] &= ~Sc2TileFlags.MARK & 0xff
					_ring_neighbors(ring, flags, index, Sc2TileFlags.MARK)

	out.flags = flags

	return out


func _ring_push(ring: Array, index: int) -> void:
	ring[0][ring[2]] = index
	ring[2] = (ring[2] + 1) & 511

	if ring[1] == ring[2]:
		ring[1] = (ring[1] + 1) & 511


func _ring_pop(ring: Array) -> int:
	var index: int = ring[0][ring[1]]
	ring[1] = (ring[1] + 1) & 511

	return index


func _ring_neighbors(ring: Array, flags: PackedByteArray, index: int, mark: int) -> void:
	var x := index / 128
	var y := index % 128

	if y > 0 and flags[index - 1] & Sc2TileFlags.MARK == mark:
		_ring_push(ring, index - 1)

	if x > 0 and flags[index - 128] & Sc2TileFlags.MARK == mark:
		_ring_push(ring, index - 128)

	if y < 127 and flags[index + 1] & Sc2TileFlags.MARK == mark:
		_ring_push(ring, index + 1)

	if x < 127 and flags[index + 128] & Sc2TileFlags.MARK == mark:
		_ring_push(ring, index + 128)


func check_water(edge: int, version: int) -> void:
	var doc := fixture(edge, version)
	var city := CityState.from_document(doc)

	# Synthetic saved counters exercise both sides of the old word boundary.
	# Exhaustive count boundaries at original/native 128 and legacy SC2X v1.
	for count in ([0, 8, 32764, 32768, 65536, 70000] if edge <= 256 else [70000]):
		doc.set_misc_u32(WaterPhase.MISC_TILE_COUNTS + WaterPhase.WATER_TREATMENT * 4, count)
		var expected_count: int = count

		if not doc.is_extended():
			expected_count &= 65535

			if expected_count >= 32768:
				expected_count -= 65536

		var expected_capacity := (expected_count / 4) * 2000
		var result := WaterPhase.run(city)
		check(result.ok and result.treatment_capacity == expected_capacity, "Water treatment retains full SC2X count and legacy SC2 width")
		check(result.treatment_sufficient == (expected_capacity >= 0), "Treatment sufficiency follows computed capacity")
		check(doc.misc_u32(WaterPhase.MISC_TILE_COUNTS + WaterPhase.WATER_TREATMENT * 4) == count, "Treatment calculation does not rewrite saved tile count")


func check_prisons(edge: int, version: int) -> void:
	var doc := fixture(edge, version)
	var count := mini(700, (doc.decoded_size("XMIC") / 8) - 1)

	for score in ([79, 80, 100] if edge <= 256 else [100]):
		var data := doc.find_chunk("XMIC").decoded_payload.duplicate()
		data.fill(0)

		for record in range(1, count + 1):
			var offset := record * 8
			data[offset] = MicrosimAnnualPhase.TILE_PRISON
			var prisoners: int = score * 400 / 3
			data[offset + 2] = prisoners >> 8
			data[offset + 3] = prisoners & 255

		doc.find_chunk("XMIC").set_decoded_payload(data)
		doc.set_misc_u32(0x01f0 + MicrosimAnnualPhase.TILE_PRISON * 4, count * 16)
		doc.set_misc_u32(0x102c, 1000000)
		doc.set_misc_u32(0x1038, 0)
		doc.set_misc_u32(0x077c + 5 * 0x006c + 4, 100)
		var result := MicrosimAnnualPhase.run(CityState.from_document(doc), 0, 0, 0, FixedRandom.new())
		check(result.ok, "Annual prison phase completes")
		check(doc.misc_u32(0x103c) == (1 if score <= 79 else 0), "Prison bonus uses actual average, including sums over 65535")
		data = doc.find_chunk("XMIC").decoded_payload
		var total := 0

		for record in range(1, count + 1):
			total += (int(data[record * 8 + 6]) << 8) | int(data[record * 8 + 7])

		check(total == count * score, "Individual prison record widths and scores stay unchanged")

	var bytes: PackedByteArray = doc.serialize().data
	var loaded := Sc2File.new()
	check(loaded.parse(bytes) and loaded.serialize(true).data == bytes, "Annual prison exact save round trip")
