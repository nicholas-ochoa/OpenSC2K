extends SceneTree
## Local test maps only. Never write source-derived fixture files to Git.

const SOURCES := [
	"SYDNEY", "TOKYO", "PARIS", "LONDON", "NYC", "ROME", "UTOPIA", "KEENLAND",
	"CENTERVL", "BAYVIEW", "LAKELAND", "HAPPYLND", "NEWMONRO", "BRIDGEPO", "JUNETOWN", "KATVILLE",
]
const COPY_CHUNKS := ["ALTM", "XTER", "XBLD", "XZON", "XUND", "XBIT", "XTRF", "XPLT", "XVAL", "XCRM", "XPLC", "XFIR", "XPOP", "XROG"]
var output_root := "res://../local/large-cities"
var sources: Array[CityState] = []
var source_hashes: Array[String] = []

func _init() -> void:
	for source_name in SOURCES:
		var path := "res://../references/CITIES/%s.SC2" % source_name
		var document := Sc2File.load_path(path)
		assert(document.is_valid(), document.parse_error)
		source_hashes.append(FileAccess.get_sha256(path))
		var city := CityState.from_document(document)
		while city.compass_rotation() != 0:
			assert(CityRotationCommand.apply(city, false).ok)
		sources.append(city)
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_root)) == OK)
	for edge in [256, 384, 512]:
		build_fixture(edge)
	for i in SOURCES.size():
		assert(FileAccess.get_sha256("res://../references/CITIES/%s.SC2" % SOURCES[i]) == source_hashes[i])
	print("PASS: stitched 256, 384, and 512 cities; source hashes unchanged")
	quit()

func build_fixture(edge: int) -> void:
	var across := edge / 128
	var document := EmptyCityTemplate.create(edge)
	var created := NewCitySetup.create(document, "Stitched %d" % edge, "Test Mayor", 1, 2050, SimRandom.new(1))
	assert(created.ok)
	document = created.document
	var city := CityState.from_document(document)
	var text := city.text_overlays.duplicate()
	var microsims := document.find_chunk("XMIC").decoded_payload.duplicate()
	var labels := document.find_chunk("XLAB").decoded_payload.duplicate()
	var misc := document.find_chunk("MISC").decoded_payload.duplicate()
	var random := SimRandom.new(17)
	var report := {"size": edge, "blocks": [], "facility_links_without_record": 0, "signs_not_copied": 0, "source_moving_objects_not_copied": 0}
	var next_sign := 1
	var normal_population := 0
	var arcology_population := 0
	for bx in across:
		for by in across:
			var source_id := bx * across + by
			var source := sources[source_id]
			report.blocks.append({"x": bx * 128, "y": by * 128, "source": SOURCES[source_id] + ".SC2", "sha256": source_hashes[source_id]})
			normal_population += source.document.misc_u32(0x102c)
			arcology_population += source.document.misc_u32(0x1020)
			for chunk_id in COPY_CHUNKS:
				var scale := 1
				if chunk_id in Sc2File.HALF_MAP_CHUNKS:
					scale = 2
				elif chunk_id in Sc2File.QUARTER_MAP_CHUNKS:
					scale = 4
				var stride := 2 if chunk_id == "ALTM" else 1
				var source_edge := 128 / scale
				var target_edge := edge / scale
				var input := source.document.find_chunk(chunk_id).decoded_payload
				var target := document.find_chunk(chunk_id).decoded_payload.duplicate()
				for x in source_edge:
					var dst := ((bx * source_edge + x) * target_edge + by * source_edge) * stride
					var src := x * source_edge * stride
					for byte in source_edge * stride:
						target[dst + byte] = input[src + byte]
				assert(document.find_chunk(chunk_id).set_decoded_payload(target))
			var overlay_map := {}
			for x in 128:
				for y in 128:
					var old := source.text_overlays[x * 128 + y]
					var target_index := (bx * 128 + x) * edge + by * 128 + y
					if old == 0:
						continue
					if not overlay_map.has(old):
						var mapped := 0
						if old <= 50:
							if next_sign <= 50:
								mapped = next_sign
								next_sign += 1
								copy_label(source, old, labels, mapped)
							else:
								report.signs_not_copied += 1
						elif old <= 200:
							var tile := int(source.microsim(old - 51).get("tile_id", 0))
							var kind := int(BuildingCommand.MICROSIM_TYPE_BY_TILE.get(tile, 0))
							var can_allocate := kind > 16
							for slot in range(10, CityState.MICROSIM_COUNT):
								can_allocate = can_allocate or microsims[slot * 8] == 0
							if can_allocate:
								mapped = BuildingCommand._provision_microsim(microsims, labels, text, tile, 2050, random, misc)
							if mapped == 0:
								report.facility_links_without_record += 1
							else:
								copy_label(source, old, labels, mapped)
						# Transient objects, disasters, and old city-edge connections are reset.
						elif old <= 240:
							report.source_moving_objects_not_copied += 1
						overlay_map[old] = mapped
					text[target_index] = int(overlay_map[old])
	assert(document.find_chunk("XTXT").set_decoded_payload(text))
	assert(document.find_chunk("XLAB").set_decoded_payload(labels))
	assert(document.find_chunk("XMIC").set_decoded_payload(microsims))
	assert(document.find_chunk("MISC").set_decoded_payload(misc))
	city = CityState.from_document(document)
	var counts := PackedInt32Array()
	counts.resize(256)
	for tile in city.buildings:
		counts[tile] += 1
	for tile in 256:
		document.set_misc_u32(0x01f0 + tile * 4, counts[tile])
	document.set_misc_u32(0x102c, normal_population)
	document.set_misc_u32(0x1020, arcology_population)
	document.set_misc_u32(0x1018, edge / 2)
	document.set_misc_u32(0x101c, edge / 2)
	city.set_funds(10000000)
	city.set_simulation_speed(1)
	city.set_auto_budget_enabled(true)
	city.set_no_disasters_enabled(true)
	var path := output_root.path_join("stitched-%d.sc2x" % edge)
	var saved := CityFileStore.save_copy(document, path, "res://../references")
	assert(saved.ok, String(saved.get("error", "")))
	var reloaded := Sc2File.load_path(path)
	assert(reloaded.is_valid() and reloaded.map_size == edge)
	assert(reloaded.serialize(true).data == saved.data)
	# Verify every copied byte in each block after writing and reloading.
	for block in report.blocks:
		var source: CityState = sources[int(block.x / 128) * across + int(block.y / 128)]
		for chunk_id in COPY_CHUNKS:
			var divisor := 2 if chunk_id in Sc2File.HALF_MAP_CHUNKS else (4 if chunk_id in Sc2File.QUARTER_MAP_CHUNKS else 1)
			var stride := 2 if chunk_id == "ALTM" else 1
			var input := source.document.find_chunk(chunk_id).decoded_payload
			var output := reloaded.find_chunk(chunk_id).decoded_payload
			for x in 128 / divisor:
				var start := ((int(block.x / divisor) + x) * (edge / divisor) + int(block.y / divisor)) * stride
				assert(output.slice(start, start + (128 / divisor) * stride) == input.slice(x * (128 / divisor) * stride, (x + 1) * (128 / divisor) * stride))
	report["output_sha256"] = FileAccess.get_sha256(path)
	report["population"] = city.population()
	var output := FileAccess.open(path + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	print("PASS: %s (%d blocks, %d people, %d omitted facility links)" % [path, across * across, city.population(), report.facility_links_without_record])

func copy_label(source: CityState, old: int, labels: PackedByteArray, target: int) -> void:
	var bytes := source.document.find_chunk("XLAB").decoded_payload
	for i in CityState.LABEL_RECORD_SIZE:
		labels[target * CityState.LABEL_RECORD_SIZE + i] = bytes[old * CityState.LABEL_RECORD_SIZE + i]
