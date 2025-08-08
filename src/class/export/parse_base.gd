extends RefCounted

static var preload_regex:RegEx
const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd") #>remote
const UFile = UtilsRemote.UFile

func _init() -> void:
	preload_regex = UtilsRemote.URegex.get_preload_path()

func edit_dep_file(line:String, to:String, remote_file:String, remote_dir:String, dependencies:Dictionary, file_lines:Array):
	file_lines.append(line)


static func _check_for_comment(line, check_array):
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


class RemoteData:
	const dir = "remote_dir"
	const single_class = "remote_class"
	const files = "remote_files"
	const other_deps = "other_deps"
	const to = "to"
	const from = "from"
	const dependent = "dependent"
