class_name ApplicationNetworkEdits
extends RefCounted


const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const Networks = preload("res://src/tools/city/network_command.gd")
const Highways = preload("res://src/tools/city/highway_command.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func apply_network_selection(
	start: Vector2i,
	finish: Vector2i,
	bridge_type := Networks.BRIDGE_UNSELECTED,
	group_index := -1,
	subtool_index := -1,
	connection_choice := Networks.CONNECTION_UNSELECTED,
	free_mode := false
) -> void:
	if group_index < 0:
		group_index = app.tool_state.selected_group

	if subtool_index < 0:
		subtool_index = app.tool_state.selected_subtool

	var tool_name: String = Tools.tool(group_index, subtool_index).name
	var network := Networks.apply(
		app.document_state.city,
		group_index,
		subtool_index,
		start,
		finish,
		bridge_type,
		connection_choice,
		free_mode
	)

	if network.bridge_selection_required:
		open_bridge_dialog(
			start,
			finish,
			group_index,
			subtool_index,
			network,
			"network",
			free_mode
		)

		return

	if network.cancelled:
		app.effects_audio.play_tool_failure_sound(group_index, subtool_index, "cancelled", free_mode)
		app.status_label.theme_type_variation = ""
		app.status_label.text = "Bridge selection canceled. No action was taken."

		return

	if network.connection_selection_required:
		app.tool_state.pending_network_connection = ToolState.ConnectionRequest.new(
			start, finish, group_index, subtool_index, bridge_type, free_mode
		)
		var message := (
			(
				"Build a %s connection to a neighboring city?\n"
				+ "The route and connection are free in Place & Print."
			) % tool_name.to_lower()
			if free_mode
			else (
				"Build a %s connection to a neighboring city for $%s?\n"
				+ "The %d-tile route costs $%s and remains if you cancel."
			) % [
				tool_name.to_lower(),
				app.interface.format_number(network.connection_cost),
				network.dry_points.size(),
				app.interface.format_number(network.dry_cost),
			]
		)
		app.city_dialogs.network_connection_dialog.show_message(message, "Keep %s" % tool_name)

		return

	if not network.ok:
		app.effects_audio.play_tool_failure_sound(
			group_index,
			subtool_index,
			network.error,
			free_mode,
		)
		app.interface.show_error(
			"Cannot build %s: %s"
			% [tool_name, network.error]
		)

		return

	app.scurk_workspace.record_edit_command(network, free_mode, tool_name)
	app.interface.refresh_details()
	app.static_render.refresh_after_city_edit(network)
	app.effects_audio.play_tool_success_sound(group_index, subtool_index, free_mode)
	app.status_label.theme_type_variation = ""
	var dry_count := network.dry_points.size()

	if network.bridge_count > 1:
		app.status_label.text = ("Built %d %s tiles and %d bridges for $%s."
				% [dry_count, tool_name, network.bridge_count, app.interface.format_number(int(network.cost))])
	elif network.bridge_built:
		if dry_count > 0:
			app.status_label.text = "Built %d %s tiles and a %s across %d water tiles for $%s." % [
				dry_count,
				tool_name,
				network.bridge_name,
				network.bridge_span_length,
				app.interface.format_number(network.cost),
			]
		else:
			app.status_label.text = "Built a %s across %d water tiles for $%s." % [
				network.bridge_name,
				network.bridge_span_length,
				app.interface.format_number(network.cost),
			]
	elif network.connection_built:
		app.status_label.text = "Built %d %s tiles and a neighboring-city connection for $%s." % [
			dry_count,
			tool_name,
			app.interface.format_number(network.cost),
		]
	else:
		app.status_label.text = "Built %d %s tiles for $%s." % [
			dry_count, tool_name, app.interface.format_number(network.cost)
		]

		if network.bridge_cancelled:
			app.status_label.text += " Bridge selection was canceled."
		elif network.connection_cancelled:
			app.status_label.text += " The neighbor connection was canceled."
		elif not network.bridge_error.is_empty():
			app.status_label.text += " The bridge was not built: %s." % network.bridge_error
		elif not network.connection_error.is_empty():
			app.status_label.text += " The connection was not offered because funds are too low."
		elif network.stopped_early:
			app.status_label.text += " The route stopped at an obstruction."

	if not network.continuation_error.is_empty():
		app.status_label.text += " Route stopped: %s." % network.continuation_error
	elif network.bridge_built and network.stopped_early:
		app.status_label.text += " The route stopped at an obstruction."


func confirm_network_connection() -> void:
	_apply_pending_network_connection(Networks.CONNECTION_CONFIRMED)


func cancel_network_connection() -> void:
	_apply_pending_network_connection(Networks.CONNECTION_CANCELLED)


func _apply_pending_network_connection(connection_choice: int) -> void:
	if app.tool_state.pending_network_connection == null:
		return

	var request := app.tool_state.pending_network_connection
	app.tool_state.pending_network_connection = null
	app.city_dialogs.network_connection_dialog.hide()
	app.tool_state.selected_group = int(request.group_index)
	app.tool_state.selected_subtool = int(request.subtool_index)
	apply_network_selection(
		request.start,
		request.finish,
		int(request.bridge_type),
		int(request.group_index),
		int(request.subtool_index),
		connection_choice,
		request.free_mode
	)


func open_bridge_dialog(
	start: Vector2i,
	finish: Vector2i,
	group_index: int,
	subtool_index: int,
	result: RouteEditResult,
	request_type := "network",
	free_mode := false
) -> void:
	var request := ToolState.BridgeRequest.new()
	request.start = start
	request.finish = finish
	request.group_index = group_index
	request.subtool_index = subtool_index
	request.request_type = request_type
	request.free_mode = free_mode
	request.choices = result.bridge_choices
	# highways report their route as 2 by 2 sections
	request.dry_points = result.sections if request_type == "highway" else result.dry_points
	app.tool_state.pending_bridge_request = request
	var choices := request.choices
	app.city_dialogs.bridge_dialog.preview_palette = app.asset_state.palette
	app.city_dialogs.bridge_dialog.preview_sprites = app.asset_state.large_sprites
	app.city_dialogs.bridge_dialog.show_choices(
		result.bridge_span_length,
		request_type,
		choices,
		free_mode,
	)


func choose_bridge(choice_index: int) -> void:
	if app.tool_state.pending_bridge_request == null:
		return

	var request := app.tool_state.pending_bridge_request.copy()
	var choices := request.choices

	if choice_index < 0 or choice_index >= choices.size():
		return

	var choice: BridgeChoice = choices[choice_index]
	app.tool_state.pending_bridge_request = null
	app.city_dialogs.bridge_dialog.hide()

	if request.request_type == "highway":
		app.tool_state.selected_group = int(request.group_index)
		app.tool_state.selected_subtool = int(request.subtool_index)
		app.route_edits.apply_highway_selection(
			request.start,
			request.finish,
			Highways.CONNECTION_UNSELECTED,
			choice.type,
			request.free_mode
		)

		return

	apply_network_selection(
		request.start,
		request.finish,
		choice.type,
		int(request.group_index),
		int(request.subtool_index),
		Networks.CONNECTION_UNSELECTED,
		request.free_mode
	)


func cancel_bridge() -> void:
	if app.tool_state.pending_bridge_request == null:
		return

	var request := app.tool_state.pending_bridge_request.copy()
	app.tool_state.pending_bridge_request = null

	if request.dry_points.is_empty():
		app.effects_audio.play_tool_failure_sound(
			int(request.group_index),
			int(request.subtool_index),
			"cancelled",
			request.free_mode,
		)
		app.status_label.theme_type_variation = ""
		app.status_label.text = "Bridge selection canceled. No action was taken."

		return

	if request.request_type == "highway":
		app.tool_state.selected_group = int(request.group_index)
		app.tool_state.selected_subtool = int(request.subtool_index)
		app.route_edits.apply_highway_selection(
			request.start,
			request.finish,
			Highways.CONNECTION_UNSELECTED,
			Highways.BRIDGE_CANCELLED,
			request.free_mode
		)

		return

	apply_network_selection(
		request.start,
		request.finish,
		Networks.BRIDGE_CANCELLED,
		int(request.group_index),
		int(request.subtool_index),
		Networks.CONNECTION_UNSELECTED,
		request.free_mode
	)
