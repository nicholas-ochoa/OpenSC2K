class_name RecordedSoundtrack
extends RefCounted
# external recordings use the original numeric midi resource ids

const EXTENSIONS := ["flac", "ogg", "mp3"]


class Result extends RefCounted:
	var stream: AudioStream
	var path := ""


class Request extends RefCounted:
	var paths := PackedStringArray()
	var request := 0

	func _init(source_paths: PackedStringArray, request_id: int) -> void:
		paths = source_paths
		request = request_id


static func find_tracks(folder: String, track_id: int) -> PackedStringArray:
	var result := PackedStringArray()
	var names := DirAccess.get_files_at(folder) if DirAccess.dir_exists_absolute(folder) else PackedStringArray()
	names.sort()

	for extension in EXTENSIONS:
		for name in names:
			var stem := name.get_basename()

			if name.get_extension().to_lower() == extension and (
				stem == str(track_id) or stem.begins_with("%d - " % track_id)
			):
				result.append(folder.path_join(name))

	return result


static func load_track(paths: PackedStringArray) -> Result:
	for path in paths:
		var stream: AudioStream

		match path.get_extension().to_lower():
			"wav":
				stream = AudioStreamWAV.load_from_file(path)
			"mp3":
				stream = AudioStreamMP3.load_from_file(path)
			"ogg":
				stream = AudioStreamOggVorbis.load_from_file(path)
			"flac":
				stream = _load_flac(path)

		if stream != null and stream.get_length() > 0.0:
			if stream is AudioStreamWAV:
				stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
			else:
				stream.set("loop", false)

			var result := Result.new()
			result.stream = stream
			result.path = path

			return result

	var result := Result.new()
	result.stream = null
	result.path = ""

	return result


static func _load_flac(path: String) -> AudioStreamWAV:
	# decode off the main thread. cache 16-bit pcm, without changing the source
	var cache_dir := ProjectSettings.globalize_path("user://soundtrack-cache")

	if DirAccess.make_dir_recursive_absolute(cache_dir) != OK:
		return null

	var key := (path + ":" + FileAccess.get_sha256(path)).sha256_text()
	var cache_path := cache_dir.path_join(key + ".wav")

	if not FileAccess.file_exists(cache_path):
		var executable := ffmpeg_executable()
		var temporary := cache_dir.path_join("%s-%d.wav" % [key, OS.get_process_id()])
		var output := []
		var status := OS.execute(executable, PackedStringArray([
			"-nostdin", "-v", "error", "-y", "-i", path, "-map", "0:a:0", "-vn",
			"-ac", "2", "-c:a", "pcm_s16le", temporary,
		]), output, true)

		if status != 0 or DirAccess.rename_absolute(temporary, cache_path) != OK:
			DirAccess.remove_absolute(temporary)

			return null

	return AudioStreamWAV.load_from_file(cache_path)


static func ffmpeg_executable() -> String:
	var configured := OS.get_environment("OPENSC2K_FFMPEG")

	if not configured.is_empty():
		return configured

	for candidate in ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]:
		if FileAccess.file_exists(candidate):
			return candidate

	return "ffmpeg"
