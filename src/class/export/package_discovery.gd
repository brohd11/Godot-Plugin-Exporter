@tool
extends RefCounted
## Package snapshots are rebuilt on demand after editor filesystem changes.

const ExportIgnore = preload("res://addons/plugin_exporter/src/class/export/export_ignore.gd")

enum Filter { ALL, VALID, NOT_VALID }

static var _cache:Dictionary = {} # absolute root -> {relative package path: configured}
static var _filesystem_connected := false


static func discover(root:String = "res://addons", filter:int = Filter.VALID) -> Dictionary:
	if filter not in [Filter.ALL, Filter.VALID, Filter.NOT_VALID]:
		return {}
	_connect_filesystem()
	var key = ProjectSettings.globalize_path(root).simplify_path().trim_suffix("/")
	if not _cache.has(key):
		var paths:Array[String] = []
		_scan(key, "", paths)
		paths.sort()
		var packages = {}
		for path in paths:
			packages[path] = FileAccess.file_exists(ExportIgnore.config_path(key.path_join(path)))
		_cache[key] = packages
	var result = {}
	for path in _cache[key]:
		var configured:bool = _cache[key][path]
		if filter == Filter.VALID and not configured:
			continue
		if filter == Filter.NOT_VALID and configured:
			continue
		result[path] = {}
	return result


static func clear_cache() -> void:
	_cache.clear()


static func _connect_filesystem() -> void:
	if _filesystem_connected or not Engine.is_editor_hint():
		return
	var editor_interface = Engine.get_singleton("EditorInterface")
	if not is_instance_valid(editor_interface):
		return # Retry on the next lookup if the editor is still starting.
	var fs = editor_interface.get_resource_filesystem()
	if not is_instance_valid(fs):
		return
	if not fs.filesystem_changed.is_connected(clear_cache):
		fs.filesystem_changed.connect(clear_cache)
	clear_cache() # Discard any snapshot taken before filesystem notifications were available.
	_filesystem_connected = true


static func _scan(root:String, relative:String, paths:Array[String]) -> void:
	var dir = root.path_join(relative)
	var access = DirAccess.open(dir)
	if access == null:
		return
	if relative != "" and (access.file_exists("plugin.cfg") or access.file_exists("version.cfg")):
		paths.append(relative)
	for child in access.get_directories():
		if child.begins_with(".") or ExportIgnore.is_name(child) or access.is_link(child):
			continue
		_scan(root, relative.path_join(child), paths)
