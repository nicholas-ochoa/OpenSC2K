class_name Sc2ImportXmi
extends RefCounted
## Convert a single XMIDI sequence to SMF with explicit note-off events.
## XMIDI delays use a fixed 120 Hz clock, independent of MIDI tempo metadata.

const MAX_EVENTS := 200000
const MAX_TICK := 0x0fffffff

class TimedEvent extends RefCounted:
	var tick := 0
	var order := 0
	var bytes := PackedByteArray()


var error := ""
var _streams: Array[PackedByteArray] = []
var _events: Array[TimedEvent] = []
var _data := PackedByteArray()
var _cursor := 0


static func convert(data: PackedByteArray) -> AssetBytesResult:
	var decoder := Sc2ImportXmi.new()
	decoder._chunks(data, 0, data.size(), 0, false)

	if not decoder.error.is_empty():
		return AssetBytesResult.failure(decoder.error)

	if decoder._streams.size() != 1:
		return AssetBytesResult.failure("Expected one XMIDI sequence; found %d." % decoder._streams.size())

	return decoder._sequence(decoder._streams[0])


func _chunks(data: PackedByteArray, start: int, end: int, depth: int, in_sequence: bool) -> void:
	if depth > 8:
		error = "XMIDI container nesting is too deep."
		return

	var cursor := start

	while cursor < end and error.is_empty():
		if end - cursor < 8:
			error = "Truncated XMIDI chunk header."
			return

		var tag := data.slice(cursor, cursor + 4).get_string_from_ascii()
		var length := Sc2ImportContainer.be32(data, cursor + 4)
		var body := cursor + 8

		if length > end - body:
			error = "XMIDI chunk exceeds its container."
			return

		if tag in ["FORM", "CAT "]:
			if length < 4:
				error = "Missing XMIDI container type."
				return

			var kind := data.slice(body, body + 4).get_string_from_ascii()

			if kind not in ["XMID", "XDIR"]:
				error = "Unsupported XMIDI container type."
				return

			_chunks(data, body + 4, body + length, depth + 1, kind == "XMID")
		elif tag == "EVNT" and in_sequence:
			_streams.append(data.slice(body, body + length))
		elif depth == 0:
			error = "Missing XMIDI FORM or CAT container."
			return

		cursor = body + length

		if length % 2 != 0 and cursor < end:
			cursor += 1


func _sequence(data: PackedByteArray) -> AssetBytesResult:
	_data = data
	_cursor = 0
	var tick := 0
	var ended := false
	_add(0, PackedByteArray([0xff, 0x51, 3, 7, 0xa1, 0x20]))

	while _cursor < _data.size() and error.is_empty():
		while _cursor < _data.size() and _data[_cursor] < 128:
			tick += int(_data[_cursor])
			_cursor += 1

		if tick > MAX_TICK or _cursor >= _data.size():
			return AssetBytesResult.failure("Invalid or truncated XMIDI delay.")

		var status := int(_data[_cursor])
		_cursor += 1
		var command := status >> 4

		if status in [0xff, 0xf0, 0xf7]:
			var type := -1

			if status == 0xff:
				if _cursor >= _data.size():
					return AssetBytesResult.failure("Truncated XMIDI meta event.")

				type = int(_data[_cursor])
				_cursor += 1

			var length := _read_vlq()

			if length < 0 or not Sc2ImportContainer.has_range(_data, _cursor, length):
				return AssetBytesResult.failure("Truncated XMIDI meta or SysEx data.")

			var payload := _data.slice(_cursor, _cursor + length)
			_cursor += length

			if type == 0x2f:
				if length != 0:
					return AssetBytesResult.failure("Invalid XMIDI end event.")

				ended = true
				break

			# A fixed output tempo retains the source's 120 Hz event clock.
			if type == 0x51:
				if length != 3:
					return AssetBytesResult.failure("Invalid XMIDI tempo metadata.")

				continue

			var event := PackedByteArray([status])

			if type >= 0:
				event.append(type)

			event.append_array(_vlq(length))
			event.append_array(payload)
			_add(tick, event)
		elif command >= 8 and command <= 14:
			var count := 1 if command in [12, 13] else 2

			if not Sc2ImportContainer.has_range(_data, _cursor, count):
				return AssetBytesResult.failure("Truncated XMIDI channel event.")

			var event := PackedByteArray([status])

			for index in count:
				var value := int(_data[_cursor])
				_cursor += 1

				if value >= 128:
					return AssetBytesResult.failure("Invalid XMIDI channel event data.")

				event.append(value)

			if command == 11 and event[1] >= 110 and event[1] <= 120:
				# Driver-specific bank, branch and loop controls need explicit handling.
				# Reject this record instead of silently producing a different song.
				return AssetBytesResult.failure("XMIDI uses unsupported driver controller %d." % event[1])

			_add(tick, event)

			if command == 9:
				# xmidi puts the duration after note-on, schedule a note-off from it
				var duration := _read_vlq()

				if duration < 0 or tick + duration > MAX_TICK:
					return AssetBytesResult.failure("Invalid XMIDI note duration.")

				if event[2] > 0:
					_add(tick + maxi(duration, 1), PackedByteArray([0x80 | (status & 15), event[1], 0]))
		else:
			return AssetBytesResult.failure("Unsupported XMIDI event 0x%02x." % status)

	if not error.is_empty():
		return AssetBytesResult.failure(error)

	if not ended:
		return AssetBytesResult.failure("XMIDI sequence has no end event.")

	_events.sort_custom(func(a: TimedEvent, b: TimedEvent) -> bool:
		return a.tick < b.tick if a.tick != b.tick else a.order < b.order)
	var track := PackedByteArray()
	var previous := 0

	for event in _events:
		track.append_array(_vlq(event.tick - previous))
		track.append_array(event.bytes)
		previous = event.tick

	track.append_array(_vlq(maxi(tick, previous) - previous))
	track.append_array(PackedByteArray([0xff, 0x2f, 0]))
	var output := PackedByteArray([77, 84, 104, 100, 0, 0, 0, 6, 0, 0, 0, 1, 0, 60, 77, 84, 114, 107])

	for shift in [24, 16, 8, 0]:
		output.append((track.size() >> shift) & 255)

	output.append_array(track)
	var result := AssetBytesResult.new()
	result.ok = true
	result.bytes = output

	return result


func _read_vlq() -> int:
	var value := 0

	for index in 4:
		if _cursor >= _data.size():
			return -1

		var byte := int(_data[_cursor])
		_cursor += 1
		value = (value << 7) | (byte & 127)

		if byte < 128:
			return value

	return -1


func _add(tick: int, bytes: PackedByteArray) -> void:
	if _events.size() >= MAX_EVENTS:
		error = "XMIDI sequence exceeds the event limit."
		return

	var event := TimedEvent.new()
	event.tick = tick
	event.order = _events.size()
	event.bytes = bytes
	_events.append(event)


static func _vlq(value: int) -> PackedByteArray:
	var bytes := PackedByteArray([value & 127])
	value >>= 7

	while value > 0:
		bytes.insert(0, (value & 127) | 128)
		value >>= 7

	return bytes
