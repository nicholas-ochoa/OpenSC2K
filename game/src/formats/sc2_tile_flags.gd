class_name Sc2TileFlags
extends RefCounted
## XBIT flags. MARK is temporary simulation workspace.

const SALT_WATER := 0x01
const FLIPPED := 0x02
const WATER := 0x04
const MARK := 0x08
const WATERED := 0x10
const PIPED := 0x20
const POWERED := 0x40
const POWERABLE := 0x80
const POWER_MASK := POWERED | POWERABLE
const STRUCTURE_MASK := PIPED | POWER_MASK
const UTILITY_MASK := WATERED | STRUCTURE_MASK


# a copy of `flags` with `bits` cleared in every tile. the loop clears eight
# tiles in each step, which is much faster than a loop over single bytes
static func without(flags: PackedByteArray, bits: int) -> PackedByteArray:
	var keep := ~bits & 0xff
	var mask := 0

	for shift in range(0, 64, 8):
		mask |= keep << shift

	var whole := flags.size() & ~7
	var words := flags.slice(0, whole).to_int64_array()

	for index in words.size():
		words[index] &= mask

	var result := words.to_byte_array()

	for index in range(whole, flags.size()):
		result.append(flags[index] & keep)

	return result
