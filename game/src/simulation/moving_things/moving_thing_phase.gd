class_name MovingThingPhase
extends RefCounted

const TrainTick = preload("res://src/simulation/moving_things/train_thing_tick.gd")
const SailboatTick = preload("res://src/simulation/moving_things/sailboat_thing_tick.gd")
const ShipTick = preload("res://src/simulation/moving_things/ship_thing_tick.gd")
const AirTick = preload("res://src/simulation/moving_things/air_thing_tick.gd")
const MaxisManTick = preload("res://src/simulation/moving_things/maxis_man_thing_tick.gd")
const DisasterTick = preload("res://src/simulation/disasters/disaster_thing_tick.gd")
const RECORD_SIZE := 12
const FIRST_RECORD := 1
const LAST_RECORD := 39
const TEXT_LABEL_BASE := 201
const TYPE_AIRPLANE := 1
const TYPE_HELICOPTER := 2
const TYPE_SHIP := 3
const TYPE_MONSTER := 5
const TYPE_EXPLOSION := 6
const TYPE_SAILBOAT := 9
const TYPE_TRAIN_ENGINE := 10
const TYPE_SUBWAY_ENGINE := 12
const TYPE_TORNADO := 15
const TYPE_MAXIS_MAN := 16
const MISC_CITY_CENTER_X := Sc2MiscLayout.CITY_CENTER_X
const MISC_CITY_CENTER_Y := Sc2MiscLayout.CITY_CENTER_Y
# things and text change on nearly every tick; the map chunks follow
const COMMIT_ORDER := [
	"XTHG", "XTXT", "ALTM", "XBLD", "XTER", "XZON", "XUND", "XBIT", "XTRF", "XLAB", "XMIC", "MISC",
]


# chunks and working copies for one tick, plus the generators and options
# the record updates share. the steps are methods because member reads on
# self are indexed; static steps that read these fields from outside cost
# several percent more per 5 hz tick
class TickContext:
	var city: CityState
	var map_edge: int
	# indexed like commit_order
	var chunks: Array[Sc2Chunk] = []
	var map_payloads_writable := false
	var altitude: PackedByteArray
	var buildings: PackedByteArray
	var terrain: PackedByteArray
	var zones: PackedByteArray
	var underground: PackedByteArray
	var flags: PackedByteArray
	var traffic: PackedByteArray
	var text: PackedByteArray
	var things: PackedByteArray
	var labels: PackedByteArray
	var microsims: PackedByteArray
	var misc: PackedByteArray
	var random: SimRandom
	var lfsr_random: SimLfsrRandom
	var game_random: GameLcgRandom
	var ship_home: Vector2i
	var allow_disaster_damage: bool
	var suppress_vehicle_crashes: bool


	func _init(
		tick_random: SimRandom,
		tick_lfsr_random: SimLfsrRandom,
		tick_game_random: GameLcgRandom,
		tick_ship_home: Vector2i,
		tick_allow_disaster_damage: bool,
		tick_suppress_vehicle_crashes: bool
	) -> void:
		random = tick_random
		lfsr_random = tick_lfsr_random
		game_random = tick_game_random
		ship_home = tick_ship_home
		allow_disaster_damage = tick_allow_disaster_damage
		suppress_vehicle_crashes = tick_suppress_vehicle_crashes


	# find each input chunk, check its size, and give the records a working copy
	# of xthg and xtxt. other payloads are read-only until prepare_map_writes
	# returns false when a chunk is missing or has the wrong size
	func load_payloads(source: CityState) -> bool:
		city = source
		map_edge = source.map_size
		var document := source.document
		var tile_count := map_edge * map_edge
		var expected_sizes := [
			document.decoded_size("XTHG"), document.decoded_size("XTXT"), tile_count * 2,
			tile_count, tile_count, tile_count, tile_count, tile_count,
			document.decoded_size("XTRF"), document.decoded_size("XLAB"),
			document.decoded_size("XMIC"), 4800,
		]

		for index in COMMIT_ORDER.size():
			var chunk := document.find_chunk(COMMIT_ORDER[index])

			if chunk == null or chunk.decoded_payload.size() != expected_sizes[index]:
				return false

			chunks.append(chunk)

		things = chunks[0].decoded_payload.duplicate()
		text = chunks[1].decoded_payload.duplicate()
		altitude = chunks[2].decoded_payload
		buildings = chunks[3].decoded_payload
		terrain = chunks[4].decoded_payload
		zones = chunks[5].decoded_payload
		underground = chunks[6].decoded_payload
		flags = chunks[7].decoded_payload
		traffic = chunks[8].decoded_payload
		labels = chunks[9].decoded_payload
		microsims = chunks[10].decoded_payload
		misc = chunks[11].decoded_payload

		return true


	# ordinary vehicles only write xthg and xtxt. copy the map planes just before
	# the first disaster record, including a record spawned earlier in this tick
	func prepare_map_writes() -> void:
		if map_payloads_writable:
			return

		altitude = altitude.duplicate()
		buildings = buildings.duplicate()
		terrain = terrain.duplicate()
		zones = zones.duplicate()
		underground = underground.duplicate()
		flags = flags.duplicate()
		traffic = traffic.duplicate()
		labels = labels.duplicate()
		microsims = microsims.duplicate()
		misc = misc.duplicate()
		map_payloads_writable = true


	# update each thing record with its type's tick rule, in record order
	func update_records(counters: MovingThingResult) -> void:
		var city_center := Vector2i(
			city.document.misc_u32(MISC_CITY_CENTER_X),
			city.document.misc_u32(MISC_CITY_CENTER_Y)
		)

		var slice := city.simulation_slice

		for record in range(FIRST_RECORD, ThingData.count(things)):
			if slice != null:
				slice.checkpoint()

			var offset := record * RECORD_SIZE

			match int(ThingData.read(things, offset)):
				TYPE_AIRPLANE:
					counters.active_airplanes += 1
					AirTick.update_airplane(
						buildings, zones, text, things, record,
						random, lfsr_random, counters, map_edge, city.no_disasters_enabled(),
						suppress_vehicle_crashes
					)
				TYPE_HELICOPTER:
					counters.active_helicopters += 1
					AirTick.update_helicopter(
						buildings, underground, traffic, text, things, record,
						city_center, random, counters, map_edge, city.no_disasters_enabled(),
						suppress_vehicle_crashes
					)
				TYPE_SHIP:
					counters.active_ships += 1
					ShipTick.update(
						buildings, underground, flags, text, things, record,
						ThingData.ship_home(things, record, ship_home), random, lfsr_random, counters, map_edge
					)
				TYPE_MONSTER:
					prepare_map_writes()
					counters.active_monsters += 1
					DisasterTick.update_monster(
						city, altitude, buildings, terrain, zones, underground,
						flags, traffic, text, labels, microsims, misc, things,
						record, city_center, random, lfsr_random, counters
					)
				TYPE_EXPLOSION:
					prepare_map_writes()
					counters.active_explosions += 1
					DisasterTick.update_explosion(
						city, altitude, buildings, terrain, zones, underground,
						flags, traffic, text, labels, microsims, misc, things,
						record, random, lfsr_random, allow_disaster_damage, counters
					)
				TYPE_SAILBOAT:
					counters.active_sailboats += 1
					SailboatTick.update(
						buildings, flags, text, things, record, random, lfsr_random, counters, map_edge
					)
				TYPE_TRAIN_ENGINE, TYPE_SUBWAY_ENGINE:
					counters.active_trains += 1
					TrainTick.update(
						buildings, underground, text, things, record,
						random, lfsr_random, game_random, counters, map_edge
					)
				TYPE_TORNADO:
					prepare_map_writes()
					counters.active_tornadoes += 1
					DisasterTick.update_tornado(
						city, altitude, buildings, terrain, zones, underground,
						flags, text, labels, microsims, misc, things, record,
						random, counters
					)
				TYPE_MAXIS_MAN:
					counters.active_maxis_men += 1
					MaxisManTick.update(
						altitude, flags, text, things, record, random, counters, map_edge
					)


	# store each changed working copy, newest-changing chunks first. on a failed
	# store, restore the chunks already stored and return the failed chunk id
	func commit_payloads() -> String:
		var working := [
			things, text, altitude, buildings, terrain, zones,
			underground, flags, traffic, labels, microsims, misc,
		]
		var replaced: Array = []
		var committed := PackedStringArray()

		for index in (COMMIT_ORDER.size() if map_payloads_writable else 2):
			var chunk := chunks[index]
			var original := chunk.decoded_payload

			if working[index] == original:
				continue

			if not chunk.set_decoded_payload(working[index], true):
				for rollback in replaced:
					rollback[0].set_decoded_payload(rollback[1])

				return COMMIT_ORDER[index]

			replaced.push_front([chunk, original])
			committed.append(COMMIT_ORDER[index])

		# most ticks only move things, so they write xthg and xtxt and nothing else
		# resyncing the chunks this tick actually wrote keeps the other map mirrors
		# and the altitude decode out of the 5 hz path
		city.resync_mirrors(committed)

		return ""


static func run(
	city: CityState,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	game_random: GameLcgRandom = null,
	ship_home := Vector2i(-1, -1),
	allow_disaster_damage := true,
	traffic_news_time_msec := -1,
	traffic_news_deadline_msec := 0,
	suppress_vehicle_crashes := false
) -> MovingThingResult:
	if city == null or not city.is_valid():
		return MovingThingResult.failure("city is invalid")

	if random == null:
		return MovingThingResult.failure("a compatible random generator is required")

	if lfsr_random == null:
		return MovingThingResult.failure("a compatible LFSR generator is required")

	if game_random == null:
		game_random = GameLcgRandom.new(1)

	if traffic_news_time_msec < 0:
		traffic_news_time_msec = Time.get_ticks_msec()

	var tick := TickContext.new(
		random, lfsr_random, game_random, ship_home, allow_disaster_damage, suppress_vehicle_crashes
	)

	if not tick.load_payloads(city):
		return MovingThingResult.failure("moving-thing input chunks are missing or have the wrong size")

	var counters := _new_counters(tick.things, traffic_news_time_msec, traffic_news_deadline_msec)
	tick.update_records(counters)
	var failed_chunk := tick.commit_payloads()

	if not failed_chunk.is_empty():
		return MovingThingResult.failure("cannot store %s after the moving-thing tick" % failed_chunk)

	_mark_complete(counters)

	return counters


static func _new_counters(
	things: PackedByteArray, traffic_news_time_msec: int, traffic_news_deadline_msec: int
) -> MovingThingResult:
	var counters := MovingThingResult.new()
	counters.scanned_records = ThingData.count(things) - 1
	counters.traffic_news_time_msec = traffic_news_time_msec
	counters.traffic_news_deadline_msec = traffic_news_deadline_msec

	return counters


static func _mark_complete(counters: MovingThingResult) -> void:
	counters.ok = true
	counters.sailboats_complete = true
	counters.train_routes_complete = true
	counters.helicopters_save_visible_complete = true
	counters.ships_save_visible_complete = true
	counters.airplanes_save_visible_complete = true
	counters.explosion_records_complete = true
	counters.tornadoes_save_visible_complete = true
	counters.maxis_man_save_visible_complete = true
	counters.monsters_save_visible_complete = true
	counters.explosion_map_damage_complete = counters.deferred_facility_explosion_hits == 0
	counters.complete = counters.explosion_map_damage_complete
	counters.error = ""
