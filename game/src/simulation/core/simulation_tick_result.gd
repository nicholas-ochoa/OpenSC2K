class_name SimulationTickResult
extends RefCounted


var ok := false
var error := ""
var base_ticks := 0
var moving_results: Array[MovingThingResult] = []
var disaster_results: Array[DisasterMapResult] = []
var day_results: Array[SimulationDayResult] = []
var news_items: Array[NewsEvent] = []
var effect_events: Array[EffectEvent] = []
var sound_events: Array[SoundEvent] = []
var view_center_requests: Array[Vector2i] = []
var refresh_requests: Array[String] = []
var interaction_requests: Array[SimulationInteractionRequest] = []
var game_over_events: Array[GameOverEvent] = []
var music_track_requests := PackedInt32Array()
var pending_actions := PackedStringArray()
var job_timings: Dictionary[String, int] = {}
var paused_on_target_day := false
