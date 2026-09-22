class_name StandardMidiFile
extends RefCounted

class TrackResult extends RefCounted:
	var ok := false
	var error := ""
	var next_order := 0
	var end_tick := 0

	static func failure(message: String) -> TrackResult:
		var result := TrackResult.new()
		result.error = message

		return result


class VariableLengthResult extends RefCounted:
	var ok := false
	var error := ""
	var value := 0
	var next := 0


class Event extends RefCounted:
	var tick := 0
	var order := 0
	var track := 0
	var type := ""
	var channel := 0
	var note := 0
	var velocity := 0
	var controller := 0
	var value := 0
	var program := 0
	var microseconds_per_quarter := 0
	var time_seconds := 0.0


var format_type := -1
var track_count := 0
var ticks_per_quarter := 0
var events: Array[Event] = []
var duration_seconds := 0.0
var parse_error := ""


static func load_path(path: String) -> StandardMidiFile:
	var result := StandardMidiFile.new()

	if not FileAccess.file_exists(path):
		result.parse_error = "File does not exist: %s" % path

		return result

	var data := FileAccess.get_file_as_bytes(path)

	if FileAccess.get_open_error() != OK:
		result.parse_error = "Cannot read MIDI file: %s" % path

		return result

	result.parse(data)

	return result


func parse(data: PackedByteArray) -> bool:
	format_type = -1
	track_count = 0
	ticks_per_quarter = 0
	events.clear()
	duration_seconds = 0.0
	parse_error = ""

	if data.size() < 14 or _ascii(data, 0, 4) != "MThd":
		return _fail("MIDI header is missing or truncated")

	var header_size := BinaryData.read_u32_be(data, 4)

	if header_size < 6 or 8 + header_size > data.size():
		return _fail("MIDI header length is invalid")

	format_type = BinaryData.read_u16_be(data, 8)
	track_count = BinaryData.read_u16_be(data, 10)
	var division := BinaryData.read_u16_be(data, 12)

	if format_type < 0 or format_type > 1:
		return _fail("MIDI format %d is not supported" % format_type)

	if track_count < 1:
		return _fail("MIDI file has no tracks")

	if division == 0 or division & 0x8000:
		return _fail("SMPTE or zero MIDI time division is not supported")

	ticks_per_quarter = division
	var cursor := 8 + header_size
	var event_order := 0
	var maximum_tick := 0

	for track_index in track_count:
		if cursor + 8 > data.size() or _ascii(data, cursor, 4) != "MTrk":
			return _fail("MIDI track %d header is missing or truncated" % track_index)

		var track_size := BinaryData.read_u32_be(data, cursor + 4)
		var track_start := cursor + 8
		var track_end := track_start + track_size

		if track_end > data.size():
			return _fail("MIDI track %d extends past the file" % track_index)

		var parsed := _parse_track(data, track_start, track_end, track_index, event_order)

		if not parsed.ok:
			return _fail(parsed.error)

		event_order = parsed.next_order
		maximum_tick = maxi(maximum_tick, parsed.end_tick)
		cursor = track_end

	if cursor != data.size():
		return _fail("Data follows the declared MIDI tracks")

	events.sort_custom(_event_precedes)
	_assign_event_times(maximum_tick)

	return true


func is_valid() -> bool:
	return parse_error.is_empty()


func _parse_track(
	data: PackedByteArray,
	start: int,
	end: int,
	track_index: int,
	first_order: int
) -> TrackResult:
	var cursor := start
	var tick := 0
	var running_status := -1
	var order := first_order

	while cursor < end:
		var delta := _read_variable_length(data, cursor, end)

		if not delta.ok:
			return TrackResult.failure("MIDI track %d has an invalid delta: %s" % [track_index, delta.error])

		cursor = delta.next
		tick += delta.value

		if cursor >= end:
			return TrackResult.failure("MIDI track %d ends after a delta" % track_index)

		var status := int(data[cursor])
		var first_data := -1

		if status & 0x80:
			cursor += 1

			if status < 0xf0:
				running_status = status
			else:
				running_status = -1
		else:
			if running_status < 0:
				return TrackResult.failure("MIDI track %d uses data without running status" % track_index)

			first_data = status
			status = running_status
			cursor += 1

		if status == 0xff:
			if cursor >= end:
				return TrackResult.failure("MIDI track %d has a truncated meta event" % track_index)

			var meta_type := int(data[cursor])
			cursor += 1
			var meta_length := _read_variable_length(data, cursor, end)

			if not meta_length.ok:
				return TrackResult.failure("MIDI track %d has an invalid meta length" % track_index)

			cursor = meta_length.next

			if cursor + meta_length.value > end:
				return TrackResult.failure("MIDI track %d has a truncated meta payload" % track_index)

			if meta_type == 0x51:
				if meta_length.value != 3:
					return TrackResult.failure("MIDI track %d has an invalid tempo event" % track_index)

				var microseconds := (
					(int(data[cursor]) << 16)
					| (int(data[cursor + 1]) << 8)
					| int(data[cursor + 2])
				)
				var event := Event.new()
				event.tick = tick
				event.order = order
				event.track = track_index
				event.type = "tempo"
				event.microseconds_per_quarter = microseconds
				events.append(event)
				order += 1

			cursor += meta_length.value
			continue

		if status == 0xf0 or status == 0xf7:
			var sysex_length := _read_variable_length(data, cursor, end)

			if not sysex_length.ok or sysex_length.next + sysex_length.value > end:
				return TrackResult.failure("MIDI track %d has a truncated system event" % track_index)

			cursor = sysex_length.next + sysex_length.value
			continue

		var command := status & 0xf0

		if command < 0x80 or command > 0xe0:
			return TrackResult.failure("MIDI track %d has unsupported status 0x%02x" % [track_index, status])

		var data_size := 1 if command == 0xc0 or command == 0xd0 else 2
		var data_1 := first_data

		if data_1 < 0:
			if cursor >= end:
				return TrackResult.failure("MIDI track %d has truncated channel data" % track_index)

			data_1 = int(data[cursor])
			cursor += 1

		if data_1 & 0x80:
			return TrackResult.failure("MIDI track %d has invalid channel data" % track_index)

		var data_2 := 0

		if data_size == 2:
			if cursor >= end:
				return TrackResult.failure("MIDI track %d has truncated channel data" % track_index)

			data_2 = int(data[cursor])
			cursor += 1

			if data_2 & 0x80:
				return TrackResult.failure("MIDI track %d has invalid channel data" % track_index)

		var event := Event.new()
		event.tick = tick
		event.order = order
		event.track = track_index
		event.channel = status & 0x0f

		match command:
			0x80:
				event.type = "note_off"
				event.note = data_1
				event.velocity = data_2
			0x90:
				event.type = "note_off" if data_2 == 0 else "note_on"
				event.note = data_1
				event.velocity = data_2
			0xb0:
				event.type = "control_change"
				event.controller = data_1
				event.value = data_2
			0xc0:
				event.type = "program_change"
				event.program = data_1
			0xe0:
				event.type = "pitch_bend"
				event.value = data_1 | (data_2 << 7)
			_:
				event = null

		if event != null:
			events.append(event)
			order += 1

	var result := TrackResult.new()
	result.ok = true
	result.next_order = order
	result.end_tick = tick
	result.error = ""

	return result


func _assign_event_times(maximum_tick: int) -> void:
	var tempo := 500000
	var previous_tick := 0
	var seconds := 0.0

	for event in events:
		var tick := int(event.tick)
		seconds += (
			float(tick - previous_tick) * float(tempo)
			/ float(ticks_per_quarter) / 1000000.0
		)
		event.time_seconds = seconds
		previous_tick = tick

		if event.type == "tempo":
			tempo = int(event.microseconds_per_quarter)

	duration_seconds = seconds + (
		float(maximum_tick - previous_tick) * float(tempo)
		/ float(ticks_per_quarter) / 1000000.0
	)


func _event_precedes(left: Event, right: Event) -> bool:
	if int(left.tick) != int(right.tick):
		return int(left.tick) < int(right.tick)

	return int(left.order) < int(right.order)


func _fail(message: String) -> bool:
	parse_error = message
	events.clear()

	return false


static func _read_variable_length(data: PackedByteArray, offset: int, end: int) -> VariableLengthResult:
	var value := 0
	var cursor := offset

	for byte_index in 4:
		if cursor >= end:
			var result := VariableLengthResult.new()
			result.ok = false
			result.value = 0
			result.next = cursor
			result.error = "truncated value"

			return result

		var current := int(data[cursor])
		cursor += 1
		value = (value << 7) | (current & 0x7f)

		if current & 0x80 == 0:
			var result := VariableLengthResult.new()
			result.ok = true
			result.value = value
			result.next = cursor
			result.error = ""

			return result

		if byte_index == 3:
			var result := VariableLengthResult.new()
			result.ok = false
			result.value = 0
			result.next = cursor
			result.error = "value exceeds four bytes"

			return result

	var result := VariableLengthResult.new()
	result.ok = false
	result.value = 0
	result.next = cursor
	result.error = "invalid value"

	return result


static func _ascii(data: PackedByteArray, offset: int, length: int) -> String:
	if offset < 0 or length < 0 or offset + length > data.size():
		return ""

	return data.slice(offset, offset + length).get_string_from_ascii()
