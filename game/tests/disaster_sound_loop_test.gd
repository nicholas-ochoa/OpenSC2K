extends SceneTree
## The siren loops for five plays, the fire loop follows it, and the end of the
## disaster stops the loop.

const WaveSounds = preload("res://src/audio/wave_sound_gate.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var audio := CityAudioController.new()
	root.add_child(audio)
	audio.setup(ProjectSettings.globalize_path("res://../references/SIMCITY2000"), 0.0, 0.5)
	var siren := SoundEvent.looped(DisasterStartConstants.SOUND_SIREN, DisasterStartConstants.SIREN_PLAYS)
	var fire := SoundEvent.looped(DisasterMapConstants.SOUND_FIRE, SoundEvent.LOOP_UNTIL_STOPPED)
	_play(audio, siren)
	var siren_player := audio.sound_loop_player
	assert(audio.sound_loop_id == DisasterStartConstants.SOUND_SIREN and siren_player != null)
	assert((siren_player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "The siren does not loop")

	_play(audio, fire)
	var siren_msec := WaveSounds.duration_ticks(DisasterStartConstants.SOUND_SIREN) * DisasterStartConstants.SIREN_PLAYS * 200.0
	audio.advance(siren_msec - 200.0)
	assert(audio.sound_loop_player == siren_player, "The fire loop did not wait for the five siren plays")
	audio.advance(200.0)
	var fire_player := audio.sound_loop_player
	assert(audio.sound_loop_id == DisasterMapConstants.SOUND_FIRE and fire_player != null and fire_player != siren_player)

	_play(audio, fire)
	audio.advance(60000.0)
	assert(audio.sound_loop_player == fire_player, "A scan that finds fire restarted the fire loop")
	audio.set_volumes(0.0, 0.25)
	assert(is_equal_approx(fire_player.volume_linear, 0.25), "The fire loop kept the old effects volume")
	_play(audio, SoundEvent.stop_loop())
	assert(audio.sound_loop_id == -1 and audio.sound_loop_player == null, "The end of the disaster did not stop the loop")

	_play(audio, fire)
	audio.stop_sound_loop()
	assert(audio.sound_loop_id == -1 and audio.wave_sound_gate.loop_sound_id == -1, "Closing the city kept the loop")
	audio.free()
	# the audio server releases stopped playbacks after a short time
	await create_timer(0.2).timeout
	print("PASS: siren plays, fire loop, volume and stop")
	quit()


func _play(audio: CityAudioController, event: SoundEvent) -> void:
	audio.play_sound_events([event], true, CityViewMode.Mode.CITY, 2, true)
