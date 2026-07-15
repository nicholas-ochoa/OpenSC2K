class_name BankruptcyPhase
extends RefCounted

const BANKRUPTCY_LIMIT := -100000


class Result extends PhaseResult:
	var bankrupt := false
	var funds := 0


static func run(city: CityState) -> Result:
	if city == null or not city.is_valid():
		return _failed("city is invalid")

	var funds := city.funds()
	var bankrupt := funds < BANKRUPTCY_LIMIT
	var events: Array[Dictionary] = []

	if bankrupt:
		events.append({"type": "bankruptcy", "funds": funds})

	var result := Result.new()
	result.ok = true
	result.bankrupt = bankrupt
	result.funds = funds
	result.game_over_events = events

	return result


static func _failed(message: String) -> Result:
	var result := Result.new()
	result.error = message

	return result
