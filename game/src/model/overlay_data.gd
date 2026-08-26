class_name OverlayData
extends RefCounted
# original ids are unchanged. sc2x v2 adds disjoint 16-bit id ranges

@warning_ignore_start("integer_division")

const EXTRA_FACILITY := 256
const EXTRA_SIGN := 4096
const EXTRA_THING := 8192


# the overlay layout keys off the payload size alone. a wide sc2x map stores a
# low and a high plane, so its cell count is half its bytes
static func cells_for(byte_count: int) -> int:
	return (byte_count / 2) if byte_count == 131072 or byte_count == 294912 or byte_count == 524288 else byte_count


static func count(data: PackedByteArray) -> int:
	return cells_for(data.size())


static func read(data: PackedByteArray, index: int) -> int:
	var cells := count(data)

	return int(data[index]) | (int(data[cells + index]) << 8 if cells != data.size() else 0)


static func write(data: PackedByteArray, index: int, value: int) -> void:
	data[index] = value & 0xff
	var cells := count(data)

	if cells != data.size():
		data[cells + index] = (value >> 8) & 0xff


static func is_sign(id: int) -> bool:
	return (id >= 1 and id <= 50) or (id >= EXTRA_SIGN and id < EXTRA_THING)


static func is_facility(id: int) -> bool:
	return (id >= 51 and id <= 200) or (id >= EXTRA_FACILITY and id < EXTRA_SIGN)


static func is_thing(id: int) -> bool:
	return (id >= 201 and id <= 240) or id >= EXTRA_THING


static func blocks_thing(id: int) -> bool:
	return is_thing(id) or (id >= 241 and id <= 255)


static func facility_id(record: int) -> int:
	return record + 51 if record < 150 else EXTRA_FACILITY + record - 150


static func facility_record(id: int) -> int:
	return id - 51 if id <= 200 else id - EXTRA_FACILITY + 150


static func thing_id(record: int) -> int:
	return record + 201 if record < 40 else EXTRA_THING + record - 40


static func thing_record(id: int) -> int:
	return id - 201 if id <= 240 else id - EXTRA_THING + 40


static func sign_ids(label_bytes: int) -> PackedInt32Array:
	var ids := PackedInt32Array(range(1, 51))

	for id in range(EXTRA_SIGN, label_bytes / 25):
		ids.append(id)

	return ids


static func find(data: PackedByteArray, value: int, start: int = 0) -> int:
	var cells := count(data)
	var found := data.find(value & 255, start)

	while found >= 0 and found < cells:
		if read(data, found) == value:
			return found

		found = data.find(value & 255, found + 1)

	return -1


static func occurrences(data: PackedByteArray, value: int) -> int:
	if count(data) == data.size():
		return data.count(value)

	var total := 0
	var index := find(data, value)

	while index >= 0:
		total += 1
		index = find(data, value, index + 1)

	return total


static func valid_id(id: int, edge: int) -> bool:
	if id >= 0 and id <= 255:
		return true

	if edge == 128:
		return false

	var factor := (edge * edge) / 16384

	return ((is_facility(id) and facility_record(id) < 150 * factor) or (is_sign(id) and id < EXTRA_SIGN + 50 * factor - 50)
			or (is_thing(id) and thing_record(id) < 40 * factor))


static func sign_indices(data: PackedByteArray, start := 0, end := -1) -> PackedInt32Array:
	assert(start >= 0 and start % 8 == 0, "Sign scan pages start on an eight-cell boundary")
	var result := PackedInt32Array()
	var cells := count(data)
	var wide := cells < data.size()
	end = cells if end < 0 else mini(end, cells)
	var full_cells := end - end % 8

	for offset in range(start, full_cells, 8):
		var low_word := data.decode_u64(offset)
		var high_word := data.decode_u64(cells + offset) if wide else 0

		if low_word == 0 and high_word == 0:
			continue

		# With bit 7 clear, adding (127 - limit) sets it when a byte exceeds limit.
		# No carry can cross into the next byte. This checks eight bytes at once
		# for original IDs 1..50 and extended high bytes 16..31.
		var low_seven := low_word & 0x7f7f7f7f7f7f7f7f
		var candidates := (low_seven + 0x7f7f7f7f7f7f7f7f) & ~(low_seven + 0x4d4d4d4d4d4d4d4d) & ~low_word

		if high_word != 0:
			var high_seven := high_word & 0x7f7f7f7f7f7f7f7f
			candidates |= (high_seven + 0x7070707070707070) & ~(high_seven + 0x6060606060606060) & ~high_word

		if (candidates & ~0x7f7f7f7f7f7f7f7f) == 0:
			continue

		for lane in 8:
			var byte := (low_word >> (lane * 8)) & 255
			var high := (high_word >> (lane * 8)) & 255

			if (high == 0 and byte >= 1 and byte <= 50) or (high >= EXTRA_SIGN >> 8 and high < EXTRA_THING >> 8):
				result.append(offset + lane)

	# finish partial scan ranges and small standalone buffers
	for index in range(maxi(start, full_cells), end):
		var byte := int(data[index])
		var high := int(data[cells + index]) if wide else 0

		if (high == 0 and byte >= 1 and byte <= 50) or (high >= EXTRA_SIGN >> 8 and high < EXTRA_THING >> 8):
			result.append(index)

	return result
