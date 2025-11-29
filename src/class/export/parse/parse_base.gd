extends RefCounted


const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")
const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd") #>remote
const UFile = UtilsRemote.UFile
const UString = UtilsRemote.UString
const URegex = UtilsRemote.URegex
const UClassDetail = UtilsRemote.UClassDetail
const ExportFileUtils = UtilsLocal.ExportFileUtils
const ExportFileKeys = ExportFileUtils.ExportFileKeys
const CompatData = UtilsLocal.CompatData

const RES_LINE_TEMPLATE = '[ext_resource type="%s" path="%s" id="%s"]'

static var preload_regex:RegEx

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

func get_adjusted_path_or_old_renamed(file_path:String) -> String:
	var new_path = export_obj.adjusted_remote_paths.get(file_path, file_path)
	new_path = export_obj.get_rel_or_absolute_path(new_path)
	if not export_obj.use_relative_paths:
		new_path = export_obj.get_renamed_path(new_path)
	return new_path

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
	
	# find all string matches and store values and positions
	var string_matches = _string_regex.search_all(code_part)
	var string_literals = []
	for _match in string_matches:
		string_literals.append(_match.get_string())
	
	# replace with placeholders by POSITION, iterating BACKWARDS
	var sanitized_code = code_part
	for i in range(string_matches.size() - 1, -1, -1):
		var _match = string_matches[i]
		var placeholder = "__STRING_PLACEHOLDER_%d__" % i
		# Reconstruct the string using the match's start and end positions
		sanitized_code = sanitized_code.left(_match.get_start()) + placeholder + sanitized_code.substr(_match.get_end())
	
	# call the provided callable on the sanitized code
	var converted_code = processor.call(sanitized_code)
	
	# restore strings
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


static func _check_text_valid(line:String, to_check:String) -> bool:
	if line.begins_with("#"):
		return false
	var string_map = ExportFileUtils.get_string_map(line) as UString.StringMapMultiLine
	var idx = line.find(to_check)
	if idx == -1:
		return false
	if string_map.string_mask[idx] == 1:
		return false
	var com_idx = string_map.comment_mask.find(1)
	if com_idx > -1 and com_idx < idx:
		return false
	return true


static func _strip_comment(line:String):
	var string_map = ExportFileUtils.get_string_map(line) as UString.StringMapMultiLine
	var com_idx = string_map.comment_mask.find(1)
	if com_idx == -1:
		return line
	return line.substr(0, com_idx)


static func get_preload_path(line):
	if not is_instance_valid(preload_regex):
		preload_regex = UtilsRemote.URegex.get_preload_path()
	
	if not _check_text_valid(line, "preload("):
		return
	
	var _match = preload_regex.search(line)
	if _match:
		var file_path = _match.get_string(2)
		return file_path

static func _construct_pre(class_nm:String, path:String):
	var c = "const"
	var p = 'preload("%s")' % path
	var constructed = "%s %s = %s" % [c, class_nm, p]
	return constructed

static func get_extended_class(line:String):
	if not _check_text_valid(line, "extends"):
		return
	var _class = line.get_slice("extends ", 1).strip_edges()
	return _class

static func line_has_tag(line:String, tag:String, prefix:="#!") -> bool:
	var pre_idx = line.find(prefix)
	if pre_idx == -1:
		return false
	var tags = line.substr(pre_idx)
	return tags.find(tag) > -1
