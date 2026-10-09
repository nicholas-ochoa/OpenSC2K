class_name CityDebugStepsTab
extends DebugWindowTab
## Step the paused simulation by one phase or one day, and read the log of
## each step: its time, its changed tiles and its changed chunks.

const COLUMNS := ["Date", "Step", "ms", "Changed tiles", "Changed chunks"]

var next_label: Label
var table: Tree
var _shown := -1


func _init() -> void:
	name = "Steps"
	next_label = Label.new()
	next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(next_label)
	var buttons := HBoxContainer.new()
	add_child(buttons)
	make_button(buttons, "Advance one phase", ("Run the next action of the day schedule, then stop. The day stays open until " +
		"its last action runs. A speed change runs the rest of the day first."), func() -> void: _step("phase"))
	make_button(buttons, "Advance one day", ("Run the rest of an open day, or the next whole day. During a disaster, run one " +
		"disaster tick."), func() -> void: _step("day"))
	make_button(buttons, "Clear log", "Remove the step log.", func() -> void:
		if application() != null:
			application().debug_tools.steps.entries.clear()
			refresh(true))
	var note := Label.new()
	note.text = ("The game must be paused. A phase step runs each action as its own native call; the game runs a whole " +
		"day in one call. Tile changes are compared on maps up to 1024 tiles.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	add_child(note)
	table = make_table(COLUMNS, 4)
	table.set_column_expand(1, true)
	table.set_column_custom_minimum_width(1, 260)
	add_child(table)


func refresh(force := false) -> void:
	var app := application()

	if app == null:
		return

	var steps := app.debug_tools.steps
	next_label.text = tr("Next step: ") + steps.next_actions()

	if not force and steps.serial == _shown:
		return

	_shown = steps.serial
	table.clear()
	var root := table.create_item()

	for index in range(steps.entries.size() - 1, -1, -1):
		var entry := steps.entries[index]
		var row := table.create_item(root)
		row.set_text(0, entry.date)
		row.set_text(1, entry.title if entry.error.is_empty() else "%s (failed: %s)" % [entry.title, entry.error])
		row.set_text(2, "%.2f" % (entry.usec / 1000.0))
		row.set_text(3, "-" if entry.changed_tiles < 0 else str(entry.changed_tiles))
		row.set_text(4, ", ".join(entry.changed_chunks))
		row.set_tooltip_text(4, ", ".join(entry.changed_chunks))


func _step(kind: String) -> void:
	var app := application()

	if app == null:
		return

	report(app.debug_tools.steps.step_phase() if kind == "phase" else app.debug_tools.steps.step_day())
	refresh(true)
