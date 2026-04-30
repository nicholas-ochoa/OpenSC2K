extends SceneTree

class FixedRandom extends RefCounted:


	func next_u15() -> int:
		return 0


	func next_mask(_mask: int) -> int:
		return 0

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(message)


func fill(doc: Sc2File, id: String, value: int) -> void:
	var data := doc.find_chunk(id).decoded_payload.duplicate()
	data.fill(value)
	doc.find_chunk(id).set_decoded_payload(data)


func total(data: PackedByteArray) -> int:
	var sum := 0

	for value in data:
		sum += value

	return sum


func _run() -> void:
	for edge in Sc2File.MAP_SIZES:
		check_industrial_samples(edge)

		if edge in [128, 512]:
			for native in [false, true]:
				check_maps(edge, native)
				check_district(edge, native)

		print("PASS: data map regression at %d" % edge)

	print("Data map regression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_maps(edge: int, native: bool) -> void:
	var doc := EmptyCityTemplate.create(edge)

	if native:
		check(doc.enable_full_resolution_maps(), "Enable per-tile fixture")

	var city := CityState.from_document(doc)
	# Exercise the producer as well as the consumer. An empty industrial sector
	# takes the original below-20-percent branch and stores low-word minus one.
	var rng := FixedRandom.new()
	check(IndustryPhase.run(city, rng, rng, 0).ok, "Industry phase completes")
	check(doc.misc_u32(0x1034) == 65535, "Industry retains original low-word encoding")

	for encoding in [65535, 4294967295, 0, 1, 2]:
		doc.set_misc_u32(0x1034, encoding)
		doc.set_misc_u32(0x104c, 0)
		doc.set_misc_u32(0xfa0, 0)
		var expected: int = 5 if encoding > 2 else 4 - encoding
		check(PollutionPhase.pollution_divisor(doc) == expected, "Signed pollution modifier")
		doc.set_misc_u32(0x104c, 1)
		doc.set_misc_u32(0xfa0, PollutionPhase.CLEAN_INDUSTRY_ORDINANCE)
		check(PollutionPhase.pollution_divisor(doc) == expected + 2, "Treatment and clean industry combine")

	doc.set_misc_u32(0x1034, 65535)
	doc.set_misc_u32(0x104c, 0)
	doc.set_misc_u32(0xfa0, 0)
	fill(doc, "XPLT", 255)
	fill(doc, "XTRF", 0)
	fill(doc, "XCRM", 255)
	fill(doc, "XVAL", 255)
	fill(doc, "XPOP", 255)
	var previous_total := total(doc.find_chunk("XPLT").decoded_payload)

	# Initial cleanup plus repeated decay catches retained scratch data.
	for month in 2:
		check(PollutionPhase.run(city).ok, "Repeated data phase completes")
		var pollution := doc.find_chunk("XPLT").decoded_payload
		var next_total := total(pollution)
		check(next_total < previous_total, "Source-free saturated pollution decays each month")
		previous_total = next_total

		if month == 0:
			var grid_edge := edge if native else IntegerMath.div_trunc(edge, 2)
			check(pollution[(IntegerMath.div_trunc(grid_edge, 2)) * grid_edge + IntegerMath.div_trunc(grid_edge, 2)] == 170, "Uniform interior decays from 255 to 170")
			check(pollution[0] == 145, "Corner omits absent pollution samples")

		check(doc.find_chunk("XVAL").decoded_payload.count(0) == doc.find_chunk("XVAL").decoded_payload.size(), "Empty land does not retain old land values")
		check(doc.find_chunk("XCRM").decoded_payload.count(0) == doc.find_chunk("XCRM").decoded_payload.size(), "Empty land does not retain or amplify old crime")

		for field in [["XPLT", 0x34], ["XVAL", 0x28], ["XCRM", 0x2c]]:
			var sum := total(doc.find_chunk(field[0]).decoded_payload)
			check(doc.misc_u32(field[1]) == (IntegerMath.div_trunc(sum, 4) if native else sum), "Saved aggregate matches " + field[0])

	# Every byte value, including the original 1..3 rounding floor.
	var traffic := doc.find_chunk("XTRF").decoded_payload.duplicate()

	for index in traffic.size():
		traffic[index] = index % 256

	doc.find_chunk("XTRF").set_decoded_payload(traffic)
	check(TrafficPhase.run(city).ok, "Traffic decay completes")
	var decayed := doc.find_chunk("XTRF").decoded_payload
	var exact := true

	for index in decayed.size():
		exact = exact and decayed[index] == int(traffic[index]) - (int(traffic[index]) >> 2)

	check(exact, "Every traffic byte decays without wrapping")
	check(doc.misc_u32(0x30) == (IntegerMath.div_trunc(total(decayed), 4) if native else total(decayed)), "Traffic aggregate retains wide sum")
	var bytes: PackedByteArray = doc.serialize().data
	var loaded := Sc2File.new()
	check(loaded.parse(bytes) and loaded.serialize(true).data == bytes, "Updated grids survive exact save round trip")


func check_industrial_samples(edge: int) -> void:
	var scratch := PackedInt32Array()
	scratch.resize(edge * edge)
	var offset := IntegerMath.div_trunc(edge, 4)
	# Distinct grids: industrial center 30 and neighbors 10, 20, 40, 50.
	# Residential X-neighbors must not enter the industrial mean.
	var x := offset - 2
	var y := offset - 2
	scratch[(x + offset) * edge + y] = 30
	scratch[(x - 1) * edge + y] = 100
	scratch[(x + 1) * edge + y] = 200
	scratch[(x + offset) * edge + y - 1] = 40
	scratch[(x + offset) * edge + y + 1] = 50
	scratch[(x + offset - 1) * edge + y] = 10
	scratch[(x + offset + 1) * edge + y] = 20
	check(PollutionPhase._average_service_grid(scratch, x, y, offset, edge) == 30, "Industrial land samples only industrial scratch rows")


func check_district(edge: int, native: bool) -> void:
	var doc := EmptyCityTemplate.create(edge)

	if native:
		doc.enable_full_resolution_maps()

	var city := CityState.from_document(doc)
	var point := Vector2i(edge - 32, edge - 32)

	for x in range(point.x - 12, point.x + 13):
		for y in range(point.y - 12, point.y + 13):
			city.set_building_id(x, y, 0x93)
			city.set_zone_id(x, y, 3)
			city.set_tile_flag(x, y, PollutionPhase.FLAG_WATERED, true)

	fill(doc, "XCRM", 0)
	fill(doc, "XPLT", 0)
	fill(doc, "XPOP", 192)
	var high_crime := doc.duplicate_document()
	fill(high_crime, "XCRM", 255)
	check(PollutionPhase.run(city).ok, "Developed district calculates land and crime")
	check(PollutionPhase.run(CityState.from_document(high_crime)).ok, "High-crime district calculates land and crime")
	var land := doc.find_chunk("XVAL").decoded_payload
	var index := CityDataGrid.index(land, edge, point.x, point.y)
	check(high_crime.find_chunk("XVAL").decoded_payload[index] == maxi(int(land[index]) - 85, 0), "Prior crime subtracts 255 / 3 from commercial land value")
	var crime := doc.find_chunk("XCRM").decoded_payload
	check(crime[index] > 0 and crime[index] < 255, "Dense district produces bounded nonzero crime")
	check(high_crime.find_chunk("XCRM").decoded_payload[index] >= crime[index], "Lower land value increases crime pressure")
	# Check traffic saturation at far-map coordinates, without wrapping or
	# writing another cell. Failed trips leave traffic unchanged.
	var origin := Vector2i(edge - 8, edge - 8)

	for dy in [1, 2, 3]:
		city.set_building_id(origin.x, origin.y + dy, 0x1d)

	city.set_zone_id(origin.x, origin.y, 1)
	city.set_zone_id(origin.x, origin.y + 4, 3)
	fill(doc, "XTRF", 254)
	var trip := TransportTrip.run(city, origin, 1, 2, SimRandom.new(1))
	check(trip.ok and trip.reached_destination, "Far-map road trip succeeds")
	var traffic := doc.find_chunk("XTRF").decoded_payload

	# The destination is three walking tiles from the first road tile. The trip
	# stops there; later road tiles are not traversed. In coarse mode adjacent
	# road tiles can share the same traffic cell.
	var expected_traffic := PackedByteArray()
	expected_traffic.resize(traffic.size())
	expected_traffic.fill(254)
	expected_traffic[CityDataGrid.index(traffic, edge, origin.x, origin.y + 1)] = 255
	check(traffic == expected_traffic, "Traversed traffic saturates at 255; all other cells stay unchanged")
	city.set_zone_id(origin.x, origin.y + 4, 1)
	trip = TransportTrip.run(city, origin, 1, 2, SimRandom.new(1))
	check(trip.ok and not trip.reached_destination and doc.find_chunk("XTRF").decoded_payload == traffic, "Failed road trip leaves traffic unchanged")
