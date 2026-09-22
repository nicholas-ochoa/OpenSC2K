class_name Sc2BudgetLayout
extends RefCounted
## MISC budget records; each month stores a count and a funding rate.

const COUNT := 16
const RECORD_SIZE := 0x006c
const CURRENT := 0x00
const FUNDING := 0x04
const YEAR_TO_DATE := 0x08
const MONTHS := 0x0c
const MONTH_RECORD_SIZE := 8
const MONTH_FUNDING := 4

const RESIDENTIAL := 0
const COMMERCIAL := 1
const INDUSTRIAL := 2
const ORDINANCES := 3
const BONDS := 4
const POLICE := 5
const FIRE := 6
const HEALTH := 7
const SCHOOL := 8
const COLLEGE := 9
const ROAD := 10
const HIGHWAY := 11
const BRIDGE := 12
const RAIL := 13
const SUBWAY := 14
const TUNNEL := 15
