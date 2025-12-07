@tool
extends EditorExportPlugin


func _get_name() -> String:
	return "IndexedGraphicsPack"


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path.get_extension().to_lower() == "png":
		# The runtime reader needs PLTE indices and tRNS, not an imported texture.
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.size() >= 26 and bytes[25] == 3 and bytes.slice(0, 8) == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
			add_file(path, bytes, false)
