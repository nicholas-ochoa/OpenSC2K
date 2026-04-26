extends "res://tests/support/scene_case.gd"

const DIALOG_SCENES := [
	"res://src/ui/city_windows/budget_dialog.tscn",
	"res://src/ui/city_windows/city_analysis_dialog.tscn",
	"res://src/ui/city_windows/city_graph_window.tscn",
	"res://src/ui/city_windows/city_industry_window.tscn",
	"res://src/ui/city_windows/city_map_window.tscn",
	"res://src/ui/city_windows/city_ordinance_window.tscn",
	"res://src/ui/city_windows/city_population_window.tscn",
	"res://src/ui/city_windows/city_simnation_window.tscn",
	"res://src/ui/scurk/scurk_editor_control.tscn",
	"res://src/ui/scurk/scurk_pick_copy_control.tscn",
	"res://src/ui/scurk/scurk_place_print_control.tscn",
	"res://src/ui/scurk/scurk_print_control.tscn",
	"res://src/ui/settings/about_dialog.tscn",
	"res://src/ui/settings/app_settings_dialog.tscn",
	"res://src/ui/shared/picture_notice_dialog.tscn",
	"res://src/ui/startup/new_city_terrain_dialog.tscn",
	"res://src/ui/startup/scenario_intro_dialog.tscn",
	"res://src/ui/tools/bridge_selection_dialog.tscn",
	"res://src/ui/tools/city_query_dialog.tscn",
	"res://src/ui/tools/city_sign_dialog.tscn",
	"res://src/ui/tools/stadium_team_dialog.tscn",
	"res://src/ui/tools/tool_choice_dialog.tscn",
]


func run() -> void:
	for path in DIALOG_SCENES:
		var scene := load(path) as PackedScene
		var dialog := scene.instantiate()
		root.add_child(dialog)
		assert(not dialog.visible, "Dialog visible at startup: " + path)
		dialog.queue_free()
		await process_frame
	print("PASS: All dialog scenes start closed at runtime")
