class_name SoundEvent
extends RefCounted
# a sound request. moving-object requests retain their source metadata for
# vehicle visibility, view-size filtering, and the shared sound gate

var sound_id: int
var from_thing := false
var thing_type := -1
var record := -1
var point := Vector2i(-1, -1)


func _init(id: int) -> void:
	sound_id = id


static func for_thing(id: int, type: int, record_id: int, location := Vector2i(-1, -1)) -> SoundEvent:
	var result := SoundEvent.new(id)
	result.from_thing = true
	result.thing_type = type
	result.record = record_id
	result.point = location

	return result


# tool and query rules can return plain ids. convert them at publication
static func from_ids(ids: Array[int]) -> Array[SoundEvent]:
	var result: Array[SoundEvent] = []

	for id in ids:
		result.append(SoundEvent.new(id))

	return result


func equals(other: SoundEvent) -> bool:
	return other != null and sound_id == other.sound_id and from_thing == other.from_thing \
		and thing_type == other.thing_type and record == other.record and point == other.point


static func same_arrays(first: Array[SoundEvent], second: Array[SoundEvent]) -> bool:
	if first.size() != second.size():
		return false

	for index in first.size():
		if not first[index].equals(second[index]):
			return false

	return true


static func count_plain(events: Array[SoundEvent], id: int) -> int:
	var expected := SoundEvent.new(id)
	var count := 0

	for event in events:
		if event.equals(expected):
			count += 1

	return count
