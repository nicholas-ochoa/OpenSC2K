class_name ApplicationBudget
extends RefCounted


const ToolSounds = preload("res://src/audio/tool_sound_rules.gd")
const Budget = preload("res://src/simulation/economy/budget_phase.gd")
const Bonds = preload("res://src/simulation/economy/bond_command.gd")
const Music = preload("res://src/audio/music_director.gd")

var app: CityApplication


func _init(application: CityApplication) -> void:
	app = application


func open_manual_budget() -> void:
	if app.tool_state.landscape_editor:
		return

	if app.document_state.city == null:
		return

	open_budget_dialog(Budget.funding_values(app.document_state.city), false)


func open_budget_dialog(values: PackedInt32Array, annual: bool) -> void:
	if app.document_state.city == null or values.size() != Budget.BUDGET_COUNT:
		app.interface.show_error("Cannot open the budget because its saved values are invalid.")

		return

	if app.document_state.city.music_enabled() and app.simulation_state.simulation_engine != null:
		app.effects_audio.play_music_track(Music.budget_track(app.simulation_state.simulation_engine.lfsr_random))

	app.simulation_state.annual_budget_pending = annual
	app.budget_dialog.open_budget(
		values,
		annual,
		app.document_state.city.document.misc_u32(Budget.MISC_AUTO_BUDGET) != 0,
	)
	_update_bond_controls()


func request_issue_bond() -> void:
	if app.document_state.city == null:
		return

	var result := Bonds.issue(app.document_state.city)

	if not result.ok:
		app.interface.show_error("Cannot issue a bond: %s" % result.error)

		return

	_update_bond_controls()

	match result.status:
		"confirmation_required":
			app.budget_dialog.open_bond_confirmation("issue", int(result.rate))
		"credit_denied":
			app.interface.show_error(
				"Sorry, your city may not issue more bonds\nuntil your credit rating improves."
			)
		"maximum_bonds":
			app.interface.show_error("The City Council believes that 50 outstanding bonds are enough.")
		_:
			app.interface.show_error("The bond could not be issued.")


func request_repay_bond() -> void:
	if app.document_state.city == null:
		return

	var result := Bonds.repay(app.document_state.city)

	if not result.ok:
		app.interface.show_error("Cannot repay a bond: %s" % result.error)

		return

	match result.status:
		"confirmation_required":
			app.budget_dialog.open_bond_confirmation("repay", int(result.rate))
		"insufficient_funds":
			app.interface.show_error("You Need $10,000 Cash\nto Repay an Outstanding Bond.")
		"no_bonds":
			app.interface.show_error("There are no outstanding bonds to repay.")
		_:
			app.interface.show_error("The bond could not be repaid.")


func resolve_bond_action(action: String, confirmed: bool) -> void:
	if app.document_state.city == null or action.is_empty():
		return

	var confirmation := (
		Bonds.CONFIRMATION_CONFIRMED
		if confirmed
		else Bonds.CONFIRMATION_CANCELLED
	)
	var result := (
		Bonds.issue(app.document_state.city, confirmation)
		if action == "issue"
		else Bonds.repay(app.document_state.city, confirmation)
	)

	if not result.ok:
		app.interface.show_error("Cannot update bonds: %s" % result.error)

		return

	_update_bond_controls()
	app.interface.refresh_details()
	app.status_label.theme_type_variation = ""

	match result.status:
		"issued":
			app.status_label.text = "Issued a $10,000 bond at %d%%." % int(result.rate)
		"repaid":
			app.status_label.text = "Repaid the oldest $10,000 bond at %d%%." % int(result.rate)
		"cancelled":
			app.status_label.text = "Bond action canceled. No bond balance changed."
		"credit_denied":
			app.interface.show_error(
				"Sorry, your city may not issue more bonds\nuntil your credit rating improves."
			)
		"maximum_bonds":
			app.interface.show_error("The City Council believes that 50 outstanding bonds are enough.")
		_:
			app.interface.show_error("The bond action did not complete.")


func _update_bond_controls() -> void:
	if app.document_state.city == null or app.budget_dialog == null:
		return

	var bond_count := app.document_state.city.document.misc_u32(Bonds.MISC_BONDS)
	var funds := app.document_state.city.funds()
	var average_fixed := app.document_state.city.document.misc_i32(
		Budget.MISC_BUDGETS
		+ Budget.BUDGET_BONDS * Budget.BUDGET_RECORD_SIZE
		+ Budget.BUDGET_FUNDING
	)
	var oldest := app.document_state.city.document.misc_u32(Bonds.MISC_BOND_RATES) & 0xffff
	app.budget_dialog.set_bond_state(bond_count, funds, average_fixed, oldest)


func commit_budget() -> void:
	if app.document_state.city == null:
		return

	var values := app.budget_dialog.funding_values()
	var auto_budget := app.budget_dialog.auto_budget_enabled()

	if app.simulation_state.annual_budget_pending:
		var result := app.simulation_state.speed_controller.resolve_annual_budget(values, auto_budget)

		if not result.ok:
			app.interface.show_error("Cannot apply the annual budget: %s" % result.error)
			call_deferred("_restore_annual_budget_dialog")

			return

		app.simulation_state.annual_budget_pending = false
		app.frame.consume_simulation_result(result)
		app.interface.refresh_details()
		app.status_label.theme_type_variation = ""
		app.status_label.text = "Annual budget applied. The simulation can continue."

		return

	var stored := Budget.set_funding(app.document_state.city, values, auto_budget)

	if not stored.ok:
		app.interface.show_error("Cannot save the budget: %s" % stored.error)

		return

	app.status_label.theme_type_variation = ""
	app.status_label.text = "Budget funding saved."


func cancel_budget() -> void:
	if app.simulation_state.annual_budget_pending:
		commit_budget()


func _restore_annual_budget_dialog() -> void:
	if app.simulation_state.annual_budget_pending:
		app.budget_dialog.popup_centered()


func open_military_proposal() -> void:
	app.simulation_state.military_proposal_pending = true
	app.military_dialog.popup_centered()


func accept_military_proposal() -> void:
	_resolve_military_proposal(true)


func decline_military_proposal() -> void:
	_resolve_military_proposal(false)


func _resolve_military_proposal(accepted: bool) -> void:
	if not app.simulation_state.military_proposal_pending or app.simulation_state.speed_controller == null:
		return

	var result := app.simulation_state.speed_controller.resolve_military_proposal(accepted)

	if not result.ok:
		app.interface.show_error("Cannot resolve the military proposal: %s" % result.error)
		call_deferred("_restore_military_proposal_dialog")

		return

	app.simulation_state.military_proposal_pending = false
	app.frame.consume_simulation_result(result)
	app.interface.refresh_details()
	app.status_label.theme_type_variation = ""
	var proposal: MilitaryProposalPhase.Result = result.day_results[0].phase_results.military_proposal

	if proposal.base_type in [2, 3, 4, 5]:
		app.effects_audio.play_sound_events(ToolSounds.zone_success_events(7))

	match proposal.base_type:
		2:
			app.status_label.text = "The Army base site is reserved."
		3:
			app.status_label.text = "The Air Force base site is reserved."
		4:
			app.status_label.text = "The Navy base site is reserved."
		5:
			app.status_label.text = "The missile silo sites are reserved."
		_:
			app.status_label.text = (
				"The military proposal was declined."
				if not accepted
				else "The military could not find a suitable site."
			)


func _restore_military_proposal_dialog() -> void:
	if app.simulation_state.military_proposal_pending:
		app.military_dialog.popup_centered()


func open_scenario_intro(scenario: ScenarioState) -> void:
	var rendered_picture := ScenarioGraphics.render(scenario, app.asset_state.scenario_palette, app.asset_state.scenario_graphics)
	var picture: Image = rendered_picture.image if rendered_picture.ok else null
	var name := app.document_state.city.city_name()

	if name.is_empty():
		name = app.document_state.current_document.source_path.get_file().get_basename()

	app.status_label.theme_type_variation = ""
	app.status_label.text = "Review the scenario briefing before the simulation starts."
	app.scenario_dialog.show_briefing(name, picture, scenario.opening_description())


func begin_scenario() -> void:
	app.status_label.theme_type_variation = ""
	app.status_label.text = "Scenario started."
