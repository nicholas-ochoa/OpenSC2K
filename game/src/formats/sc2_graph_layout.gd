class_name Sc2GraphLayout
extends RefCounted
## XGRP stores sixteen series of big-endian values in three history periods.

const SERIES_COUNT := 16
const VALUE_SIZE := 4
const YEAR_OFFSET := 0
const YEAR_COUNT := 12
const DECADE_OFFSET := YEAR_OFFSET + YEAR_COUNT
const DECADE_COUNT := 20
const CENTURY_OFFSET := DECADE_OFFSET + DECADE_COUNT
const CENTURY_COUNT := 20
const VALUES_PER_SERIES := CENTURY_OFFSET + CENTURY_COUNT
const SERIES_SIZE := VALUES_PER_SERIES * VALUE_SIZE
const SIZE := SERIES_COUNT * SERIES_SIZE
