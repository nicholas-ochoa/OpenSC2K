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
