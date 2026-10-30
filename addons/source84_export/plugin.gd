@tool
extends EditorPlugin
var exporter: EditorExportPlugin

func _enter_tree() -> void:
	exporter = preload("res://addons/source84_export/raw_pack_export.gd").new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
