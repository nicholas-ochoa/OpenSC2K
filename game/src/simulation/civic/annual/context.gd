class_name MicrosimAnnualContext
extends RefCounted


var city: CityState
var bus_passengers: int
var rail_passengers: int
var subway_passengers: int
var random: SimRandom
var lfsr_random: SimLfsrRandom
var game_random: GameLcgRandom
var power_usage_percent: int
var water_usage_percent: int
var australian_locale: bool
var mayor_approval: int
var map_edge: int
var span: SimulationTimingSpan
var old_payloads: Dictionary
var changed_payloads: Dictionary
var microsims: PackedByteArray
var misc: PackedByteArray
var subway_count: int
var bus_count: int
var rail_count: int
var counts: Dictionary
var old_arrests: int
var prison_population: int
var prison_count: int
var news_items: Array[NewsEvent]
var random_records_pending: int
var low_school_score: bool
var expired_power_records: Array[PowerPlantExpiry]
var demolished_power_records: Array[PowerPlantExpiry]
var arcology_population: int
var arcology_launch_pending: bool
var launch_arcology_records: int
var launched_structures: int
var arcology_launched: bool
var sound_events: Array[int]
var view_center_requests: Array[Vector2i]
var effect_events: Array[EffectEvent]
var next_effect_frame: int
var updated_subway: int
var updated_bus: int
var updated_rail: int
