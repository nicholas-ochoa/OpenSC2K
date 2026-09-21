class_name TerrainTileIds
extends RefCounted
## Saved XTER tile IDs. Building IDs and sprite offsets use separate catalogs.
## Dry slopes name raised screen corners, as in IsometricConstants.
## Surface-water suffixes name connected map edges (N: -y, E: +x).
## BANK names identify a missing diagonal water neighbor.
## Water connections follow LandscapeCommand._water_shape, not dry corner masks.

const FLAT := 0x00
const SLOPE_TOP_LEFT := 0x01
const SLOPE_TOP_RIGHT := 0x02
const SLOPE_BOTTOM_RIGHT := 0x03
const SLOPE_BOTTOM_LEFT := 0x04
const RAISED_EXCEPT_BOTTOM := 0x05
const RAISED_EXCEPT_LEFT := 0x06
const RAISED_EXCEPT_TOP := 0x07
const RAISED_EXCEPT_RIGHT := 0x08
const CORNER_TOP := 0x09
const CORNER_RIGHT := 0x0a
const CORNER_BOTTOM := 0x0b
const CORNER_LEFT := 0x0c
const RAISED := 0x0d
const UNUSED_0E := 0x0e
const UNUSED_0F := 0x0f

const DEEP_WATER_FLAT := 0x10
const DEEP_WATER_SLOPE_TOP_LEFT := 0x11
const DEEP_WATER_SLOPE_TOP_RIGHT := 0x12
const DEEP_WATER_SLOPE_BOTTOM_RIGHT := 0x13
const DEEP_WATER_SLOPE_BOTTOM_LEFT := 0x14
const DEEP_WATER_RAISED_EXCEPT_BOTTOM := 0x15
const DEEP_WATER_RAISED_EXCEPT_LEFT := 0x16
const DEEP_WATER_RAISED_EXCEPT_TOP := 0x17
const DEEP_WATER_RAISED_EXCEPT_RIGHT := 0x18
const DEEP_WATER_CORNER_TOP := 0x19
const DEEP_WATER_CORNER_RIGHT := 0x1a
const DEEP_WATER_CORNER_BOTTOM := 0x1b
const DEEP_WATER_CORNER_LEFT := 0x1c
const DEEP_WATER_RAISED := 0x1d

const SHORE_FLAT := 0x20
const SHORE_SLOPE_TOP_LEFT := 0x21
const SHORE_SLOPE_TOP_RIGHT := 0x22
const SHORE_SLOPE_BOTTOM_RIGHT := 0x23
const SHORE_SLOPE_BOTTOM_LEFT := 0x24
const SHORE_RAISED_EXCEPT_BOTTOM := 0x25
const SHORE_RAISED_EXCEPT_LEFT := 0x26
const SHORE_RAISED_EXCEPT_TOP := 0x27
const SHORE_RAISED_EXCEPT_RIGHT := 0x28
const SHORE_CORNER_TOP := 0x29
const SHORE_CORNER_RIGHT := 0x2a
const SHORE_CORNER_BOTTOM := 0x2b
const SHORE_CORNER_LEFT := 0x2c
const SHORE_RAISED := 0x2d
const UNUSED_1E := 0x1e
const UNUSED_1F := 0x1f
const FORBIDDEN_COAST := 0x2e
const UNUSED_2F := 0x2f

const SURFACE_WATER_OPEN := 0x30
const SURFACE_WATER_NES := 0x31
const SURFACE_WATER_ESW := 0x32
const SURFACE_WATER_NSW := 0x33
const SURFACE_WATER_NEW := 0x34
const SURFACE_WATER_ES := 0x35
const SURFACE_WATER_SW := 0x36
const SURFACE_WATER_NW := 0x37
const SURFACE_WATER_NE := 0x38
const SURFACE_WATER_BANK_NW := 0x39
const SURFACE_WATER_BANK_NE := 0x3a
const SURFACE_WATER_BANK_SE := 0x3b
const SURFACE_WATER_BANK_SW := 0x3c
const SURFACE_WATER_POND := 0x3d
const WATERFALL := 0x3e
const UNUSED_3F := 0x3f

const CHANNEL_NS := 0x40
const CHANNEL_EW := 0x41
const CHANNEL_E := 0x42
const CHANNEL_S := 0x43
const CHANNEL_W := 0x44
const CHANNEL_N := 0x45
const UNUSED_46 := 0x46
const UNUSED_47 := 0x47

# The native range checks include unused codes. Keep those bounds intact.
const LAND_FIRST := FLAT
const LAND_LAST := UNUSED_0F
const LAND_DRAW_LAST := UNUSED_0E
const DEEP_WATER_FIRST := DEEP_WATER_FLAT
const DEEP_WATER_LAST := UNUSED_1F
const DEEP_WATER_DRAW_LAST := UNUSED_1E
const SHORE_FIRST := SHORE_FLAT
const SHORE_LAST := UNUSED_2F
const SURFACE_WATER_FIRST := SURFACE_WATER_OPEN
const SURFACE_WATER_LAST := UNUSED_3F
const CHANNEL_FIRST := CHANNEL_NS
const CHANNEL_LAST := CHANNEL_N
const WATER_RANGE_LAST := 0x4f
const ROTATION_TABLE_SIZE := 0x48
const SHAPE_MASK := 0x0f
const GROUP_MASK := 0xf0
