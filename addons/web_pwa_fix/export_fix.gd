@tool
extends EditorExportPlugin

var _export_base := ""


func _get_name() -> String:
	return "DarioWebPWAExportFix"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformWeb


func _export_begin(features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
	_export_base = ""
	if not features.has("web") or path.get_extension().to_lower() != "html":
		return
	if bool(get_export_preset().get("progressive_web_app/enabled")):
		_export_base = path.get_basename()


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path.begins_with("res://addons/web_pwa_fix/"):
		skip()


func _export_end() -> void:
	if _export_base.is_empty():
		return
	var worker_path := _export_base + ".service.worker.js"
	var manifest_path := _export_base + ".manifest.json"
	_export_base = ""
	if not FileAccess.file_exists(worker_path) or not FileAccess.file_exists(manifest_path):
		return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary or not manifest.get("name") is String:
		push_error("Web PWA export fix: unable to read the exported application name.")
		return
	var source := FileAccess.get_file_as_string(worker_path)
	var marker := "const CACHE_PREFIX = "
	var start := source.find(marker)
	if start == -1:
		push_error("Web PWA export fix: generated cache prefix was not found.")
		return
	var end := source.find("\n", start)
	if end == -1:
		end = source.length()
	var cache_prefix: String = manifest["name"].substr(0, 16) + "-sw-cache-"
	var replacement := marker + JSON.stringify(cache_prefix) + ";"
	var patched := source.substr(0, start) + replacement + source.substr(end)
	if patched == source:
		return
	var file := FileAccess.open(worker_path, FileAccess.WRITE)
	if file == null:
		push_error("Web PWA export fix: unable to write " + worker_path)
		return
	file.store_string(patched)
	file.close()
