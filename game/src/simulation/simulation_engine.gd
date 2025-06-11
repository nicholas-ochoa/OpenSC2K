# todo: land value and service maps still pending
# todo: demand calculation
# todo: education and health
# todo: run the zone growth scan on the growth days
# todo: monthly budget is only a schedule entry for now

class_name SimulationEngine
extends RefCounted

var city: CityState
var clock: SimulationClock
var random: SimRandom


func _init(initial_city: CityState, random_seed := 1) -> void:
	city = initial_city
	clock = SimulationClock.new(initial_city.age_in_days() if initial_city != null else 0)
	random = SimRandom.new(random_seed)


func advance_day() -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	var schedule := clock.advance_day()
	if not city.set_age_in_days(clock.city_days):
		return {"ok": false, "error": "cannot store the new simulation day"}

	var applied := PackedStringArray()
	var pending := PackedStringArray()
	var phase_results: Dictionary = {}
	for action in schedule.actions:
		match action:
			"power":
				var power := PowerPhase.run(city, random)
				if not power.ok:
					return {"ok": false, "error": power.error}
				phase_results[action] = power
				applied.append(action)
			"water":
				var water := WaterPhase.run(city)
				if not water.ok:
					return {"ok": false, "error": water.error}
				phase_results[action] = water
				applied.append(action)
			"traffic":
				var traffic := TrafficPhase.run(city)
				if not traffic.ok:
					return {"ok": false, "error": traffic.error}
				phase_results[action] = traffic
				applied.append(action)
			_:
				pending.append(action)
	return {
		"ok": true,
		"day": clock.city_days,
		"schedule": schedule,
		"applied": applied,
		"pending": pending,
		"phase_results": phase_results,
		"complete": pending.is_empty(),
		"error": "",
	}
