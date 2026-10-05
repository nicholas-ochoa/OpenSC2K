class_name StandardMidiFile
extends RefCounted
## A Standard MIDI File of format 0 or 1: its channel events and tempo changes
## in time order, with the time of each event.

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


# The native audio library parses the file; see native/core/audio/src/smf.rs
func parse(data: PackedByteArray) -> bool:
	var parsed := NativeMidiFile.parse(data)
	format_type = parsed.format_type
	track_count = parsed.track_count
	ticks_per_quarter = parsed.ticks_per_quarter
	duration_seconds = parsed.duration_seconds
	parse_error = parsed.error
	events.clear()
	var times: PackedFloat64Array = parsed.times
	var types: PackedStringArray = parsed.types

	for index in times.size():
		var event := Event.new()
		event.tick = parsed.ticks[index]
		event.order = parsed.orders[index]
		event.track = parsed.tracks[index]
		event.type = types[index]
		event.channel = parsed.channels[index]
		event.note = parsed.notes[index]
		event.velocity = parsed.velocities[index]
		event.controller = parsed.controllers[index]
		event.value = parsed.values[index]
		event.program = parsed.programs[index]
		event.microseconds_per_quarter = parsed.tempos[index]
		event.time_seconds = times[index]
		events.append(event)

	return is_valid()


func is_valid() -> bool:
	return parse_error.is_empty()


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
