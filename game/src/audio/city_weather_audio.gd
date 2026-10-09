class_name CityWeatherAudio
extends RefCounted
## Streaming rain/wind ambience and at most three thunder tails. No simulation state.

const RAIN := [preload("res://assets/audio/weather/rain_light.ogg"), preload("res://assets/audio/weather/rain_heavy.ogg")]
const THUNDER := [preload("res://assets/audio/weather/thunder_0.ogg"), preload("res://assets/audio/weather/thunder_1.ogg"),
	preload("res://assets/audio/weather/thunder_2.ogg"), preload("res://assets/audio/weather/thunder_3.ogg"),
	preload("res://assets/audio/weather/thunder_4.ogg")]
const WIND := preload("res://assets/audio/weather/storm_wind.ogg")
const MAX_THUNDER := 3

var app: CityApplication
var rain_players: Array[AudioStreamPlayer] = []
var thunder_players: Array[AudioStreamPlayer] = []
var rain_gains := Vector2.ZERO
var storm_gain := 0.0
var wind_gain := 0.0
var wind_player: AudioStreamPlayer


func _init(application: CityApplication) -> void:
	app = application


func allowed() -> bool:
	var audio := app.audio_controller
	var city := app.document_state.city
	return audio != null and audio.is_inside_tree() and audio.audio_allowed() and audio.effects_volume > 0.0 and city != null and city.sound_enabled()


func reset() -> void:
	for player in rain_players + thunder_players + [wind_player]:
		_dispose(player)
	rain_players.clear()
	thunder_players.clear()
	rain_gains = Vector2.ZERO
	storm_gain = 0.0
	wind_gain = 0.0
	wind_player = null


func update(delta: float, enabled: bool, rain: float, storm: bool, paused := false, dry_storm_strength := 0.0) -> void:
	if not enabled or not allowed():
		reset()
		return
	for player in rain_players + thunder_players + [wind_player]:
		if _alive(player):
			player.stream_paused = paused
	if paused:
		return
	var intensity := clampf(rain, 0.0, 1.0)
	var blend := smoothstep(0.2, 0.9, intensity)
	var level := smoothstep(0.0, 0.28, intensity)
	# Equal-power crossfade; heavy rain has a denser recording and a higher gain.
	var target := Vector2(sqrt(1.0 - blend) * 0.34, sqrt(blend) * 0.58) * level
	rain_gains = rain_gains.move_toward(target, maxf(delta, 0.0) * 0.45)
	storm_gain = move_toward(storm_gain, 1.0 if storm else 0.0, maxf(delta, 0.0) * 2.0)
	wind_gain = move_toward(wind_gain, clampf(dry_storm_strength, 0.0, 1.0) * 0.7, maxf(delta, 0.0) * 0.45)
	var audio := app.audio_controller
	if wind_gain > 0.0001:
		if not _alive(wind_player):
			wind_player = _player(WIND)
			wind_player.volume_linear = 0.0
			wind_player.play()
		wind_player.volume_linear = wind_gain * audio.effects_volume
	else:
		_dispose(wind_player)
		wind_player = null
	if rain_gains.length_squared() > 0.000001:
		while rain_players.size() < RAIN.size():
			rain_players.append(null)
		for i in RAIN.size():
			if not _alive(rain_players[i]):
				rain_players[i] = _player(RAIN[i])
				rain_players[i].volume_linear = 0.0
				rain_players[i].play()
			rain_players[i].volume_linear = rain_gains[i] * audio.effects_volume
	else:
		for player in rain_players:
			_dispose(player)
		rain_players.clear()
	for i in range(thunder_players.size() - 1, -1, -1):
		var player := thunder_players[i]
		if not _alive(player):
			thunder_players.remove_at(i)
		elif storm_gain <= 0.0:
			_dispose(player)
			thunder_players.remove_at(i)
		else:
			player.volume_linear = float(player.get_meta("weather_gain")) * audio.effects_volume * storm_gain


func play_thunder(discharge: CityLightning, strength: float) -> void:
	if not allowed() or strength <= 0.0 or discharge.sound_index < 0:
		return
	# The cap also covers very long samples and repeated debug previews.
	while thunder_players.size() >= MAX_THUNDER:
		_dispose(thunder_players.pop_front())
	var player := _player(THUNDER[discharge.sound_index])
	var gain := discharge.gain * clampf(strength, 0.0, 1.0)
	player.set_meta("weather_gain", gain)
	player.pitch_scale = discharge.pitch
	player.volume_linear = gain * app.audio_controller.effects_volume * storm_gain
	player.finished.connect(player.queue_free)
	thunder_players.append(player)
	player.play()


func _player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	app.audio_controller.add_child(player)
	player.add_to_group(CityAudioController.SOUND_EFFECT_GROUP)
	return player


static func _alive(player: Variant) -> bool:
	# The shared effects controller can free a player before our next frame.
	return is_instance_valid(player) and not player.is_queued_for_deletion()


static func _dispose(player: Variant) -> void:
	if _alive(player):
		player.stop()
		player.queue_free()
