class_name Sc2OverlayLayout
extends RefCounted
## XTXT IDs link signs, facilities, and things. SC2X adds disjoint 16-bit ranges.

const ORIGINAL_SIGN_FIRST := 1
const ORIGINAL_SIGN_LAST := 50
const ORIGINAL_SIGN_COUNT := ORIGINAL_SIGN_LAST - ORIGINAL_SIGN_FIRST + 1
const ORIGINAL_FACILITY_FIRST := ORIGINAL_SIGN_LAST + 1
const ORIGINAL_FACILITY_LAST := ORIGINAL_FACILITY_FIRST + Sc2MicrosimLayout.ORIGINAL_COUNT - 1
const ORIGINAL_THING_FIRST := ORIGINAL_FACILITY_LAST + 1
const ORIGINAL_THING_LAST := ORIGINAL_THING_FIRST + Sc2ThingLayout.ORIGINAL_COUNT - 1
const ORIGINAL_RESERVED_FIRST := ORIGINAL_THING_LAST + 1
const ORIGINAL_MAX_ID := 0xff
const CONNECTION_MARKER := 0xfa
const EXTRA_FACILITY := ORIGINAL_MAX_ID + 1
const EXTRA_SIGN := 4096
const EXTRA_THING := 8192
# facility records past the 3,990 of the extra range: only the 2048 and 4096
# tile maps of SC2X version 4 reach them. Moving objects end below this ID
const EXTRA_FACILITY_HIGH := 16384
const HIGH_FACILITY_FIRST_RECORD := Sc2MicrosimLayout.ORIGINAL_COUNT + EXTRA_SIGN - EXTRA_FACILITY


# extra facility ids end below EXTRA_SIGN. only 1024 tile cities reach this cap
static func facility_capacity(factor: int) -> int:
	return mini(Sc2MicrosimLayout.ORIGINAL_COUNT * factor, Sc2MicrosimLayout.ORIGINAL_COUNT + EXTRA_SIGN - EXTRA_FACILITY)
