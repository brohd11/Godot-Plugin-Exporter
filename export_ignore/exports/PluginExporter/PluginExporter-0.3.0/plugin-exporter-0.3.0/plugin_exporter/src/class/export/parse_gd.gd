extends "res://addons/plugin_exporter/src/class/export/parse_base.gd"

const PLUGIN_EXPORTED_STRING = "const PLUGIN_EXPORTED = true"
const PLUGIN_EXPORTED_REPLACE = "const PLUGIN_EXPORTED = true"





func set_parse_settings(settings):
	#var class_renames_array = settings.get("class_rename", [])
	#for name in class_renames_array:
		#class_renames[name] = ""
	pass


func edit_dep_file(line:String, to:String, remote_file:String, remote_dir:String, dependencies:Dictionary):
	if line.find("extends") > -1 and line.count('"') == 2:
		if _check_for_comment(line, ["extends", "class"]):
			#file_lines.append(line) 
			return line
		var _class
		if line.find("class ") > -1:
			_class = line.get_slice("class ", 1)
			_class = _class.get_slice(" ", 0)
		var extend_path = line.get_slice('extends', 1).strip_edges().trim_prefix('"')
		extend_path = extend_path.get_slice('"', 0)
		if FileAccess.file_exists(extend_path):
			var file_name = extend_path.get_file()
			var to_path = remote_dir.path_join(file_name)
			var depen_data = {RemoteData.from: extend_path, RemoteData.to: to_path, RemoteData.dependent: remote_file}
			var final_path = file_name
			var rel_path = UFile.get_relative_path(to, to_path)
			if _class == null:
				line = 'extends "%s"' % rel_path # "" stop false positive parsing this file
			else:
				line = 'class %s extends "%s":' % [_class, rel_path] # "" stop false positive parsing this file
			dependencies[file_name] = depen_data
	elif line.find("preload(") > -1 and line.count('"') == 2: #TODO make these regexs or somtehitng more robust.
		var preload_path = get_preload_path(line)
		if preload_path == null:
			#file_lines.append(line)
			return line
		var file_name = preload_path.get_file()
		var to_path = remote_dir.path_join(file_name)
		var rel_path = UFile.get_relative_path(to, to_path)
		var original_preload_call = 'preload("%s")' % preload_path # "" stop false positive parsing this file
		if line.find('"%s"' % preload_path) == -1:
			original_preload_call = 'preload("%s")' % UFile.path_to_uid(preload_path) # "" stop false positive parsing this file
		var new_preload_call = 'preload("%s")' % rel_path # "" stop false positive parsing this file
		line = line.replace(original_preload_call, new_preload_call)
		var depen_data = {RemoteData.from: preload_path, RemoteData.to: to_path, RemoteData.dependent: remote_file}
		if dependencies.has(file_name) and dependencies[file_name].from != remote_file:
			printerr("WARNING: Filename collision detected for '%s'." % file_name)
			printerr("  Source 1: %s" % dependencies[file_name].from)
			printerr("  Source 2: %s" % preload_path)
			printerr("  The second file will overwrite the first in the destination directory.")
		dependencies[file_name] = depen_data
		
	elif line.find("#! dependency") > -1 and line.count('"') == 2:
		var dep_path = line.get_slice('"', 1)
		dep_path = dep_path.get_slice('"', 0)
		if FileAccess.file_exists(dep_path):
			var file_name = dep_path.get_file()
			var to_path = remote_dir.path_join(file_name)
			var old_path = '"%s"' % dep_path
			line = line.replace(old_path, '"%s"' % file_name)
			var depen_data = {RemoteData.from: dep_path, RemoteData.to: to_path, RemoteData.dependent: remote_file}
			dependencies[file_name] = depen_data
	elif line.find("const PLUGIN_EXPORT_FLAT = false") > -1:
		line = line.replace("const PLUGIN_EXPORT_FLAT = false", "const PLUGIN_EXPORT_FLAT = true")
	
	# always append line before return
	return line
	#file_lines.append(line)

func post_export_edit_line(line:String):
	line = _update_file_export_flags(line)
	return line

func post_export_edit_file(file_path:String):
	var class_list_keys = export_obj.export_data.class_list.keys()
	var class_renames = export_obj.export_data.class_renames
	var class_renames_keys = class_renames.keys()
	var classes_preloaded = []
	var classes_used = []
	
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	
	var adjusted_file_lines = []
	while not file_access.eof_reached():
		var line:String = file_access.get_line()
		
		# TODO
		classes_used.append_array(UtilsLocal.get_global_classes_in_text(line, class_list_keys))
		# TODO
		
		if line.find("class_name ") > -1:
			var class_nm = line.get_slice("class_name ", 1).strip_edges()
			if class_nm in class_renames_keys:
				var class_path = export_obj.export_data.class_list.get(class_nm)
				if class_path.get_file() == file_path.get_file():
					line = ""
					#if not class_nm in classes_preloaded:
						#classes_preloaded.append(class_nm) # is the class, don't preload// this actually seems ok..
		elif line.find("preload(") > -1 and line.count('"') == 2:
			var class_nm = line.get_slice("preload(", 0)
			class_nm = class_nm.get_slice("=", 0)
			class_nm = class_nm.get_slice("const", 1).strip_edges()
			if class_nm in class_renames_keys:
				if not class_nm in classes_preloaded:
					classes_preloaded.append(class_nm)
		elif line.find("extends ") > -1 and line.count('"') == 2:
			if line.find("class ") == -1:
				var extend_file_path = line.get_slice('"', 1)
				extend_file_path = line.get_slice('"', 0)
				var inherited_used_classes = _recursive_get_globals(extend_file_path)
				classes_preloaded.append_array(inherited_used_classes)
				#classes_preloaded.append_array(class_renames_keys)
			pass
		
		adjusted_file_lines.append(line)
	
	if not classes_used.is_empty():
		print(file_path)
		print(classes_used)
		print(classes_preloaded)
	
	var rename_lines = []
	for name in export_obj.global_classes.keys():
		if name in classes_preloaded:
			continue
		if not name in class_renames_keys:
			continue
		if not name in classes_used:
			continue
		var export_path = class_renames[name]
		if export_path == "":
			printerr("Error renaming class: %s, could not get export path.")
			continue
		var line = 'const %s' % name 
		line = line + ' = preload("%s")' % export_path # "" <- stop parse issue. Get export path
		rename_lines.append(line)
	
	if not rename_lines.is_empty():
		var i = 5
		adjusted_file_lines.insert(i, ""); i += 1
		adjusted_file_lines.insert(i, "### Plugin Exporter Global Classes"); i += 1
		for line in rename_lines:
			adjusted_file_lines.insert(i, line)
			i += 1
		adjusted_file_lines.insert(i, "### Plugin Exporter Global Classes"); i += 1
		adjusted_file_lines.insert(i, "")
		#adjusted_file_lines.append("")
		#adjusted_file_lines.append_array(rename_lines)
	
	return adjusted_file_lines

func _recursive_get_globals(file_path) -> Array:
	var class_list_keys = export_obj.export_data.class_list.keys()
	var classes = []
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	if not file_access:
		return []
	while not file_access.eof_reached():
		var line = file_access.get_line()
		classes.append_array(UtilsLocal.get_global_classes_in_text(line, class_list_keys))
	file_access.close()
	return classes


func _update_file_export_flags(line:String):
	if line.find(PLUGIN_EXPORTED_STRING) > -1:
		line = line.replace(PLUGIN_EXPORTED_STRING, PLUGIN_EXPORTED_REPLACE)
	return line

