class_name MaxisRle
extends RefCounted
## The Maxis run-length code of compressed city chunks. The native simulation
## library runs the codec; see native/core/sim/src/formats/rle.rs.


static func decode(encoded: PackedByteArray, expected_size: int = -1) -> BinaryResult:
	var decoded: Dictionary = NativeMaxisRle.decode(encoded, expected_size)

	if not decoded.ok:
		return BinaryResult.failure(decoded.error)

	var outcome := BinaryResult.new()
	outcome.ok = true
	outcome.data = decoded.data
	outcome.error = ""

	return outcome


static func encode(decoded: PackedByteArray) -> PackedByteArray:
	return NativeMaxisRle.encode(decoded)
