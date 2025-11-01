class_name CityAnalysisDialog
extends AcceptDialog

var table: Tree


func _ready() -> void:
	title = "City Analysis"
	min_size = Vector2i(600, 480)
	get_label().visible = false

	table = Tree.new()
	table.custom_minimum_size = Vector2i(540, 360)
	table.columns = 3
	table.column_titles_visible = true
	table.hide_root = true
	table.set_column_title(0, "LAND USE")
	table.set_column_title(1, "ACRES")
	table.set_column_title(2, "% of CITY")
	table.set_column_expand(0, true)
	table.set_column_expand(1, false)
	table.set_column_expand(2, false)
	table.set_column_custom_minimum_width(1, 100)
	table.set_column_custom_minimum_width(2, 100)
	var content := get_label().get_parent()
	content.add_child(table)
	content.move_child(table, 0)


func set_categories(categories: Array) -> void:
	table.clear()
	var root := table.create_item()
	for category in categories:
		var item := table.create_item(root)
		item.set_text(0, str(category.name))
		item.set_text(1, str(category.acres))
		item.set_text(2, "%d%%" % category.percent)
		item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		item.set_text_alignment(2, HORIZONTAL_ALIGNMENT_RIGHT)


func show_categories(categories: Array) -> void:
	set_categories(categories)
	popup_centered()
