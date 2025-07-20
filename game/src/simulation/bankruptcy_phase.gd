class_name BankruptcyPhase
extends RefCounted

const BANKRUPTCY_LIMIT := -100000


static func run(city: CityState) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	var funds := city.funds()
	var bankrupt := funds < BANKRUPTCY_LIMIT
	var events: Array[Dictionary] = []
	if bankrupt:
		events.append({"type": "bankruptcy", "funds": funds})
	return {
		"ok": true,
		"error": "",
		"bankrupt": bankrupt,
		"funds": funds,
		"game_over_events": events,
		"complete": true,
	}
