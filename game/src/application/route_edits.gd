class_name ApplicationRouteEdits
extends RefCounted


const Tunnels = preload("res://src/tools/city/tunnel_command.gd")
const Highways = preload("res://src/tools/city/highway_command.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func apply_tunnel_selection(
	start: Vector2i,
	confirmation_choice := Tunnels.CONFIRMATION_UNSELECTED,
	free_mode := false
) -> void:
	var tunnel := Tunnels.apply(
		app.document_state.city,
		app.tool_state.selected_group,
		app.tool_state.selected_subtool,
		start,
		confirmation_choice,
		free_mode
	)

	if tunnel.confirmation_required:
		if free_mode:
			apply_tunnel_selection(
				start, Tunnels.CONFIRMATION_CONFIRMED, true
			)

			return

		app.tool_state.pending_tunnel_request = ToolState.TunnelRequest.new(
			start, app.tool_state.selected_group, app.tool_state.selected_subtool
		)
		var message := (
			"Engineers report that tunnel construction costs will be $%s.\n"
			+ "Do you wish to construct the tunnel?"
		) % app.interface.format_number(tunnel.cost)
		app.city_dialogs.tunnel_dialog.show_message(message)

		return

	if tunnel.cancelled:
		app.effects_audio.play_tool_failure_sound(
			app.tool_state.selected_group, app.tool_state.selected_subtool, "cancelled", free_mode
		)
		app.status_label.theme_type_variation = ""
		app.status_label.text = "Tunnel construction canceled. No action was taken."

		return

	if not tunnel.ok:
		app.effects_audio.play_tool_failure_sound(
			app.tool_state.selected_group,
			app.tool_state.selected_subtool,
			tunnel.error,
			free_mode,
		)
		app.interface.show_error("Cannot build tunnel: %s" % tunnel.error)

		return

	var scurk_tool := (
		app.scurk_place_print.selected_edit_tool()
		if free_mode and app.scurk_place_print != null else null
	)
	app.scurk_workspace.record_edit_command(
		tunnel, free_mode, scurk_tool.name if scurk_tool != null else "Tunnel"
	)
	app.interface.refresh_details()
	app.static_render.refresh_after_city_edit(tunnel)
	app.effects_audio.play_tool_success_sound(app.tool_state.selected_group, app.tool_state.selected_subtool, free_mode)
	app.status_label.theme_type_variation = ""
	app.status_label.text = "Built a %d-tile tunnel for $%s." % [
		tunnel.points.size(), app.interface.format_number(tunnel.cost)
	]


func confirm_tunnel() -> void:
	_apply_pending_tunnel(Tunnels.CONFIRMATION_CONFIRMED)


func cancel_tunnel() -> void:
	_apply_pending_tunnel(Tunnels.CONFIRMATION_CANCELLED)


func _apply_pending_tunnel(confirmation_choice: int) -> void:
	if app.tool_state.pending_tunnel_request == null:
		return

	var request := app.tool_state.pending_tunnel_request
	app.tool_state.pending_tunnel_request = null
	app.city_dialogs.tunnel_dialog.hide()
	app.tool_state.selected_group = int(request.group_index)
	app.tool_state.selected_subtool = int(request.subtool_index)
	apply_tunnel_selection(request.start, confirmation_choice)


func apply_highway_selection(
	start: Vector2i,
	finish: Vector2i,
	connection_choice := Highways.CONNECTION_UNSELECTED,
	bridge_type := Highways.BRIDGE_UNSELECTED,
	free_mode := false
) -> void:
	var highway := Highways.apply(
		app.document_state.city,
		app.tool_state.selected_group,
		app.tool_state.selected_subtool,
		start,
		finish,
		connection_choice,
		bridge_type,
		free_mode
	)

	if highway.bridge_selection_required:
		app.network_edits.open_bridge_dialog(
			start,
			finish,
			app.tool_state.selected_group,
			app.tool_state.selected_subtool,
			highway,
			"highway",
			free_mode
		)

		return

	if highway.cancelled:
		app.effects_audio.play_tool_failure_sound(
			app.tool_state.selected_group, app.tool_state.selected_subtool, "cancelled", free_mode
		)
		app.status_label.theme_type_variation = ""
		app.status_label.text = "Bridge selection canceled. No action was taken."

		return

	if highway.connection_selection_required:
		app.tool_state.pending_highway_connection = ToolState.ConnectionRequest.new(
			start, finish, app.tool_state.selected_group, app.tool_state.selected_subtool, bridge_type, free_mode
		)
		var message := (
			(
				"Build a highway connection to a neighboring city?\n"
				+ "The highway and connection are free in Place & Print."
			)
			if free_mode
			else (
				"Build a highway connection to a neighboring city for $%s?\n"
				+ "The %d-section highway costs $%s and remains if you cancel."
			) % [
				app.interface.format_number(highway.connection_cost),
				highway.sections.size(),
				app.interface.format_number(highway.route_cost),
			]
		)
		app.city_dialogs.highway_connection_dialog.show_message(message)

		return

	if not highway.ok:
		app.effects_audio.play_tool_failure_sound(
			app.tool_state.selected_group,
			app.tool_state.selected_subtool,
			highway.error,
			free_mode,
		)
		app.interface.show_error("Cannot build highway: %s" % highway.error)

		return

	app.scurk_workspace.record_edit_command(highway, free_mode, "Highway")
	app.interface.refresh_details()
	app.static_render.refresh_after_city_edit(highway)
	app.effects_audio.play_tool_success_sound(app.tool_state.selected_group, app.tool_state.selected_subtool, free_mode)
	app.status_label.theme_type_variation = ""

	if highway.bridge_count > 1:
		app.status_label.text = ("Built %d highway sections and %d bridges for $%s."
				% [highway.sections.size(), highway.bridge_count, app.interface.format_number(highway.cost)])
	elif highway.bridge_built:
		if highway.sections.is_empty():
			app.status_label.text = "Built a %s across %d water sections for $%s." % [
				highway.bridge_name,
				highway.bridge_span_length,
				app.interface.format_number(highway.cost),
			]
		else:
			app.status_label.text = "Built %d highway sections and a %s across %d water sections for $%s." % [
				highway.sections.size(),
				highway.bridge_name,
				highway.bridge_span_length,
				app.interface.format_number(highway.cost),
			]
	elif highway.connection_built:
		app.status_label.text = "Built %d highway sections and a neighboring-city connection for $%s." % [
			highway.sections.size(), app.interface.format_number(highway.cost)
		]
	else:
		app.status_label.text = "Built %d highway sections for $%s." % [
			highway.sections.size(), app.interface.format_number(highway.cost)
		]

		if highway.connection_cancelled:
			app.status_label.text += " The neighbor connection was canceled."
		elif highway.bridge_cancelled:
			app.status_label.text += " The bridge selection was canceled."
		elif not highway.bridge_error.is_empty():
			app.status_label.text += " The bridge was not built: %s." % highway.bridge_error
		elif not highway.connection_error.is_empty():
			app.status_label.text += " The connection was not offered because funds are too low."
		elif highway.stopped_early:
			app.status_label.text += " The route stopped at an obstruction."

	if not highway.continuation_error.is_empty():
		app.status_label.text += " Route stopped: %s." % highway.continuation_error
	elif highway.bridge_built and highway.stopped_early:
		app.status_label.text += " The route stopped at an obstruction."


func confirm_highway_connection() -> void:
	_apply_pending_highway_connection(Highways.CONNECTION_CONFIRMED)


func cancel_highway_connection() -> void:
	_apply_pending_highway_connection(Highways.CONNECTION_CANCELLED)


func _apply_pending_highway_connection(connection_choice: int) -> void:
	if app.tool_state.pending_highway_connection == null:
		return

	var request := app.tool_state.pending_highway_connection
	app.tool_state.pending_highway_connection = null
	app.city_dialogs.highway_connection_dialog.hide()
	app.tool_state.selected_group = int(request.group_index)
	app.tool_state.selected_subtool = int(request.subtool_index)
	apply_highway_selection(
		request.start,
		request.finish,
		connection_choice,
		request.bridge_type,
		request.free_mode
	)
