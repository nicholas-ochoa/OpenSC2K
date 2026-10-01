class_name DebugEdits
extends RefCounted
## Debug edits of saved records and MISC words. Each edit checks its value,
## writes the chunk, and keeps the chunk bytes before the edit, so Undo can put
## them back. The status line marks each change as a debug edit, because the
## edit does not follow game rules. A save keeps the edited bytes.

const MAX_HISTORY := 50
const THING_FIELDS := ThingRecord.FIELDS
const MICROSIM_FIELDS := {
	"tile_id": [Sc2MicrosimLayout.TILE_ID, 1], "stat_0": [Sc2MicrosimLayout.STAT_0, 1],
	"stat_1": [Sc2MicrosimLayout.STAT_1, 2], "stat_2": [Sc2MicrosimLayout.STAT_2, 2], "stat_3": [Sc2MicrosimLayout.STAT_3, 2],
}
const INT32_MIN := -2147483648
const INT32_MAX := 2147483647

var app: CityApplication
var history: Array[Entry] = []


func _init(application: CityApplication) -> void:
	app = application


func clear() -> void:
	history.clear()


# Change one field of an XTHG record. A coordinate must be on the map; a
# field that the record type stores in one byte takes 0 to 255
func set_thing_field(record: int, field: String, text: String) -> String:
	var city := app.document_state.city
	var chunk := city.document.find_chunk("XTHG") if city != null else null
	var field_index := THING_FIELDS.find(field)

	if chunk == null or field_index < 0 or record <= 0 or record >= ThingData.count(chunk.decoded_payload):
		return "This moving thing field cannot be changed."

	var value: Variant = parse_number(text)
	var offset := record * Sc2ThingLayout.RECORD_SIZE + field_index
	var payload := chunk.decoded_payload.duplicate()
	var wide := ThingData.split_planes(payload) and ThingData._wide(payload, offset)
	var maximum := 0xffff if wide else 0xff

	if field in ["x", "y"]:
		maximum = mini(maximum, city.map_size - 1)

	if value == null or value < 0 or value > maximum:
		return "Enter a number from 0 to %d for %s." % [maximum, field]

	ThingData.write(payload, offset, value)

	return _replace(chunk, payload, "Object %d %s = %d" % [record, field, value])


# Change one field of an XMIC record: the tile ID and the first statistic are
# bytes, the other statistics are 16-bit words
func set_microsim_field(record: int, field: String, text: String) -> String:
	var city := app.document_state.city
	var chunk := city.document.find_chunk("XMIC") if city != null else null

	if chunk == null or not MICROSIM_FIELDS.has(field) or record < 0 or record >= city.microsim_count():
		return "This MicroSim field cannot be changed."

	var value: Variant = parse_number(text)
	var layout: Array = MICROSIM_FIELDS[field]
	var maximum := 0xff if layout[1] == 1 else 0xffff

	if value == null or value < 0 or value > maximum:
		return "Enter a number from 0 to %d for %s." % [maximum, field]

	var payload := chunk.decoded_payload.duplicate()
	var offset: int = record * Sc2MicrosimLayout.RECORD_SIZE + int(layout[0])

	if layout[1] == 1:
		payload[offset] = value
	else:
		BinaryData.write_u16_be(payload, offset, value)

	return _replace(chunk, payload, "MicroSim %d %s = %d" % [record, field, value])


# Change one big-endian MISC word. It takes a signed or an unsigned 32-bit value
func set_misc_word(offset: int, text: String, name := "") -> String:
	var city := app.document_state.city
	var chunk := city.document.find_chunk("MISC") if city != null else null

	if chunk == null or offset < 0 or offset + Sc2MiscLayout.WORD_SIZE > chunk.decoded_payload.size() or offset % 4 != 0:
		return "This MISC word cannot be changed."

	var value: Variant = parse_number(text)

	if value == null or value < INT32_MIN or value > 0xffffffff:
		return "Enter a 32-bit number."

	var payload := chunk.decoded_payload.duplicate()
	BinaryData.write_u32_be(payload, offset, value & 0xffffffff)

	return _replace(chunk, payload, "MISC 0x%04X%s = %d" % [offset, " (%s)" % name if not name.is_empty() else "", value])


func undo() -> String:
	if history.is_empty():
		return "There is no debug edit to undo."

	var entry: Entry = history.pop_back()
	var chunk := app.document_state.city.document.find_chunk(entry.chunk_id) if app.document_state.city != null else null

	if chunk == null or chunk != entry.chunk:
		return "The edited city is closed. The edit cannot be undone."

	chunk.set_decoded_payload(entry.before, true)
	_after_edit(entry.chunk_id)

	return "Undid the debug edit: %s." % entry.description


func _replace(chunk: Sc2Chunk, payload: PackedByteArray, description: String) -> String:
	var entry := Entry.new()
	entry.chunk = chunk
	entry.chunk_id = chunk.chunk_id
	entry.before = chunk.decoded_payload
	entry.description = description

	if not chunk.set_decoded_payload(payload, true):
		return "The %s chunk keeps its size. The edit was not applied." % chunk.chunk_id

	history.append(entry)

	if history.size() > MAX_HISTORY:
		history.pop_front()

	_after_edit(chunk.chunk_id)

	return "Debug edit: %s." % description


# show the edit: mirrors, the details, the moving things and the map
func _after_edit(chunk_id: String) -> void:
	var city := app.document_state.city
	city.resync_mirrors(PackedStringArray([chunk_id]))
	app.tool_state.last_edit_command = null

	if app.interface != null and app.status_label != null:
		app.interface.refresh_details()

	if app.map_view != null:
		if chunk_id == "XTHG":
			app.moving_sprites.refresh_moving_things()
		else:
			app.map_render.refresh_map(false)


# a decimal or 0x hexadecimal number, the first part of "12 / 0x0C", or null
static func parse_number(text: String) -> Variant:
	var value := text.split("/")[0].strip_edges().replace(",", "").replace("$", "")
	var negative := value.begins_with("-")

	if negative:
		value = value.substr(1)

	if value.to_lower().begins_with("0x") and value.length() > 2 and value.substr(2).is_valid_hex_number():
		return (-1 if negative else 1) * value.substr(2).hex_to_int()

	if value.is_valid_int():
		return (-1 if negative else 1) * value.to_int()

	return null


class Entry extends RefCounted:
	var chunk: Sc2Chunk
	var chunk_id := ""
	var before := PackedByteArray()
	var description := ""
