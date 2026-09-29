class_name MaxisManResponse
extends RefCounted

const ARRIVAL_SOUND := 513


static func apply(city: CityState, started: DisasterStartResult, random: SimRandom, lfsr_random: SimLfsrRandom) -> DisasterStartResult:
	if not started.ok or not started.started:
		return started

	var arrival: DisasterStartResult.MaxisManArrival = NativeSimulationBridge.run("maxis_man", city, random, lfsr_random, null, {
		"point": started.point, "disaster_type": started.disaster_type, "record": started.record,
	}).result

	if arrival == null:
		return started

	started.maxis_man_response = arrival
	started.sound_events.append(SoundEvent.new(ARRIVAL_SOUND))
	started.view_center_requests.append(arrival.point)

	return started
