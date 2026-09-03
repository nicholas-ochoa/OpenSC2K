class_name MicrosimAnnualUtilities
extends MicrosimAnnualValues
# update utilities records without changing record or random-call order


static func update_hydro_one(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	var hydro_count := _tile_count(annual.misc, TILE_HYDRO_ONE, annual.map_edge) + _tile_count(annual.misc, TILE_HYDRO_TWO, annual.map_edge)
	_write_u16_be(annual.microsims, offset + 2, hydro_count)
	_write_u16_be(annual.microsims, offset + 4, hydro_count * 20)
	annual.counts.hydro += 1


static func update_wind_power(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	var wind_count := _tile_count(annual.misc, TILE_WIND_POWER, annual.map_edge)
	_write_u16_be(annual.microsims, offset + 2, wind_count)
	_write_u16_be(annual.microsims, offset + 4, wind_count * 4)
	annual.counts.wind += 1


static func update_power(annual: MicrosimAnnualContext, record_id: int, offset: int, power_tile: int) -> void:
	if annual.random == null:
		annual.random_records_pending += 1
		return

	annual.microsims[offset + 1] = (int(annual.microsims[offset + 1]) + 1) & 0xff
	var power_random: int = annual.random.next_u15()

	if annual.power_usage_percent >= 0:
		_write_u16_be(
			annual.microsims, offset + 4, (power_random & 0x07) + annual.power_usage_percent
		)
	else:
		annual.random_records_pending += 1

	if int(annual.microsims[offset + 1]) > 48:
		annual.news_items.append({"type": NEWS_POWER_PLANT, "argument": power_tile + 0x37})

	if int(annual.microsims[offset + 1]) > 50:
		annual.span.mark("expired plant search and demolition")
		var location := _find_microsim_location(annual.changed_payloads.XTXT, record_id, annual.map_edge, annual.city.simulation_slice)

		if location.x >= 0:
			var plant_cost: int = POWER_PLANT_COSTS.get(power_tile, 0)
			var funds := _read_i32(annual.misc, MISC_FUNDS)

			if _read_u32(annual.misc, MISC_NO_DISASTERS) != 0 and funds >= plant_cost:
				_write_i32(annual.misc, MISC_FUNDS, funds - plant_cost)
				annual.microsims[offset + 1] = 0
			else:
				var expired_record := {
					"record": record_id,
					"tile": power_tile,
					"x": location.x,
					"y": location.y,
				}
				var demolition := DemolishStructures.damage_structure_payloads(
					annual.city, annual.changed_payloads, Vector2i(location.x, location.y), annual.random, true
				)

				if demolition.changed:
					annual.next_effect_frame = DemolishEffectsSites.append_effect_sequence(
						annual.effect_events,
						demolition.effect_events,
						annual.next_effect_frame
					)
					annual.demolished_power_records.append(expired_record)
					annual.sound_events.append(SOUND_EXPLOSION)

					if _read_u32(annual.misc, MISC_AUTO_GOTO) != 0:
						annual.view_center_requests.append(Vector2i(location.x, location.y))
				else:
					annual.expired_power_records.append(expired_record)

	annual.span.mark("facility records")
	annual.counts.power += 1


static func update_water_treatment(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	if annual.random == null:
		annual.random_records_pending += 1
		return

	var water_first: int = annual.random.next_u15()
	var water_second: int = annual.random.next_u15()
	var water_third: int = annual.random.next_u15()

	if annual.water_usage_percent >= 0:
		annual.microsims[offset + 1] = ((water_first & 0x07) + annual.water_usage_percent) & 0xff
	else:
		annual.random_records_pending += 1

	_write_u16_be(annual.microsims, offset + 2, water_second % 100)
	_write_u16_be(
		annual.microsims,
		offset + 4,
		mini(
			(water_third & 0x1f) + 135,
			_divide_toward_zero(_read_u32(annual.misc, MISC_NORMAL_POPULATION), 50)
		)
	)
	annual.counts.water_facility += 1


static func update_arcology(annual: MicrosimAnnualContext, record_id: int, offset: int, arcology_tile: int) -> void:
	if annual.lfsr_random == null:
		annual.random_records_pending += 1
		return

	var arcology_count := maxi(_arcology_count(annual.misc, annual.map_edge), 1)
	var arcology_capacity := _population_cap(
		annual.misc,
		_to_i16(_divide_toward_zero(_read_u16_be(annual.microsims, offset + 2) * 1000, 10)),
		arcology_count * 20, annual.map_edge
	) & 0xffff
	var tax_effect := (
		_divide_toward_zero(
			60
			- _budget_funding(annual.misc, 0)
			- _budget_funding(annual.misc, 1)
			- _budget_funding(annual.misc, 2),
			6
		)
		+ int(annual.microsims[offset + 1])
	)
	var arcology_growth := mini((tax_effect * 5 - 50) * 40, arcology_capacity)
	var next_population := (
		arcology_growth
		+ _divide_toward_zero(_read_u16_be(annual.microsims, offset + 4), 50)
		+ _read_u16_be(annual.microsims, offset + 4)
	)
	next_population = mini(
		next_population, _read_u16_be(annual.microsims, offset + 2) * 1000
	)
	var arcology_record_population := (
		_to_i16(annual.lfsr_random.next_mask(0x3f)) + _to_i16(next_population)
	)
	_write_u16_be(annual.microsims, offset + 4, arcology_record_population)
	annual.arcology_population = _to_i32(
		annual.arcology_population + (arcology_record_population & 0xffff)
	)

	if arcology_tile == TILE_LAUNCH_ARCOLOGY:
		annual.launch_arcology_records += 1

	annual.counts.arcology += 1
