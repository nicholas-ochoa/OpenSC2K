extends "res://tests/support/core_test_suite.gd"

## Tools: catalog checks.

@warning_ignore_start("integer_division")

const Power = preload("res://src/simulation/infrastructure/power_phase.gd")
const Bonds = preload("res://src/simulation/economy/bond_command.gd")
const Transport = preload("res://src/simulation/infrastructure/transport_trip.gd")
const Tools = preload("res://src/tools/shared/tool_catalog.gd")
const ToolAvailability = preload("res://src/tools/shared/tool_availability.gd")
const ToolEditState = preload("res://src/tools/shared/tool_edit_state.gd")
const Dispatch = preload("res://src/tools/city/dispatch_command.gd")


func test_tool_catalog() -> void:
	_check(Tools.GROUPS.size() == 18, "Tool catalog has all eighteen original groups")
	_check(Tools.all_tools().size() == 76, "Tool catalog retains original entries, Cancel Dispatch, five editor tools, and Trip Query")
	var coal := Tools.tool(3, 2)
	_check(coal.cost == 4000 and coal.area == 4, "Coal plant uses the executable cost and area")
	var coal_details := Tools.power_plant_details(2)
	_check(
		coal_details.output_mw == 200
		and coal_details.grid_capacity.contains("44")
		and coal_details.pollution == 50
		and coal_details.service_life.contains("50"),
		"Coal plant details expose output, grid capacity, pollution, and service life",
	)
	var hydro_details := Tools.power_plant_details(3)
	_check(
		hydro_details.output_mw == 20
		and hydro_details.grid_capacity.contains("40"),
		"Hydroelectric details expose its output and grid capacity",
	)
	var wind_details := Tools.power_plant_details(7)
	_check(
		wind_details.output_mw == 4,
		"Wind details expose its rated power output",
	)
	_check(
		Tools.power_plant_details(1) == null,
		"Power-plant details reject the retired chooser entry",
	)
	var road := Tools.tool(6, 0)
	_check(road.cost == 10 and road.area == 1, "Road uses the executable cost and area")
	var college := Tools.tool(12, 1)
	_check(college.cost == 1000 and college.area == 4, "College uses the executable cost and area")
	var prison := Tools.tool(13, 3)
	_check(prison.cost == 3000 and prison.area == 4, "Prison uses the executable cost and area")
	var marina := Tools.tool(14, 4)
	_check(marina.cost == 1000 and marina.area == 3, "Marina uses the executable cost and area")
	_check(Tools.tool(-1, 0) == null, "Tool catalog rejects an invalid group")
	_check(Tools.tool(0, 12) == null, "Tool catalog rejects an invalid subtool")


func test_tool_availability(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	_check(document.set_misc_u32(ToolAvailability.MISC_PROGRESSION, 0), "Tool availability fixture clears progression")
	_check(document.set_misc_u32(ToolAvailability.MISC_GRANTED_REWARDS, 0), "Tool availability fixture clears rewards")
	_check(document.set_misc_u32(ToolAvailability.MISC_ORDINANCES, 0), "Tool availability fixture clears ordinances")

	for invention_index in ToolAvailability.INVENTION_COUNT:
		_check(
			document.set_misc_u32(
				ToolAvailability.MISC_INVENTION_YEARS + invention_index * 4,
				2100,
			),
			"Tool availability fixture schedules invention %d" % invention_index,
		)

	var city := CityModel.from_document(document)
	var base := ToolAvailability.inspect(city)
	_check(base.ok, "Tool availability reads the saved MISC state: %s" % base.error)

	if not base.ok:
		return

	_check(
		base.group_masks == PackedInt32Array([
			0x1f, 0x03, 0x03, 0x03, 0x07, 0x00,
			0x05, 0x05, 0x01, 0x03, 0x03, 0x03,
			0x0f, 0x0f, 0x1f, 0x00, 0x00, 0x00,
		]),
		"Tool availability starts from the executable group-mask table",
	)
	_check(base.power_plant_mask == 0x07, "Coal, hydro, and oil are the initial power choices")
	_check(
		ToolAvailability.is_available(city, 3, 2)
		and ToolAvailability.is_available(city, 3, 3)
		and ToolAvailability.is_available(city, 3, 4)
		and not ToolAvailability.is_available(city, 3, 5),
		"Initial power availability includes only the first three plants",
	)
	_check(
		ToolAvailability.is_available(city, 6, 0)
		and ToolAvailability.is_available(city, 6, 2)
		and not ToolAvailability.is_available(city, 6, 1)
		and not ToolAvailability.is_available(city, 6, 4),
		"Initial road availability includes road and tunnel only",
	)
	_check(
		ToolAvailability.is_available(city, 2, 2),
		"Dispatch selection stays available because live capacity controls dispatch",
	)
	var zone_edit_state := ToolEditState.normal(city, CityViewMode.Mode.CITY, 9, 0)
	var road_edit_state := ToolEditState.normal(city, CityViewMode.Mode.CITY, 6, 0)
	var building_edit_state := ToolEditState.normal(city, CityViewMode.Mode.CITY, 13, 3)
	_check(
		zone_edit_state.enabled
		and zone_edit_state.selection == "rectangle"
		and road_edit_state.enabled
		and road_edit_state.selection == "path"
		and building_edit_state.enabled
		and building_edit_state.selection == "point"
		and building_edit_state.area == 4,
		"Tool edit state classifies zone, route, and building input",
	)
	var underground_pipe_state := ToolEditState.normal(city, CityViewMode.Mode.UNDERGROUND, 4, 0)
	var underground_zone_state := ToolEditState.normal(city, CityViewMode.Mode.UNDERGROUND, 9, 0)
	_check(
		underground_pipe_state.enabled
		and underground_pipe_state.selection == "path"
		and not underground_zone_state.enabled,
		"Tool edit state limits underground input to supported tools",
	)
	var scurk_object_state := ToolEditState.scurk_object(city, CityViewMode.Mode.CITY, 0xcf)
	var scurk_zone_state := ToolEditState.scurk_tool(
		city, ScurkEditTool.new("Light Residential", 9, 0, 1, "city")
	)
	_check(
		scurk_object_state.enabled
		and scurk_object_state.area == 4
		and scurk_zone_state.enabled
		and scurk_zone_state.selection == "rectangle",
		"Tool edit state classifies SCURK object and edit modes",
	)
	_check(
		not ToolEditState.is_tool_chooser(5, 4)
		and not ToolEditState.is_tool_variant(5, 5)
		and not ToolEditState.is_tool_variant(5, 4),
		"Tool edit state owns reward chooser and variant rules",
	)

	for invention_index in range(12):
		_check(
			document.set_misc_u32(
				ToolAvailability.MISC_INVENTION_YEARS + invention_index * 4,
				0,
			),
			"Tool availability fixture releases invention %d" % invention_index,
		)

	var released := ToolAvailability.inspect(city)
	_check(released.power_plant_mask == 0x1ff, "The first six inventions unlock all later power plants")
	_check(
		released.group_masks[8] == 0x03
		and released.group_masks[6] == 0x1f
		and released.group_masks[7] == 0x1f
		and released.group_masks[4] == 0x1f,
		"Transport and water inventions extend their exact executable masks",
	)
	_check(document.set_misc_u32(ToolAvailability.MISC_ORDINANCES, ToolAvailability.ORDINANCE_NUCLEAR_FREE), "Tool availability fixture enacts Nuclear-Free Zone")
	_check(
		not ToolAvailability.is_available(city, 3, 6),
		"Nuclear-Free Zone hides an invented nuclear power plant",
	)

	_check(document.set_misc_u32(ToolAvailability.MISC_GRANTED_REWARDS, 0x05), "Tool availability fixture grants mayor house and statue")
	_check(document.set_misc_u32(ToolAvailability.MISC_PROGRESSION, 5), "Tool availability fixture stays below arcology progression")
	_check(document.set_misc_u32(ToolAvailability.MISC_INVENTION_YEARS + 12 * 4, 0), "Tool availability fixture releases one arcology")
	_check(
		ToolAvailability.is_available(city, 5, 0)
		and not ToolAvailability.is_available(city, 5, 1)
		and ToolAvailability.is_available(city, 5, 2)
		and not ToolAvailability.is_available(city, 5, 4),
		"Saved reward bits control the four one-use rewards",
	)
	_check(document.set_misc_u32(ToolAvailability.MISC_PROGRESSION, 6), "Tool availability fixture reaches arcology progression")
	_check(
		ToolAvailability.is_available(city, 5, 4)
		and ToolAvailability.is_available(city, 5, 5)
		and not ToolAvailability.is_available(city, 5, 6),
		"One released arcology enables the chooser and its first entry",
	)
	_check(document.set_misc_u32(ToolAvailability.MISC_INVENTION_YEARS + 15 * 4, 0), "Tool availability fixture releases a second arcology slot")
	_check(
		ToolAvailability.is_available(city, 5, 5)
		and ToolAvailability.is_available(city, 5, 6)
		and not ToolAvailability.is_available(city, 5, 7),
		"Arcology availability uses the original released-count behavior",
	)
	var misc: PackedByteArray = document.find_chunk("MISC").decoded_payload.duplicate()
	_check(ToolAvailability.rebuild_reward_mask(misc) == 0x15, "Availability rebuild preserves rewards and enables arcologies")


func test_bond_command(reference_root: String) -> void:
	var document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var city := CityModel.from_document(document)

	for tile_id in 256:
		_check(
			document.set_misc_i32(0x01f0 + tile_id * 4, 0),
			"Bond fixture clears tile count 0x%02X" % tile_id,
		)

	_check(document.set_misc_u32(0x0fe8, 0), "Bond fixture clears subway count")
	_check(city.set_funds(2000), "Bond fixture sets funds")
	_check(document.set_misc_u32(0x0018, 0), "Bond fixture clears bond count")
	_check(document.set_misc_i32(0x0024, 12345), "Bond fixture sets stale city value")
	_check(document.set_misc_u32(0x0058, 3), "Bond fixture sets federal rate")

	for rate_index in 50:
		_check(
			document.set_misc_u32(0x0610 + rate_index * 4, 0x77770000),
			"Bond fixture clears rate %d" % rate_index,
		)

	var invalid_before: PackedByteArray = document.find_chunk("MISC").decoded_payload.duplicate()
	var invalid := Bonds.issue(city, 2)
	_check(not invalid.ok, "Bond issue rejects an invalid confirmation choice")
	_check(
		document.find_chunk("MISC").decoded_payload == invalid_before,
		"Rejected bond confirmation preserves MISC",
	)

	var request := Bonds.issue(city)
	_check(
		request.ok and request.status == "confirmation_required"
		and request.confirmation_required and request.rate == 4,
		"Bond issue requests confirmation at federal rate plus one",
	)
	_check(document.misc_i32(0x0024) == 0, "Bond issue first rebuilds the city value")
	_check(city.funds() == 2000 and document.misc_u32(0x0018) == 0, "Bond prompt does not issue")
	var cancel_before: PackedByteArray = document.find_chunk("MISC").decoded_payload.duplicate()
	var cancelled := Bonds.issue(city, Bonds.CONFIRMATION_CANCELLED)
	_check(cancelled.ok and cancelled.status == "cancelled", "Bond issue can be declined")
	_check(
		document.find_chunk("MISC").decoded_payload == cancel_before,
		"Declined bond issue preserves the post-valuation MISC data",
	)

	var first := Bonds.issue(city, Bonds.CONFIRMATION_CONFIRMED)
	_check(first.ok and first.status == "issued" and first.changed, "Bond issue completes")
	_check(city.funds() == 12000 and document.misc_u32(0x0018) == 1, "Bond issue adds $10,000")
	_check(document.misc_u32(0x0610) == 4, "Bond issue appends the offered rate")
	_check(document.misc_i32(0x092c) == 1, "Bond issue updates the budget bond count")
	_check(document.misc_i32(0x0930) == 40000, "Bond issue updates the average rate")
	_check(document.misc_u32(0x0614) == 0, "Bond issue normalizes saved rate fields")

	_check(document.set_misc_u32(0x0058, 5), "Bond fixture changes federal rate")
	_check(document.set_misc_u32(0x01f0 + 0x1d * 4, 100), "Bond fixture improves city value")
	var second := Bonds.issue(city, Bonds.CONFIRMATION_CONFIRMED)
	_check(second.ok and second.rate == 6, "A second bond uses the current rate")
	_check(city.funds() == 22000 and document.misc_u32(0x0018) == 2, "Second bond is stored")
	_check(document.misc_u32(0x0614) == 6, "Second bond uses the next saved rate slot")
	_check(document.misc_i32(0x0930) == 50000, "Two bond rates use their integer average")

	var repay_before: PackedByteArray = document.find_chunk("MISC").decoded_payload.duplicate()
	var repay_request := Bonds.repay(city)
	_check(
		repay_request.ok and repay_request.status == "confirmation_required"
		and repay_request.rate == 4,
		"Bond repayment offers the oldest bond",
	)
	_check(
		document.find_chunk("MISC").decoded_payload == repay_before,
		"Bond repayment prompt preserves MISC",
	)
	var repay_cancel := Bonds.repay(city, Bonds.CONFIRMATION_CANCELLED)
	_check(repay_cancel.ok and repay_cancel.status == "cancelled", "Bond repayment can be declined")
	_check(
		document.find_chunk("MISC").decoded_payload == repay_before,
		"Declined bond repayment preserves MISC",
	)
	var repaid := Bonds.repay(city, Bonds.CONFIRMATION_CONFIRMED)
	_check(repaid.ok and repaid.status == "repaid" and repaid.rate == 4, "Oldest bond is repaid")
	_check(city.funds() == 12000 and document.misc_u32(0x0018) == 1, "Repayment removes $10,000")
	_check(document.misc_u32(0x0610) == 6, "Repayment shifts the remaining rate forward")
	_check(document.misc_u32(0x0614) == 6, "Repayment preserves the stale last active slot")
	_check(document.misc_i32(0x092c) == 1 and document.misc_i32(0x0930) == 60000, "Repayment updates the bond budget")
	var final_repay := Bonds.repay(city, Bonds.CONFIRMATION_CONFIRMED)
	_check(final_repay.ok and final_repay.bond_count == 0, "Last bond can be repaid")
	_check(city.funds() == 2000 and document.misc_i32(0x0930) == 0, "No bonds have zero average rate")
	_check(document.misc_u32(0x0610) == 6, "Last repayment does not clear its stale rate")
	var no_bonds_before: PackedByteArray = document.find_chunk("MISC").decoded_payload.duplicate()
	var no_bonds := Bonds.repay(city)
	_check(no_bonds.ok and no_bonds.status == "no_bonds", "Repayment reports no bonds")
	_check(document.find_chunk("MISC").decoded_payload == no_bonds_before, "No-bond repayment is read-only")

	var denied_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var denied_city := CityModel.from_document(denied_document)

	for tile_id in 256:
		denied_document.set_misc_i32(0x01f0 + tile_id * 4, 0)

	_check(denied_document.set_misc_u32(0x01f0 + 0x1d * 4, 10), "Credit fixture sets roads")
	_check(denied_document.set_misc_u32(0x0018, 1), "Credit fixture sets one bond")
	_check(denied_document.set_misc_u32(0x0610, 4), "Credit fixture sets its rate")
	_check(denied_city.set_funds(9999), "Credit fixture sets insufficient repayment funds")
	var denied := Bonds.issue(denied_city)
	_check(
		denied.ok and denied.status == "credit_denied" and denied.credit_value == 24,
		"Supplied 2,500 credit formula can deny a bond",
	)
	_check(denied_document.misc_i32(0x0024) == 100, "Denied issue stores rebuilt city value")
	var insufficient := Bonds.repay(denied_city)
	_check(
		insufficient.ok and insufficient.status == "insufficient_funds",
		"Repayment requires $10,000 before it asks for confirmation",
	)

	var maximum_document := _load_fixture(reference_root.path_join("DEFAULT.SC2"))
	var maximum_city := CityModel.from_document(maximum_document)

	for tile_id in 256:
		maximum_document.set_misc_i32(0x01f0 + tile_id * 4, 0)

	_check(maximum_document.set_misc_u32(0x0018, 50), "Maximum fixture sets fifty bonds")
	var maximum := Bonds.issue(maximum_city)
	_check(maximum.ok and maximum.status == "maximum_bonds", "Bond count is limited to fifty")
