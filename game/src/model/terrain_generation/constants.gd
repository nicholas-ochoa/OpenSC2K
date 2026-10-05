class_name NewTerrainConstants
extends RefCounted
## The New City terrain settings. The native simulation library makes the
## terrain; see native/core/sim/src/sim/new_city.

const LAYOUTS := [
	"classic",
	"meander",
	"delta",
	"peninsula",
	"crossing",
	"branch",
	"rejoin",
	"bay",
	"island",
	"islands",
	"plateau",
	"ridge",
	"valley",
	"rolling",
	"basin",
	"canyon",
	"cliffs",
	"lake",
	"lakes",
]
const MISC_SIZE := Sc2MiscLayout.SIZE
const MISC_TILE_COUNTS := Sc2MiscLayout.TILE_COUNTS
const MISC_WATER_LEVEL := Sc2MiscLayout.WATER_LEVEL
const MISC_HAS_OCEAN := Sc2MiscLayout.HAS_OCEAN
const MISC_HAS_RIVER := Sc2MiscLayout.HAS_RIVER
const MIN_SLIDER := 0
const MAX_SLIDER := 47
const DEFAULT_OCEAN := false
const DEFAULT_RIVER := true
const DEFAULT_HILLS := 12
const DEFAULT_WATER := 5
const DEFAULT_TREES := 15
