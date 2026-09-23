class_name CityDebugActions
extends RefCounted

@warning_ignore_start("integer_division")

const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
const DisasterStart = preload("res://src/simulation/disasters/disaster_start_phase.gd")
const MovingThingSpawner = preload("res://src/simulation/moving_things/moving_thing_spawner.gd")

const MAX_FUNDS := 0x7fffffff
const MIN_FUNDS := -0x80000000
const MISC_SIZE := Sc2MiscLayout.SIZE
const NORMAL_CITY_MODE := 1
const DISASTER_OVERLAY_FIRST := 0xfb
const MAXIS_TARGET_OVERLAY_FIRST := 241
# order of the debug spawn list
const SPAWN_TYPES := ["Helicopter", "Airplane", "Cargo ship", "Sailboats", "Train"]
const TRAIN_SEARCH_RADIUS := 16


class Result extends RefCounted:
	var ok := false
	var error := ""


class FundsResult extends Result:
	var new_funds := 0


class EndDisasterResult extends Result:
	var active_type := 0
	var cleared_markers := 0
	var cleared_objects := 0


class DispatchResult extends Result:
	var start := Vector2i.ZERO
	var target := Vector2i.ZERO


class SpawnResult extends Result:
	var point := Vector2i.ZERO
	var count := 0


class RemoveResult extends Result:
	var count := 0


class DisasterTarget extends RefCounted:
	var point := Vector2i.ZERO
	var goal := 0


# days from the founding date. days run from 1 to 25 in each month
static func age_for_date(city: CityState, month: int, day: int, year: int) -> int:
	return ((year - city.founding_year()) * CityCalendar.DAYS_PER_YEAR + (month - 1) * CityCalendar.DAYS_PER_MONTH
		+ day - 1)


static func add_funds(city: CityState, amount: int) -> FundsResult:
	if city == null or amount <= 0:
		var result := FundsResult.new()
		result.ok = false
		result.error = "No city is loaded."

		return result

	var new_funds := mini(MAX_FUNDS, city.funds() + amount)

	if not city.set_funds(new_funds):
		var result := FundsResult.new()
		result.ok = false
		result.error = "Funds could not be changed."

		return result

	var result := FundsResult.new()
	result.ok = true
	result.new_funds = new_funds

	return result


static func set_funds(city: CityState, amount: int) -> FundsResult:
	var result := FundsResult.new()

	if city == null:
		result.error = "No city is loaded."
	elif amount < MIN_FUNDS or amount > MAX_FUNDS:
		result.error = "Funds must be from $%d to $%d." % [MIN_FUNDS, MAX_FUNDS]
	elif not city.set_funds(amount):
		result.error = "Funds could not be changed."
	else:
		result.ok = true
		result.new_funds = amount

	return result


static func unlock_everything(city: CityState, document: Sc2File) -> Result:
	if city == null or document == null:
		var result := Result.new()
		result.ok = false
		result.error = "No city is loaded."

		return result

	var misc_chunk := document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != MISC_SIZE:
		var result := Result.new()
		result.ok = false
		result.error = "The city MISC data is not valid."

		return result

	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	BinaryData.write_u32_be(misc, ToolAvailability.MISC_PROGRESSION, 6)
	BinaryData.write_u32_be(
		misc, ToolAvailability.MISC_GRANTED_REWARDS, 0xffff
	)

	for invention_index in ToolAvailability.INVENTION_COUNT:
		BinaryData.write_u32_be(
			misc,
			ToolAvailability.MISC_INVENTION_YEARS + invention_index * 4,
			0,
		)

	var ordinances := BinaryData.read_u32_be(
		misc, ToolAvailability.MISC_ORDINANCES
	)
	BinaryData.write_u32_be(
		misc,
		ToolAvailability.MISC_ORDINANCES,
		ordinances & ~ToolAvailability.ORDINANCE_NUCLEAR_FREE,
	)

	if not misc_chunk.set_decoded_payload(misc):
		var result := Result.new()
		result.ok = false
		result.error = "The unlock state could not be stored."

		return result

	var result := Result.new()
	result.ok = true

	return result


# open the military prompt now. no day phases run after the answer
static func offer_military_base(controller: GameSpeedController) -> Result:
	var engine := controller.engine if controller != null else null
	var result := Result.new()

	if engine == null or engine.city == null or not engine.city.is_valid():
		result.error = "No city is loaded."
	elif engine.terminal_state:
		result.error = "The game has ended."
	elif not engine.pending_interaction.is_empty() or controller.interaction_blocked:
		result.error = "Another prompt is waiting for an answer."
	elif engine.city.document.misc_u32(Sc2MiscLayout.MILITARY_BASE_TYPE) >= MilitaryProposalPhase.BASE_ARMY:
		result.error = "The city already has a military base."

	if not result.error.is_empty():
		return result

	var schedule := SimulationClock.state_for_day(engine.clock.city_days)
	schedule.actions = PackedStringArray()
	engine.pending_interaction = "military_proposal"
	engine.pending_day_schedule = schedule
	controller.interaction_blocked = true
	result.ok = true

	return result


static func set_no_disasters(city: CityState, enabled: bool) -> Result:
	if city == null:
		var result := Result.new()
		result.ok = false
		result.error = "No city is loaded."

		return result

	if not city.set_no_disasters_enabled(enabled):
		var result := Result.new()
		result.ok = false
		result.error = "The random-disaster option could not be stored."

		return result

	var result := Result.new()
	result.ok = true

	return result


static func end_disaster(
	city: CityState,
	document: Sc2File,
	engine: SimulationEngine,
) -> EndDisasterResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or document == null or engine == null:
		var result := EndDisasterResult.new()
		result.ok = false
		result.error = "No city is loaded."

		return result

	var thing_chunk := document.find_chunk("XTHG")
	var text_chunk := document.find_chunk("XTXT")
	var misc_chunk := document.find_chunk("MISC")

	if not _valid_disaster_chunks(thing_chunk, text_chunk, misc_chunk, map_edge):
		var result := EndDisasterResult.new()
		result.ok = false
		result.error = "The city disaster data is not valid."

		return result

	var old_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var old_text: PackedByteArray = text_chunk.decoded_payload.duplicate()
	var things := old_things.duplicate()
	var text := old_text.duplicate()
	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var disaster_records := _disaster_record_indices(things)
	var cleared_markers := _clear_disaster_markers(text, things, disaster_records, map_edge)
	_clear_thing_records(things, disaster_records)
	BinaryData.write_u32_be(misc, Sc2MiscLayout.CITY_MODE, NORMAL_CITY_MODE)
	BinaryData.write_u32_be(misc, Sc2MiscLayout.DISASTER_TYPE, 0)
	var active_type := engine.active_disaster_type
	var had_disaster := (
		active_type != 0
		or engine.pending_disaster_type != 0
		or not disaster_records.is_empty()
		or cleared_markers > 0
	)

	if not had_disaster:
		var result := EndDisasterResult.new()
		result.ok = false
		result.error = "No active disaster was found."

		return result

	if not thing_chunk.set_decoded_payload(things):
		var result := EndDisasterResult.new()
		result.ok = false
		result.error = "The disaster objects could not be cleared."

		return result

	if not text_chunk.set_decoded_payload(text):
		thing_chunk.set_decoded_payload(old_things)

		var result := EndDisasterResult.new()
		result.ok = false
		result.error = "The disaster markers could not be cleared."

		return result

	if not misc_chunk.set_decoded_payload(misc):
		thing_chunk.set_decoded_payload(old_things)
		text_chunk.set_decoded_payload(old_text)

		var result := EndDisasterResult.new()
		result.ok = false
		result.error = "The disaster mode could not be cleared."

		return result

	city.resync_mirrors(["XTXT"])
	_reset_disaster_engine(engine)

	var result := EndDisasterResult.new()
	result.ok = true
	result.active_type = active_type
	result.cleared_markers = cleared_markers
	result.cleared_objects = disaster_records.size()

	return result


static func dispatch_maxis_man(
	city: CityState,
	document: Sc2File,
	view_center: Vector2i,
) -> DispatchResult:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or document == null:
		var result := DispatchResult.new()
		result.ok = false
		result.error = "No city is loaded."

		return result

	var target := _disaster_target(city, document, view_center)

	if target == null:
		var result := DispatchResult.new()
		result.ok = false
		result.error = "No active disaster target was found."

		return result

	var start := _maxis_man_start(city, target.point)

	if start.x < 0:
		var result := DispatchResult.new()
		result.ok = false
		result.error = "No clear launch tile was found."

		return result

	var thing_chunk := document.find_chunk("XTHG")
	var text_chunk := document.find_chunk("XTXT")

	if thing_chunk == null or text_chunk == null:
		var result := DispatchResult.new()
		result.ok = false
		result.error = "The moving-object data is missing."

		return result

	var old_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var things: PackedByteArray = old_things.duplicate()
	var text: PackedByteArray = city.text_overlays.duplicate()
	var spawned := MovingThingSpawner.spawn_maxis_man(
		things,
		text,
		start,
		target.point,
		int(target.goal),
		city.object_altitude(start.x, start.y) + 4, map_edge,
	)

	if not spawned.spawned:
		var result := DispatchResult.new()
		result.ok = false
		result.error = "Maxis Man is already active or no record is free."

		return result

	if not thing_chunk.set_decoded_payload(things):
		var result := DispatchResult.new()
		result.ok = false
		result.error = "The Maxis Man record could not be stored."

		return result

	if not text_chunk.set_decoded_payload(text):
		thing_chunk.set_decoded_payload(old_things)

		var result := DispatchResult.new()
		result.ok = false
		result.error = "The Maxis Man map link could not be stored."

		return result

	city.resync_mirrors(["XTXT"])

	var result := DispatchResult.new()
	result.ok = true
	result.start = start
	result.target = target.point

	return result


# add a moving thing near the view center. the spawn uses its own random
# generators, so the saved simulation random state does not change
static func spawn_moving_thing(
	city: CityState,
	document: Sc2File,
	engine: SimulationEngine,
	kind: int,
	view_center: Vector2i,
	seed: int,
) -> SpawnResult:
	var result := SpawnResult.new()

	if city == null or document == null or engine == null:
		result.error = "No city is loaded."

		return result

	var thing_chunk := document.find_chunk("XTHG")
	var text_chunk := document.find_chunk("XTXT")

	if thing_chunk == null or text_chunk == null:
		result.error = "The moving-object data is missing."

		return result

	var map_edge := city.map_size
	var old_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var things := old_things.duplicate()
	var text: PackedByteArray = city.text_overlays.duplicate()
	var buildings: PackedByteArray = document.find_chunk("XBLD").decoded_payload
	var random := SimRandom.new(seed)
	var lfsr_random := SimLfsrRandom.new(maxi(1, seed & 0xffff))
	var game_random := GameLcgRandom.new(seed)

	match kind:
		0:
			var spawned := MovingThingSpawner.spawn_helicopter(things, text, view_center, random, map_edge)
			result.count = 1 if spawned.spawned else 0
			result.point = spawned.point
			result.error = "The view center is blocked, a monster is active, or the helicopter limit is reached."
		1:
			var spawned := MovingThingSpawner.spawn_airplane(things, text, view_center, 0, random, map_edge)
			result.count = 1 if spawned.spawned else 0
			result.point = spawned.point
			result.error = "The view center is blocked, a monster is active, or the airplane limit is reached."
		2:
			var terrain: PackedByteArray = document.find_chunk("XTER").decoded_payload
			var spawned := MovingThingSpawner.spawn_ship(terrain, things, text, view_center, random, map_edge)
			result.count = 1 if spawned.spawned else 0
			result.point = spawned.point
			result.error = "A cargo ship needs deep water near a map edge. Only one cargo ship can be active."
		3:
			var flags: PackedByteArray = document.find_chunk("XBIT").decoded_payload
			result.count = MovingThingSpawner.spawn_sailboats(buildings, flags, things, text, view_center, lfsr_random, map_edge)
			result.point = view_center
			result.error = "Sailboats need open water next to the view center, and the sailboat limit applies."
		4:
			result.point = _spawn_train_near(buildings, things, text, view_center, game_random, lfsr_random, map_edge)
			result.count = 1 if result.point.x >= 0 else 0
			result.error = "No clear rail tile was found near the view center, or the train limit is reached."
		_:
			result.error = "The moving thing selection is not valid."

	if result.count == 0:
		return result

	result.error = ""

	if not thing_chunk.set_decoded_payload(things):
		result.error = "The moving-object records could not be stored."

		return result

	if not text_chunk.set_decoded_payload(text):
		thing_chunk.set_decoded_payload(old_things)
		result.error = "The moving-object map links could not be stored."

		return result

	city.resync_mirrors(["XTXT"])

	if kind == 2:
		engine.ship_home = result.point

	result.ok = true

	return result


# remove every moving thing and put back the map labels under them
static func remove_moving_things(city: CityState, document: Sc2File) -> RemoveResult:
	var result := RemoveResult.new()

	if city == null or document == null:
		result.error = "No city is loaded."

		return result

	var thing_chunk := document.find_chunk("XTHG")
	var text_chunk := document.find_chunk("XTXT")

	if thing_chunk == null or text_chunk == null:
		result.error = "The moving-object data is missing."

		return result

	var old_things: PackedByteArray = thing_chunk.decoded_payload.duplicate()
	var things := old_things.duplicate()
	var text: PackedByteArray = city.text_overlays.duplicate()
	var records: Dictionary[int, bool] = {}

	for record in range(1, ThingData.count(things)):
		if ThingData.read(things, record * CityState.THING_RECORD_SIZE) != 0:
			records[record] = true

	if records.is_empty():
		result.error = "There are no moving things to remove."

		return result

	_unlink_things(text, things, records, city.map_size)
	_clear_thing_records(things, records)

	if not thing_chunk.set_decoded_payload(things):
		result.error = "The moving-object records could not be cleared."

		return result

	if not text_chunk.set_decoded_payload(text):
		thing_chunk.set_decoded_payload(old_things)
		result.error = "The moving-object map links could not be cleared."

		return result

	city.resync_mirrors(["XTXT"])
	result.ok = true
	result.count = records.size()

	return result


# nearest clear rail tile first. the train spawner checks the route and the limit
static func _spawn_train_near(
	buildings: PackedByteArray,
	things: PackedByteArray,
	text: PackedByteArray,
	center: Vector2i,
	game_random: GameLcgRandom,
	lfsr_random: SimLfsrRandom,
	map_edge: int,
) -> Vector2i:
	var candidates: Array[Vector2i] = []

	for x in range(center.x - TRAIN_SEARCH_RADIUS, center.x + TRAIN_SEARCH_RADIUS + 1):
		for y in range(center.y - TRAIN_SEARCH_RADIUS, center.y + TRAIN_SEARCH_RADIUS + 1):
			if x >= 0 and x < map_edge and y >= 0 and y < map_edge:
				candidates.append(Vector2i(x, y))

	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return absi(a.x - center.x) + absi(a.y - center.y) < absi(b.x - center.x) + absi(b.y - center.y))

	for point in candidates:
		if MovingThingSpawner._spawn_train_record(buildings, things, text, point, game_random, lfsr_random, map_edge):
			return point

	return Vector2i(-1, -1)


static func _valid_disaster_chunks(
	thing_chunk: Sc2Chunk,
	text_chunk: Sc2Chunk,
	misc_chunk: Sc2Chunk,
	map_edge: int = 128,
) -> bool:
	return (
		thing_chunk != null
		and thing_chunk.decoded_payload.size()
		== ThingData.BASE_SIZE * (1 if map_edge <= 128 else ((2 * map_edge * map_edge) / 16384))
		and text_chunk != null
		and OverlayData.count(text_chunk.decoded_payload) == (map_edge * map_edge)
		and misc_chunk != null
		and misc_chunk.decoded_payload.size() == MISC_SIZE
	)


static func _disaster_record_indices(things: PackedByteArray) -> Dictionary[int, bool]:
	var result: Dictionary[int, bool] = {}

	for record in range(1, ThingData.count(things)):
		var offset := record * CityState.THING_RECORD_SIZE
		var thing_type := int(ThingData.read(things, offset))
		var is_disaster_object := thing_type in [
			DisasterStart.TYPE_MONSTER,
			DisasterStart.TYPE_EXPLOSION,
			DisasterStart.TYPE_TORNADO,
		]
		var is_crashing_airplane := (
			thing_type == DisasterStart.TYPE_AIRPLANE and ThingData.read(things, offset + 2) == 7
		)

		if is_disaster_object or is_crashing_airplane:
			result[record] = true

	return result


static func _clear_disaster_markers(
	text: PackedByteArray,
	things: PackedByteArray,
	disaster_records: Dictionary[int, bool],
	map_edge: int = 128,
) -> int:
	var cleared_markers := 0

	for index in (map_edge * map_edge):
		var overlay := int(OverlayData.read(text, index))

		if overlay >= DISASTER_OVERLAY_FIRST and overlay <= 255:
			OverlayData.write(text, index, 0)
			cleared_markers += 1

	_unlink_things(text, things, disaster_records, map_edge)

	return cleared_markers


# a thing keeps the overlay it covers. restore it on the thing's own tile
static func _unlink_things(
	text: PackedByteArray,
	things: PackedByteArray,
	records: Dictionary[int, bool],
	map_edge: int,
) -> void:
	for index in (map_edge * map_edge):
		var overlay := int(OverlayData.read(text, index))

		if not OverlayData.is_thing(overlay):
			continue

		var record := OverlayData.thing_record(overlay)

		if not records.has(record):
			continue

		var offset := record * CityState.THING_RECORD_SIZE
		var point_index := (
			int(ThingData.read(things, offset + 3)) * map_edge + int(ThingData.read(things, offset + 4))
		)
		var prior_overlay := int(ThingData.read(things, offset + 10))
		OverlayData.write(text, index, (
			prior_overlay
			if index == point_index and not OverlayData.blocks_thing(prior_overlay)
			else 0
		))


static func _clear_thing_records(
	things: PackedByteArray,
	disaster_records: Dictionary[int, bool],
) -> void:
	for record in disaster_records:
		var offset := int(record) * CityState.THING_RECORD_SIZE

		for byte_index in CityState.THING_RECORD_SIZE:
			ThingData.write(things, offset + byte_index, 0)


static func _reset_disaster_engine(engine: SimulationEngine) -> void:
	engine.pending_disaster_type = 0
	engine.pending_disaster_point = Vector2i.ZERO
	engine.active_disaster_type = 0
	engine.unsupported_disaster_type = 0
	engine.disaster_map_counter = 0
	engine.disaster_hurricane_counter = 0


static func _disaster_target(
	city: CityState,
	document: Sc2File,
	view_center: Vector2i,
) -> DisasterTarget:
	var map_edge: int = city.map_size if city != null else 128
	var thing_chunk := document.find_chunk("XTHG")

	if thing_chunk != null:
		var things: PackedByteArray = thing_chunk.decoded_payload

		for record in range(1, ThingData.count(things)):
			var offset := record * CityState.THING_RECORD_SIZE

			if int(ThingData.read(things, offset)) in [5, 15]:
				var result := DisasterTarget.new()
				result.point = Vector2i(ThingData.read(things, offset + 3), ThingData.read(things, offset + 4))
				result.goal = ThingData.target_id(record)

				return result

	var nearest := Vector2i(-1, -1)
	var nearest_distance := MAX_FUNDS

	for x in map_edge:
		for y in map_edge:
			if city.text_overlay_id(x, y) < MAXIS_TARGET_OVERLAY_FIRST:
				continue

			var point := Vector2i(x, y)
			var distance := absi(point.x - view_center.x) + absi(point.y - view_center.y)

			if distance < nearest_distance:
				nearest = point
				nearest_distance = distance

	if nearest.x < 0:
		return null

	var result := DisasterTarget.new()
	result.point = nearest
	result.goal = MAXIS_TARGET_OVERLAY_FIRST

	return result


static func _maxis_man_start(city: CityState, target: Vector2i) -> Vector2i:
	const DIRECTIONS := [
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]

	for radius in range(12, 0, -1):
		for direction in DIRECTIONS:
			var point: Vector2i = target + Vector2i(direction) * radius

			if (
				city.index_of(point.x, point.y) >= 0
				and not OverlayData.blocks_thing(city.text_overlay_id(point.x, point.y))
			):
				return point

	return Vector2i(-1, -1)
