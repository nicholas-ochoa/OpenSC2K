class_name SimulationClock
extends RefCounted

@warning_ignore_start("integer_division")

# february isn't special, every month has 25 days
const DAYS_PER_MONTH := 25
const MONTHS_PER_YEAR := 12
const DAYS_PER_YEAR := DAYS_PER_MONTH * MONTHS_PER_YEAR

var city_days := 0


func _init(initial_city_days: int = 0) -> void:
	city_days = maxi(initial_city_days, 0)


func advance_day() -> SimulationSchedule:
	city_days += 1

	return state_for_day(city_days)


func write_to_city(city: CityState) -> bool:
	return city.set_age_in_days(city_days)


static func state_for_day(days: int) -> SimulationSchedule:
	var safe_days := maxi(days, 0)
	var month_day := safe_days % DAYS_PER_MONTH
	var month := int(safe_days / DAYS_PER_MONTH) % MONTHS_PER_YEAR
	var phase := SimulationSchedule.new()
	phase.city_days = safe_days
	phase.elapsed_years = int(safe_days / DAYS_PER_YEAR)
	phase.month = month
	phase.month_day = month_day
	phase.season = int(((month + 1) % MONTHS_PER_YEAR) / 3)
	var actions: PackedStringArray = phase.actions

	match month_day:
		0:
			actions.append_array(["budget", "month_start"])
		1:
			actions.append("power")
		2:
			actions.append("pollution_terrain_land_value")
		19:
			actions.append("traffic")
		20:
			actions.append("water")
		21:
			actions.append_array(["rci_demand", "education_health", "graphs"])
		22:
			actions.append_array(["milestones", "scenario", "bankruptcy"])
		23:
			actions.append("statistics_windows")
		24:
			actions.append_array(["map", "simnation", "weather_disaster"])
		_:
			if month_day >= 3 and month_day <= 18:
				phase.growth_step = int((month_day - 3) / 4) % 4
				phase.growth_substep = (month_day + 1) % 4
				actions.append("growth")

	return phase
