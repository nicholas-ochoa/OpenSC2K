class_name SimRandom
extends RefCounted

const MULTIPLIER := 214013
const INCREMENT := 2531011

var state := 1


func _init(seed := 1) -> void:
	state = int(seed) & 0xffffffff


func next_u15() -> int:
	state = (state * MULTIPLIER + INCREMENT) & 0xffffffff

	return (state >> 16) & 0x7fff
