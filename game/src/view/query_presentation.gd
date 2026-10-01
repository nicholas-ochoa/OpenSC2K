class_name QueryPresentation
extends RefCounted

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const FIRST_THING_OVERLAY := 201
const LAST_THING_OVERLAY := 240
const SAILBOAT_TYPE := 9
const LARGE_SPRITE_BASE := 1000
const LARGE_SAILBOAT_NORTHEAST := 1380
const LARGE_VIEW := Renderer.VIEW_LARGE
# ALTM bit 15 sits above the five tunnel level bits. Its use is not known
const ALTITUDE_HIGH_BIT := 0x8000
const MARKER_NAMES := {
	Sc2OverlayLayout.CONNECTION_MARKER: "Connection marker", DisasterMapConstants.TOXIC_OVERLAY: "Toxic spill marker",
	DisasterMapConstants.FLOOD_OVERLAY: "Flood marker", DisasterMapConstants.RIOT_OVERLAY_FORWARD: "Riot marker",
	DisasterMapConstants.RIOT_OVERLAY_REVERSE: "Riot marker", DisasterMapConstants.FIRE_OVERLAY: "Fire marker",
}
const TERRAIN_GROUPS := ["Land", "Deep water", "Shore", "Surface water", "Channel"]
# catalog bounds and masks share values with the tile names
const TERRAIN_NAME_SUFFIXES := ["_FIRST", "_LAST", "_MASK", "_SIZE"]

static var _terrain_names: Dictionary[int, String] = {}


static func sprite_id(city: CityState, info: QueryResult) -> int:
	if city == null or not city.is_valid() or info == null or not info.ok:
		return -1

	if info.kind == "specific":
		var microsim: CityRecords.Microsim = info.microsim
		var facility_tile := microsim.tile_id if microsim != null else 0

		return LARGE_SPRITE_BASE + facility_tile if facility_tile > BuildingTileIds.EMPTY else -1

	var point: Vector2i = info.point

	if city.index_of(point.x, point.y) < 0:
		return -1

	var building := city.building_id(point.x, point.y)
	var result := (
		LARGE_SPRITE_BASE + building
		if building != BuildingTileIds.EMPTY
		else Renderer.terrain_sprite_id(
			city.terrain_id(point.x, point.y), city.is_water(point.x, point.y)
		)
	)
	var overlay := city.text_overlay_id(point.x, point.y)

	if OverlayData.is_thing(overlay):
		var thing := city.thing(OverlayData.thing_record(overlay))

		if thing != null and thing.type == SAILBOAT_TYPE:
			result = LARGE_SAILBOAT_NORTHEAST

	return result


static func thing_sprite(
	city: CityState, point: Vector2i, thing: ThingRecord, record := -1
) -> CitySpriteVisual:
	if city == null or not city.is_valid() or thing == null:
		return null

	var thing_type := thing.type

	if thing_type < 1 or thing_type >= Renderer.THING_SPRITES.size():
		return null

	match thing_type:
		5:
			var result := CitySpriteVisual.new()
			result.sprite_id = Renderer.THING_SPRITES[5]
			result.flip = false

			return result
		7, 8, 14:
			var offset := int(Renderer.DISPATCH_SPRITE_OFFSETS.get(thing_type, 0))

			var result := CitySpriteVisual.new()
			result.sprite_id = LARGE_SPRITE_BASE + offset
			result.flip = false

			return result
		10, 11:
			return Renderer.train_sprite(city, point.x, point.y, thing)
		12, 13:
			var result := CitySpriteVisual.new()
			result.sprite_id = Renderer.THING_SPRITES[thing_type]
			result.flip = false

			return result
		15:
			return Renderer.tornado_sprite(
				city, point.x, point.y, thing, max(record, 0), LARGE_VIEW
			)
		_:
			return Renderer.moving_thing_sprite(thing, LARGE_VIEW)


static func advanced_rows(info: QueryResult) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []

	if info == null:
		return rows

	var point: Vector2i = info.point

	for entry in [["Tile ID", "tile_id", 2], ["Sprite ID", "sprite_id", 4],
		["ALTM", "altitude_raw", 4], ["XVAL", "land_value_raw", 2],
		["XCRM", "crime_raw", 2], ["XPLT", "pollution_raw", 2]]:
		rows.append(_number_row(entry[0], int(info.get(entry[1])), "", entry[2]))

	rows.append(_number_row("XTXT", int(info.overlay_id), overlay_name(int(info.overlay_id))))
	rows.append(_number_row("XTER", int(info.terrain_id), terrain_name(int(info.terrain_id))))
	rows.append(_number_row("X", point.x))
	rows.append(_number_row("Y", point.y))
	var altitude := int(info.altitude_raw)
	var tunnel_levels := (altitude >> Sc2AltitudeLayout.TUNNEL_SHIFT) & Sc2AltitudeLayout.LEVEL_MASK
	rows.append(_number_row("Z", altitude & Sc2AltitudeLayout.LAND_MASK))
	rows.append(_number_row("Water Z", (altitude >> Sc2AltitudeLayout.WATER_SHIFT) & Sc2AltitudeLayout.LEVEL_MASK))
	rows.append(_number_row("Tunnel", tunnel_levels,
		"None" if tunnel_levels == 0 else "%d %s below" % [tunnel_levels, "level" if tunnel_levels == 1 else "levels"]))
	rows.append(PackedStringArray(["ALTM bit 15", str(int((altitude & ALTITUDE_HIGH_BIT) != 0)),
		"Set" if altitude & ALTITUDE_HIGH_BIT else "Clear", ""]))
	rows.append(_number_row("XZON", int(info.zone_raw), str(info.corner_name)))
	rows.append(_number_row("Zone", int(info.zone_id), str(info.zone_name)))
	rows.append(_number_row("XBIT", int(info.flags_raw), " ".join(info.flag_names)))
	rows.append(_number_row("XUND", int(info.underground_id), str(info.underground_name)))
	var microsim_id := int(info.microsim_id)

	if microsim_id < 0:
		rows.append(PackedStringArray(["Microsim", "", "None", ""]))
	else:
		rows.append(_number_row("Microsim ID", microsim_id, str(info.microsim_label)))
		var microsim: CityRecords.Microsim = info.microsim

		if microsim == null:
			rows.append(PackedStringArray(["XMIC", "", "Unavailable", ""]))

		for index in 4:
			if microsim != null:
				rows.append(_number_row("XMIC data %d" % index, microsim.statistic(index), "", 2 if index == 0 else 4))

	return rows


# the kind of the XTXT value on top: a moving object, a marker, a facility or a sign
static func overlay_name(id: int) -> String:
	if id == 0:
		return "None"

	if MARKER_NAMES.has(id):
		return MARKER_NAMES[id]

	if OverlayData.is_thing(id):
		return "Moving object %d" % OverlayData.thing_record(id)

	if OverlayData.is_facility(id):
		return "Facility %d" % OverlayData.facility_record(id)

	if OverlayData.is_sign(id):
		return "Sign"

	return "Unknown"


# the group and shape of an XTER ID, from the TerrainTileIds constant names
static func terrain_name(id: int) -> String:
	if _terrain_names.is_empty():
		var constants := (TerrainTileIds as Script).get_script_constant_map()

		for constant: String in constants:
			var value := int(constants[constant])

			if not _terrain_names.has(value) and not TERRAIN_NAME_SUFFIXES.any(func(suffix: String) -> bool: return constant.ends_with(suffix)):
				_terrain_names[value] = constant

	var group := (id & TerrainTileIds.GROUP_MASK) >> 4
	var group_name: String = TERRAIN_GROUPS[group] if group < TERRAIN_GROUPS.size() else "Unknown group"

	return "%s, shape %d (%s)" % [group_name, id & TerrainTileIds.SHAPE_MASK, _terrain_names.get(id, "unknown")]


static func thing_rows(info: QueryResult) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []

	if info == null:
		return rows

	for thing: QueryThing in info.things:
		rows.append(_number_row("Record", int(thing.record), str(thing.type_name)))
		rows.append(_number_row("Type", int(thing.type), str(thing.type_name)))
		rows.append(_number_row("Direction", int(thing.direction), str(thing.direction_name)))

		for field in ["state", "x", "y", "z", "px", "py", "dx", "dy", "label", "goal"]:
			rows.append(_number_row(field.to_upper(), int(thing.get(field))))

	return rows


static func _number_row(field: String, value: int, description := "", digits := 2) -> PackedStringArray:
	return PackedStringArray([field, str(value), description, ("0x%0*X" % [digits, value]) if value >= 0 else "-0x%X" % -value])
