extends RefCounted


class ZeroRandom:
	extends SimRandom


	func next_u15() -> int:
		return 0


class SequenceRandom:
	extends SimRandom

	var values := PackedInt32Array()
	var position := 0


	func _init(initial_values: Array[int]) -> void:
		values = PackedInt32Array(initial_values)


	func next_u15() -> int:
		if position >= values.size():
			return 1

		var value := int(values[position])
		position += 1

		return value


class SparseRandom:
	extends SimRandom

	var values := {}
	var default_value := 1
	var position := 0


	func _init(initial_values: Dictionary, fallback := 1) -> void:
		values = initial_values.duplicate()
		default_value = fallback


	func next_u15() -> int:
		var value := int(values.get(position, default_value))
		position += 1

		return value


class CountingRandom:
	extends SimRandom

	var position := 0


	func next_u15() -> int:
		position += 1

		return position & 0x7fff
