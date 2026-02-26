class_name SimLfsrRandom
extends RefCounted

# this lfsr has its own state; don't merge it with the other random generators
const FEEDBACK := 0x1bf5

var state := 1


func _init(seed := 1) -> void:
	state = int(seed) & 0xffff


func next_word() -> int:
	if state & 0x8000:
		state = ((state << 1) ^ FEEDBACK) & 0xffff
	else:
		state = (state << 1) & 0xffff

	return state


func next_mask(mask: int) -> int:
	return next_word() & mask


func next_mod(divisor: int) -> int:
	if divisor <= 0:
		return 0

	return next_word() % divisor
