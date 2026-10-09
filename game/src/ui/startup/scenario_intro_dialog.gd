class_name ScenarioIntroDialog
extends AcceptDialog

var picture_view: TextureRect
var text_view: Label
var text_scroll: ScrollContainer
var progress_heading: Label
var progress_grid: GridContainer
var starts_scenario := true


func _ready() -> void:
	hide()
	theme = AppUiTheme.current()
	get_label().visible = false
	picture_view = $Layout/PictureFrame/Picture
	text_scroll = $Layout/TextScroll
	text_view = $Layout/TextScroll/Content/Text
	progress_heading = $Layout/TextScroll/Content/ProgressHeading
	progress_grid = $Layout/TextScroll/Content/Progress


func set_briefing(scenario_name: String, picture: Image, description: String) -> void:
	title = tr("Scenario: %s") % scenario_name
	picture_view.texture = (
		PixelArtTexture.wrap(ImageTexture.create_from_image(picture)) if picture != null else null
	)
	var briefing := OriginalTextLocalization.scenario(description)
	text_view.text = briefing.trim_prefix("Extended Description:").strip_edges()
	text_scroll.scroll_vertical = 0


func show_briefing(
	scenario_name: String, picture: Image, description: String, starting := true
) -> void:
	starts_scenario = starting
	ok_button_text = tr("Begin Scenario") if starting else tr("OK")
	set_briefing(scenario_name, picture, description)

	if starting:
		set_progress("", [])

	popup_centered(min_size)


# The goals with their current values, as the sc2kfix scenario status window
# shows them. An empty heading hides the section.
func set_progress(heading: String, rows: Array[ScenarioState.ProgressRow]) -> void:
	progress_heading.text = heading
	progress_heading.visible = not heading.is_empty()
	progress_grid.visible = not heading.is_empty() and not rows.is_empty()

	for child in progress_grid.get_children():
		progress_grid.remove_child(child)
		child.queue_free()

	if not progress_grid.visible:
		return

	for text in ["Goal", "Target", "Now", ""]:
		progress_grid.add_child(_cell(text, true))

	for row in rows:
		progress_grid.add_child(_cell(row.label))
		progress_grid.add_child(_cell(row.requirement))
		progress_grid.add_child(_cell(row.current))
		progress_grid.add_child(_cell("Met" if row.met else "Not met"))


func _cell(text: String, heading := false) -> Label:
	var label := Label.new()
	label.text = text

	if heading:
		label.theme_type_variation = "HeaderSmall"

	return label
