class_name TimingState
extends RefCounted


var simulation_timings := SimulationTimingHistory.new()

var edit_display_timings := {}
# display time since the frame rate label was refreshed
var fps_update_seconds := 0.0
