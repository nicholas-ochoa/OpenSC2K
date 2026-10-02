class_name OverlayData
extends RefCounted
# original ids are unchanged. sc2x v2 adds disjoint 16-bit id ranges.
#
# A layered index keeps each kind of tile content in its own planes: the
# marker byte, the facility ID (low and high plane), and the ID of the top
# moving object (low and high plane). `read` gives the value that a combined
# index would show on top: the object, else the marker, else the facility.
# `write` changes the layer of the value; zero clears the top layer. Code that
# must keep the other layers uses the layer functions.

@warning_ignore_start("integer_division")

const Layout = preload("res://src/formats/sc2_overlay_layout.gd")
const EXTRA_FACILITY := Layout.EXTRA_FACILITY
const EXTRA_SIGN := Layout.EXTRA_SIGN
const EXTRA_THING := Layout.EXTRA_THING
const EXTRA_FACILITY_HIGH := Layout.EXTRA_FACILITY_HIGH
const LAYERED_PLANES := 5
const FACILITY_PLANE := 1
const OBJECT_PLANE := 3
const LAYERED_SIZES: Array[int] = [
	1280, 5120, 20480, 81920, 327680, 737280, 1310720, 2048000, 5242880, 20971520, 83886080,
]


# the overlay layout keys off the payload size alone. a wide sc2x map stores a
# low and a high plane, so its cell count is half its bytes. an sc2x version 4
# working document uses both planes at every map size. no square narrow plane
# of a supported map size has one of these sizes
static func cells_for(byte_count: int) -> int:
	if (
		byte_count == 512 or byte_count == 2048 or byte_count == 8192 or byte_count == 32768
		or byte_count == 131072 or byte_count == 294912 or byte_count == 524288
		or byte_count == 819200 or byte_count == 2097152 or byte_count == 8388608 or byte_count == 33554432
	):
		return byte_count / 2

	return byte_count / LAYERED_PLANES if byte_count in LAYERED_SIZES else byte_count


static func count(data: PackedByteArray) -> int:
	return cells_for(data.size())


static func is_layered(data: PackedByteArray) -> bool:
	return data.size() in LAYERED_SIZES


# an empty layered index of `cells` tiles
static func layered(cells: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(cells * LAYERED_PLANES)

	return result


static func read(data: PackedByteArray, index: int) -> int:
	var cells := count(data)

	if cells == data.size():
		return data[index]

	if cells * 2 == data.size():
		return int(data[index]) | (int(data[cells + index]) << 8)

	var top := object(data, index)

	if top != 0:
		return top

	return data[index] if data[index] != 0 else facility(data, index)


static func write(data: PackedByteArray, index: int, value: int) -> void:
	var cells := count(data)

	if cells * 2 < data.size():
		_write_layer(data, index, value)

		return

	data[index] = value & 0xff

	if cells != data.size():
		data[cells + index] = (value >> 8) & 0xff


# the marker byte of a layered index
static func marker(data: PackedByteArray, index: int) -> int:
	return data[index]


static func set_marker(data: PackedByteArray, index: int, value: int) -> void:
	data[index] = value & 0xff


# the facility ID of a layered index, or 0
static func facility(data: PackedByteArray, index: int) -> int:
	return _wide_at(data, FACILITY_PLANE, index)


static func set_facility(data: PackedByteArray, index: int, id: int) -> void:
	_set_wide_at(data, FACILITY_PLANE, index, id)


# the ID of the top moving object of a layered index, or 0
static func object(data: PackedByteArray, index: int) -> int:
	return _wide_at(data, OBJECT_PLANE, index)


static func set_object(data: PackedByteArray, index: int, id: int) -> void:
	_set_wide_at(data, OBJECT_PLANE, index, id)


# the marker of a tile: the marker layer of a layered index, else the value of
# a combined index
static func marker_at(data: PackedByteArray, index: int) -> int:
	return data[index] if is_layered(data) else read(data, index)


# set or clear the marker of a tile. A combined index writes the value
static func set_marker_at(data: PackedByteArray, index: int, value: int) -> void:
	if is_layered(data):
		data[index] = value & 0xff
	else:
		write(data, index, value)


# the facility layer of a layered index, else the value of a combined index.
# The caller checks is_facility
static func facility_at(data: PackedByteArray, index: int) -> int:
	return facility(data, index) if is_layered(data) else read(data, index)


# Take moving object `record` off tile `index`. A combined index gets
# `legacy`. A layered index shows the object below it again, and its other
# layers stay unchanged.
static func lift_object(data: PackedByteArray, things: PackedByteArray, record: int, index: int, legacy: int) -> void:
	if not is_layered(data):
		write(data, index, legacy)

		return

	var id := thing_id(record)
	var records := ThingData.count(things)
	var own := ThingData.read(things, record * Sc2ThingLayout.RECORD_SIZE + Sc2ThingLayout.Field.LABEL)
	var below := own if is_thing(own) and own != id else 0
	var above := object(data, index)

	if above == id:
		set_object(data, index, below)

		return

	# an object that another object covers leaves the chain of its tile
	for step in records:
		var above_record := thing_record(above)

		if not is_thing(above) or above_record < 0 or above_record >= records:
			return

		var label_offset := above_record * Sc2ThingLayout.RECORD_SIZE + Sc2ThingLayout.Field.LABEL

		if ThingData.read(things, label_offset) == id:
			ThingData.write(things, label_offset, below)

			return

		above = ThingData.read(things, label_offset)


# The facility of a tile: the facility layer of a layered index, else the base
# of the tile's object chain in a combined index. Returns 0 without a facility.
static func base_facility(data: PackedByteArray, things: PackedByteArray, index: int) -> int:
	if is_layered(data):
		return facility(data, index)

	var id := read(data, index)
	var hops := 0
	var records := ThingData.count(things)

	while is_thing(id) and hops < records:
		id = ThingData.read(things, thing_record(id) * Sc2ThingLayout.RECORD_SIZE + Sc2ThingLayout.Field.LABEL)
		hops += 1

	return id if is_facility(id) else 0


static func _wide_at(data: PackedByteArray, plane: int, index: int) -> int:
	var cells := data.size() / LAYERED_PLANES

	return int(data[plane * cells + index]) | (int(data[(plane + 1) * cells + index]) << 8)


static func _set_wide_at(data: PackedByteArray, plane: int, index: int, value: int) -> void:
	var cells := data.size() / LAYERED_PLANES
	data[plane * cells + index] = value & 0xff
	data[(plane + 1) * cells + index] = (value >> 8) & 0xff


# `write` of a layered index. A sign ID has no layer; signs of a layered city
# are XSGN records
static func _write_layer(data: PackedByteArray, index: int, value: int) -> void:
	if value == 0:
		if object(data, index) != 0:
			set_object(data, index, 0)
		elif data[index] != 0:
			data[index] = 0
		else:
			set_facility(data, index, 0)
	elif is_thing(value):
		set_object(data, index, value)
	elif is_facility(value):
		set_facility(data, index, value)
	elif value >= Layout.ORIGINAL_RESERVED_FIRST and value <= Layout.ORIGINAL_MAX_ID:
		data[index] = value


static func is_sign(id: int) -> bool:
	return (id >= Layout.ORIGINAL_SIGN_FIRST and id <= Layout.ORIGINAL_SIGN_LAST) or (id >= EXTRA_SIGN and id < EXTRA_THING)


static func is_facility(id: int) -> bool:
	return ((id >= Layout.ORIGINAL_FACILITY_FIRST and id <= Layout.ORIGINAL_FACILITY_LAST) or (id >= EXTRA_FACILITY and id < EXTRA_SIGN)
		or (id >= EXTRA_FACILITY_HIGH and id <= 0xffff))


static func is_thing(id: int) -> bool:
	return (id >= Layout.ORIGINAL_THING_FIRST and id <= Layout.ORIGINAL_THING_LAST) or (id >= EXTRA_THING and id < EXTRA_FACILITY_HIGH)


static func blocks_thing(id: int) -> bool:
	return is_thing(id) or (id >= Layout.ORIGINAL_RESERVED_FIRST and id <= Layout.ORIGINAL_MAX_ID)


static func facility_id(record: int) -> int:
	if record >= Layout.HIGH_FACILITY_FIRST_RECORD:
		return EXTRA_FACILITY_HIGH + record - Layout.HIGH_FACILITY_FIRST_RECORD

	return (record + Layout.ORIGINAL_FACILITY_FIRST if record < Sc2MicrosimLayout.ORIGINAL_COUNT
		else EXTRA_FACILITY + record - Sc2MicrosimLayout.ORIGINAL_COUNT)


static func facility_record(id: int) -> int:
	if id >= EXTRA_FACILITY_HIGH:
		return id - EXTRA_FACILITY_HIGH + Layout.HIGH_FACILITY_FIRST_RECORD

	return (id - Layout.ORIGINAL_FACILITY_FIRST if id <= Layout.ORIGINAL_FACILITY_LAST
		else id - EXTRA_FACILITY + Sc2MicrosimLayout.ORIGINAL_COUNT)


static func thing_id(record: int) -> int:
	return (record + Layout.ORIGINAL_THING_FIRST if record < Sc2ThingLayout.ORIGINAL_COUNT
		else EXTRA_THING + record - Sc2ThingLayout.ORIGINAL_COUNT)


static func thing_record(id: int) -> int:
	return id - Layout.ORIGINAL_THING_FIRST if id <= Layout.ORIGINAL_THING_LAST else id - EXTRA_THING + Sc2ThingLayout.ORIGINAL_COUNT


static func sign_ids(label_bytes: int) -> PackedInt32Array:
	var ids := PackedInt32Array(range(Layout.ORIGINAL_SIGN_FIRST, Layout.ORIGINAL_SIGN_LAST + 1))

	for id in range(EXTRA_SIGN, label_bytes / Sc2LabelLayout.RECORD_SIZE):
		ids.append(id)

	return ids


static func find(data: PackedByteArray, value: int, start: int = 0) -> int:
	var cells := count(data)

	if is_layered(data):
		return _find_layer(data, value, start)

	var found := data.find(value & 255, start)

	while found >= 0 and found < cells:
		if read(data, found) == value:
			return found

		found = data.find(value & 255, found + 1)

	return -1


# a layered index searches the layer of the value
static func _find_layer(data: PackedByteArray, value: int, start: int) -> int:
	var cells := count(data)
	var plane := OBJECT_PLANE if is_thing(value) else FACILITY_PLANE if is_facility(value) else 0

	if plane == 0 and (value <= 0 or value > Layout.ORIGINAL_MAX_ID or is_sign(value)):
		return -1

	var found := data.find(value & 255, plane * cells + start)

	while found >= 0 and found < (plane + 1) * cells:
		if plane == 0 or _wide_at(data, plane, found - plane * cells) == value:
			return found - plane * cells

		found = data.find(value & 255, found + 1)

	return -1


static func occurrences(data: PackedByteArray, value: int) -> int:
	if count(data) == data.size():
		return data.count(value)

	if is_layered(data) and value > 0 and value <= Layout.ORIGINAL_MAX_ID and not is_facility(value) and not is_thing(value):
		return data.slice(0, count(data)).count(value)

	var total := 0
	var index := find(data, value)

	while index >= 0:
		total += 1
		index = find(data, value, index + 1)

	return total


static func valid_id(id: int, edge: int) -> bool:
	if id >= 0 and id <= Layout.ORIGINAL_MAX_ID:
		return true

	if edge == 128:
		return false

	var factor := (edge * edge) / 16384

	return (
		(is_facility(id) and facility_record(id) < Layout.facility_capacity(factor))
		or (is_sign(id) and id < EXTRA_SIGN + Layout.ORIGINAL_SIGN_COUNT * factor - Layout.ORIGINAL_SIGN_COUNT)
		or (is_thing(id) and thing_record(id) < Sc2ThingLayout.ORIGINAL_COUNT * factor)
	)


# the cells of start..end that hold a sign ID, in cell order. a negative end
# scans to the last cell. a layered index holds no sign links
static func sign_indices(data: PackedByteArray, start := 0, end := -1) -> PackedInt32Array:
	return NativeCityArrays.sign_indices(data, start, end)
