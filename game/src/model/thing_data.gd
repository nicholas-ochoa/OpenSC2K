class_name ThingData
extends RefCounted
# sclg stores equal low and high record planes. scdh remains byte-exact

@warning_ignore_start("integer_division")

const BASE_SIZE := Sc2ThingLayout.ORIGINAL_SIZE
const RECORD_SIZE := Sc2ThingLayout.RECORD_SIZE
const Field = Sc2ThingLayout.Field
const Type = Sc2ThingLayout.Type
const ShipHome = Sc2ThingLayout.ShipHomeField


static func read(data: PackedByteArray, index: int) -> int:
	var value := int(data[index])

	if data.size() > BASE_SIZE and _wide(data, index):
		value |= int(data[(data.size() / 2) + index]) << 8

	return value


static func write(data: PackedByteArray, index: int, value: int) -> void:
	data[index] = value & 0xff

	if data.size() > BASE_SIZE and not (data[index - index % RECORD_SIZE] == Type.SHIP
			and index % RECORD_SIZE in [Field.TYPE, Field.DIRECTION, Field.STATE, Field.Z]):
		data[(data.size() / 2) + index] = (value >> 8) & 0xff if _wide(data, index) else 0


static func count(data: PackedByteArray) -> int:
	return data.size() / (2 * RECORD_SIZE if data.size() > BASE_SIZE else RECORD_SIZE)


# only some fields widen, and which ones depends on the object type
static func _wide(data: PackedByteArray, index: int) -> bool:
	var field := index % RECORD_SIZE
	var type := int(data[index - field])

	return (field == Field.X or field == Field.Y or field == Field.DX or field == Field.DY or field == Field.LABEL
			or (type >= Type.TRAIN_ENGINE and type <= Type.SUBWAY_CAR
				and (field == Field.STATE or field == Field.PX or field == Field.PY))
			or (type == Type.MAXIS_MAN and field == Field.GOAL))


static func target_id(record: int) -> int:
	return record if record < 241 else OverlayData.thing_id(record)


static func target_record(goal: int) -> int:
	return OverlayData.thing_record(goal) if goal >= OverlayData.EXTRA_THING else goal


static func is_record_target(goal: int) -> bool:
	return goal < 241 or goal >= OverlayData.EXTRA_THING


# ship home lives in spare bytes; add one because zero means missing
static func set_ship_home(data: PackedByteArray, record: int, point: Vector2i) -> void:
	if data.size() <= BASE_SIZE:
		return

	var offset := (data.size() / 2) + record * RECORD_SIZE
	# spare high-plane bytes store coordinate + 1; zero means no saved home
	data[offset + ShipHome.X_LOW] = (point.x + 1) & 255
	data[offset + ShipHome.X_HIGH] = (point.x + 1) >> 8
	data[offset + ShipHome.Y_LOW] = (point.y + 1) & 255
	data[offset + ShipHome.Y_HIGH] = (point.y + 1) >> 8


static func ship_home(data: PackedByteArray, record: int, fallback: Vector2i) -> Vector2i:
	if data.size() <= BASE_SIZE:
		return fallback

	var offset := (data.size() / 2) + record * RECORD_SIZE
	var x := (int(data[offset + ShipHome.X_LOW]) | (int(data[offset + ShipHome.X_HIGH]) << 8)) - 1
	var y := (int(data[offset + ShipHome.Y_LOW]) | (int(data[offset + ShipHome.Y_HIGH]) << 8)) - 1

	return Vector2i(x, y) if x >= 0 and y >= 0 else Vector2i(
		read(data, record * RECORD_SIZE + Field.X), read(data, record * RECORD_SIZE + Field.Y))
