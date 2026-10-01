class_name DebugTableSource
extends RefCounted
## The rows of a debug record table. A source lists the record IDs and builds
## a row only when the table draws, sorts or searches it. Built rows stay until
## the source changes, so a large table builds each row at most once.

var ids := PackedStringArray()
# a value that changes when the rows change. the table keeps its order otherwise
var signature: Array = []
# MicroSim rows have a position cell
var with_position := false
var _builder := Callable()
# (id, data column) -> sort value without a row. empty uses the built row
var key_builder := Callable()
# (id) -> lowercase search text without a row. empty uses the built row
var search_builder := Callable()
var _rows: Dictionary[String, DebugTableRecord] = {}
var _search: Dictionary[String, String] = {}


# a source that builds each row with `builder`, a callable of an ID
static func lazy(record_ids: PackedStringArray, builder: Callable, source_signature: Array) -> DebugTableSource:
	var source := DebugTableSource.new()
	source.ids = record_ids
	source._builder = builder
	source.signature = source_signature

	return source


# a source of rows that are built already
static func of(records: Array[DebugTableRecord]) -> DebugTableSource:
	var source := DebugTableSource.new()

	for record in records:
		source.ids.append(record.id)
		source._rows[record.id] = record

	source.signature = [records.hash()]

	return source


func size() -> int:
	return ids.size()


func has(id: String) -> bool:
	return _rows.has(id) or (_builder.is_valid() and ids.has(id))


func row(id: String) -> DebugTableRecord:
	var record: DebugTableRecord = _rows.get(id)

	if record == null and _builder.is_valid():
		record = _builder.call(id)
		_rows[id] = record

	return record


# the sort value of a row in a data column. rows without a value return null
func sort_key(id: String, column: int) -> Variant:
	if key_builder.is_valid():
		return key_builder.call(id, column)

	var record := row(id)

	if record == null:
		return null

	if column < record.sort.size():
		return record.sort[column]

	var cells := record.cells if not record.cells.is_empty() else DebugVirtualTable.record_cells(record, with_position)

	return cells[column] if column < cells.size() else ""


# the text of a row and its fields, for the search box
func search_text(id: String) -> String:
	if _search.has(id):
		return _search[id]

	if search_builder.is_valid():
		_search[id] = search_builder.call(id)

		return _search[id]

	var record := row(id)
	var parts := PackedStringArray()

	for item: DebugTableRecord in [record] + record.fields:
		parts.append_array(item.cells if not item.cells.is_empty() else DebugVirtualTable.record_cells(item, with_position))

	var text := " ".join(parts).to_lower()
	_search[id] = text

	return text
