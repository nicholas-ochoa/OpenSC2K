class_name PollutionPhase
extends RefCounted

const MAP_SIZE := 64
const FULL_MAP_SIZE := CityState.MAP_SIZE
const VALUE_COUNT := MAP_SIZE * MAP_SIZE
const MISC_CITY_POLLUTION := 0x0034
const MISC_ORDINANCES := 0x0fa0
const MISC_POLLUTION_BONUS := 0x1034
const MISC_SEWER_BONUS := 0x1050
const CLEAN_INDUSTRY_ORDINANCE := 0x00080000
const RADIOACTIVITY := 0x05
const FIRST_POLLUTING_BUILDING := 0x70

# nonzero bytes from the supplied executable table at 0x004e95b8
const BUILDING_POLLUTION := {
	0x84: 6, 0x85: 6, 0x86: 6, 0x87: 6,
	0x9e: 12, 0x9f: 12, 0xa0: 12, 0xa1: 12,
	0xa2: 18, 0xa3: 18, 0xa4: 18, 0xa5: 18,
	0xbc: 24, 0xbd: 24, 0xbe: 24, 0xbf: 24, 0xc0: 24, 0xc1: 24,
	0xc9: 10, 0xca: 25, 0xcb: 2, 0xce: 2, 0xcf: 50,
	0xd7: 4, 0xd8: 10, 0xdc: 2, 0xdd: 10, 0xde: 10, 0xdf: 10,
	0xe0: 5, 0xe3: 5, 0xe4: 5, 0xe5: 5, 0xe6: 10, 0xe7: 10,
	0xe9: 5, 0xec: 3, 0xed: 4, 0xee: 2, 0xef: 2, 0xf0: 2, 0xf1: 2,
	0xf2: 10, 0xf4: 10, 0xf6: 5, 0xfb: 25, 0xfc: 10, 0xfd: 12, 0xfe: 15,
}


static func run(city: CityState) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	var misc_chunk := city.document.find_chunk("MISC")
	var traffic_chunk := city.document.find_chunk("XTRF")
	var pollution_chunk := city.document.find_chunk("XPLT")
	if misc_chunk == null or misc_chunk.decoded_payload.size() != 4800:
		return {"ok": false, "error": "MISC is missing or has the wrong size"}
	if traffic_chunk == null or traffic_chunk.decoded_payload.size() != VALUE_COUNT:
		return {"ok": false, "error": "XTRF is missing or has the wrong size"}
	if pollution_chunk == null or pollution_chunk.decoded_payload.size() != VALUE_COUNT:
		return {"ok": false, "error": "XPLT is missing or has the wrong size"}

	var temporary := PackedInt32Array()
	temporary.resize(VALUE_COUNT)
	for x in MAP_SIZE:
		for y in MAP_SIZE:
			var index := x * MAP_SIZE + y
			var value := int(traffic_chunk.decoded_payload[index] / 5)
			value += pollution_chunk.decoded_payload[index]
			for full_x in range(x * 2, x * 2 + 2):
				for full_y in range(y * 2, y * 2 + 2):
					var building := city.building_id(full_x, full_y)
					if building >= FIRST_POLLUTING_BUILDING:
						value += BUILDING_POLLUTION.get(building, 0)
					if building == RADIOACTIVITY:
						value += 200
			temporary[index] = value

	var base_divisor := (
		city.document.misc_i32(MISC_SEWER_BONUS)
		- city.document.misc_i32(MISC_POLLUTION_BONUS)
		+ 4
	)
	if city.document.misc_u32(MISC_ORDINANCES) & CLEAN_INDUSTRY_ORDINANCE:
		base_divisor += 1
	base_divisor = maxi(base_divisor, 1)

	var pollution := PackedByteArray()
	pollution.resize(VALUE_COUNT)
	var total := 0
	for x in MAP_SIZE:
		for y in MAP_SIZE:
			var index := x * MAP_SIZE + y
			var numerator := temporary[index] * 2
			var divisor := base_divisor
			if x > 0:
				numerator += temporary[(x - 1) * MAP_SIZE + y]
				divisor += 1
			if x < MAP_SIZE - 1:
				numerator += temporary[(x + 1) * MAP_SIZE + y]
				divisor += 1
			if y > 0:
				numerator += temporary[x * MAP_SIZE + y - 1]
				divisor += 1
			if y < MAP_SIZE - 1:
				numerator += temporary[x * MAP_SIZE + y + 1]
				divisor += 1
			var value := mini(int(numerator / divisor), 0xff)
			pollution[index] = value
			total += value

	if not pollution_chunk.set_decoded_payload(pollution):
		return {"ok": false, "error": "cannot store updated XPLT data"}
	if not city.document.set_misc_u32(MISC_CITY_POLLUTION, total):
		return {"ok": false, "error": "cannot store the city pollution total"}
	return {"ok": true, "pollution_total": total, "error": ""}
