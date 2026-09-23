class_name ScurkZip
extends RefCounted
## Byte-only ZIP container for SCURK projects. No files are extracted to disk.

@warning_ignore_start("integer_division")

const Checksum = preload("res://src/formats/crc32.gd")
const Limits = preload("res://src/tools/scurk/scurk_project_limits.gd")
const MAX_FILE_BYTES := Limits.MAX_FILE_BYTES
const MAX_MEMBER_BYTES := Limits.MAX_FILE_BYTES
const LOCAL_SIGNATURE := 0x04034b50
const CENTRAL_SIGNATURE := 0x02014b50
const END_SIGNATURE := 0x06054b50
const DESCRIPTOR_SIGNATURE := 0x08074b50
const ZIP64_END_SIGNATURE := 0x06064b50
const ZIP64_LOCATOR_SIGNATURE := 0x07064b50
const LOCAL_SIZE := 30
const CENTRAL_SIZE := 46
const END_SIZE := 22
const ZIP64_END_SIZE := 56
const ZIP64_LOCATOR_SIZE := 20
const ZIP16_MAX := 0xffff
# Every member needs two headers and a nonempty name in each header.
const MAX_MEMBERS := MAX_FILE_BYTES / (LOCAL_SIZE + CENTRAL_SIZE + 2)
const STORED := 0
const DEFLATE := 8
const UTF8_FLAG := 0x0800
const DESCRIPTOR_FLAG := 0x0008
const DEFLATE_OPTIONS := 0x0006
const ALLOWED_FLAGS := UTF8_FLAG | DESCRIPTOR_FLAG | DEFLATE_OPTIONS
const ZIP64_EXTRA := 0x0001
const ZIP32_MAX := 0xffffffff
const STREAM_CHUNK := 32768
const GZIP_HEADER := [0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 255]
const GZIP_TRAILER_SIZE := 8

class Result extends RefCounted:
	var ok := false
	var error := ""
	var bytes := PackedByteArray()
	var members: Dictionary[String, PackedByteArray] = {}


class Entry extends RefCounted:
	var path := ""
	var name := PackedByteArray()
	var flags := 0
	var method := STORED
	var crc := 0
	var compressed_size := 0
	var size := 0
	var local_offset := 0
	var data_offset := 0
	var end_offset := 0


class Directory extends RefCounted:
	var count := 0
	var size := 0
	var offset := 0
	var end := 0


static func encode(members: Dictionary[String, PackedByteArray], max_data_bytes := MAX_MEMBER_BYTES) -> Result:
	if max_data_bytes < 0 or max_data_bytes > MAX_MEMBER_BYTES:
		return _failure("The project ZIP member size limit is invalid.")
	if members.size() > MAX_MEMBERS:
		return _failure("The project ZIP has too many members.")
	var names: Array[String] = members.keys()
	names.sort()
	var total := 0
	var header_size := END_SIZE + (ZIP64_END_SIZE + ZIP64_LOCATOR_SIZE if names.size() >= ZIP16_MAX else 0)
	for path in names:
		var name := path.to_utf8_buffer()
		if not _valid_path(path) or name.size() > 65535:
			return _failure("The project ZIP member path is invalid.")
		total += members[path].size()
		header_size += LOCAL_SIZE + CENTRAL_SIZE + name.size() * 2
		if total > max_data_bytes or header_size > MAX_FILE_BYTES:
			return _failure("The project ZIP exceeds the size limit.")
	var bytes := PackedByteArray()
	var directory := PackedByteArray()
	var payload_size := 0
	for path in names:
		var entry := Entry.new()
		entry.path = path
		entry.name = path.to_utf8_buffer()
		entry.flags = UTF8_FLAG
		entry.size = members[path].size()
		entry.local_offset = bytes.size()
		var payload: PackedByteArray = members[path]
		if not payload.is_empty():
			var gzip := payload.compress(FileAccess.COMPRESSION_GZIP)
			# Godot emits a fixed GZIP header. Its trailer supplies the native CRC.
			if gzip.size() < GZIP_HEADER.size() + GZIP_TRAILER_SIZE or gzip[0] != 0x1f or gzip[1] != 0x8b or gzip[2] != DEFLATE or gzip[3] != 0:
				return _failure("Cannot compress the project ZIP member.")
			if gzip.decode_u32(gzip.size() - 4) != entry.size:
				return _failure("The project ZIP compressed size is invalid.")
			entry.crc = gzip.decode_u32(gzip.size() - GZIP_TRAILER_SIZE)
			var deflated := gzip.slice(GZIP_HEADER.size(), gzip.size() - GZIP_TRAILER_SIZE)
			if deflated.size() < payload.size():
				payload = deflated
				entry.method = DEFLATE
		entry.compressed_size = payload.size()
		payload_size += payload.size()
		if header_size + payload_size > MAX_FILE_BYTES:
			return _failure("The encoded project ZIP exceeds the file size limit.")
		var local := _local_header(entry)
		bytes.append_array(local)
		bytes.append_array(entry.name)
		bytes.append_array(payload)
		directory.append_array(_central_header(entry))
		directory.append_array(entry.name)
	var end := PackedByteArray()
	end.resize(END_SIZE)
	end.encode_u32(0, END_SIGNATURE)
	end.encode_u16(8, mini(names.size(), ZIP16_MAX))
	end.encode_u16(10, mini(names.size(), ZIP16_MAX))
	end.encode_u32(12, directory.size())
	end.encode_u32(16, bytes.size())
	var directory_offset := bytes.size()
	bytes.append_array(directory)
	if names.size() >= ZIP16_MAX:
		bytes.append_array(_zip64_end(names.size(), directory.size(), directory_offset, bytes.size()))
	bytes.append_array(end)
	var result := _success()
	result.bytes = bytes
	return result


static func decode(bytes: PackedByteArray, max_data_bytes := MAX_MEMBER_BYTES) -> Result:
	if bytes.size() < END_SIZE or bytes.size() > MAX_FILE_BYTES or max_data_bytes < 0 or max_data_bytes > MAX_MEMBER_BYTES:
		return _failure("The project ZIP size is invalid.")
	var end := _find_end(bytes)
	if end < 0:
		return _failure("The project ZIP directory is missing.")
	var directory := _read_directory(bytes, end)
	if directory == null:
		return _failure("The project ZIP directory bounds or disk fields are invalid.")
	var count := directory.count
	var directory_offset := directory.offset
	var directory_end := directory.end
	var entries: Array[Entry] = []
	var paths: Dictionary[String, bool] = {}
	var position := directory_offset
	var total := 0
	for _index in count:
		if position + CENTRAL_SIZE > directory_end or bytes.decode_u32(position) != CENTRAL_SIGNATURE:
			return _failure("The project ZIP directory entry is invalid.")
		var entry := Entry.new()
		entry.flags = bytes.decode_u16(position + 8)
		entry.method = bytes.decode_u16(position + 10)
		entry.crc = bytes.decode_u32(position + 16)
		entry.compressed_size = bytes.decode_u32(position + 20)
		entry.size = bytes.decode_u32(position + 24)
		entry.local_offset = bytes.decode_u32(position + 42)
		var name_size := bytes.decode_u16(position + 28)
		var extra_size := bytes.decode_u16(position + 30)
		var comment_size := bytes.decode_u16(position + 32)
		var next := position + CENTRAL_SIZE + name_size + extra_size + comment_size
		if next > directory_end or bytes.decode_u16(position + 6) > 45:
			return _failure("The project ZIP member header is unsupported.")
		entry.name = bytes.slice(position + CENTRAL_SIZE, position + CENTRAL_SIZE + name_size)
		if entry.name.has(0):
			return _failure("The project ZIP member path contains a null byte.")
		entry.path = entry.name.get_string_from_utf8()
		if entry.path.to_utf8_buffer() != entry.name or not _valid_path(entry.path) or paths.has(entry.path):
			return _failure("The project ZIP member path is invalid or repeated.")
		var extra := _read_extra(bytes, position + CENTRAL_SIZE + name_size, extra_size)
		if not extra.ok or not _resolve_zip64(entry, extra.bytes, bytes.decode_u16(position + 34)):
			return _failure("The project ZIP member extra data is invalid.")
		if not _supported(entry):
			return _failure("The project ZIP member encoding is unsupported.")
		paths[entry.path] = true
		total += entry.size
		if total > max_data_bytes:
			return _failure("The decoded project ZIP exceeds the size limit.")
		if not _read_local(bytes, entry, directory_offset):
			return _failure("The project ZIP local header does not match its directory.")
		entries.append(entry)
		position = next
	if position != directory_end:
		return _failure("The project ZIP directory has trailing data.")
	entries.sort_custom(func(a: Entry, b: Entry) -> bool: return a.local_offset < b.local_offset)
	position = 0
	for entry in entries:
		if entry.local_offset != position:
			return _failure("The project ZIP members overlap or have unlisted data.")
		position = entry.end_offset
	if position != directory_offset:
		return _failure("The project ZIP data bounds are invalid.")
	# Every member and the aggregate output size are checked before decompression.
	var result := _success()
	for entry in entries:
		var payload := bytes.slice(entry.data_offset, entry.data_offset + entry.compressed_size)
		if entry.method == STORED:
			if Checksum.calculate(payload) != entry.crc:
				return _failure("The project ZIP member checksum is invalid.")
		else:
			var inflated := _inflate(payload, entry.crc, entry.size)
			if not inflated.ok:
				return inflated
			payload = inflated.bytes
		result.members[entry.path] = payload
	return result


static func _find_end(bytes: PackedByteArray) -> int:
	for offset in range(bytes.size() - END_SIZE, maxi(-1, bytes.size() - END_SIZE - 65535 - 1), -1):
		if bytes.decode_u32(offset) == END_SIGNATURE and offset + END_SIZE + bytes.decode_u16(offset + 20) == bytes.size():
			return offset
	return -1


static func _supported(entry: Entry) -> bool:
	return entry.flags & ~ALLOWED_FLAGS == 0 and (entry.method == DEFLATE or (entry.method == STORED and entry.flags & DEFLATE_OPTIONS == 0 and entry.size == entry.compressed_size))


static func _valid_path(path: String) -> bool:
	if path.is_empty() or path.contains("\\") or path.contains(":") or path.to_utf8_buffer().has(0):
		return false
	for part in path.split("/"):
		if part.is_empty() or part == "." or part == "..":
			return false
	return true


static func _read_extra(bytes: PackedByteArray, offset: int, size: int) -> Result:
	var result := _success()
	var found := false
	var end := offset + size
	while offset < end:
		if offset + 4 > end:
			return _failure("The ZIP extra field is incomplete.")
		var tag := bytes.decode_u16(offset)
		var length := bytes.decode_u16(offset + 2)
		if offset + 4 + length > end:
			return _failure("The ZIP extra field size is invalid.")
		if tag == ZIP64_EXTRA:
			if found:
				return _failure("The ZIP64 extra field is repeated.")
			result.bytes = bytes.slice(offset + 4, offset + 4 + length)
			found = true
		offset += 4 + length
	return result


static func _resolve_zip64(entry: Entry, extra: PackedByteArray, disk: int) -> bool:
	var offset := 0
	for field in ["size", "compressed_size", "local_offset"]:
		if entry.get(field) != ZIP32_MAX:
			continue
		if offset + 8 > extra.size():
			return false
		var value := extra.decode_u64(offset)
		if value < 0 or value > MAX_FILE_BYTES:
			return false
		entry.set(field, value)
		offset += 8
	if disk == ZIP16_MAX:
		return offset + 4 <= extra.size() and extra.decode_u32(offset) == 0
	return disk == 0


static func _read_local(bytes: PackedByteArray, entry: Entry, directory_offset: int) -> bool:
	var offset := entry.local_offset
	if offset + LOCAL_SIZE > directory_offset or bytes.decode_u32(offset) != LOCAL_SIGNATURE:
		return false
	if bytes.decode_u16(offset + 4) > 45 or bytes.decode_u16(offset + 6) != entry.flags or bytes.decode_u16(offset + 8) != entry.method:
		return false
	var name_size := bytes.decode_u16(offset + 26)
	var extra_size := bytes.decode_u16(offset + 28)
	entry.data_offset = offset + LOCAL_SIZE + name_size + extra_size
	entry.end_offset = entry.data_offset + entry.compressed_size
	if entry.end_offset > directory_offset or name_size != entry.name.size():
		return false
	if bytes.slice(offset + LOCAL_SIZE, offset + LOCAL_SIZE + name_size) != entry.name:
		return false
	var extra := _read_extra(bytes, offset + LOCAL_SIZE + name_size, extra_size)
	if not extra.ok:
		return false
	var local := Entry.new()
	local.crc = bytes.decode_u32(offset + 14)
	local.compressed_size = bytes.decode_u32(offset + 18)
	local.size = bytes.decode_u32(offset + 22)
	var zip64 := local.size == ZIP32_MAX or local.compressed_size == ZIP32_MAX
	if not _resolve_zip64(local, extra.bytes, 0):
		return false
	if entry.flags & DESCRIPTOR_FLAG == 0:
		return local.crc == entry.crc and local.compressed_size == entry.compressed_size and local.size == entry.size
	if (local.crc != 0 and local.crc != entry.crc) or (local.compressed_size != 0 and local.compressed_size != entry.compressed_size) or (local.size != 0 and local.size != entry.size):
		return false
	var descriptor := entry.end_offset
	var fields_size := 20 if zip64 else 12
	# The optional signature can also be a valid CRC. Check both interpretations.
	if descriptor + 4 <= directory_offset and bytes.decode_u32(descriptor) == DESCRIPTOR_SIGNATURE and _descriptor_matches(bytes, descriptor + 4, entry, zip64, directory_offset):
		entry.end_offset = descriptor + 4 + fields_size
		return true
	if _descriptor_matches(bytes, descriptor, entry, zip64, directory_offset):
		entry.end_offset = descriptor + fields_size
		return true
	return false


static func _descriptor_matches(bytes: PackedByteArray, offset: int, entry: Entry, zip64: bool, limit: int) -> bool:
	if offset + (20 if zip64 else 12) > limit or bytes.decode_u32(offset) != entry.crc:
		return false
	if zip64:
		return bytes.decode_u64(offset + 4) == entry.compressed_size and bytes.decode_u64(offset + 12) == entry.size
	return bytes.decode_u32(offset + 4) == entry.compressed_size and bytes.decode_u32(offset + 8) == entry.size


static func _read_directory(bytes: PackedByteArray, end: int) -> Directory:
	var result := Directory.new()
	result.count = bytes.decode_u16(end + 10)
	result.size = bytes.decode_u32(end + 12)
	result.offset = bytes.decode_u32(end + 16)
	result.end = end
	if bytes.decode_u16(end + 4) != 0 or bytes.decode_u16(end + 6) != 0 or bytes.decode_u16(end + 8) != result.count:
		return null
	var locator := end - ZIP64_LOCATOR_SIZE
	var has_zip64 := locator >= 0 and bytes.decode_u32(locator) == ZIP64_LOCATOR_SIGNATURE
	if result.count == ZIP16_MAX or result.size == ZIP32_MAX or result.offset == ZIP32_MAX or has_zip64:
		if not has_zip64 or bytes.decode_u32(locator + 4) != 0 or bytes.decode_u32(locator + 16) != 1:
			return null
		var position := bytes.decode_u64(locator + 8)
		if position < 0 or position > locator - ZIP64_END_SIZE or bytes.decode_u32(position) != ZIP64_END_SIGNATURE:
			return null
		var record_size := bytes.decode_u64(position + 4)
		if record_size < 44 or record_size > MAX_FILE_BYTES or position + 12 + record_size != locator:
			return null
		if bytes.decode_u16(position + 14) > 45 or bytes.decode_u32(position + 16) != 0 or bytes.decode_u32(position + 20) != 0:
			return null
		var count := bytes.decode_u64(position + 32)
		var size := bytes.decode_u64(position + 40)
		var offset := bytes.decode_u64(position + 48)
		if count < 0 or count > MAX_MEMBERS or count != bytes.decode_u64(position + 24) or size < 0 or size > MAX_FILE_BYTES or offset < 0 or offset > MAX_FILE_BYTES:
			return null
		if (result.count != ZIP16_MAX and result.count != count) or (result.size != ZIP32_MAX and result.size != size) or (result.offset != ZIP32_MAX and result.offset != offset):
			return null
		result.count = count
		result.size = size
		result.offset = offset
		result.end = position
	if result.offset + result.size != result.end or result.count * CENTRAL_SIZE > result.size or result.count > MAX_MEMBERS:
		return null
	return result


static func _zip64_end(count: int, size: int, offset: int, position: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(ZIP64_END_SIZE + ZIP64_LOCATOR_SIZE)
	bytes.encode_u32(0, ZIP64_END_SIGNATURE)
	bytes.encode_u64(4, 44)
	bytes.encode_u16(12, 45)
	bytes.encode_u16(14, 45)
	bytes.encode_u64(24, count)
	bytes.encode_u64(32, count)
	bytes.encode_u64(40, size)
	bytes.encode_u64(48, offset)
	bytes.encode_u32(ZIP64_END_SIZE, ZIP64_LOCATOR_SIGNATURE)
	bytes.encode_u64(ZIP64_END_SIZE + 8, position)
	bytes.encode_u32(ZIP64_END_SIZE + 16, 1)
	return bytes


static func _inflate(raw: PackedByteArray, crc: int, expected: int) -> Result:
	# ZIP uses raw deflate. Godot exposes wrapped GZIP/zlib streams instead.
	# The GZIP trailer validates the ZIP CRC and size in the native decoder.
	var framed := PackedByteArray(GZIP_HEADER)
	framed.append_array(raw)
	var trailer := PackedByteArray()
	trailer.resize(GZIP_TRAILER_SIZE)
	trailer.encode_u32(0, crc)
	trailer.encode_u32(4, expected)
	framed.append_array(trailer)
	var boundary := framed.size()
	# One unused byte proves that the decoder reached its end, including for empty data.
	framed.append(0)
	var peer := StreamPeerGZIP.new()
	if peer.start_decompression(false, STREAM_CHUNK * 2) != OK:
		return _failure("Cannot start project ZIP decompression.")
	var offset := 0
	var output := PackedByteArray()
	while offset < framed.size():
		var sent := peer.put_partial_data(framed.slice(offset, mini(offset + STREAM_CHUNK, framed.size())))
		if sent[0] != OK:
			return _failure("The compressed project ZIP member is invalid.")
		offset += int(sent[1])
		var count := peer.get_available_bytes()
		if count > expected - output.size():
			return _failure("The project ZIP member exceeds its declared size.")
		if count > 0:
			var received := peer.get_data(count)
			if received[0] != OK:
				return _failure("Cannot read the project ZIP member.")
			output.append_array(received[1])
		if int(sent[1]) == 0 and count == 0:
			break
	if offset != boundary or output.size() != expected:
		return _failure("The project ZIP member size or stream boundary is invalid.")
	var result := _success()
	result.bytes = output
	return result


static func _local_header(entry: Entry) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(LOCAL_SIZE)
	bytes.encode_u32(0, LOCAL_SIGNATURE)
	bytes.encode_u16(4, 20)
	bytes.encode_u16(6, entry.flags)
	bytes.encode_u16(8, entry.method)
	bytes.encode_u16(12, 33) # 1980-01-01, fixed for deterministic output.
	bytes.encode_u32(14, entry.crc)
	bytes.encode_u32(18, entry.compressed_size)
	bytes.encode_u32(22, entry.size)
	bytes.encode_u16(26, entry.name.size())
	return bytes


static func _central_header(entry: Entry) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(CENTRAL_SIZE)
	bytes.encode_u32(0, CENTRAL_SIGNATURE)
	bytes.encode_u16(4, 20)
	bytes.encode_u16(6, 20)
	bytes.encode_u16(8, entry.flags)
	bytes.encode_u16(10, entry.method)
	bytes.encode_u16(14, 33)
	bytes.encode_u32(16, entry.crc)
	bytes.encode_u32(20, entry.compressed_size)
	bytes.encode_u32(24, entry.size)
	bytes.encode_u16(28, entry.name.size())
	bytes.encode_u32(42, entry.local_offset)
	return bytes


static func _success() -> Result:
	var result := Result.new()
	result.ok = true
	return result


static func _failure(message: String) -> Result:
	var result := Result.new()
	result.error = message
	return result
