class_name DisasterStartPowerAccidents
extends DisasterStartConstants


static func _start_meltdown(
	city: CityState, requested_point: Vector2i, random: SimRandom, lfsr_random: SimLfsrRandom
) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if random == null:
		return {"ok": false, "error": "a compatible process random generator is required"}

	if lfsr_random == null:
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	var original := DisasterStartObjectsState._map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "meltdown disaster input chunks are missing or invalid"}

	var payloads := DisasterStartObjectsState._duplicate_payloads(original)
	var runtime_events := DisasterMapDamage.new_runtime_events()
	var plant_point := _find_nuclear_power_plant(payloads.XBLD, requested_point, map_edge)

	if plant_point.x < 0:
		return DisasterStartObjectsState._result(DISASTER_MELTDOWN, requested_point, false, true, 0)

	var center := plant_point
	var site := Demolish._find_building_site(
		payloads.XBLD,
		payloads.XZON,
		plant_point,
		NUCLEAR_POWER_PLANT,
		4,
		city.compass_rotation(), map_edge,
	)

	if site.size != Vector2i.ZERO:
		center = Vector2i(site.position.x + 1, site.end.y - 2)

	var plant_damage := DisasterMapDamage.burn_structure(
		city,
		payloads.ALTM,
		payloads.XBLD,
		payloads.XTER,
		payloads.XZON,
		payloads.XUND,
		payloads.XBIT,
		payloads.XTXT,
		payloads.XLAB,
		payloads.XMIC,
		payloads.MISC,
		center,
		random,
		lfsr_random,
		true,
		true,
		true,
	)
	DisasterMapDamage.append_damage_events(runtime_events, plant_damage)

	var gate_hits := 0
	var fire_damage_attempts := 0
	var structure_damage_attempts := 0
	var radioactive_writes := 0
	var toxic_writes := 0

	for x_offset in range(-32, 33):
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y_offset in range(-32, 33):
			if random.next_u15() & 0x1f != 0:
				continue

			gate_hits += 1
			var target := center + Vector2i(x_offset, y_offset)
			var index := DisasterStartObjectsState._index(target, map_edge)

			if index < 0:
				continue

			if random.next_u15() & 3 == 0:
				fire_damage_attempts += 1
				DisasterMapDamage.apply(
					city,
					payloads.ALTM,
					payloads.XBLD,
					payloads.XTER,
					payloads.XZON,
					payloads.XUND,
					payloads.XBIT,
					payloads.XTRF,
					payloads.XTXT,
					payloads.XLAB,
					payloads.XMIC,
					payloads.MISC,
					target,
					random,
					lfsr_random,
					true,
					runtime_events,
				)
			else:
				structure_damage_attempts += 1
				DisasterMapDamage.burn_structure(
					city,
					payloads.ALTM,
					payloads.XBLD,
					payloads.XTER,
					payloads.XZON,
					payloads.XUND,
					payloads.XBIT,
					payloads.XTXT,
					payloads.XLAB,
					payloads.XMIC,
					payloads.MISC,
					target,
					random,
					lfsr_random,
					false,
					false,
				)

				if random.next_u15() & 1 != 0:
					if payloads.XBIT[index] & 0x04 == 0:
						if _write_radioactivity(payloads, target, map_edge):
							radioactive_writes += 1
					else:
						OverlayData.write(payloads.XTXT, index, 0xfb)
						toxic_writes += 1

	for x_offset in range(-1, 3):
		if city.simulation_slice != null:
			city.simulation_slice.checkpoint()

		for y_offset in range(-2, 2):
			if random.next_u15() & 1 != 0:
				if _write_radioactivity(payloads, center + Vector2i(x_offset, y_offset), map_edge):
					radioactive_writes += 1

	var map_changed := DisasterStartObjectsState._payloads_changed(original, payloads)

	if map_changed and not DisasterStartObjectsState._apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the meltdown disaster"}

	var result := DisasterStartObjectsState._result(DISASTER_MELTDOWN, center, true, true, 0)
	result["plant_point"] = plant_point
	result["plant_site"] = site
	result["gate_attempts"] = 65 * 65
	result["gate_hits"] = gate_hits
	result["fire_damage_attempts"] = fire_damage_attempts
	result["structure_damage_attempts"] = structure_damage_attempts
	result["radioactive_writes"] = radioactive_writes
	result["toxic_writes"] = toxic_writes
	result["map_changed"] = map_changed
	result["effect_events"] = runtime_events.effect_events
	var sounds: Array[int] = runtime_events.sound_events.duplicate()
	sounds.append(SOUND_SIREN)
	result["sound_events"] = sounds

	return result


static func _find_nuclear_power_plant(
	buildings: PackedByteArray, requested_point: Vector2i,
	map_edge: int = 128,
) -> Vector2i:
	var requested_index := DisasterStartObjectsState._index(requested_point, map_edge)

	if requested_index >= 0 and buildings[requested_index] == NUCLEAR_POWER_PLANT:
		return requested_point

	for x in map_edge:
		for y in map_edge:
			if buildings[x * map_edge + y] == NUCLEAR_POWER_PLANT:
				return Vector2i(x, y)

	return Vector2i(-1, -1)


static func _write_radioactivity(payloads: Dictionary, point: Vector2i, map_edge: int = 128) -> bool:
	var index := DisasterStartObjectsState._index(point, map_edge)

	if index < 0:
		return false

	var old_tile := int(payloads.XBLD[index])
	SpecialZoneGrowth.replace_building(
		payloads.XBLD, payloads.XZON, payloads.MISC, index, RADIOACTIVITY_TILE
	)

	return old_tile != RADIOACTIVITY_TILE


static func _start_microwave(city: CityState, random: SimRandom, lfsr_random: SimLfsrRandom) -> Dictionary:
	var map_edge: int = city.map_size if city != null else 128

	if random == null:
		return {"ok": false, "error": "a compatible process random generator is required"}

	if lfsr_random == null:
		return {"ok": false, "error": "a compatible LFSR generator is required"}

	var original := DisasterStartObjectsState._map_payloads(city)

	if original.is_empty():
		return {"ok": false, "error": "microwave disaster input chunks are missing or invalid"}

	var payloads := DisasterStartObjectsState._duplicate_payloads(original)
	var plant_point := _find_first_building(payloads.XBLD, MICROWAVE_POWER_PLANT, map_edge)

	if plant_point.x < 0:
		return DisasterStartObjectsState._result(DISASTER_MICROWAVE, plant_point, false, true, 0)

	var point := plant_point
	var remaining := 39
	var direction: int = random.next_u15()
	var damage_points: Array[Vector2i] = []
	var toxic_writes := 0
	var view_centers: Array[Vector2i] = [plant_point]
	var runtime_events := DisasterMapDamage.new_runtime_events()

	while remaining > 0:
		var index := DisasterStartObjectsState._index(point, map_edge)

		if index < 0:
			break

		if payloads.XBLD[index] != MICROWAVE_POWER_PLANT:
			if payloads.XBIT[index] & 0x04 != 0:
				OverlayData.write(payloads.XTXT, index, 0xfb)
				toxic_writes += 1

			if remaining % 10 == 0:
				view_centers.append(point)

			DisasterMapDamage.apply(
				city,
				payloads.ALTM,
				payloads.XBLD,
				payloads.XTER,
				payloads.XZON,
				payloads.XUND,
				payloads.XBIT,
				payloads.XTRF,
				payloads.XTXT,
				payloads.XLAB,
				payloads.XMIC,
				payloads.MISC,
				point,
				random,
				lfsr_random,
				true,
				runtime_events,
			)
			damage_points.append(point)
			runtime_events.sound_events.append(SOUND_MICROWAVE)

		remaining -= 1
		point += EIGHT_DIRECTIONS[direction & 7]
		direction = random.next_u15()

	var map_changed := DisasterStartObjectsState._payloads_changed(original, payloads)

	if map_changed and not DisasterStartObjectsState._apply_map_payloads(city, original, payloads):
		return {"ok": false, "error": "cannot store the microwave disaster"}

	var result := DisasterStartObjectsState._result(DISASTER_MICROWAVE, plant_point, true, true, 0)
	var sounds: Array[int] = runtime_events.sound_events.duplicate()
	sounds.append(SOUND_SIREN)
	result["sound_events"] = sounds
	result["effect_events"] = runtime_events.effect_events
	result["view_center_requests"] = view_centers
	result["plant_point"] = plant_point
	result["path_finish"] = point
	result["path_steps"] = 39 - remaining
	result["damage_points"] = damage_points
	result["damage_attempts"] = damage_points.size()
	result["toxic_writes"] = toxic_writes
	result["map_changed"] = map_changed

	return result


static func _find_first_building(buildings: PackedByteArray, tile_id: int, map_edge: int = 128) -> Vector2i:
	for x in map_edge:
		for y in map_edge:
			if buildings[x * map_edge + y] == tile_id:
				return Vector2i(x, y)

	return Vector2i(-1, -1)
