extends SceneTree
## The Dummy driver stops draining the ring buffer. Check paced waiting,
## main-thread track_finished delivery, and thread shutdown in that state.

var finished_tracks := PackedInt32Array()
var finished_on_main := true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(AudioServer.get_driver_name() == "Dummy", "Automated audio checks use the Dummy driver")
	var player := MidiSynthPlayer.new()
	root.add_child(player)
	player.track_finished.connect(_on_track_finished)
	var theme := ProjectSettings.globalize_path(
		"res://../references/SIMCITY2000/SOUNDS/10001.MID"
	)
	assert(player.play_path(theme, 10001).ok)
	assert(player.is_track_active())
	await create_timer(0.4).timeout
	var filled: Dictionary = player.debug_metrics()
	assert(filled.thread_running and filled.track_id == 10001)
	assert(filled.frames_pushed > 10000, "The synth thread primes the ring buffer")
	assert(filled.position_seconds > 0.0)

	# The Dummy driver leaves the ring full; check that the worker waits between polls.
	var before_polls: int = filled.idle_polls
	await create_timer(0.3).timeout
	var polled: Dictionary = player.debug_metrics()
	var poll_delta: int = polled.idle_polls - before_polls
	assert(poll_delta > 0, "The synth thread keeps checking the ring buffer")
	assert(poll_delta < 300, "The synth thread waits instead of spinning: %d polls" % poll_delta)

	player.stop()
	assert(not player.is_track_active() and player.current_track_id == -1)
	var stopped: Dictionary = player.debug_metrics()
	await create_timer(0.2).timeout
	var parked: Dictionary = player.debug_metrics()
	assert(parked.fills == stopped.fills, "A stopped synth thread renders nothing")
	assert(parked.idle_polls == stopped.idle_polls, "A stopped synth thread parks")

	# A short sequence reaches its end, so the thread has to report it.
	assert(player.play_sequence(_short_sequence(), 10002).ok)
	var waited := 0

	while finished_tracks.is_empty() and waited < 200:
		await process_frame
		waited += 1

	assert(finished_tracks == PackedInt32Array([10002]), "track_finished reports the ended track")
	assert(finished_on_main, "track_finished arrived off the main thread")
	assert(not player.is_track_active() and player.current_track_id == -1)
	assert(player.debug_metrics().thread_running)

	# Deletion removes the node from the tree first, so _exit_tree joins the thread.
	player.queue_free()
	await process_frame
	assert(not is_instance_valid(player), "The player frees without a live synth thread")
	print("PASS: The synth thread fills, paces, parks, reports on the main thread and joins")
	quit()


func _on_track_finished(track_id: int) -> void:
	finished_on_main = finished_on_main and OS.get_thread_caller_id() == OS.get_main_thread_id()
	finished_tracks.append(track_id)


func _short_sequence() -> StandardMidiFile:
	var sequence := StandardMidiFile.new()
	sequence.format_type = 1
	sequence.track_count = 1
	sequence.ticks_per_quarter = 192
	var event_0 := StandardMidiFile.Event.new()
	event_0.type = "note_on"
	event_0.channel = 0
	event_0.note = 60
	event_0.velocity = 100
	event_0.time_seconds = 0.0

	var event_1 := StandardMidiFile.Event.new()
	event_1.type = "note_off"
	event_1.channel = 0
	event_1.note = 60
	event_1.velocity = 0
	event_1.time_seconds = 0.08

	sequence.events.assign([event_0, event_1])
	sequence.duration_seconds = 0.1

	return sequence
