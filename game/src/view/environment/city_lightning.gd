class_name CityLightning
extends RefCounted
## One cosmetic discharge, its return strokes and its delayed thunder.
## This generator is independent of both the simulation and weather selection.

var random := RandomNumberGenerator.new()
var wait := 4.0
var thunder_wait := -1.0
var flash := 0.0
var origin := Vector2(0.5, -0.15)
var spread := 0.8
var color := Color(0.87, 0.93, 1.0)
var distance := 1000.0
var sound_index := -1
var pitch := 1.0
var gain := 0.0
var age := 10.0
var pulses: Array[Vector3] = []
var bag: Array[int] = []


func _init() -> void:
	random.randomize()


func reset() -> void:
	wait = 4.0
	thunder_wait = -1.0
	flash = 0.0
	age = 10.0
	pulses.clear()


func advance(delta: float, enabled: bool, strength: float) -> bool:
	if not enabled or strength <= 0.0:
		reset()
		return false

	var elapsed := maxf(delta, 0.0)
	var thunder_due := false
	if thunder_wait >= 0.0:
		thunder_wait -= elapsed
		if thunder_wait < 0.0:
			thunder_due = true
	# A long suspended frame must not emit several catch-up discharges.
	wait -= elapsed
	age += elapsed
	if wait <= 0.0 and not thunder_due:
		_begin()
	flash = 0.0
	for pulse in pulses:
		var time := age - pulse.x
		if time >= 0.0 and time < pulse.y:
			var attack := minf(time / 0.008, 1.0)
			var decay := pow(1.0 - time / pulse.y, 2.0)
			flash = maxf(flash, attack * decay * pulse.z * strength)
	return thunder_due


func _begin() -> void:
	if bag.is_empty():
		bag.assign([0, 1, 2, 3, 4])
		for i in range(bag.size() - 1, 0, -1):
			var other := random.randi_range(0, i)
			var value := bag[i]
			bag[i] = bag[other]
			bag[other] = value
		if bag.back() == sound_index:
			var value := bag[0]
			bag[0] = bag.back()
			bag[bag.size() - 1] = value
	sound_index = bag.pop_back()
	var nearby := sound_index < 2
	var distant := sound_index == 4
	distance = random.randf_range(250.0, 650.0) if nearby else random.randf_range(900.0, 1800.0)
	if distant:
		distance = random.randf_range(2000.0, 3200.0)
	thunder_wait = distance / 343.0
	wait = thunder_wait + random.randf_range(9.0, 20.0)
	pitch = random.randf_range(0.94, 1.04) if nearby else random.randf_range(0.88, 0.98)
	gain = 0.65 if nearby else (0.3 if distant else 0.46)
	origin = Vector2(random.randf_range(-0.25, 1.25), random.randf_range(-0.4, 0.25))
	spread = random.randf_range(0.45, 0.75) if nearby else random.randf_range(0.85, 1.3)
	color = Color(0.9, 0.94, 1.0) if nearby else Color(0.79, 0.85, 1.0)
	age = 0.008
	pulses.clear()
	var amplitude := random.randf_range(0.65, 0.95) if nearby else random.randf_range(0.3, 0.6)
	pulses.append(Vector3(0.0, random.randf_range(0.1, 0.22), amplitude))
	# Individual, rolling sheet and multiple return-stroke discharges.
	var count := random.randi_range(1, 3) if nearby else random.randi_range(0, 2)
	var onset := 0.0
	for i in count:
		onset += random.randf_range(0.16, 0.3)
		pulses.append(Vector3(onset, random.randf_range(0.08, 0.18), amplitude * random.randf_range(0.4, 0.85)))
