class_name Sc2AltitudeLayout
extends RefCounted
## ALTM packs land, water, and tunnel levels into a big-endian word.

const LEVEL_MASK := 0x1f
const LAND_MASK := LEVEL_MASK
const WATER_SHIFT := 5
const WATER_MASK := LEVEL_MASK << WATER_SHIFT
const TUNNEL_SHIFT := 10
const TUNNEL_MASK := LEVEL_MASK << TUNNEL_SHIFT
# Model accessors retain all six high bits.
const TUNNEL_FIELD_VALUE_MASK := 0x3f
const TUNNEL_FIELD_MASK := TUNNEL_FIELD_VALUE_MASK << TUNNEL_SHIFT
