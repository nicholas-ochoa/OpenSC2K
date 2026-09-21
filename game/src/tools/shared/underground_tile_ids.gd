class_name UndergroundTileIds
extends RefCounted
## Tile IDs stored in the XUND underground plane.
## Edge labels follow QueryConstants.UNDERGROUND_NAMES.

const EMPTY := 0x00
const SUBWAY_LR := 0x01
const SUBWAY_TB := 0x02
const SUBWAY_HTB := 0x03
const SUBWAY_LHR := 0x04
const SUBWAY_THB := 0x05
const SUBWAY_HLR := 0x06
const SUBWAY_BR := 0x07
const SUBWAY_BL := 0x08
const SUBWAY_TL := 0x09
const SUBWAY_TR := 0x0a
const SUBWAY_RTB := 0x0b
const SUBWAY_LBR := 0x0c
const SUBWAY_TLB := 0x0d
const SUBWAY_LTR := 0x0e
const SUBWAY_LTBR := 0x0f
const PIPE_LR := 0x10
const PIPE_TB := 0x11
const PIPE_HTB := 0x12
const PIPE_LHR := 0x13
const PIPE_THB := 0x14
const PIPE_HLR := 0x15
const PIPE_BR := 0x16
const PIPE_BL := 0x17
const PIPE_TL := 0x18
const PIPE_TR := 0x19
const PIPE_RTB := 0x1a
const PIPE_LBR := 0x1b
const PIPE_TLB := 0x1c
const PIPE_LTR := 0x1d
const PIPE_LTBR := 0x1e
const PIPE_TB_SUBWAY_LR := 0x1f
const PIPE_LR_SUBWAY_TB := 0x20
const UNKNOWN := 0x21
const MISSILE_SILO := 0x22
const SUBWAY_ENTRANCE := 0x23

# Unused XUND values cleared by the native rotation table.
const UNUSED_24 := 0x24
const UNUSED_25 := 0x25
const UNUSED_26 := 0x26
const UNUSED_27 := 0x27
const ROTATION_TABLE_SIZE := 0x28

# Inclusive network bounds.
const SUBWAY_FIRST := SUBWAY_LR
const SUBWAY_LAST := SUBWAY_LTBR
const PIPE_FIRST := PIPE_LR
const PIPE_LAST := PIPE_LTBR
