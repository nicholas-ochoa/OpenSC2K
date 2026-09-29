extends SceneTree
## Every supplied city and scenario converts to SC2X version 4, saves, and loads
## the same working chunks again. The supplied files stay unchanged.

var checks := 0
var failures := 0


func _initialize() -> void:
	var user_args := OS.get_cmdline_user_args()
	var root_path := str(user_args[0]) if not user_args.is_empty() else ProjectSettings.globalize_path("res://../references/SIMCITY2000")
	var paths := PackedStringArray()

	for folder in ["CITIES", "SCENARIO"]:
		for name in DirAccess.get_files_at(root_path.path_join(folder)):
			if name.get_extension().to_upper() in ["SC2", "SCN"]:
				paths.append(root_path.path_join(folder).path_join(name))

	_check(paths.size() > 50, "The supplied cities and scenarios are present")
	var reported := 0

	for path in paths:
		var source_bytes := FileAccess.get_file_as_bytes(path)
		var legacy := Sc2File.load_path(path)
		_check(legacy.is_valid() and legacy.serialize().data == source_bytes, "%s keeps its original bytes" % path.get_file())
		var converted := Sc2xDocument.from_legacy(legacy, path.get_file().get_basename())
		_check(converted.ok, "%s converts: %s" % [path.get_file(), converted.error])

		if not converted.ok:
			continue

		reported += converted.issues.size()
		var document := converted.document
		var encoded := document.serialize()
		_check(encoded.ok, "%s saves: %s" % [path.get_file(), encoded.error])
		var reloaded := Sc2File.new()
		_check(reloaded.parse(encoded.data), "%s loads: %s" % [path.get_file(), reloaded.parse_error])
		var same := reloaded.city_name() == document.city_name() and reloaded.chunks.size() == document.chunks.size()

		for index in mini(reloaded.chunks.size(), document.chunks.size()):
			same = same and reloaded.chunks[index].chunk_id == document.chunks[index].chunk_id
			same = same and reloaded.chunks[index].decoded_payload == document.chunks[index].decoded_payload

		_check(same, "%s loads the same working chunks" % path.get_file())
		_check(reloaded.serialize().data == encoded.data, "%s saves the same bytes again" % path.get_file())
		var legacy_city := CityState.from_document(legacy)
		var city := CityState.from_document(reloaded)
		var visible := legacy_city.sign_texts()
		var signs := city.sign_texts()
		var kept := city.is_valid()

		for index in visible:
			kept = kept and signs.get(index) == visible[index]

		# a sign that a moving object covered in the original file is kept too
		for index in signs:
			kept = kept and (visible.has(index) or OverlayData.is_thing(OverlayData.read(legacy_city.text_overlays, index)))

		_check(kept, "%s keeps every sign, including covered signs" % path.get_file())

		if legacy.find_chunk("SCEN") != null:
			var before := ScenarioState.from_document(legacy)
			var after := ScenarioState.from_document(reloaded)
			_check(after.is_valid() and after.disaster_x == before.disaster_x and after.cash_goal == before.cash_goal
				and after.first_building_tile_count == before.first_building_tile_count
				and after.opening_description() == before.opening_description(), "%s keeps its scenario" % path.get_file())

		_check(FileAccess.get_file_as_bytes(path) == source_bytes, "%s stays unchanged on disk" % path.get_file())

	# a few original files hold object links that point at freed or repeated
	# records; conversion reports them instead of keeping them
	_check(reported < paths.size(), "Conversion reports only the broken links of a few files")
	print("SC2X reference conversion: %d files, %d reported links, %d checks, %d failures" % [
		paths.size(), reported, checks, failures])
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	checks += 1

	if not ok:
		failures += 1
		push_error(message)
