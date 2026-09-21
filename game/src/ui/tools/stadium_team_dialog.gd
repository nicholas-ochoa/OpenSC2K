class_name StadiumTeamDialog
extends ConfirmationDialog

class Team extends RefCounted:
	var id: int
	var name: String

	func _init(team_id: int, team_name: String) -> void:
		id = team_id
		name = team_name


var team_selector: OptionButton
var name_input: LineEdit


func _ready() -> void:
	hide()
	theme = AppUiTheme.current()
	team_selector = $Fields/TeamSelector
	name_input = $Fields/NameInput
	team_selector.item_selected.connect(_select_team)


func set_teams(teams: Array[Team]) -> void:
	team_selector.clear()

	for team in teams:
		team_selector.add_item(team.name, team.id)

	if not teams.is_empty():
		team_selector.select(0)
		_select_team(0)


func show_teams(teams: Array[Team]) -> void:
	set_teams(teams)
	popup_centered()
	name_input.grab_focus()
	name_input.select_all()


func selected_team_id() -> int:
	var selected := team_selector.selected

	return team_selector.get_item_id(selected) if selected >= 0 else -1


func entered_name() -> String:
	return name_input.text


func _select_team(item_index: int) -> void:
	if item_index < 0 or item_index >= team_selector.item_count:
		return

	name_input.text = team_selector.get_item_text(item_index)
	name_input.select_all()
