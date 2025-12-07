@tool
extends EditorPlugin

const IndexedPackExport = preload("res://addons/indexed_pack_export/export.gd")
var exporter: EditorExportPlugin


func _enter_tree() -> void:
	exporter = IndexedPackExport.new()
	add_export_plugin(exporter)


func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter = null
