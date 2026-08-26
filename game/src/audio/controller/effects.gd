class_name CityAudioEffects
extends RefCounted
# Sound event playback, tool loops, toolbar clicks, and the wave cache.


static func stop_sound_effects(audio: CityAudioController) -> void:
	audio.wave_sound_gate.stop()

	if not audio.is_inside_tree():
		return

	for node in audio.get_tree().get_nodes_in_group(CityAudioController.SOUND_EFFECT_GROUP):
		var player := node as AudioStreamPlayer

		if player == null:
			continue

		player.stop()
		player.queue_free()

	audio.tool_loop_player = null


static func play_sound_events(
	audio: CityAudioController,
	sound_events: Array, sound_enabled: bool, overlay_mode: CityViewMode.Mode, view_size: int
) -> void:
	if not sound_enabled or not audio.audio_allowed():
		return

	for sound_event in sound_events:
		var sound_id := CityAudioController.MovingThingAudio.event_sound_id(
			sound_event, overlay_mode, view_size
		)

		if sound_id < 0:
			continue

		var stream := audio.wave_stream_cache.get(sound_id) as AudioStreamWAV

		if stream == null or not audio.wave_sound_gate.request(
			sound_id, sound_event is Dictionary and sound_event.has("thing_type")
		):
			continue

		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_linear = audio.effects_volume
		player.finished.connect(player.queue_free)
		audio.add_child(player)
		player.add_to_group(CityAudioController.SOUND_EFFECT_GROUP)
		player.play()


static func start_tool_loop_sound(audio: CityAudioController, sound_id: int, sound_enabled: bool) -> void:
	audio.stop_tool_loop_sound()

	if not sound_enabled or not audio.audio_allowed():
		return

	var cached_stream := audio.wave_stream_cache.get(sound_id) as AudioStreamWAV

	if cached_stream == null:
		return

	var stream := cached_stream.duplicate() as AudioStreamWAV

	if stream == null:
		return

	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = maxi(1, roundi(stream.get_length() * stream.mix_rate))
	audio.tool_loop_player = AudioStreamPlayer.new()
	audio.tool_loop_player.stream = stream
	audio.tool_loop_player.volume_linear = audio.effects_volume
	audio.add_child(audio.tool_loop_player)
	audio.tool_loop_player.add_to_group(CityAudioController.SOUND_EFFECT_GROUP)
	audio.tool_loop_player.play()


static func stop_tool_loop_sound(audio: CityAudioController) -> void:
	if not is_instance_valid(audio.tool_loop_player):
		audio.tool_loop_player = null

		return

	audio.tool_loop_player.stop()
	audio.tool_loop_player.queue_free()
	audio.tool_loop_player = null


static func debug_metrics(audio: CityAudioController) -> Dictionary:
	return {
		"wave_sound_id": audio.wave_sound_gate.current_sound_id,
		"wave_sound_ticks": audio.wave_sound_gate.remaining_ticks,
		"wave_sound_accepted": audio.wave_sound_gate.accepted_count,
		"wave_sound_suppressed": audio.wave_sound_gate.suppressed_count,
		"wave_stream_cache": audio.wave_stream_cache.size(),
	}


static func _load_wave_sound_cache(audio: CityAudioController) -> void:
	audio.wave_stream_cache.clear()

	for sound_id in range(CityAudioController.WaveSounds.SOUND_FIRST, CityAudioController.WaveSounds.SOUND_LAST + 1):
		var sound_path := str(audio.sound_pack.files.get(sound_id, audio.reference_root.path_join("SOUNDS/%d.WAV" % sound_id)
				if audio.original_media_enabled else ""))

		if not FileAccess.file_exists(sound_path):
			continue

		var stream := AudioStreamWAV.load_from_file(sound_path)

		if stream != null:
			audio.wave_stream_cache[sound_id] = stream


static func play_toolbar_click(audio: CityAudioController, sound_enabled: bool) -> void:
	if not sound_enabled or not audio.audio_allowed():
		return

	var stream := audio.wave_stream_cache.get(ToolSoundRules.SOUND_CENTER) as AudioStreamWAV

	if stream == null:
		return

	# each button activation gets feedback, including rapid consecutive clicks
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_linear = audio.effects_volume
	player.finished.connect(player.queue_free)
	audio.add_child(player)
	player.add_to_group(CityAudioController.SOUND_EFFECT_GROUP)
	player.play()
