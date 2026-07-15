class_name SimulationDayPhase
extends RefCounted
# run records results in completion order and returns the last one.
# The action stays pending until that result is complete.


# false when the action cannot run yet and must stay pending for this day
func is_ready(_context: SimulationPhaseContext) -> bool:
	return true


func run(_context: SimulationPhaseContext) -> PhaseResult:
	return SimulationPhaseContext.failed("the phase does nothing")
