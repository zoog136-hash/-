@tool
extends EditorPlugin
var exporter: EditorExportPlugin
var startup_exporter: EditorExportPlugin

func _enter_tree() -> void:
	exporter = preload("res://addons/source84_export/raw_pack_export.gd").new()
	add_export_plugin(exporter)
	startup_exporter = preload("res://addons/source84_export/startup_data_export.gd").new()
	add_export_plugin(startup_exporter)

func _exit_tree() -> void:
	remove_export_plugin(startup_exporter)
	remove_export_plugin(exporter)
