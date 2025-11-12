extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"

const PLUGIN_EXPORTED_STRING = "const PLUGIN_EXPORTED = false"
const PLUGIN_EXPORTED_REPLACE = "const PLUGIN_EXPORTED = true"

const OUT_OF_PLUGIN_MSG = "Out of plugin file path is not updated, if it should be, ensure it is in a \"#! remote\" file: \"%s\", in \"%s\""

var path_regex:RegEx
var const_name_regex:RegEx

var global_class_names = []

func _init() -> void:
	super()
	
	
	path_regex = RegEx.new()
	#var pattern = r"""(?:\bextends\b\s+|preload\s*\(|load\s*\()[\s"']*\K((?:res|uid)://[^"'\)]+)"""
	var all_string_paths_pattern = "[\"']((?:res:\\/\\/|uid:\\/\\/|user:\\/\\/).*?)[\"']"
	path_regex.compile(all_string_paths_pattern)
	
	const_name_regex = UtilsRemote.URegex.get_const_name()

func set_parse_settings(settings):
	#var class_renames_array = settings.get("class_rename", [])
	#for name in class_renames_array:
		#class_renames[name] = ""
	pass

func get_direct_dependencies(file_path:String) -> Dictionary:
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	if not file_access:
		printerr("Could not open file: %s" % file_path)
		return {}
	var direct_dependencies = {}
	var remote_dir_overide = ""
	var first_line = true
	while not file_access.eof_reached():
		var line = file_access.get_line()
		if first_line:
			first_line = false
			if line.find("#! remote") > -1:
				remote_dir_overide = line.get_slice("#! remote", 1).strip_edges()
		
		var tokens = Tokenizer.words_only(line)
		for tok:String in tokens: ## Check for global classes
			if tok in export_obj.export_data.class_list_array:
				var path = export_obj.export_data.class_list.get(tok)
				#direct_dependencies[path] = {}
				if not tok in export_obj.global_classes_used.keys():
					export_obj.global_classes_used[tok] = {
						ExportFileKeys.dependent: file_path,
						ExportFileKeys.path: path
					}
					
					direct_dependencies[path] = {}
					
					#var local_export_path = export_obj.remote_dir.path_join(file_name)
					#export_obj.class_renames[tok] = local_export_path
		
		if line.find("extends") > -1 and line.count('"') == 2:
			if not _check_for_comment(line, ["extends", "class"]):
				var _class
				if line.find("class ") > -1:
					_class = line.get_slice("class ", 1)
					_class = _class.get_slice(" ", 0)
				var extend_path = line.get_slice('extends', 1).strip_edges().trim_prefix('"')
				extend_path = extend_path.get_slice('"', 0)
				if FileAccess.file_exists(extend_path):
					var file_name = extend_path.get_file()
					direct_dependencies[extend_path] = {}
		elif line.find("preload(") > -1 and line.count('"') == 2: #TODO make these regexs or something more robust.
			var preload_path = get_preload_path(line)
			if preload_path != null:
				direct_dependencies[preload_path] = {}
				## make this '#! remote custom/dir' work? recursive deps will not be in this folder without refactor
				#direct_dependencies[preload_path][ExportFileKeys.dependency_dir] = remote_dir_overide
		elif line.find("#! dependency") > -1 and line.count('"') == 2:
			var dep_path = line.get_slice('"', 1)
			dep_path = dep_path.get_slice('"', 0)
			if FileAccess.file_exists(dep_path):
				var file_name = dep_path.get_file()
				var dependency_dir = line.get_slice("#! dependency", 1).strip_edges()
				direct_dependencies[dep_path] = {ExportFileKeys.dependency_dir: dependency_dir}
	
	return direct_dependencies


func post_export_edit_file(file_path:String, file_lines:Variant=null):
	var class_list_keys = export_obj.export_data.class_list.keys()
	var class_renames = export_obj.class_renames
	var class_renames_keys = class_renames.keys()
	var classes_preloaded = []
	var classes_used = []
	
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	
	var adjusted_file_lines = []
	while not file_access.eof_reached():
		var line:String = file_access.get_line()
		
		# TODO why is this todo?
		classes_used.append_array(UtilsLocal.get_global_classes_in_text(line, class_list_keys))
		# TODO
		
		if line.find("class_name ") > -1:
			var class_nm = line.get_slice("class_name ", 1)
			var comment_index = line.find("#")
			if comment_index > -1:
				class_nm = class_nm.get_slice("#", 0)
			class_nm = class_nm.strip_edges()
			if class_nm in class_renames_keys:
				var class_path = export_obj.export_data.class_list.get(class_nm)
				if class_path.get_file() == file_path.get_file():
					line = ""
					#if not class_nm in classes_preloaded:
						#classes_preloaded.append(class_nm) # is the class, don't preload// this actually seems ok..
		
		elif line.find("extends ") > -1 and line.count('"') == 2:
			if not _check_for_comment(line, ["extends", "class"]):
				if line.find("class ") == -1:
					var extend_file_path = line.get_slice('"', 1)
					extend_file_path = extend_file_path.get_slice('"', 0)
					if not FileAccess.file_exists(extend_file_path):
						printerr("Could not find extended file in line: %s" % line)
					
					var inherited_used_classes = _recursive_get_globals(extend_file_path)
					classes_preloaded.append_array(inherited_used_classes)
		
		elif line.find("extends ") > -1: # "" 
			
			if line.find("class ") == -1: # i think this could work for both class types
				var global_class = line.get_slice("extends ", 1) # ""
				var comment_index = line.find("#")
				if comment_index > -1:
					global_class = global_class.get_slice("#", 0)
				global_class = global_class.strip_edges()
				if global_class.find(" ") > -1:
					global_class = global_class.get_slice(" ", 0)
				if global_class in global_class_names:
					var path = export_obj.export_data.class_list.get(global_class)
					var inherited_used_classes = _recursive_get_globals(path)
					classes_preloaded.append_array(inherited_used_classes)
					if global_class in class_renames_keys:
						line = line.replace(global_class, '"%s"' % path)
		
		elif line.find("const") > -1:
			var result = const_name_regex.search(line)
			if result:
				var const_name = result.get_string(1)
				if const_name in class_renames_keys:
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
		if not name in class_renames_keys:
			continue
		if not name in classes_used:
			continue
		var remote_path = class_renames[name]
		var adjusted_path = export_obj.adjusted_remote_paths.get(remote_path)
		if adjusted_path == "":
			printerr("Error renaming class: %s, could not get export path." % name)
			continue
		var line = 'const %s' % name 
		line = line + ' = preload("%s")' % adjusted_path # "" <- stop parse issue. Get export path
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
		var new_path = export_obj.adjusted_remote_paths.get(old_path)
		if not new_path:
			if not UFile.is_file_in_directory(old_path, export_obj.source):
				if not FileAccess.file_exists(old_path):
					continue
				if line.find("#! ignore-remote") == -1:
					UtilsRemote.UEditor.print_warn(OUT_OF_PLUGIN_MSG % [line, export_obj.file_parser.current_file_path_parsing])
				continue
			if export_obj.rename_plugin:
				if old_path.find(export_obj.plugin_name) > -1:
					#new_path = old_path.replace(export_obj.plugin_name, export_obj.new_plugin_name)
					new_path = export_obj.get_renamed_path(old_path)
					line = line.substr(0, start) + new_path + line.substr(end)
		else:
			line = line.substr(0, start) + new_path + line.substr(end)
	
	return line



func _recursive_get_globals(file_path) -> Array:
	var class_list_keys = export_obj.export_data.class_list.keys()
	var classes = []
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	if not file_access:
		print("ERROR OPENING: %s" % file_path)
		return []
	while not file_access.eof_reached():
		var line = file_access.get_line()
		var global_classes = UtilsLocal.get_global_classes_in_text(line, class_list_keys)
		for _class in global_classes:
			if not _class in classes:
				classes.append(_class)
	
	file_access.close()
	return classes

func post_export_edit_line(line:String):
	line = _update_file_export_flags(line)
	return line

func _update_file_export_flags(line:String):
	if line.find(PLUGIN_EXPORTED_STRING) > -1:
		line = line.replace(PLUGIN_EXPORTED_STRING, PLUGIN_EXPORTED_REPLACE)
	return line
