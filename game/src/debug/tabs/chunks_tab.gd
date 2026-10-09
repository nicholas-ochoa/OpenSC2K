class_name CityDebugChunksTab
extends DebugWindowTab
## Every chunk of the open city with its size, revision and kind, and a hex
## view of the selected chunk. Bytes that changed since the mark are marked:
## the city at load in debug mode, or the moment of Mark bytes now. Preserved
## SC2X entries are listed with their sizes. Export writes a chunk to a file.

@warning_ignore_start("integer_division")

const COLUMNS := ["Chunk", "Bytes", "Revision", "Kind", "Changed bytes"]
const ROW_BYTES := 16
const PAGE_ROWS := 32
const PAGE_BYTES := ROW_BYTES * PAGE_ROWS
const REFRESH_MSEC := 1000
# the search for the previous change reads blocks of this size
const SEARCH_BLOCK := 65536
const CHANGED_COLOR := "#f5c518"
const EXPORT_FOLDER := "debug_captures/chunks"

var table: Tree
var hex: RichTextLabel
var offset_input: SpinBox
var summary: Label
var _selected := ""
var _rows: Dictionary[String, TreeItem] = {}
# changed byte counts by chunk key: [revision, mark identity, count]
var _counts: Dictionary[String, Array] = {}
var _city_id := 0
var _refreshed_at := -REFRESH_MSEC


func _init() -> void:
	name = "Chunks"
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 380
	split.add_child(left)
	table = make_table(COLUMNS, 3)
	table.item_selected.connect(_on_selected)

	for column in COLUMNS.size():
		table.set_column_custom_minimum_width(column, 64)

	left.add_child(table)
	var buttons := HBoxContainer.new()
	left.add_child(buttons)
	make_button(buttons, "Mark bytes now", "Compare the chunks with their bytes at this moment.", _mark)
	make_button(buttons, "Export chunk", "Write the decoded bytes of the selected chunk to a file in the debug_captures folder.", _export)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	var controls := HBoxContainer.new()
	right.add_child(controls)
	var caption := Label.new()
	caption.text = "Offset"
	controls.add_child(caption)
	offset_input = SpinBox.new()
	# any offset; the page starts at the row that holds it
	offset_input.step = 1
	offset_input.custom_minimum_size.x = 140
	offset_input.value_changed.connect(func(_value: float) -> void: _show_page())
	controls.add_child(offset_input)
	make_button(controls, "Previous change", "Go to the last changed byte before the offset.", _previous_change)
	make_button(controls, "Next change", "Go to the first changed byte after the offset.", _next_change)
	summary = Label.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.clip_text = true
	controls.add_child(summary)
	hex = RichTextLabel.new()
	hex.bbcode_enabled = true
	hex.scroll_active = true
	hex.selection_enabled = true
	hex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# hex rows do not wrap. a narrow window cuts their right end
	hex.autowrap_mode = TextServer.AUTOWRAP_OFF
	hex.clip_contents = true
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono", "monospace"])
	hex.add_theme_font_override("normal_font", font)
	hex.add_theme_font_size_override("normal_font_size", 13)
	right.add_child(hex)


func refresh(force := false) -> void:
	var app := application()
	var document := app.document_state.current_document if app != null else null

	if document == null:
		table.clear()
		_rows.clear()
		hex.text = ""
		_city_id = 0

		return

	if document.get_instance_id() != _city_id:
		_build(document)
	elif not force and Time.get_ticks_msec() - _refreshed_at < REFRESH_MSEC:
		return

	_refreshed_at = Time.get_ticks_msec()
	_update(document)
	_show_page()


func _build(document: Sc2File) -> void:
	table.clear()
	_rows.clear()
	_counts.clear()
	_city_id = document.get_instance_id()
	var root := table.create_item()
	var seen: Dictionary[String, int] = {}

	for chunk in document.chunks:
		var key := ApplicationDebugTools.chunk_key(chunk.chunk_id, seen)
		var row := table.create_item(root)
		row.set_text(0, key)
		row.set_text(3, "Known" if NativeSimulationBridge.CHUNK_IDS.has(chunk.chunk_id) else "Unknown (kept)")
		row.set_meta("key", key)
		_rows[key] = row

	for record in document.sc2x_preserved:
		var row := table.create_item(root)
		row.set_text(0, str(record.get("entry", record.get("id", "Preserved"))))
		row.set_text(1, str((record.get("payload", PackedByteArray()) as PackedByteArray).size()))
		row.set_text(3, "Preserved SC2X data")

	for entry in document.sc2x_extra_entries:
		var row := table.create_item(root)
		row.set_text(0, entry)
		row.set_text(1, str(document.sc2x_extra_entries[entry].size()))
		row.set_text(3, "Extra SC2X entry")

	if not _rows.has(_selected) and not _rows.is_empty():
		_selected = _rows.keys()[0]
		_rows[_selected].select(0)


func _update(document: Sc2File) -> void:
	var marks := _marks()
	var seen: Dictionary[String, int] = {}

	for chunk in document.chunks:
		var key := ApplicationDebugTools.chunk_key(chunk.chunk_id, seen)
		var row: TreeItem = _rows.get(key)

		if row == null:
			continue

		row.set_text(1, str(chunk.decoded_payload.size()))
		row.set_text(2, str(chunk.mutation_revision) + (" (edited)" if chunk.is_dirty else ""))
		row.set_text(4, _changed_text(key, chunk, marks))


# the changed byte count, counted again only after the chunk or the mark changes
func _changed_text(key: String, chunk: Sc2Chunk, marks: Dictionary) -> String:
	if not marks.has(key):
		return "No mark"

	var mark: PackedByteArray = marks[key]
	var cached: Array = _counts.get(key, [])
	var identity := [chunk.mutation_revision, application().debug_tools.chunk_mark_serial]

	if cached.is_empty() or cached[0] != identity:
		var count := 0 if mark == chunk.decoded_payload else int(NativeDebugTiles.byte_differences(mark, chunk.decoded_payload, 0).count)
		cached = [identity, count]
		_counts[key] = cached

	return str(cached[1])


func _marks() -> Dictionary:
	var app := application()

	return app.debug_tools.chunk_marks if app != null else {}


func _selected_chunk() -> Sc2Chunk:
	var app := application()
	var document := app.document_state.current_document if app != null else null

	return ApplicationDebugTools.find_keyed_chunk(document, _selected) if document != null else null


func _on_selected() -> void:
	var row := table.get_selected()

	if row == null or not row.has_meta("key"):
		return

	_selected = str(row.get_meta("key"))
	offset_input.set_value_no_signal(0)
	_show_page()


func _show_page() -> void:
	var chunk := _selected_chunk()

	if chunk == null:
		hex.text = "Select a chunk."

		return

	var data := chunk.decoded_payload
	var mark: Variant = _marks().get(_selected)
	offset_input.max_value = maxi(0, data.size() - 1)
	var start := (int(offset_input.value) / ROW_BYTES) * ROW_BYTES
	var end := mini(data.size(), start + PAGE_BYTES)
	var changed: Dictionary[int, bool] = {}

	if mark is PackedByteArray:
		var found: Dictionary = NativeDebugTiles.byte_differences((mark as PackedByteArray).slice(start, end), data.slice(start, end),
			PAGE_BYTES)

		for offset in found.offsets as PackedInt32Array:
			changed[start + offset] = true

	summary.tooltip_text = tr("%s: %d bytes, %s") % [_selected, data.size(), "no mark" if mark == null else "%s changed since the mark" % (
		_rows[_selected].get_text(4) if _rows.has(_selected) else "?")]
	summary.text = summary.tooltip_text
	hex.text = page_text(data, start, end, changed)


# hex rows of `data` from `start` to `end`, with the changed bytes marked
static func page_text(data: PackedByteArray, start: int, end: int, changed: Dictionary[int, bool] = {}) -> String:
	var lines := PackedStringArray()

	for row in range(start, end, ROW_BYTES):
		var bytes := PackedStringArray()
		var text := ""

		for offset in range(row, row + ROW_BYTES):
			if offset >= end:
				bytes.append("  ")
				continue

			var value := data[offset]
			var cell := "%02X" % value
			bytes.append("[bgcolor=%s][color=black]%s[/color][/bgcolor]" % [CHANGED_COLOR, cell] if changed.has(offset) else cell)
			text += char(value) if value >= 0x20 and value < 0x7f and char(value) not in ["[", "]"] else "."

		lines.append("%08X  %s  %s" % [row, " ".join(bytes), text])

	return "\n".join(lines)


func _next_change() -> void:
	var chunk := _selected_chunk()
	var mark: Variant = _marks().get(_selected)

	if chunk == null or not mark is PackedByteArray:
		report("Mark the chunks first, then look for changes.")

		return

	var start := mini(int(offset_input.value) + 1, chunk.decoded_payload.size())
	var found: Dictionary = NativeDebugTiles.byte_differences((mark as PackedByteArray).slice(start), chunk.decoded_payload.slice(start), 1)

	if (found.offsets as PackedInt32Array).is_empty():
		report("No changed byte after this offset.")
	else:
		offset_input.value = start + found.offsets[0]


func _previous_change() -> void:
	var chunk := _selected_chunk()
	var mark: Variant = _marks().get(_selected)

	if chunk == null or not mark is PackedByteArray:
		report("Mark the chunks first, then look for changes.")

		return

	var end := int(offset_input.value)

	while end > 0:
		var start := maxi(0, end - SEARCH_BLOCK)
		var found: Dictionary = NativeDebugTiles.byte_differences((mark as PackedByteArray).slice(start, end),
			chunk.decoded_payload.slice(start, end), SEARCH_BLOCK)

		if not (found.offsets as PackedInt32Array).is_empty():
			offset_input.value = start + found.offsets[-1]

			return

		end = start

	report("No changed byte before this offset.")


func _mark() -> void:
	var app := application()

	if app != null:
		report(app.debug_tools.mark_chunks())
		_counts.clear()
		refresh(true)


func _export() -> void:
	var chunk := _selected_chunk()

	if chunk == null:
		report("Select a chunk to export.")

		return

	var folder := AppPaths.path(EXPORT_FOLDER)
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("%s_%s.bin" % [_selected.replace("#", "_"), Time.get_datetime_string_from_system().replace(":", "-")])
	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		report("Cannot write %s." % path)

		return

	file.store_buffer(chunk.decoded_payload)
	file.close()
	report("Exported %d bytes to %s." % [chunk.decoded_payload.size(), path])
