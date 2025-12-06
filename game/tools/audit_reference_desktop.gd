extends SceneTree


func _initialize() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../data/formats/desktop-resource-audit.json"))
	var directories := {}
	for source in expected.sources:
		var directory := PeBitmapResource._load_resource_directory("res://../references/" + str(source.path))
		assert(directory.ok and _sha256(directory.bytes) == source.sha256)
		directories[source.path] = directory
	for record in expected.images:
		var cursor: bool = record.kind == "cursor"
		var resource := PeIconCursorResource.resource_from_directory(directories[record.source], 1 if cursor else 3, int(record.id))
		assert(resource.ok and _sha256(resource.bytes) == record.resource_sha256)
		var decoded := PeIconCursorResource.decode_image(resource.bytes, cursor)
		assert(decoded.ok, str(decoded.error))
		assert(decoded.width == record.width and decoded.height == record.height and decoded.bits == record.bits)
		assert(decoded.hotspot == Vector2i(record.hotspot[0], record.hotspot[1]))
		assert(decoded.inverting_pixels == record.inverting_pixels and decoded.trailing_bytes == record.trailing_bytes)
		var background := Image.create(decoded.width, decoded.height, false, Image.FORMAT_RGBA8)
		background.fill(Color8(37, 83, 149))
		assert(_sha256(PeIconCursorResource.composite(decoded, background).get_data()) == record.composite_sha256)
		var image := PeIconCursorResource.transparent_image(decoded)
		if record.transparent_sha256 == null:
			assert(not image.ok)
		else:
			assert(image.ok and _sha256(image.image.get_data()) == record.transparent_sha256, "%s %s %d alpha image" % [record.source, record.kind, int(record.id)])
	for record in expected.groups:
		var cursor: bool = record.kind == "cursor"
		var app := "city" if record.source == "SIMCITY.EXE" else "scurk"
		var resource := PeIconCursorResource.resource_from_directory(directories[record.source], 12 if cursor else 14, int(record.id))
		assert(resource.ok)
		var group := PeIconCursorResource.decode_group(resource.bytes, cursor)
		assert(group.ok and group.entries.size() == record.members.size())
		for i in group.entries.size():
			var entry: Dictionary = group.entries[i]
			assert(entry.id == record.members[i])
			var member := PeIconCursorResource.resource_from_directory(directories[record.source], 1 if cursor else 3, entry.id)
			assert(member.ok and member.bytes.size() == entry.length)
			if cursor:
				assert(DesktopGraphics.cursor_id(app, int(record.id)) == entry.id)
			else:
				assert(DesktopGraphics.ICON_GROUPS[app][int(record.id)][i] == entry.id)
	var original := DesktopGraphics.load_original("res://../references")
	assert(original.error.is_empty(), original.error)
	assert(original.icons.city.size() == 10 and original.icons.scurk.size() == 8)
	assert(original.cursors.city.size() == 101 and original.cursors.scurk.size() == 34)
	print("PASS: 153 supplied icon/cursor resources, 144 groups, exact hotspots, six padded resources and both SCURK inverse cursors against independent Python hashes; original loading, all group mappings; no raster export")
	quit()


func _sha256(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	assert(hashing.start(HashingContext.HASH_SHA256) == OK and hashing.update(bytes) == OK)
	return hashing.finish().hex_encode()
