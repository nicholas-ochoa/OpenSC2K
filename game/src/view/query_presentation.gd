class_name QueryPresentation
extends RefCounted

const Renderer = preload("res://src/view/city_isometric_renderer.gd")
const FIRST_THING_OVERLAY := 201
const LAST_THING_OVERLAY := 240
const SAILBOAT_TYPE := 9
const LARGE_SPRITE_BASE := 1000
const LARGE_SAILBOAT_NORTHEAST := 1380
const LARGE_VIEW := Renderer.VIEW_LARGE


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
		["XCRM", "crime_raw", 2], ["XPLT", "pollution_raw", 2], ["XTXT", "overlay_id", 2]]:
		rows.append(_number_row(entry[0], int(info.get(entry[1])), "", entry[2]))

	rows.append(_number_row("X", point.x))
	rows.append(_number_row("Y", point.y))
	rows.append(_number_row("Z", int(info.altitude_raw) & 0x1f))
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
