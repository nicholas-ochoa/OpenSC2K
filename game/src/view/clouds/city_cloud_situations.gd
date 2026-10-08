class_name CityCloudSituations
extends RefCounted
## Cohesive presentation-only cloud fronts. Never consumes simulation randomness.

enum Type { CUMULUS, STRATUS, ALTOSTRATUS, CIRRUS, CIRROCUMULUS, FOG }
const ATLASES := [preload("res://assets/clouds/cumulus_atlas.png"),
	preload("res://assets/clouds/stratus_atlas.png"), preload("res://assets/clouds/altostratus_atlas.png"),
	preload("res://assets/clouds/cirrus_atlas.png"), preload("res://assets/clouds/cirrocumulus_atlas.png"),
	preload("res://assets/clouds/stratus_atlas.png")]
# Spread toward broad banks, vertical proportion, body opacity, shadow strength.
const APPEARANCE := [Vector4(0, 1, 1, 1), Vector4(1, 0.78, 0.9, 0.7),
	Vector4(1, 0.85, 0.55, 0.35), Vector4(0.75, 0.9, 0.5, 0.08),
	Vector4(0.5, 0.85, 0.8, 0.18), Vector4(1, 0.7, 0.0, 0.0)]
const TRANSITION_SECONDS := 90.0
const HOLD_SECONDS := 360.0
var current := Type.CUMULUS
var target := Type.CUMULUS
var blend := 0.0
var hold_clock := 0.0
var initialized := false
var preview := false
var duration := TRANSITION_SECONDS


func reset() -> void:
	current = Type.CUMULUS
	target = current
	blend = 0.0
	hold_clock = 0.0
	initialized = false
	preview = false


static func wet(kind: int) -> bool:
	return kind != CityVisualWeather.Kind.SUNNY


static func choose(mode: int, kind: int, game_weather: int, epoch := 0) -> int:
	# A fixed type is authoritative. Only Automatic follows weather fronts.
	if mode > 0:
		return clampi(mode - 1, Type.CUMULUS, Type.FOG)
	match kind:
		CityVisualWeather.Kind.LIGHT_RAIN, CityVisualWeather.Kind.LIGHT_SNOW, CityVisualWeather.Kind.HEAVY_SNOW:
			return Type.ALTOSTRATUS
		CityVisualWeather.Kind.HEAVY_RAIN:
			return Type.STRATUS
		CityVisualWeather.Kind.RAIN_STORM, CityVisualWeather.Kind.DRY_STORM:
			return Type.CUMULUS
	if game_weather == 3:
		return Type.FOG
	if game_weather == 5:
		return Type.STRATUS if epoch % 2 == 0 else Type.ALTOSTRATUS
	# Long, orderly situations, never independently randomized cloud types.
	if game_weather == -2:
		return Type.CUMULUS
	return [Type.CUMULUS, Type.CIRRUS, Type.CUMULUS, Type.CIRROCUMULUS][posmod(epoch, 4)]


func advance(mode: int, kind: int, game_weather: int, delta: float, elapsed: float, manual: bool) -> void:
	var step := minf(maxf(delta, 0.0), maxf(elapsed, 0.0))
	hold_clock += step
	var wanted := choose(mode, kind, game_weather, int(hold_clock / HOLD_SECONDS))
	if not initialized:
		current = wanted as Type
		target = current
		initialized = true
		return
	if manual:
		preview = true
	if current == target and wanted != current:
		target = wanted as Type
		duration = 8.0 if preview else TRANSITION_SECONDS
	if current != target:
		blend = minf(1.0, blend + (maxf(delta, 0.0) if preview else step) / duration)
		if blend >= 1.0 - 0.000001:
			current = target
			blend = 0.0
			preview = preview and wanted != current
	elif wanted == current:
		preview = false


func weight() -> float:
	return smoothstep(0.0, 1.0, blend)


func appearance() -> Vector4:
	return APPEARANCE[current].lerp(APPEARANCE[target], weight())


func fog_weight() -> float:
	return lerpf(float(current == Type.FOG), float(target == Type.FOG), weight())


func rain_cover() -> float:
	var suitable := [Type.CUMULUS, Type.STRATUS, Type.ALTOSTRATUS]
	return lerpf(float(current in suitable), float(target in suitable), weight())
