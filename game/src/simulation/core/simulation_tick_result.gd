class_name SimulationTickResult
extends RefCounted


var ok := false
var error := ""
var base_ticks := 0
var moving_results: Array[MovingThingResult] = []
var disaster_results: Array[DisasterMapScanDispatch.Result] = []
var day_results: Array[SimulationDayResult] = []
var news_items: Array = []
var effect_events: Array = []
var sound_events: Array = []
var view_center_requests: Array = []
var refresh_requests: Array = []
var interaction_requests: Array = []
var game_over_events: Array = []
var music_track_requests := PackedInt32Array()
var pending_actions := PackedStringArray()
var job_timings: Dictionary[String, int] = {}
