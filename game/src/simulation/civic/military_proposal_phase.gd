class_name MilitaryProposalPhase
extends RefCounted

const MISC_SIZE := 4800
const MISC_TILE_COUNTS := 0x01f0
const MISC_BASE_TYPE := 0x0e4c
const MISC_MILITARY_TILE_COUNTS := 0x0fa8
const ZONE_MILITARY := 7
const FLAG_WATER := 0x04

const BASE_DECLINED := 1
const BASE_ARMY := 2
const BASE_AIR_FORCE := 3
const BASE_NAVY := 4
const BASE_MISSILE_SILOS := 5

const NOTICE_ARMY := 0xf1
const NOTICE_AIR_FORCE := 0xf2
const NOTICE_NAVY := 0xf3
const NOTICE_MISSILE_SILOS := 0xf4
const NOTICE_NO_SITE := 0x19b


class Result extends PhaseResult:
	var accepted := false
	var base_type := 0
	var site := Rect2i()
	var changed_indices := PackedInt32Array()
	var notice_id := -1
	var sites: Array = []


static func resolve(city: CityState, accepted: bool, game_random: GameLcgRandom) -> Result:
	var span := SimulationTimingSpan.new(city.simulation_slice if city != null else null)
	span.mark("prepare data")
	var result := _resolve(city, accepted, game_random, span)

	if result.ok:
		result.timing = span.finish()

	return result


static func _resolve(city: CityState, accepted: bool, game_random: GameLcgRandom, span: SimulationTimingSpan) -> Result:
	var map_edge: int = city.map_size if city != null else 128

	if city == null or not city.is_valid():
		return _failed("city is invalid")

	if accepted and game_random == null:
		return _failed("a compatible game random generator is required")

	var chunks := _chunks(city)

	if chunks.is_empty():
		return _failed("military proposal data is missing or invalid")

	var zones: PackedByteArray = chunks.XZON.decoded_payload.duplicate()
	var misc: PackedByteArray = chunks.MISC.decoded_payload.duplicate()

	if not accepted:
		span.mark("store declined proposal")
		_write_u32(misc, MISC_BASE_TYPE, BASE_DECLINED)

		if not chunks.MISC.set_decoded_payload(misc):
			return _failed("cannot store the declined military proposal")

		return _result(false, BASE_DECLINED, Rect2i(), PackedInt32Array(), -1)

	var buildings: PackedByteArray = chunks.XBLD.decoded_payload.duplicate()
	var terrain: PackedByteArray = chunks.XTER.decoded_payload.duplicate()
	var underground: PackedByteArray = chunks.XUND.decoded_payload
	var flags: PackedByteArray = chunks.XBIT.decoded_payload.duplicate()
	span.mark("naval site search")
	var navy_site := NavalBaseSite.find(city)
	if navy_site.has_area() and game_random.next_mod(2) == 1:
		span.mark("build and store naval base")
		var changed := _zone_plot(buildings, terrain, underground, flags, zones, misc, navy_site, map_edge)
		for index in changed:
			# ownership was transferred to the military-other counter above
			buildings[index] = 0
		_write_u32(misc, MISC_BASE_TYPE, BASE_NAVY)
		if not _store(city, chunks, zones, misc, {"XBLD": buildings}):
			return _failed("cannot store the Navy base plot")
		var result := _result(true, BASE_NAVY, navy_site, changed, NOTICE_NAVY)
		result.view_center_requests = [navy_site.get_center()]
		return result

	span.mark("land base site search")
	var last_altitude := 0

	for _attempt in 24:
		var origin := Vector2i(game_random.next_mod(map_edge - 9), game_random.next_mod(map_edge - 9))
		last_altitude = city.land_altitude(origin.x, origin.y)
		var valid := 0
		var level := 0

		for x in range(origin.x, origin.x + 8):
			for y in range(origin.y, origin.y + 8):
				var index := x * map_edge + y

				if _is_clear_land(buildings, terrain, flags, index) and (zones[index] & 15) == 0 and underground[index] == 0:
					valid += 1

					if city.land_altitude(x, y) == last_altitude:
						level += 1

		if valid < 40:
			continue

		span.mark("build and store land base")
		var base_type := BASE_AIR_FORCE if valid == level else BASE_ARMY
		var notice := NOTICE_AIR_FORCE if base_type == BASE_AIR_FORCE else NOTICE_ARMY
		var changed := _zone_plot(
			buildings, terrain, underground, flags, zones, misc, Rect2i(origin, Vector2i(8, 8)), map_edge
		)
		_write_u32(misc, MISC_BASE_TYPE, base_type)

		if base_type == BASE_ARMY:
			ArmyBaseLayout.build(buildings, terrain, zones, underground, flags, misc, origin, map_edge)

		if not _store(city, chunks, zones, misc, {"XBLD": buildings, "XTER": terrain, "XBIT": flags}):
			return _failed("cannot store the military base plot")

		return _result(true, base_type, Rect2i(origin, Vector2i(8, 8)), changed, notice)

	span.mark("missile site search")
	var sites: Array[Rect2i] = []

	for _attempt in 40:
		var origin := Vector2i(game_random.next_mod(map_edge - 4), game_random.next_mod(map_edge - 4))
		var valid := 0

		for x in range(origin.x, origin.x + 3):
			for y in range(origin.y, origin.y + 3):
				var index := x * map_edge + y

				if (
					_is_clear_land(buildings, terrain, flags, index)
					and city.land_altitude(x, y) == last_altitude
					and (zones[index] & 0x0f) != ZONE_MILITARY
					and underground[index] == 0
				):
					valid += 1

		if valid == 9:
			sites.append(Rect2i(origin, Vector2i(3, 3)))

			if sites.size() == 6:
				break

	span.mark("store missile sites or failed proposal")
	if sites.size() != 6:
		_write_u32(misc, MISC_BASE_TYPE, BASE_DECLINED)

		if not chunks.MISC.set_decoded_payload(misc):
			return _failed("cannot store the failed military proposal")

		return _result(false, BASE_DECLINED, Rect2i(), PackedInt32Array(), NOTICE_NO_SITE)

	var changed_indices := PackedInt32Array()

	for site in sites:
		for x in range(site.position.x, site.end.x):
			for y in range(site.position.y, site.end.y):
				var index := x * map_edge + y
				_decrement_tile_count(misc, int(buildings[index]), map_edge)
				zones[index] = (zones[index] & 0xf7) | ZONE_MILITARY
				_increment_military_other(misc, map_edge)
				changed_indices.append(index)

	_write_u32(misc, MISC_BASE_TYPE, BASE_MISSILE_SILOS)

	if not _store(city, chunks, zones, misc):
		return _failed("cannot store the military missile sites")

	var result := _result(
		true, BASE_MISSILE_SILOS, sites[-1], changed_indices, NOTICE_MISSILE_SILOS
	)
	result.sites = sites

	return result


static func _zone_plot(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	zones: PackedByteArray,
	misc: PackedByteArray,
	site: Rect2i,
	map_edge: int = 128,
) -> PackedInt32Array:
	var changed := PackedInt32Array()

	for x in range(site.position.x, site.end.x):
		for y in range(site.position.y, site.end.y):
			var index := x * map_edge + y

			if (
				_is_clear_land(buildings, terrain, flags, index)
				and (zones[index] & 0x0f) == 0
				and underground[index] == 0
			):
				_decrement_tile_count(misc, int(buildings[index]), map_edge)
				zones[index] = (zones[index] & 0xf7) | ZONE_MILITARY
				_increment_military_other(misc, map_edge)
				changed.append(index)

	return changed


static func _is_clear_land(
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	flags: PackedByteArray,
	index: int
) -> bool:
	return buildings[index] < 0x0d and terrain[index] == 0 and (flags[index] & FLAG_WATER) == 0


static func _store(
	city: CityState, chunks: Dictionary, zones: PackedByteArray, misc: PackedByteArray,
	map_changes: Dictionary = {},
) -> bool:
	var payloads := {"XZON": zones, "MISC": misc}
	payloads.merge(map_changes)
	var old_payloads := {}
	var ids := PackedStringArray()
	for id in payloads:
		old_payloads[id] = chunks[id].decoded_payload.duplicate()
		ids.append(id)
	return BuildingState._apply_payloads(city, ids, payloads, old_payloads)


static func _chunks(city: CityState) -> Dictionary[String, Sc2Chunk]:
	var map_edge: int = city.map_size if city != null else 128
	var result: Dictionary[String, Sc2Chunk] = {}

	for checked in [
		["XBLD", (map_edge * map_edge)],
		["XTER", (map_edge * map_edge)],
		["XZON", (map_edge * map_edge)],
		["XUND", (map_edge * map_edge)],
		["XBIT", (map_edge * map_edge)],
		["MISC", MISC_SIZE],
	]:
		var chunk := city.document.find_chunk(checked[0])

		if chunk == null or chunk.decoded_payload.size() != city.document.decoded_size(str(checked[0])):
			return {}

		result[checked[0]] = chunk

	return result


static func _result(
	accepted: bool, base_type: int, site: Rect2i, changed_indices, notice_id: int
) -> Result:
	var result := Result.new()
	result.ok = true
	result.accepted = accepted
	result.base_type = base_type
	result.site = site
	result.changed_indices = changed_indices
	result.notice_id = notice_id
	result.view_center_requests = (
		[site.position + Vector2i(4, 4)]
		if accepted and (base_type == BASE_ARMY or base_type == BASE_AIR_FORCE)
		else ([site.position] if accepted else [])
	)

	return result


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func _decrement_tile_count(misc: PackedByteArray, tile_id: int, map_edge: int = 128) -> void:
	var offset := MISC_TILE_COUNTS + tile_id * 4
	_write_u32(misc, offset, (_read_u32(misc, offset) - 1) & (0xffff if map_edge == 128 else 0xffffffff))


static func _increment_military_other(misc: PackedByteArray, map_edge: int = 128) -> void:
	_write_u32(
		misc,
		MISC_MILITARY_TILE_COUNTS,
		(_read_u32(misc, MISC_MILITARY_TILE_COUNTS) + 1) & (0xffff if map_edge == 128 else 0xffffffff)
	)


static func _read_u32(data: PackedByteArray, offset: int) -> int:
	return (
		(data[offset] << 24)
		| (data[offset + 1] << 16)
		| (data[offset + 2] << 8)
		| data[offset + 3]
	)


static func _write_u32(data: PackedByteArray, offset: int, value: int) -> void:
	var encoded := value & 0xffffffff
	data[offset] = (encoded >> 24) & 0xff
	data[offset + 1] = (encoded >> 16) & 0xff
	data[offset + 2] = (encoded >> 8) & 0xff
	data[offset + 3] = encoded & 0xff
