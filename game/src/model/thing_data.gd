class_name ThingData
extends RefCounted
# sclg stores equal low and high record planes. scdh remains byte-exact

const BASE_SIZE := 480


static func read(data: PackedByteArray, index: int) -> int:
	var value := int(data[index])

	if data.size() > BASE_SIZE and _wide(data, index):
		value |= int(data[IntegerMath.div_trunc(data.size(), 2) + index]) << 8

	return value


static func write(data: PackedByteArray, index: int, value: int) -> void:
	data[index] = value & 0xff

	if data.size() > BASE_SIZE and not (data[index - index % 12] == 3 and index % 12 in [0, 1, 2, 5]):
		data[IntegerMath.div_trunc(data.size(), 2) + index] = (value >> 8) & 0xff if _wide(data, index) else 0


static func count(data: PackedByteArray) -> int:
	return IntegerMath.div_trunc(data.size(), (24 if data.size() > BASE_SIZE else 12))


# only some fields widen, and which ones depends on the object type
static func _wide(data: PackedByteArray, index: int) -> bool:
	var field := index % 12
	var type := int(data[index - field])

	return field == 3 or field == 4 or field == 8 or field == 9 or field == 10 or (type >= 10 and type <= 13 and (field == 2 or field == 6 or field == 7)) or (type == 16 and field == 11)


static func target_id(record: int) -> int:
	return record if record < 241 else OverlayData.thing_id(record)


static func target_record(goal: int) -> int:
	return OverlayData.thing_record(goal) if goal >= 8192 else goal


static func is_record_target(goal: int) -> bool:
	return goal < 241 or goal >= 8192


# ship home lives in spare bytes; add one because zero means missing
static func set_ship_home(data: PackedByteArray, record: int, point: Vector2i) -> void:
	if data.size() <= BASE_SIZE:
		return

	var offset := IntegerMath.div_trunc(data.size(), 2) + record * 12
	# spare high-plane bytes store coordinate + 1; zero means no saved home
	data[offset] = (point.x + 1) & 255
	data[offset + 1] = (point.x + 1) >> 8
	data[offset + 2] = (point.y + 1) & 255
	data[offset + 5] = (point.y + 1) >> 8


static func ship_home(data: PackedByteArray, record: int, fallback: Vector2i) -> Vector2i:
	if data.size() <= BASE_SIZE:
		return fallback

	var offset := IntegerMath.div_trunc(data.size(), 2) + record * 12
	var x := (int(data[offset]) | (int(data[offset + 1]) << 8)) - 1
	var y := (int(data[offset + 2]) | (int(data[offset + 5]) << 8)) - 1

	return Vector2i(x, y) if x >= 0 and y >= 0 else Vector2i(read(data, record * 12 + 3), read(data, record * 12 + 4))
