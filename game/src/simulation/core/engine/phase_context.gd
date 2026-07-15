class_name SimulationPhaseContext
extends RefCounted
# The schedule copies ENGINE_STATE from the engine, then writes it back
# after each action. Keep these names in SimulationSnapshot.ENGINE_FIELDS
# so snapshots include all simulation state.

# engine state that a scheduled phase may read or write
const ENGINE_STATE := [
	"developed_tiles", "power_usage_percent", "water_usage_percent",
	"bus_passengers", "rail_passengers", "subway_passengers", "ship_home",
	"city_status_resource_id", "commerce_connections", "industry_connections",
	"mayor_approval", "midi_playback_active", "pending_disaster_type",
	"pending_disaster_point", "terminal_state",
]

# simulation inputs. the day schedule owns these objects
var city: CityState
var random: SimRandom
var lfsr_random: SimLfsrRandom
var game_random: GameLcgRandom
var scenario: ScenarioState
var span: SimulationTimingSpan
var schedule: Dictionary = {}
var annual_budget_approved := false

# the action being run, which names its result
var action := ""

# results in completion order. the controller reads the events in this order
var phase_results: Dictionary = {}

# set by a phase that must stop the day and ask the player a question
var interaction_request: Dictionary = {}

# engine state. see engine_state
var developed_tiles := -1
var power_usage_percent := -1
var water_usage_percent := -1
var bus_passengers := 0
var rail_passengers := 0
var subway_passengers := 0
var ship_home := Vector2i(-1, -1)
var city_status_resource_id := -1
var commerce_connections := 0
var industry_connections := 0
var mayor_approval := 0
var midi_playback_active := false
var pending_disaster_type := 0
var pending_disaster_point := Vector2i.ZERO
var terminal_state := false


# store a finished result under `name` and persist its newspaper stories
# returns the stored result, or a failed result when the queue write fails
func record(name: String, result: PhaseResult) -> PhaseResult:
	var persisted := persist_news(city, result)

	if not persisted.ok:
		return failed(persisted.error)

	phase_results[name] = result

	return result


# insert the stories of one result into the saved newspaper queue
static func persist_news(city: CityState, result: PhaseResult) -> Dictionary:
	if result.news_queue_updated:
		return {"ok": true, "error": "", "inserted": 0}

	if result.news_items.is_empty():
		return {"ok": true, "error": "", "inserted": 0}

	var misc_chunk := city.document.find_chunk("MISC")

	if misc_chunk == null or misc_chunk.decoded_payload.size() != NewsQueue.MISC_SIZE:
		return {"ok": false, "error": "MISC is missing or has the wrong size"}

	var misc: PackedByteArray = misc_chunk.decoded_payload.duplicate()
	var insertion := NewsQueue.insert_items(misc, result.news_items)

	if not insertion.ok:
		return insertion

	if insertion.inserted == 0:
		return insertion

	if not misc_chunk.set_decoded_payload(misc):
		return {"ok": false, "error": "cannot store newspaper stories"}

	result.news_queue_updated = true
	result.news_queue_inserted = insertion.inserted

	return insertion


static func failed(message: String) -> PhaseResult:
	var result := PhaseResult.new()
	result.error = message

	return result
