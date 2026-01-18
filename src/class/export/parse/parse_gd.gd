extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"

const PLUGIN_EXPORTED_STRING = "const PLUGIN_EXPORTED = false"
const PLUGIN_EXPORTED_REPLACE = "const PLUGIN_EXPORTED = true"

const OUT_OF_PLUGIN_MSG = \
"Out of plugin file path updated (if needed) but file not copied, if it should be, tag with \"#! dependency\" or ignore warning with \"#! ignore-remote\".
 File: \"%s\", in \"%s\""

var path_regex:RegEx
var const_name_regex:RegEx

func _init() -> void:
	super()
	
	path_regex = RegEx.new()
	var all_string_paths_pattern = "[\"'](.*?)[\"']"
	path_regex.compile(all_string_paths_pattern)
	
	const_name_regex = UtilsRemote.URegex.get_const_name()

func set_parse_settings(settings):
	pass

func get_direct_dependencies(file_path:String) -> Dictionary:
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	if not file_access:
		printerr("Could not open file: %s" % file_path)
		return {}
	
	var direct_dependencies = {}
	var global_class_data = get_global_classes_in_file(file_path)
	var global_classes_in_files = global_class_data
	for _class_name in global_classes_in_files:
		var path = export_obj.export_data.class_list.get(_class_name)
		if not export_obj.global_classes_used.has(_class_name):
			export_obj.global_classes_used[_class_name] = {
				ExportFileKeys.dependent: file_path,
				ExportFileKeys.path: path
			}
		direct_dependencies[path] = {}
	
	file_access.seek(0)
	
	var remote_dir_overide = ""
	var first_line = true
	while not file_access.eof_reached():
		var line = file_access.get_line()
		var comment_stripped = _strip_comment(line)
		if first_line:
			first_line = false
			if line.find("#! remote") > -1:
				remote_dir_overide = line.get_slice("#! remote", 1).strip_edges()
		
		if comment_stripped.find("extends") > -1 and comment_stripped.count('"') >= 2:
			if _check_text_valid(line, "extends"):
				#var _class #^ i think can just be removed because is covered by below
				#if line.find("class ") > -1:
					#if _check_text_valid(line, "class "):
						#_class = line.get_slice("class ", 1)
						#_class = _class.get_slice(" ", 0)
				
				var extends_part = comment_stripped.get_slice("extends", 1).strip_edges()
				if extends_part.count('"') == 2:
					var extend_path = extends_part.trim_prefix('"')
					extend_path = extend_path.get_slice('"', 0)
					extend_path = export_obj.ensure_absolute_path(extend_path, file_path)
					if FileAccess.file_exists(extend_path):
						var file_name = extend_path.get_file()
						direct_dependencies[extend_path] = {}
		elif line.find("preload(") > -1 and line.count('"') == 2: #TODO make these regexs or something more robust.
			var preload_path = get_preload_path(line)
			if preload_path != null:
				preload_path = export_obj.ensure_absolute_path(preload_path, file_path)
				direct_dependencies[preload_path] = {}
				## make this '#! remote custom/dir' work? recursive deps will not be in this folder without refactor
				#direct_dependencies[preload_path][ExportFileKeys.dependency_dir] = remote_dir_overide
		elif line.find("#! dependency") > -1 and line.count('"') >= 2:
			if _check_text_valid(line, "#! dependency"):
				var slice = line.get_slice("#! dependency", 1)
				var dep_path = line.get_slice('"', 1)
				dep_path = dep_path.get_slice('"', 0)
				dep_path = export_obj.ensure_absolute_path(dep_path, file_path)
				if FileAccess.file_exists(dep_path):
					var file_name = dep_path.get_file()
					var dependency_dir = line.get_slice("#! dependency", 1).strip_edges()
					direct_dependencies[dep_path] = {ExportFileKeys.dependency_dir: dependency_dir}
	
	return direct_dependencies


func post_export_edit_file(file_path:String, file_lines:Variant=null):
	var class_renames = export_obj.class_renames
	var classes_preloaded = []
	var classes_used = []
	
	var global_classes_in_file = ExportFileUtils._get_global_classes_in_file(file_path, export_obj.export_data.class_list)
	var class_declaration = global_classes_in_file.get("global_class_definition", "")
	global_classes_in_file.erase("global_class_definition")
	
	classes_used.append_array(global_classes_in_file.keys())
	
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	
	var adjusted_file_lines = []
	while not file_access.eof_reached():
		var line:String = file_access.get_line()
		var comment_stripped = _strip_comment(line)
		
		if comment_stripped.begins_with("class_name "):
			if _check_text_valid(line, "class_name "):
				if class_renames.has(class_declaration):
					if comment_stripped.find(" extends ") > -1:
						line = "extends " + comment_stripped.get_slice(" extends ", 1)
					else:
						line = ""
		
		if comment_stripped.find("extends ") > -1 and comment_stripped.count('"') == 2: # make this if so it will scan class nm too?
			#if not _check_for_comment(line, ["extends", "class"]):
			if _check_text_valid(line, "extends "): #^c these 2 are mostly for checking preloaded in the current script,
				if comment_stripped.find("class ") == -1: #^c hence no inner?
					var extend_file_path = comment_stripped.get_slice('"', 1)
					extend_file_path = extend_file_path.get_slice('"', 0)
					extend_file_path = export_obj.ensure_absolute_path(extend_file_path, file_path)
					if not FileAccess.file_exists(extend_file_path):
						printerr("Could not find extended file in line: %s" % line)
					
					var inherited_used_classes = _recursive_get_globals(extend_file_path)
					classes_preloaded.append_array(inherited_used_classes)
		
		elif comment_stripped.find("extends ") > -1:
			if _check_text_valid(line, "extends "): #^ use line as arg so it just reuses string map
				if comment_stripped.find("class ") == -1: #^c i think this could work for both class types
					var global_class = comment_stripped.get_slice("extends ", 1) # ""
					global_class = global_class.strip_edges()
					if global_class.find(" ") > -1: #^c what is this for?
						printerr("GETTING SPACE GLOBAL CLASS")
						global_class = global_class.get_slice(" ", 0)
					if export_obj.export_data.class_list.has(global_class):
						var path = export_obj.export_data.class_list.get(global_class)
						var inherited_used_classes = _recursive_get_globals(path)
						classes_preloaded.append_array(inherited_used_classes)
						if class_renames.has(global_class):
							line = line.replace(global_class, '"%s"' % path)
		
		elif comment_stripped.find("const") > -1:
			if _check_text_valid(line, "const"):
				var result = const_name_regex.search(line)
				if result:
					var const_name = result.get_string(1)
					if class_renames.has(const_name):
						if not const_name in classes_preloaded:
							classes_preloaded.append(const_name)
		
		line = _update_paths(line)
		
		adjusted_file_lines.append(line)
	##
	
	#if not classes_used.is_empty(): #debug prints
		#print(file_path)
		#print(classes_used)
		#print(classes_preloaded)
	
	var rename_lines = []
	for name in export_obj.export_data.class_list_array:
		if name in classes_preloaded:
			continue
		if not class_renames.has(name):
		#if not name in class_renames_keys:
			continue
		if not name in classes_used:
			continue
		var remote_path = class_renames[name]
		var adjusted_path = export_obj.adjusted_remote_paths.get(remote_path)
		if adjusted_path == "":
			printerr("Error renaming class: %s, could not get export path." % name)
			continue
		#if use_relative_paths:
			#adjusted_path = export_obj.get_relative_path(adjusted_path)
		adjusted_path = export_obj.get_rel_or_absolute_path(adjusted_path)
		var line = 'const %s' % name 
		line = line + ' = preload("%s")' % adjusted_path
		rename_lines.append(line)
		
	
	if not rename_lines.is_empty():
		adjusted_file_lines.append("")
		adjusted_file_lines.append("")
		adjusted_file_lines.append("### Plugin Exporter Global Classes")
		adjusted_file_lines.append_array(rename_lines)
		#adjusted_file_lines.append("### Plugin Exporter Global Classes")
		adjusted_file_lines.append("")
	
	
	return adjusted_file_lines


func _update_paths(line:String):
	var has_ignore_tag = line_has_tag(line, "ignore-remote")
	if has_ignore_tag:
		return line
	var current_parse_file = export_obj.file_parser.current_file_path_parsing
	var comment_index = line.find("#")
	var matches = path_regex.search_all(line)
	for i in range(matches.size() - 1, -1, -1):
		var _match:RegExMatch = matches[i]
		var start = _match.get_start(1)
		var end = _match.get_end(1)
		if comment_index > -1 and comment_index < start:
			return line
		
		var old_path = _match.get_string(1)
		if old_path.begins_with(UFile._UID):
			if old_path == UFile._UID or old_path == UFile._UID_INVALID:
				continue
			old_path = UFile.uid_to_path(old_path)
		if old_path.count("/") == 0:
			if not old_path.is_valid_filename():
				continue
		else:
			if not old_path.get_file().is_valid_filename():
				continue
		
		
		if old_path.is_relative_path():
			old_path = export_obj.ensure_absolute_path(old_path, current_parse_file)
			if not FileAccess.file_exists(old_path):
				continue
		
		var new_path = export_obj.adjusted_remote_paths.get(old_path)
		if new_path == null:
			if not UFile.is_file_in_directory(old_path, export_obj.source): #TODO #^ this needs some work, would be nice to allow renaming out of plugin
				#if not has_ignore_tag: # redundant
					#print(has_ignore_tag)
				#UtilsRemote.UEditor.print_warn(OUT_OF_PLUGIN_MSG % [line, current_parse_file])
				continue
			if export_obj.rename_plugin: # if new path was null, the old path was not processed. If rename, update to be accurate to new name
				if old_path.find(export_obj.plugin_name) > -1:
					new_path = export_obj.get_renamed_path(old_path)
		
		if new_path == null:
			new_path = old_path
		
		new_path = export_obj.get_rel_or_absolute_path(new_path)
		line = line.substr(0, start) + new_path + line.substr(end)
	
	return line

func get_global_class_in_file_data(file_path:String):
	return ExportFileUtils._get_global_classes_in_file(file_path, export_obj.export_data.class_list)

func get_global_classes_in_file(file_path:String) -> Array:
	var global_classes_in_files = ExportFileUtils._get_global_classes_in_file(file_path, export_obj.export_data.class_list)
	global_classes_in_files.erase("global_class_definition")
	return global_classes_in_files.keys()

func _recursive_get_globals(file_path:String) -> Array:
	var _classes = {}
	var script = load(file_path) as GDScript
	var inherited_scripts = UClassDetail.script_get_inherited_script_paths(script)
	for path in inherited_scripts:
		var global_classes = get_global_classes_in_file(path)
		for cl in global_classes:
			_classes[cl] = true
	return _classes.keys()

#func _parse_extended_class(file_path:String):
	#var file_text = FileAccess.get_file_as_string(file_path)
	#var string_map = ExportFileUtils.get_string_map(file_text)
	#var extend_index = file_text.find("extends ")
	#while extend_index != -1:
		#if string_map.index_not_string_or_comment(extend_index): # index_in_string_or_comment is new
			#break
		#extend_index = file_text.find("extends ", extend_index + 1)
	#
	#var line = string_map.get_line_at_index(extend_index)
	#var line_stripped = line.get_slice("#", 1).strip_edges()
	#if line_stripped.count('"') == 2:
		#var path = line_stripped.get_slice('"', 1)
		#path = path.get_slice('"', 0)
		#path = export_obj.ensure_absolute_path(path, file_path)
		#return path


func post_export_edit_line(line:String):
	line = _update_file_export_flags(line)
	return line

func _update_file_export_flags(line:String):
	if line.find(PLUGIN_EXPORTED_STRING) > -1:
		line = line.replace(PLUGIN_EXPORTED_STRING, PLUGIN_EXPORTED_REPLACE)
	return line
