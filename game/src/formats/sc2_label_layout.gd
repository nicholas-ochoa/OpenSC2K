class_name Sc2LabelLayout
extends RefCounted
## XLAB stores a length byte, up to 23 text bytes, and a zero terminator.

const ORIGINAL_COUNT := 256
const LENGTH_OFFSET := 0
const TEXT_OFFSET := 1
const MAX_TEXT_BYTES := 23
const RECORD_SIZE := TEXT_OFFSET + MAX_TEXT_BYTES + 1
const ORIGINAL_SIZE := ORIGINAL_COUNT * RECORD_SIZE
