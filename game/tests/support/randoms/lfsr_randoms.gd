extends RefCounted


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
