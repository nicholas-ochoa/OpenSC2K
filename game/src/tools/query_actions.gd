class_name QueryActions
extends RefCounted

const FIRST_BUILDING := 0x0d
const CATEGORY_COUNT := 12
const CATEGORY_RESOURCE_BASE := 988
const MISC_TILE_COUNTS := 0x01f0
const FIRST_MICROSIM_LABEL := 51
const LAST_MICROSIM_LABEL := 200

const TILE_UPPER_BOUNDS := [
	0x0e,
	0x1d,
	0x70,
	0x7c,
	0x84,
	0x88,
	0x8c,
	0x94,
	0x9e,
	0xa6,
	0xae,
	0xb2,
	0xbc,
	0xc2,
	0xc6,
	0xd0,
	0xd4,
	0xd5,
	0xd6,
	0xd7,
	0xd8,
	0xd9,
	0xda,
	0xdc,
	0xdd,
	0xe9,
	0xeb,
	0xec,
	0xee,
	0xf3,
	0xf4,
	0xf5,
	0xf6,
	0xf7,
	0xf8,
	0xf9,
	0xfa,
	0xfb,
	0xff,
	0x00,
]

const CATEGORY_BY_RANGE := [
	10,
	2,
	1,
	4,
	5,
	6,
	0,
	4,
	5,
	6,
	0,
	4,
	5,
	6,
	0,
	2,
	9,
	8,
	10,
	8,
	10,
	9,
	8,
	10,
	3,
	7,
	1,
	3,
	1,
	7,
	0,
	3,
	8,
	7,
	4,
	10,
	7,
	3,
	11,
	10,
]

const FALLBACK_CATEGORY_NAMES := [
	"",
	"Transportation",
	"Power",
	"Water",
	"Residential",
	"Commercial",
	"Industrial",
	"Ports and airports",
	"Education",
	"Health and safety",
	"Recreation",
	"Arcologies",
]


static func rename_facility(
	city: CityState, info: Dictionary, value: String
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	if info.get("kind", "") != "specific":
		return {"ok": false, "error": "query does not select a facility"}
	var overlay_id := int(info.get("overlay_id", 0))
	var point: Vector2i = info.get("point", Vector2i(-1, -1))
	if not OverlayData.is_facility(overlay_id):
		return {"ok": false, "error": "facility label is invalid"}
	if city.text_overlay_id(point.x, point.y) != overlay_id:
		return {"ok": false, "error": "queried facility has changed"}
	var old_value := city.label(overlay_id)
	if not city.set_label(overlay_id, value):
		return {"ok": false, "error": "cannot store facility name"}
	return {
		"ok": true,
		"overlay_id": overlay_id,
		"old_value": old_value,
		"new_value": city.label(overlay_id),
		"error": "",
	}


static func city_analysis(
	city: CityState, resource_strings: Dictionary = {}
) -> Dictionary:
	if city == null or not city.is_valid():
		return {"ok": false, "error": "city is invalid"}
	var misc_chunk := city.document.find_chunk("MISC")
	if (
		misc_chunk == null
		or misc_chunk.decoded_payload.size() < MISC_TILE_COUNTS + 0x100 * 4
	):
		return {"ok": false, "error": "MISC tile counts are missing or invalid"}

	var counts := PackedInt32Array()
	counts.resize(CATEGORY_COUNT)
	for building in range(FIRST_BUILDING, 0x100):
		var building_count := city.document.misc_i32(MISC_TILE_COUNTS + building * 4)
		for range_index in TILE_UPPER_BOUNDS.size():
			if building >= TILE_UPPER_BOUNDS[range_index]:
				continue
			counts[CATEGORY_BY_RANGE[range_index]] += building_count
			break

	var total := 0
	for category_id in range(1, CATEGORY_COUNT):
		total += counts[category_id]
	var categories: Array[Dictionary] = []
	for category_id in range(1, CATEGORY_COUNT):
		var name: String = FALLBACK_CATEGORY_NAMES[category_id]
		var resource_id := CATEGORY_RESOURCE_BASE + category_id
		if resource_strings.has(resource_id):
			name = str(resource_strings[resource_id]).strip_edges()
		categories.append({
			"id": category_id,
			"name": name,
			"acres": counts[category_id],
			"percent": int(counts[category_id] * 100 / total) if total != 0 else 0,
		})
	var header := "Category                 Acres   Share"
	if resource_strings.has(CATEGORY_RESOURCE_BASE):
		header = str(resource_strings[CATEGORY_RESOURCE_BASE])
	return {
		"ok": true,
		"header": header,
		"counts": counts,
		"total": total,
		"categories": categories,
		"error": "",
	}


static func format_city_analysis(analysis: Dictionary) -> String:
	if not analysis.get("ok", false):
		return "Analysis failed: %s" % analysis.get("error", "unknown error")
	var lines := PackedStringArray([str(analysis.header)])
	for category in analysis.categories:
		lines.append(
			"%s\t%d\t%d%%"
			% [category.name, category.acres, category.percent]
		)
	return "\n".join(lines)
