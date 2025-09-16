extends RefCounted

static var preload_regex:RegEx
const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")
const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd") #>remote
const UFile = UtilsRemote.UFile
const URegex = UtilsRemote.URegex
const ExportFileUtils = UtilsLocal.ExportFileUtils
const ExportFileKeys = ExportFileUtils.ExportFileKeys
const CompatData = UtilsLocal.CompatData

var _string_regex:RegEx

var export_obj: UtilsLocal.ExportData.Export

func _init() -> void:
	preload_regex = UtilsRemote.URegex.get_preload_path()

func set_parse_settings(settings) -> void:
	pass

func get_direct_dependencies(file_path:String) -> Dictionary:
	var direct_dependencies = {}
	return direct_dependencies

func pre_export() -> void:
	return

func post_export_edit_line(line:String) -> String:
	return line

func post_export_edit_file(file_path:String, file_lines:Variant=null) -> Variant:
	return file_lines

func _update_file_export_flags(line:String) -> String:
	return line


func _string_safe_regex_sub(line: String, processor: Callable) -> String:
	if not is_instance_valid(_string_regex):
		_string_regex = URegex.get_strings()
	line = URegex.string_safe_regex_sub(line, processor, _string_regex)
	return line
	
	var code_part = line
	var comment_part = ""
	var comment_pos = line.find("#")
	if comment_pos != -1:
		code_part = line.substr(0, comment_pos)
		comment_part = line.substr(comment_pos)
	
	# 1. Find all string matches and store both their values and positions
	var string_matches = _string_regex.search_all(code_part)
	var string_literals = []
	for _match in string_matches:
		string_literals.append(_match.get_string())
	
	# 2. Replace strings with placeholders by POSITION, iterating BACKWARDS
	var sanitized_code = code_part
	for i in range(string_matches.size() - 1, -1, -1):
		var _match = string_matches[i]
		var placeholder = "__STRING_PLACEHOLDER_%d__" % i
		# Reconstruct the string using the match's start and end positions
		sanitized_code = sanitized_code.left(_match.get_start()) + placeholder + sanitized_code.substr(_match.get_end())
	
	# 3. Call the provided processor function on the sanitized code
	var converted_code = processor.call(sanitized_code)
	
	# 4. Restore strings (this part can remain the same)
	var final_code = converted_code
	for i in range(string_literals.size()):
		var placeholder = "__STRING_PLACEHOLDER_%d__" % i
		final_code = final_code.replace(placeholder, string_literals[i])
	
	return final_code + comment_part


func file_extends_class(file_lines:Array, backport_target:=100) -> bool:
	var global_class_names = export_obj.export_data.class_list.keys()
	var extends_class = false
	for i in range(file_lines.size()):
		var line = file_lines[i]
		
		var _class = get_extended_class(line)
		if _class:
			if _class.find('"') > -1:
				extends_class = true
			else:
				if _class in global_class_names:
					extends_class = true
				elif _class not in ClassDB.get_class_list():
					extends_class = true
				if backport_target < 4:
					if _class in CompatData.COMPAT_CLASSES:
						extends_class = true
				
				break
	return extends_class

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

static func _construct_pre(class_nm:String, path:String):
	var c = "const" # "" '' <- for parser
	var p = 'preload("%s")' % path # "" '' <- for parser
	var constructed = "%s %s = %s" % [c, class_nm, p]
	return constructed

static func get_extended_class(line:String):
	if not line.begins_with("extends "): # "" "" <- parser
		return
	var code = line
	if line.find("#") > -1:
		code = line.get_slice("#", 0)
	
	var _class = code.get_slice("extends ", 1).strip_edges() # "" "" <- parser
	return _class

