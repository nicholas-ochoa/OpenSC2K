class_name ScurkPickCopy
extends RefCounted

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

class Result extends ScurkMif.Result:
	var object_count := 0
	var shape_count := 0


class PreparedShape extends RefCounted:
	var sprite_id := 0
	var width := 0
	var height := 0
	var pixels := PackedInt32Array()


const GROUP_RESIDENTIAL := 0
const GROUP_COMMERCIAL := 1
const GROUP_INDUSTRIAL := 2
const GROUP_SPECIAL := 3
const GROUP_POWER := 4
const GROUP_TRANSPORTATION := 5
const GROUP_MISC := 6
const GROUP_ANIMATING_I := 7
const GROUP_ANIMATING_II := 8
const GROUP_CONSTRUCTION := 9
const GROUP_ALL := 10

const GROUP_NAMES := [
	"Residential",
	"Commercial",
	"Industrial",
	"Special",
	"Power",
	"Transportation",
	"Misc",
	"Animating I",
	"Animating II",
	"Construction",
	"All",
]

# original.mif stores these objects in group order. each value is a city tile id,
# except the animating groups, which list sprite ids above the tile range.
# add 1000 to select the large-view sprite
const GROUP_TILE_IDS := [
	[
		Tiles.LARGE_APARTMENT_BUILDING_3X3_1, Tiles.LARGE_APARTMENT_BUILDING_3X3_2,
		Tiles.CONDOMINIUM_3X3_1, Tiles.CONDOMINIUM_3X3_2, Tiles.CHEAP_APARTMENTS_2X2,
		Tiles.APARTMENTS_2X2_1, Tiles.APARTMENTS_2X2_2, Tiles.NICE_APARTMENTS_2X2_1,
		Tiles.NICE_APARTMENTS_2X2_2, Tiles.CONDOMINIUM_2X2_1, Tiles.CONDOMINIUM_2X2_2,
		Tiles.CONDOMINIUM_2X2_3, Tiles.LOWER_CLASS_HOMES_1X1_1, Tiles.LOWER_CLASS_HOMES_1X1_2,
		Tiles.LOWER_CLASS_HOMES_1X1_3, Tiles.LOWER_CLASS_HOMES_1X1_4,
		Tiles.MIDDLE_CLASS_HOMES_1X1_1, Tiles.MIDDLE_CLASS_HOMES_1X1_2,
		Tiles.MIDDLE_CLASS_HOMES_1X1_3, Tiles.MIDDLE_CLASS_HOMES_1X1_4, Tiles.LUXURY_HOMES_1X1_1,
		Tiles.LUXURY_HOMES_1X1_2, Tiles.LUXURY_HOMES_1X1_3, Tiles.LUXURY_HOMES_1X1_4,
	],
	[
		Tiles.OFFICE_PARK_3X3, Tiles.MINI_MALL_3X3, Tiles.THEATER_SQUARE_3X3,
		Tiles.DRIVE_IN_THEATER_3X3, Tiles.OFFICE_TOWER_3X3_1, Tiles.OFFICE_TOWER_3X3_2,
		Tiles.OFFICE_TOWER_3X3_3, Tiles.PARKING_LOT_3X3, Tiles.HISTORIC_OFFICE_BUILDING_3X3,
		Tiles.CORPORATE_HEADQUARTERS_3X3, Tiles.SHOPPING_CENTER_2X2, Tiles.GROCERY_STORE_2X2,
		Tiles.RESORT_HOTEL_2X2, Tiles.OFFICE_RETAIL_2X2, Tiles.OFFICE_BUILDING_2X2_1,
		Tiles.OFFICE_BUILDING_2X2_2, Tiles.OFFICE_BUILDING_2X2_3, Tiles.OFFICE_BUILDING_2X2_4,
		Tiles.OFFICE_BUILDING_2X2_5, Tiles.OFFICE_BUILDING_2X2_6, Tiles.GAS_STATION_1X1_1,
		Tiles.GAS_STATION_1X1_2, Tiles.BED_BREAKFAST_INN_1X1, Tiles.CONVENIENCE_STORE_1X1,
		Tiles.SMALL_OFFICE_BUILDING_1X1, Tiles.OFFICE_BUILDING_1X1, Tiles.WAREHOUSE_1X1_1,
		Tiles.CASSIDYS_TOY_STORE_1X1,
	],
	[
		Tiles.CHEMICAL_PROCESSING_3X3, Tiles.CHEMICAL_PROCESSING_2X2, Tiles.LARGE_FACTORY_3X3,
		Tiles.INDUSTRIAL_THINGAMAJIG_3X3, Tiles.FACTORY_3X3, Tiles.LARGE_WAREHOUSE_3X3,
		Tiles.WAREHOUSE_3X3, Tiles.WAREHOUSE_2X2, Tiles.FACTORY_2X2_1, Tiles.FACTORY_2X2_2,
		Tiles.FACTORY_2X2_3, Tiles.FACTORY_2X2_4, Tiles.FACTORY_2X2_5, Tiles.FACTORY_2X2_6,
		Tiles.WAREHOUSE_1X1_2, Tiles.WAREHOUSE_1X1_3, Tiles.CHEMICAL_STORAGE_1X1,
		Tiles.INDUSTRIAL_SUBSTATION_1X1,
	],
	[
		Tiles.PLYMOUTH_ARCOLOGY, Tiles.FOREST_ARCOLOGY, Tiles.DARCO_ARCOLOGY, Tiles.LAUNCH_ARCOLOGY,
		Tiles.LLAMA_DOME, Tiles.CITY_HALL, Tiles.HOSPITAL, Tiles.POLICE_STATION, Tiles.FIRE_STATION,
		Tiles.MUSEUM, Tiles.BIG_PARK, Tiles.SMALL_PARK, Tiles.SCHOOL, Tiles.STADIUM, Tiles.PRISON,
		Tiles.COLLEGE, Tiles.ZOO, Tiles.STATUE, Tiles.WATER_PUMP, Tiles.WATER_TREATMENT,
		Tiles.DESALINIZATION, Tiles.MAYOR_HOUSE, Tiles.LIBRARY, Tiles.CHURCH, Tiles.WATER_TOWER,
		Tiles.MARINA,
	],
	[
		Tiles.HYDRO_POWER_1, Tiles.HYDRO_POWER_2, Tiles.WIND_POWER, Tiles.GAS_POWER,
		Tiles.OIL_POWER, Tiles.NUCLEAR_POWER, Tiles.SOLAR_POWER, Tiles.MICROWAVE_POWER,
		Tiles.FUSION_POWER, Tiles.COAL_POWER,
	],
	[
		Tiles.CONSTRUCTION_3X3_1, Tiles.CONSTRUCTION_3X3_2, Tiles.CONSTRUCTION_2X2_1,
		Tiles.CONSTRUCTION_2X2_2, Tiles.CONSTRUCTION_2X2_3, Tiles.CONSTRUCTION_2X2_4,
		Tiles.CONSTRUCTION_1X1_1, Tiles.CONSTRUCTION_1X1_2, Tiles.ABANDONED_1X1_1,
		Tiles.ABANDONED_1X1_2, Tiles.ABANDONED_2X2_1, Tiles.ABANDONED_2X2_2, Tiles.ABANDONED_2X2_3,
		Tiles.ABANDONED_2X2_4, Tiles.ABANDONED_3X3_1, Tiles.ABANDONED_3X3_2, Tiles.SUBWAY_STATION,
		Tiles.BUS_DEPOT, Tiles.RAIL_STATION, Tiles.CRANE, Tiles.LOADING_BAY, Tiles.CARGO_YARD,
	],
	[
		Tiles.SEAPORT_WAREHOUSE, Tiles.RUNWAY, Tiles.RUNWAY_CROSSING, Tiles.CONTROL_TOWER_1,
		Tiles.PARKING_LOT_1, Tiles.TARMAC, Tiles.RADAR, Tiles.HANGAR_1, Tiles.HANGAR_2,
		Tiles.AIRPORT_BUILDING_1, Tiles.AIRPORT_BUILDING_2, Tiles.CONTROL_TOWER_2,
	],
	[499, 498, 497, 496, 495, 494, 493, 399, 398, 397, 396, 395, 394, 393, 392],
	[387, 388, 389, 391, 390, 373, 372, 371, 370, 369, 363, 362, 361, 360, 359],
	[
		Tiles.FIGHTER_JET, Tiles.PARKING_LOT_2, Tiles.TOP_SECRET, Tiles.MISSILE_SILO,
		Tiles.RUBBLE_1, Tiles.RUBBLE_2, Tiles.RUBBLE_3, Tiles.RUBBLE_4, Tiles.TREES_1,
		Tiles.TREES_2, Tiles.TREES_3, Tiles.TREES_4, Tiles.TREES_5, Tiles.TREES_6, Tiles.TREES_7,
		Tiles.RADIOACTIVE_WASTE,
	],
]


static func group_large_ids(group: int) -> PackedInt32Array:
	var result := PackedInt32Array()

	if group == GROUP_ALL:
		for group_index in GROUP_TILE_IDS.size():
			result.append_array(_large_ids_for_tiles(GROUP_TILE_IDS[group_index]))

		return result

	if group < 0 or group >= GROUP_TILE_IDS.size():
		return result

	return _large_ids_for_tiles(GROUP_TILE_IDS[group])


static func copy_objects(
	working: ScurkMif,
	source: ScurkMif,
	large_ids: PackedInt32Array,
	base_large: Sc2SpriteArchive,
	base_small_medium: Sc2SpriteArchive
) -> Result:
	if working == null or not working.is_valid():
		return _failure("The working object set is invalid.")

	if source == null or not source.is_valid():
		return _failure("The source object set is invalid.")

	if source == working:
		return _failure("The source and working object sets must be different.")

	if base_large == null or not base_large.is_valid():
		return _failure("The original large sprites are not available.")

	if base_small_medium == null or not base_small_medium.is_valid():
		return _failure("The original small and medium sprites are not available.")

	var prepared: Array[PreparedShape] = []
	var seen := {}

	for large_id in large_ids:
		if large_id < 1000 or large_id > 1499:
			return _failure("Object sprite %d is outside the SCURK range." % large_id)

		if seen.has(large_id):
			continue

		seen[large_id] = true

		for view in 3:
			var sprite_id := large_id - view * 500
			var entry := resolved_entry(
				source, sprite_id, base_large, base_small_medium
			)

			if entry == null:
				return _failure("Source sprite %d is missing." % sprite_id)

			var decoded := entry.decode_indices()

			if not decoded.ok:
				return _failure(decoded.error)

			var shape := PreparedShape.new()
			shape.sprite_id = sprite_id
			shape.width = entry.width
			shape.height = entry.height
			shape.pixels = decoded.pixels
			prepared.append(shape)

	for shape in prepared:
		var changed := working.set_shape_indices(
			shape.sprite_id, shape.width, shape.height, shape.pixels
		)

		if not changed.ok:
			return _failure(changed.error)

	var result := Result.new()
	result.ok = true
	result.error = ""
	result.object_count = seen.size()
	result.shape_count = prepared.size()

	return result


static func resolved_entry(
	tile_set: ScurkMif,
	sprite_id: int,
	base_large: Sc2SpriteArchive,
	base_small_medium: Sc2SpriteArchive
) -> Sc2SpriteArchive.SpriteEntry:
	if tile_set == null:
		return null

	var entry := tile_set.overrides.find_sprite(sprite_id)

	if entry != null:
		return entry

	var base := base_large if sprite_id >= 1000 else base_small_medium
	entry = base.find_sprite(sprite_id) if base != null else null

	if entry != null:
		return entry

	return tile_set.archive.find_sprite(sprite_id)


static func _large_ids_for_tiles(tile_ids: Array) -> PackedInt32Array:
	var result := PackedInt32Array()

	for tile_id in tile_ids:
		result.append(1000 + int(tile_id))

	return result


static func _failure(message: String) -> Result:
	var result := Result.new()
	result.ok = false
	result.error = message
	result.object_count = 0
	result.shape_count = 0

	return result
