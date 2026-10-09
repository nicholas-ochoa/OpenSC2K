class_name ModsSettingsPanel
extends VBoxContainer
## The Mods tab of Settings: each mod in the mods folder, with a check box
## that turns it on or off, its state, and the facts of its info.json. A
## change applies at once. ApplicationMods keeps the mods. This file does not
## refer to the application classes: they preload the Settings scene.

signal mod_enabled_changed(id: String, enabled: bool)
signal reload_requested
signal open_folder_requested

enum Column { NAME, VERSION, AUTHOR, STATUS }

const COLUMN_TITLES := ["Mod", "Version", "Author", "Status"]
const ERROR_COLOR := Color(0.85, 0.15, 0.1)

var tree: Tree
var details: RichTextLabel
var open_folder_button: Button
var reload_button: Button
# the id of the selected mod, kept when the list changes
var selected_id := ""
var _rows: Array[Dictionary] = []
var _showing := false


func _init() -> void:
	name = "Mods"
	add_theme_constant_override("separation", 6)

	tree = Tree.new()
	tree.columns = COLUMN_TITLES.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size = Vector2(0, 140)

	for column in COLUMN_TITLES.size():
		tree.set_column_title(column, COLUMN_TITLES[column])
		tree.set_column_expand(column, column == Column.NAME or column == Column.STATUS)
		tree.set_column_clip_content(column, true)

	tree.set_column_custom_minimum_width(Column.NAME, 150)
	tree.set_column_custom_minimum_width(Column.VERSION, 70)
	tree.set_column_custom_minimum_width(Column.AUTHOR, 110)
	tree.set_column_expand_ratio(Column.STATUS, 2)
	tree.item_edited.connect(_on_item_edited)
	tree.item_selected.connect(_on_item_selected)
	add_child(tree)

	details = RichTextLabel.new()
	details.bbcode_enabled = true
	details.fit_content = true
	details.selection_enabled = true
	details.custom_minimum_size = Vector2(0, 90)
	details.meta_clicked.connect(_on_meta_clicked)
	add_child(details)

	var buttons := HBoxContainer.new()
	open_folder_button = Button.new()
	open_folder_button.text = "Open Mods Folder"
	open_folder_button.pressed.connect(open_folder_requested.emit)
	buttons.add_child(open_folder_button)
	reload_button = Button.new()
	reload_button.text = "Reload Mods"
	reload_button.tooltip_text = "Stop all mods, find the mods in the folder again, and start the enabled ones."
	reload_button.pressed.connect(reload_requested.emit)
	buttons.add_child(reload_button)
	add_child(buttons)


## Shows the rows of ApplicationMods.rows().
func show_mods(rows: Array[Dictionary], folder: String) -> void:
	_showing = true
	_rows = rows
	open_folder_button.tooltip_text = tr("Open %s. Each folder in it with an info.json file is a mod.") % folder
	tree.clear()
	var root := tree.create_item()
	var selected: TreeItem = null

	for row in rows:
		var item := tree.create_item(root)
		item.set_cell_mode(Column.NAME, TreeItem.CELL_MODE_CHECK)
		item.set_editable(Column.NAME, true)
		item.set_checked(Column.NAME, bool(row.enabled))
		item.set_text(Column.NAME, str(row.name))
		item.set_text(Column.VERSION, str(row.version))
		item.set_text(Column.AUTHOR, str(row.author))
		item.set_text(Column.STATUS, str(row.status).get_slice("\n", 0))
		item.set_tooltip_text(Column.STATUS, str(row.status))
		item.set_metadata(Column.NAME, str(row.id))

		if bool(row.get("failed", false)):
			item.set_custom_color(Column.STATUS, ERROR_COLOR)

		if str(row.id) == selected_id:
			selected = item

	if selected == null and root.get_child_count() > 0:
		selected = root.get_child(0)

	if selected != null:
		selected.select(Column.NAME)

	_show_details(_row(str(selected.get_metadata(Column.NAME))) if selected != null else {})
	_showing = false


func _row(id: String) -> Dictionary:
	for row in _rows:
		if str(row.id) == id:
			return row

	return {}


func _on_item_edited() -> void:
	var item := tree.get_edited()

	if _showing or item == null:
		return

	mod_enabled_changed.emit(str(item.get_metadata(Column.NAME)), item.is_checked(Column.NAME))


func _on_item_selected() -> void:
	var item := tree.get_selected()

	if item == null:
		return

	selected_id = str(item.get_metadata(Column.NAME))
	_show_details(_row(selected_id))


func _show_details(row: Dictionary) -> void:
	if row.is_empty():
		details.text = "No mods installed. To add a mod, copy its folder into the mods folder, then click Reload Mods."

		return

	var lines := PackedStringArray(["[b]%s[/b] %s  [i](%s)[/i]" % [_escape(row.name), _escape(row.version), _escape(row.id)]])

	if not str(row.description).is_empty():
		lines.append(_escape(row.description))

	var facts := PackedStringArray()

	if not str(row.author).is_empty():
		facts.append("Author: " + _escape(row.author))

	if not str(row.email).is_empty():
		facts.append("Email: [url=mailto:%s]%s[/url]" % [_escape(row.email), _escape(row.email)])

	if not str(row.website).is_empty():
		facts.append("Website: [url=%s]%s[/url]" % [_escape(row.website), _escape(row.website)])

	if not str(row.license).is_empty():
		facts.append("License: " + _escape(row.license))

	if not facts.is_empty():
		lines.append("  ".join(facts))

	if not (row.dependencies as Array).is_empty():
		lines.append("Needs: " + _escape(", ".join(PackedStringArray(row.dependencies))))

	lines.append("Status: " + _escape(row.status))
	details.text = "\n".join(lines)


static func _escape(value: Variant) -> String:
	return str(value).replace("[", "[lb]")


# opens a website or an email link of the details
func _on_meta_clicked(meta: Variant) -> void:
	var link := str(meta)

	if link.begins_with("https://") or link.begins_with("http://") or link.begins_with("mailto:"):
		OS.shell_open(link)
