class_name DisasterDamage
extends RefCounted

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const TEXT_LABEL_BASE := 201
const SOUND_DAMAGE := 0x1f8

# story weight of each damaged building class, from executable table 0x004e8848.
# classes 0 to 9 are zone types. class 10 and up are tiles from 0xc6
const DAMAGE_CLASS_WEIGHTS := [
	0, 1, 1, 1, 1, 1, 1, 1, 4, 8, 5, 5, 5, 5, 5, 5, 5, 5, 5, 3, 4, 4, 4, 2, 2, 3, 2, 4, 3, 2,
	3, 2, 8, 8, 2, 4, 8, 1, 4, 1, 1, 8, 1, 1, 3, 8, 2, 2, 2, 1, 1, 4, 1, 1, 2, 2, 2, 1, 3, 2,
	5, 3, 6, 6, 6, 6, 6,
]


class RuntimeEvents extends RefCounted:
	var effect_events: Array[EffectEvent] = []
	var sound_events: Array[int] = []
	var next_effect_frame := 0


static func new_runtime_events() -> RuntimeEvents:
	return RuntimeEvents.new()


static func append_damage_events(runtime_events: RuntimeEvents, damage: DemolishPointResult) -> void:
	if runtime_events == null or damage.effect_events.is_empty():
		return

	runtime_events.next_effect_frame = DemolishEffectsSites.append_effect_sequence(
		runtime_events.effect_events, damage.effect_events, runtime_events.next_effect_frame
	)
	runtime_events.sound_events.append(SOUND_DAMAGE)


static func apply(
	city: CityState,
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	traffic: PackedByteArray,
	text: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	allow_small_tile := false,
	runtime_events: DisasterDamage.RuntimeEvents = null,
) -> int:
	var map_edge: int = city.map_size if city != null else 128
	var index := _index(point, map_edge)

	if index < 0 or flags[index] & Sc2TileFlags.WATER != 0:
		return 0

	if buildings[index] < Tiles.TREES_1 and not allow_small_tile:
		return 0

	var overlay := int(OverlayData.read(text, index))
	var result_code := 1

	if overlay > 0:
		if (overlay == 0 or OverlayData.is_sign(overlay)):
			labels[overlay * CityState.LABEL_RECORD_SIZE] = 0
		elif OverlayData.is_facility(overlay):
			var damage := burn_structure(
				city, altitude, buildings, terrain, zones, underground,
				flags, text, labels, microsims, misc, point, random, lfsr_random,
				true, false, true
			)
			append_damage_events(runtime_events, damage)
			result_code = 3
		elif OverlayData.is_thing(overlay):
			return 0
		elif overlay < 250:
			NetworkState.replace_building(
				buildings, zones, misc, index, lfsr_random.next_mod(4) + Tiles.RUBBLE_FIRST
			)

			return 2
		elif overlay != 250:
			return 0
		else:
			result_code = 4

	OverlayData.write(text, index, 0xff)
	traffic[CityDataGrid.index(traffic, map_edge, point.x, point.y)] = 0

	return result_code


static func apply_flood(
	city: CityState,
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	traffic: PackedByteArray,
	text: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	maximum_altitude: int,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	runtime_events: DisasterDamage.RuntimeEvents = null,
) -> int:
	var map_edge: int = city.map_size if city != null else 128
	var index := _index(point, map_edge)

	if index < 0 or _altitude_word(altitude, index) & 0x1f > maximum_altitude:
		return 0

	if terrain[index] >= TerrainTileIds.DEEP_WATER_FIRST and terrain[index] <= TerrainTileIds.DEEP_WATER_LAST:
		return 0

	var overlay := int(OverlayData.read(text, index))

	if overlay > 0:
		if (overlay == 0 or OverlayData.is_sign(overlay)):
			labels[overlay * CityState.LABEL_RECORD_SIZE] = 0
		elif OverlayData.is_facility(overlay):
			var damage := burn_structure(
				city, altitude, buildings, terrain, zones, underground,
				flags, text, labels, microsims, misc, point, random, lfsr_random,
				false, false, true
			)
			append_damage_events(runtime_events, damage)
		elif OverlayData.is_thing(overlay):
			return 0
		elif overlay < 250:
			NetworkState.replace_building(
				buildings, zones, misc, index, lfsr_random.next_mod(4) + Tiles.RUBBLE_FIRST
			)

			return 2
		else:
			return 0

	OverlayData.write(text, index, 0xfc)
	traffic[CityDataGrid.index(traffic, map_edge, point.x, point.y)] = 0

	return 1


static func burn_structure(
	city: CityState,
	altitude: PackedByteArray,
	buildings: PackedByteArray,
	terrain: PackedByteArray,
	zones: PackedByteArray,
	underground: PackedByteArray,
	flags: PackedByteArray,
	text: PackedByteArray,
	labels: PackedByteArray,
	microsims: PackedByteArray,
	misc: PackedByteArray,
	point: Vector2i,
	random: SimRandom,
	lfsr_random: SimLfsrRandom,
	mark_fire := true,
	clear_current := true,
	emit_effects := false
) -> DemolishPointResult:
	var map_edge: int = city.map_size if city != null else 128
	record_damage_class(city, buildings, zones, _index(point, map_edge))
	var result := DemolishStructures._demolish_point(
		city, altitude, buildings, terrain, zones, underground,
		flags, text, labels, microsims, misc, point, random, true, true, emit_effects
	)

	for index in result.indices:
		if mark_fire and flags[index] & Sc2TileFlags.WATER == 0:
			OverlayData.write(text, index, 0xff)

	var point_index := _index(point, map_edge)

	if mark_fire and clear_current and point_index >= 0 and OverlayData.read(text, point_index) == 0xff:
		OverlayData.write(text, point_index, 0)
		var tile := int(buildings[point_index])

		if (tile < Tiles.TUNNEL_ENTRANCE_1 or tile > Tiles.TUNNEL_ENTRANCE_4) and tile < Tiles.HIGHWAY_SLOPE_1:
			NetworkState.replace_building(
				buildings, zones, misc, point_index, lfsr_random.next_mod(4) + Tiles.RUBBLE_FIRST
			)

	return result


# keep the most important building class that the disaster damaged. the
# original skips tunnel entrances and keeps the earlier class on a tie
static func record_damage_class(
	city: CityState, buildings: PackedByteArray, zones: PackedByteArray, index: int
) -> void:
	if city == null or index < 0:
		return

	var tile := int(buildings[index])

	if tile >= Tiles.TUNNEL_ENTRANCE_1 and tile <= Tiles.TUNNEL_ENTRANCE_4:
		return

	var damage_class := int(zones[index]) & Sc2ZoneLayout.TYPE_MASK

	if tile >= Tiles.HYDRO_POWER_1:
		damage_class = 10 if tile == Tiles.HYDRO_POWER_1 else tile - 0xbd

	if damage_class >= DAMAGE_CLASS_WEIGHTS.size():
		return

	var current := city.disaster_damage_class

	if current < 0 or int(DAMAGE_CLASS_WEIGHTS[current]) < int(DAMAGE_CLASS_WEIGHTS[damage_class]):
		city.disaster_damage_class = damage_class


static func _altitude_word(altitude: PackedByteArray, index: int) -> int:
	return (altitude[index * 2] << 8) | altitude[index * 2 + 1]


static func _index(point: Vector2i, map_edge: int = 128) -> int:
	if point.x < 0 or point.y < 0 or point.x >= map_edge or point.y >= map_edge:
		return -1

	return point.x * map_edge + point.y
