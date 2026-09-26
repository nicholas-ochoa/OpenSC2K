extends SimulationDayPhase


func run(context: SimulationPhaseContext) -> PhaseResult:
	var weather := WeatherDisasterPhase.run(
		context.city,
		context.random,
		context.lfsr_random,
		context.power_usage_percent,
		context.water_usage_percent,
		context.commerce_connections,
		context.industry_connections,
		context.pending_disaster_point
	)

	if not weather.ok:
		return weather

	var stored := context.record(context.action, weather)

	if not stored.ok:
		return stored

	context.city_status_resource_id = CityStatusMessages.monthly_resource(
		weather.status_index, context.city.weather_type()
	)

	if weather.disaster_type != 0:
		context.pending_disaster_type = weather.disaster_type
		context.pending_disaster_point = weather.disaster_point

	return weather
