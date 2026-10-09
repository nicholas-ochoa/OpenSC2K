class_name VisualEnhancementOptions
extends RefCounted
## Local presentation preferences. No value is written to a city document.

const FIELDS := [
	["nature_forests_enabled", "Connected forests and tree variants", "bool", true],
	["nature_terrain_enabled", "Subtle terrain variation", "bool", true],
	["nature_terrain_strength", "Terrain overlay strength", "number", 0.5, 0.0, 1.0, 0.05],
	["disaster_enabled", "Disaster effects", "bool", true],
	["disaster_strength", "Effect strength", "number", 0.7, 0.0, 1.0, 0.05],
	["disaster_crowds", "Use city pedestrians for riots", "bool", true],
	["disaster_dust", "Demolition and damage dust", "bool", true],
	["disaster_motion", "Smooth tornado movement", "bool", true],
	["disaster_blending", "Smooth effect transitions", "bool", true],
	["disaster_lights", "Fire and impact light strength", "number", 0.4, 0.0, 1.0, 0.05],
	["disaster_shake", "Earthquake shake strength", "number", 0.6, 0.0, 1.0, 0.05],
	["water_reflections", "Water reflections", "choice", 1, ["Off", "Subtle"]],
	["water_topography", "Underwater terrain", "bool", true],
	["water_waves_enabled", "Waves and coastal surf", "bool", true],
	["cloud_enabled", "Clouds and fog", "bool", true],
	["cloud_mode", "Cloud type", "choice", 0, ["Automatic (weather)", "Cumulus", "Stratus", "Altostratus", "Cirrus", "Cirrocumulus", "Fog"]],
	["cloud_density", "Cloud and fog coverage", "number", 0.4, 0.0, 1.0, 0.05],
	["cloud_shadow_strength", "Cloud shadow strength", "number", 0.4, 0.0, 0.5, 0.02],
	["cloud_speed", "Cloud and fog movement", "number", 1.0, 0.0, 3.0, 0.1],
	["life_cars_enabled", "Individual cars", "bool", true],
	["life_car_amount", "Car amount", "number", 1.0, 0.25, 2.0, 0.05],
	["life_people_enabled", "Pedestrians", "bool", true],
	["life_people_amount", "Pedestrian amount", "number", 1.0, 0.25, 2.0, 0.05],
	["traffic_vehicles_enabled", "Smooth vehicles", "bool", true],
	["traffic_shadows_enabled", "Transparent aircraft shadows", "bool", true],
	["day_enabled", "Day and night", "bool", true],
	["day_mode", "Time of day", "choice", 0, ["Cycle", "Fixed time"]],
	["day_hour", "Fixed hour", "number", 12.0, 0.0, 23.99, 0.25],
	["day_seconds", "Full cycle (seconds at Turtle)", "number", 600.0, 60.0, 7200.0, 30.0],
	["day_lut_strength", "Time of day LUT strength", "number", 0.5, 0.0, 1.0, 0.05],
	["speed_link", "Follow game speed", "bool", true],
	["pause_freezes", "Freeze environment cycles while paused", "bool", true],
	["night_strength", "Night strength", "number", 1.0, 0.0, 1.0, 0.05],
	["night_ambient", "Night ambient light", "number", 35.0, 0.0, 100.0, 5.0],
	["brightmaps", "Lights and brightmaps", "bool", true],
	["night_daytime_enabled", "Keep lights on during daytime", "bool", false],
	["night_light_strength", "Night light strength", "number", 100.0, 0.0, 100.0, 5.0],
	["night_glow", "Light glow strength", "number", 35.0, 0.0, 100.0, 5.0],
	["night_ground", "Street and junction lighting", "number", 45.0, 0.0, 100.0, 5.0],
	["detail_lights_min_zoom", "Detail lights from zoom", "choice", 2, ["10% (all zoom levels)", "25%", "50%", "100%", "200%", "400%"]],
	["brightmap_folder", "Brightmap folder", "path", ""],
	["lut_path", "Optional color LUT (PNG strip)", "path", ""],
	["lut_folder", "Custom LUT profile folder (empty = built-in)", "path", ""],
	["season_enabled", "Seasons", "bool", true],
	["season_mode", "Season source", "choice", 0, ["City calendar", "Visual cycle", "Fixed season"]],
	["season_fixed", "Fixed season", "choice", 1, ["Spring", "Summer", "Autumn", "Winter"]],
	["season_seconds", "Full year (seconds at Turtle)", "number", 2400.0, 120.0, 14400.0, 60.0],
	["season_transition", "Season transition (fraction)", "number", 0.35, 0.01, 1.0, 0.01],
	["season_lut_strength", "Season LUT strength", "number", 0.5, 0.0, 1.0, 0.05],
	["season_water_strength", "Seasonal water color strength", "number", 0.35, 0.0, 1.0, 0.05],
	["weather_enabled", "Weather", "bool", true],
	["weather_mode", "Weather source", "choice", 0, ["Game weather", "Visual automation", "Fixed weather"]],
	["weather_fixed", "Fixed weather", "choice", 0, ["Sunny", "Light rain", "Heavy rain", "Rain and thunderstorm", "Dry thunderstorm", "Light snow", "Heavy snow"]],
	["weather_seconds", "Weather interval (seconds at Turtle)", "number", 180.0, 30.0, 3600.0, 15.0],
	["weather_transition", "Weather transition (seconds)", "number", 4.0, 0.1, 30.0, 0.1],
	["weather_strength", "Weather strength", "number", 1.0, 0.1, 1.0, 0.05],
	["weather_lut_strength", "Weather LUT strength", "number", 0.5, 0.0, 1.0, 0.05],
]


static func normalize(source: Variant) -> Dictionary:
	var input: Dictionary = source if source is Dictionary else {}
	# The retired weather_fog_enabled flag is ignored. cloud_enabled remains
	# authoritative, so migration never re-enables clouds the player disabled.
	var result := {}
	for field in FIELDS:
		var value: Variant = input.get(field[0], field[3])
		match field[2]:
			"bool":
				result[field[0]] = value if value is bool else field[3]
			"choice":
				result[field[0]] = clampi(int(value), 0, field[4].size() - 1) if value is int else field[3]
			"number":
				result[field[0]] = clampf(float(value), field[4], field[5]) if (value is float or value is int) and is_finite(float(value)) else field[3]
			"path":
				result[field[0]] = str(value).strip_edges() if value is String else field[3]
				if field[0] == "brightmap_folder" and not result[field[0]].is_empty():
					result[field[0]] = AppPaths.stored_path(result[field[0]])
	if not input.has("traffic_vehicles_enabled"):
		# Keep smoothing enabled if any previously separate vehicle option was enabled.
		var previous := ["traffic_helicopters_enabled", "traffic_planes_enabled", "traffic_ships_enabled", "traffic_trains_enabled"]
		result.traffic_vehicles_enabled = previous.any(func(key: String) -> bool:
			var value: Variant = input.get(key, true)
			return value if value is bool else true)
	return result


static func speed_factor(speed: int) -> float:
	return [0.0, 0.0, 1.0, 1.5, 2.0, 3.0][clampi(speed, 0, 5)]


static func detail_lights_visible(options: Dictionary, zoom: float) -> bool:
	return zoom + 0.00001 >= [0.1, 0.25, 0.5, 1.0, 2.0, 4.0][clampi(int(options.get("detail_lights_min_zoom", 2)), 0, 5)]


static func water_pass_enabled(options: Dictionary) -> bool:
	return options.water_reflections == 1 or options.water_topography or options.get("water_waves_enabled", false) or (options.season_enabled and options.season_water_strength > 0.0)
