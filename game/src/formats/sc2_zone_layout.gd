class_name Sc2ZoneLayout
extends RefCounted
## XZON stores the zone type below the building corners.

const TYPE_MASK := 0x0f
const CORNERS_MASK := 0xf0
const MILITARY := 7
const CORNER_BOTTOM_LEFT := [0x10, 0x20, 0x40, 0x80]
const CORNER_BOTTOM_RIGHT := [0x20, 0x40, 0x80, 0x10]
const CORNER_TOP_LEFT := [0x40, 0x80, 0x10, 0x20]
const CORNER_TOP_RIGHT := [0x80, 0x10, 0x20, 0x40]
