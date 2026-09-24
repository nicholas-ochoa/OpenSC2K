extends SceneTree
## A bought neighbor connection changes the engine connection count, as in the
## original. Undo and SCURK undo and redo reverse it. The demand rescan stays.

const Networks = preload("res://src/tools/city/network_command.gd")
const Highways = preload("res://src/tools/city/highway_command.gd")

var main: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	preload("res://tests/support/app_fixture.gd").configure(main, true)
	root.add_child(main)
	await process_frame
	main.set_process(false)
	main.main_menu.city_background.set_process(false)
	main.main_menu.hide()
	assert(main.city_session.activate_document(EmptyCityTemplate.create(128)))
	main.scurk_place_print = main.main_overlays.ensure_scurk_place_print()
	var engine: SimulationEngine = main.simulation_state.simulation_engine
	assert(engine.commerce_connections == 0 and engine.industry_connections == 0)

	main.network_edits.apply_network_selection(Vector2i(124, 40), Vector2i(127, 40), Networks.BRIDGE_UNSELECTED, 6, 0,
		Networks.CONNECTION_CONFIRMED)
	assert(main.document_state.city.text_overlay_id(127, 40) == 0xfa)
	assert(engine.commerce_connections == 1 and engine.industry_connections == 0, "A road connection adds commerce")
	assert(RciDemandPhase.connection_counts(main.document_state.city).commerce == 1, "The demand rescan finds the same connection")
	main.city_edits.undo_last_edit()
	assert(engine.commerce_connections == 0, "Undo removes the road connection count")

	main.tool_state.selected_group = 6
	main.tool_state.selected_subtool = 1
	main.route_edits.apply_highway_selection(Vector2i(120, 10), Vector2i(126, 10), Highways.CONNECTION_CONFIRMED)
	assert(engine.industry_connections == 1 and engine.commerce_connections == 0, "A highway connection adds industry")
	main.city_edits.undo_last_edit()
	assert(engine.industry_connections == 0, "Undo removes the highway connection count")

	main.network_edits.apply_network_selection(Vector2i(3, 42), Vector2i(0, 42), Networks.BRIDGE_UNSELECTED, 7, 0,
		Networks.CONNECTION_CONFIRMED, true)
	assert(engine.industry_connections == 1, "A free Place & Print rail connection adds industry")
	main.scurk_workspace.undo_scurk_place()
	assert(engine.industry_connections == 0, "SCURK undo removes the rail connection count")
	main.scurk_workspace._redo_scurk_place()
	assert(engine.industry_connections == 1, "SCURK redo adds the rail connection count again")

	# stop the tool sounds so their playback does not outlive the scene
	main.effects_audio.stop_sound_effects()
	main.queue_free()
	await process_frame
	print("PASS: bought neighbor connections change the engine connection counts")
	quit()
