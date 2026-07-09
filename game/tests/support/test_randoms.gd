extends RefCounted


class ZeroRandom:
	extends SimRandom


	func next_u15() -> int:
		return 0


class ZeroLfsrRandom:
	extends SimLfsrRandom


	func next_mask(_mask: int) -> int:
		return 0


	func next_mod(_divisor: int) -> int:
		return 0


class NonzeroLfsrRandom:
	extends SimLfsrRandom


	func next_mask(_mask: int) -> int:
		return 1


	func next_mod(divisor: int) -> int:
		return 1 % divisor


class MicrosimLfsrRandom:
	extends SimLfsrRandom


	func next_mask(mask: int) -> int:
		return 0 if mask == 3 else 1


	func next_mod(_divisor: int) -> int:
		return 0


class SequenceLfsrRandom:
	extends SimLfsrRandom

	var values := PackedInt32Array()
	var position := 0


	func _init(initial_values: Array[int]) -> void:
		values = PackedInt32Array(initial_values)


	func next_mask(mask: int) -> int:
		return _next() & mask


	func next_mod(divisor: int) -> int:
		return _next() % divisor


	func _next() -> int:
		if position >= values.size():
			return 1

		var value := int(values[position])
		position += 1

		return value


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


class SequenceModuloRandom:
	extends SimLfsrRandom

	var values := PackedInt32Array()
	var position := 0


	func _init(initial_values: Array[int]) -> void:
		values = PackedInt32Array(initial_values)


	func next_mod(divisor: int) -> int:
		var value := int(values[position]) if position < values.size() else 0
		position += 1

		return value % divisor


class SequenceGameModuloRandom:
	extends GameLcgRandom

	var values := PackedInt32Array()
	var position := 0


	func _init(initial_values: Array[int]) -> void:
		values = PackedInt32Array(initial_values)


	func next_mod(divisor: int) -> int:
		var value := int(values[position]) if position < values.size() else 0
		position += 1

		return value % divisor


class ZeroGameRandom:
	extends GameLcgRandom


	func next_mod(_divisor: int) -> int:
		return 0


class NonzeroGameRandom:
	extends GameLcgRandom


	func next_mod(divisor: int) -> int:
		return 1 % divisor


class SequenceGameRandom:
	extends GameLcgRandom

	var values := PackedInt32Array()
	var position := 0


	func _init(initial_values: Array[int]) -> void:
		values = PackedInt32Array(initial_values)


	func next_mod(divisor: int) -> int:
		return _next() % divisor


	func _next() -> int:
		if position >= values.size():
			return 1

		var value := int(values[position])
		position += 1

		return value
