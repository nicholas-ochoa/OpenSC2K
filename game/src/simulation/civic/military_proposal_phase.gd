class_name MilitaryProposalPhase
extends RefCounted

const UnderTiles = preload("res://src/tools/shared/underground_tile_ids.gd")
const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_BASE_TYPE := Sc2MiscLayout.MILITARY_BASE_TYPE
const MISC_MILITARY_TILE_COUNTS := Sc2MiscLayout.MILITARY_TILE_COUNTS
const ZONE_MILITARY := 7
const FLAG_WATER := Sc2TileFlags.WATER
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


static func _store(
	city: CityState, chunks: Dictionary, zones: PackedByteArray, misc: PackedByteArray,
	map_changes: Dictionary = {},
) -> bool:
	var payloads := { "XZON": zones, "MISC": misc }

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

	if notice_id >= 0:
		result.notice_ids.append(notice_id)

	if accepted:
		result.view_center_requests.append(
			site.position + Vector2i(4, 4)
			if base_type == BASE_ARMY or base_type == BASE_AIR_FORCE
			else site.position
		)

	return result


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result


static func resolve(city: CityState, accepted: bool, game_random: GameLcgRandom, defer_land_plot := false) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	return NativeSimulationBridge.run("military.resolve", city, null, null, game_random, {
		"accepted": accepted,
		"has_game": game_random != null,
		"defer_land_plot": defer_land_plot,
	}).result


static func reserve_land_site(city: CityState, base_type: int, site: Rect2i, notice_id := -1) -> Result:
	return NativeSimulationBridge.run("military.reserve", city, null, null, null, {
		"base_type": base_type, "site": site, "notice_id": notice_id,
	}).result


class Result extends PhaseResult:
	var accepted := false
	var base_type := 0
	var site := Rect2i()
	var changed_indices := PackedInt32Array()
	var notice_id := -1
	var sites: Array[Rect2i] = []
