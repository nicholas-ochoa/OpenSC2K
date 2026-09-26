extends SimulationDayPhase


func run(context: SimulationPhaseContext) -> PhaseResult:
	var music_span := SimulationTimingSpan.new(context.city.simulation_slice)
	music_span.mark("music choice")
	var playback_was_active := context.midi_playback_active
	var selected := MusicDirector.monthly_track(
		context.city.simulation_speed(), playback_was_active, context.random
	)
	var requests := PackedInt32Array()

	if selected >= MusicDirector.FIRST_TRACK_ID:
		requests.append(selected)

		if context.city.music_enabled():
			context.midi_playback_active = true

	var music := context.record(
		"music", MonthlyMusicResult.selected(playback_was_active, requests)
	)

	if not music.ok:
		return music

	var music_timing := music_span.finish()
	var demand := RciDemandPhase.run(context.city)

	if not demand.ok:
		return demand

	# the music choice runs first in the demand action. show it as the first demand step
	music_timing.steps.merge(demand.timing.steps)
	demand.timing.steps = music_timing.steps
	demand.timing.work_usec += music_timing.work_usec

	var stored := context.record(context.action, demand)

	if not stored.ok:
		return stored

	context.span.mark("rci_aftermath")
	var aftermath := RciAftermathPhase.run(
		context.city, context.random, int(context.schedule.season)
	)

	if not aftermath.ok:
		return aftermath

	return context.record("rci_aftermath", aftermath)
