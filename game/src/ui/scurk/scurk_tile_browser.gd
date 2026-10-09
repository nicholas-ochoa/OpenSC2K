class_name ScurkTileBrowser
extends AcceptDialog

signal tile_selected(large_id: int)

const CARD_SIZE := Vector2(192, 208)

var entries: Array[ScurkTileSelector.Entry] = []
var cards: Array[Button] = []
var category_checks: Dictionary[String, CheckBox] = {}
var selected_id := -1

@onready var search: LineEdit = $Content/Search
@onready var categories: HFlowContainer = $Content/Categories
@onready var scroll: ScrollContainer = $Content/Scroll
@onready var grid: GridContainer = $Content/Scroll/Grid
@onready var results: Label = $Content/Results


func _ready() -> void:
	get_ok_button().text = "Close"
	search.text_changed.connect(func(_value: String) -> void: _filter_cards())
	scroll.resized.connect(_resize_grid)


func show_tiles(values: Array[ScurkTileSelector.Entry], current_id: int, artwork: Callable) -> void:
	entries = values
	selected_id = current_id
	for card in cards:
		grid.remove_child(card)
		card.queue_free()
	cards.clear()
	for entry in entries:
		if not category_checks.has(entry.category):
			var check := CheckBox.new()
			check.text = entry.category
			check.button_pressed = true
			check.toggled.connect(func(_enabled: bool) -> void: _filter_cards())
			categories.add_child(check)
			category_checks[entry.category] = check
		var card := Button.new()
		card.custom_minimum_size = CARD_SIZE
		card.toggle_mode = true
		card.button_pressed = entry.large_id == selected_id
		card.tooltip_text = "%03d — %s\n%s" % [ScurkEditorRules.object_tile_id(entry.large_id), entry.title, entry.category]
		grid.add_child(card)
		var graphic := TextureRect.new()
		graphic.texture = artwork.call(entry.large_id)
		graphic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		graphic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		graphic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		graphic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(graphic)
		graphic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		graphic.offset_left = 12
		graphic.offset_top = 12
		graphic.offset_right = -12
		graphic.offset_bottom = -12
		card.pressed.connect(_choose.bind(entry.large_id))
		card.focus_entered.connect(func() -> void: scroll.ensure_control_visible(card))
		cards.append(card)
	_filter_cards()
	popup_centered_clamped(Vector2i(1040, 760), 0.9)
	_resize_grid()
	search.grab_focus()


func _filter_cards() -> void:
	var query := search.text.strip_edges().to_lower()
	var count := 0
	for index in entries.size():
		var entry := entries[index]
		var searchable := "%03d %s %s" % [ScurkEditorRules.object_tile_id(entry.large_id), entry.title, entry.category]
		cards[index].visible = category_checks[entry.category].button_pressed and (query.is_empty() or searchable.to_lower().contains(query))
		if cards[index].visible:
			count += 1
	results.text = tr("%d tiles") % count if count > 0 else "No matching tiles"
	scroll.scroll_vertical = 0


func _resize_grid() -> void:
	var gap := grid.get_theme_constant("h_separation")
	var available := scroll.size.x - scroll.get_v_scroll_bar().size.x
	grid.columns = maxi(1, floori((available + gap) / (CARD_SIZE.x + gap)))


func _choose(large_id: int) -> void:
	hide()
	tile_selected.emit(large_id)
