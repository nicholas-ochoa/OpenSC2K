class_name CityAudioEffects
extends RefCounted
# Sound event playback, tool and disaster loops, toolbar clicks, and the wave cache.


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
	audio.sound_loop_player = null
	audio.sound_loop_id = -1


static func play_sound_events(
	audio: CityAudioController,
	sound_events: Array[SoundEvent], sound_enabled: bool, overlay_mode: CityViewMode.Mode, view_size: int,
	simulation := false
) -> void:
	if not sound_enabled or not audio.audio_allowed():
		return

	for sound_event in sound_events:
		if sound_event.sound_id == SoundEvent.STOP_LOOP:
			audio.wave_sound_gate.stop_loop()

			continue

		var sound_id := MovingThingAudio.event_sound_id(
			sound_event, overlay_mode, view_size
		)

		if sound_id < 0:
			continue

		if sound_event.loop_plays != 0:
			audio.wave_sound_gate.request_loop(sound_id, sound_event.loop_plays)

			continue

		var stream := audio.wave_stream_cache.get(sound_id) as AudioStreamWAV

		if stream == null or not audio.wave_sound_gate.request(
			sound_id, sound_event.from_thing, simulation
		):
			continue

		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_linear = audio.effects_volume
		player.finished.connect(player.queue_free)
		audio.add_child(player)
		player.add_to_group(CityAudioController.SOUND_EFFECT_GROUP)
		player.play()

	sync_sound_loop(audio)


# start, change, or stop the disaster loop player to match the gate
static func sync_sound_loop(audio: CityAudioController) -> void:
	var sound_id := audio.wave_sound_gate.loop_sound_id

	if sound_id == audio.sound_loop_id:
		return

	if is_instance_valid(audio.sound_loop_player):
		audio.sound_loop_player.stop()
		audio.sound_loop_player.queue_free()

	audio.sound_loop_player = (
		_start_loop_player(audio, sound_id, audio.wave_sound_gate.loop_plays) if sound_id >= 0 else null
	)
	audio.sound_loop_id = sound_id


static func start_tool_loop_sound(audio: CityAudioController, sound_id: int, sound_enabled: bool) -> void:
	audio.stop_tool_loop_sound()

	if not sound_enabled or not audio.audio_allowed():
		return

	audio.tool_loop_player = _start_loop_player(audio, sound_id)


# a player that repeats the sound without a gap, or null without the sound.
# a counted loop plays `plays` copies of the sound and stops; the gate counts
# base ticks, which last longer than each play
static func _start_loop_player(audio: CityAudioController, sound_id: int, plays := 0) -> AudioStreamPlayer:
	var cached_stream := audio.wave_stream_cache.get(sound_id) as AudioStreamWAV

	if cached_stream == null:
		return null

	var stream := cached_stream.duplicate() as AudioStreamWAV

	if stream == null:
		return null

	if plays > 0:
		var copies := PackedByteArray()

		for play in plays:
			copies.append_array(cached_stream.data)

		stream.data = copies
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	else:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = maxi(1, roundi(stream.get_length() * stream.mix_rate))

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_linear = audio.effects_volume
	audio.add_child(player)
	player.add_to_group(CityAudioController.SOUND_EFFECT_GROUP)
	player.play()

	return player


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
		"wave_loop_id": audio.wave_sound_gate.loop_sound_id,
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
