class_name GameLcgRandom
extends RefCounted

const MULTIPLIER := 1103515245
const INCREMENT := 12345

var state := 1


func _init(seed := 1) -> void:
	state = int(seed) & 0xffffffff


func next_mod(divisor: int) -> int:
	if divisor <= 0:
		return 0

	state = (state * MULTIPLIER + INCREMENT) & 0xffffffff

	return ((state >> 16) & 0x7fff) % divisor
