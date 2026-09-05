@tool
extends EditorPlugin

const ExportFix = preload("res://addons/web_pwa_fix/export_fix.gd")
var _export_fix: EditorExportPlugin


func _enter_tree() -> void:
	_export_fix = ExportFix.new()
	add_export_plugin(_export_fix)


func _exit_tree() -> void:
	remove_export_plugin(_export_fix)
	_export_fix = null
