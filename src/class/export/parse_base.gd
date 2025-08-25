extends RefCounted

static var preload_regex:RegEx
const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")
const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd") #>remote
const UFile = UtilsRemote.UFile
const ExportFileUtils = UtilsLocal.ExportFileUtils
const ExportFileKeys = ExportFileUtils.ExportFileKeys

const RemoteData = ExportFileUtils.RemoteData

var export_obj: UtilsLocal.ExportData.Export

func _init() -> void:
	preload_regex = UtilsRemote.URegex.get_preload_path()

func set_parse_settings(settings) -> void:
	pass

func get_direct_dependencies(file_path:String) -> Dictionary:
	var direct_dependencies = {}
	return direct_dependencies

func edit_dep_file(line:String, to:String, remote_file:String, remote_dir:String, dependencies:Dictionary) -> String:
	return line

func post_export_edit_line(line:String) -> String:
	return line

func post_export_edit_file(file_path:String) -> Variant:
	return

func _update_file_export_flags(line:String) -> String:
	return line


static func _check_for_comment(line, check_array) -> bool:
	if check_array is String:
		check_array = [check_array]
	var comment_index = line.find("#")
	if comment_index == -1:
		return false
	for text in check_array:
		var index = line.find(text)
		if index == -1:
			continue
		if comment_index < index:
			return true
	
	return false


static func get_preload_path(line):
	if preload_regex == null:
		preload_regex = UtilsRemote.URegex.get_preload_path()
	
	if _check_for_comment(line, "preload("):
		return
	var _match = preload_regex.search(line)
	if _match:
		var file_path = _match.get_string(2)
		file_path = UFile.uid_to_path(file_path)
		return file_path
