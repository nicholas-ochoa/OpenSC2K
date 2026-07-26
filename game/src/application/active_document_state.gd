class_name ActiveDocumentState
extends RefCounted


var current_document: Sc2File
var saved_city_snapshot := PackedByteArray()
var current_save_path := ""
var current_city_saved_once := false
