class_name SimulationDayPhases
extends RefCounted
# Pairs scheduled action names with phases. Add new actions here and
# in simulation_clock.gd.

const Budget = preload("res://src/simulation/core/engine/day_phases/budget.gd")
const Power = preload("res://src/simulation/core/engine/day_phases/power.gd")
const Growth = preload("res://src/simulation/core/engine/day_phases/growth.gd")
const RciDemand = preload("res://src/simulation/core/engine/day_phases/rci_demand.gd")
const EducationHealth = preload("res://src/simulation/core/engine/day_phases/education_health.gd")
const WeatherDisaster = preload("res://src/simulation/core/engine/day_phases/weather_disaster.gd")

# built once on load. the phases hold no mutable state, so the simulation
# worker and the main thread can share them
static var _table: Dictionary[String, SimulationDayPhase] = _build_table()


# the action name that `SimulationClock` emits, and the phase that runs it
static func table() -> Dictionary[String, SimulationDayPhase]:
	return _table


static func _build_table() -> Dictionary[String, SimulationDayPhase]:
	return {
		"month_start": MonthStart.new(),
		"budget": Budget.new(),
		"power": Power.new(),
		"growth": Growth.new(),
		"pollution_terrain_land_value": DataMaps.new(),
		"water": Water.new(),
		"traffic": Traffic.new(),
		"rci_demand": RciDemand.new(),
		"education_health": EducationHealth.new(),
		"graphs": Graphs.new(),
		"milestones": Milestones.new(),
		"scenario": Scenario.new(),
		"bankruptcy": Bankruptcy.new(),
		"statistics_windows": Refresh.new(["population", "industries", "graphs"]),
		"map": Refresh.new(["toolbar", "map"]),
		"simnation": Refresh.new(["simnation"]),
		"weather_disaster": WeatherDisaster.new(),
	}


class MonthStart extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var month_start := MonthStartPhase.run(context.city)

		if not month_start.ok:
			return month_start

		return context.record(context.action, month_start)


class DataMaps extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var scan: PollutionPhase.Result

		if context.city.document.full_resolution_maps():
			scan = NativeDataMapPhase.run_land_value_and_crime(context.city)
		else:
			scan = PollutionPhase.run(context.city)

		if not scan.ok:
			return scan

		var stored := context.record(context.action, scan)

		if not stored.ok:
			return stored

		context.developed_tiles = scan.developed_tiles

		return scan


class Water extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var water := WaterPhase.run(context.city)

		if not water.ok:
			return water

		var stored := context.record(context.action, water)

		if not stored.ok:
			return stored

		context.water_usage_percent = water.usage_percent

		return water


class Traffic extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var traffic := TrafficPhase.run(context.city)

		if not traffic.ok:
			return traffic

		return context.record(context.action, traffic)


class Graphs extends SimulationDayPhase:
	func is_ready(context: SimulationPhaseContext) -> bool:
		return (
			context.developed_tiles >= 0
			and context.power_usage_percent >= 0
			and context.water_usage_percent >= 0
		)

	func run(context: SimulationPhaseContext) -> PhaseResult:
		var graphs := GraphHistory.run(
			context.city,
			context.developed_tiles,
			context.power_usage_percent,
			context.water_usage_percent
		)

		if not graphs.ok:
			return graphs

		return context.record(context.action, graphs)


class Milestones extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var milestones := MilestonePhase.run(context.city)

		if not milestones.ok:
			return milestones

		var stored := context.record(context.action, milestones)

		if not stored.ok:
			return stored

		if milestones.military_proposal_pending:
			context.interaction_request = SimulationInteractionRequest.military_proposal()

		return milestones


class Scenario extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var check := ScenarioPhase.run(context.scenario, context.city)

		if not check.ok:
			return check

		return context.record(context.action, check)


class Bankruptcy extends SimulationDayPhase:
	func run(context: SimulationPhaseContext) -> PhaseResult:
		var bankruptcy := BankruptcyPhase.run(context.city)

		if not bankruptcy.ok:
			return bankruptcy

		return context.record(context.action, bankruptcy)


# an action that only asks the interface to refresh
class Refresh extends SimulationDayPhase:
	var requests: Array[String]

	func _init(refresh_requests: Array[String]) -> void:
		requests = refresh_requests

	func run(context: SimulationPhaseContext) -> PhaseResult:
		return context.record(context.action, PhaseResult.refreshing(requests))
