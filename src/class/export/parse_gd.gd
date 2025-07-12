extends "res://addons/plugin_exporter/src/class/export/parse_base.gd"



func edit_dep_file(line:String, to:String, remote_file:String, remote_dir:String, dependencies:Dictionary, file_lines:Array):
	if line.find("#! remote") > -1:
		
		pass
	if line.find("extends") > -1 and line.count('"') == 2:
		if _check_for_comment(line, ["extends", "class"]):
			file_lines.append(line) 
			return
		var _class
		if line.find("class ") > -1:
			_class = line.get_slice("class ", 1)
			_class = _class.get_slice(" ", 0)
		var extend_path = line.get_slice('extends', 1).strip_edges().trim_prefix('"')
		extend_path = extend_path.get_slice('"', 0)
		var file_name = extend_path.get_file()
		var to_path = remote_dir.path_join(file_name)
		var depen_data = {"from": extend_path, "to": to_path, RemoteData.dependent: remote_file}
		var final_path = file_name
		var rel_path = UFile.get_relative_path(to, to_path)
		if _class == null:
			line = 'extends "%s"' % rel_path
		else:
			line = 'class %s extends "%s":' % [_class, rel_path]
		dependencies[file_name] = depen_data
	elif line.find("preload(") > -1: #TODO make these regexs or somtehitng more robust.
		var preload_path = get_preload_path(line)
		if preload_path == null:
			file_lines.append(line)
			return
		var file_name = preload_path.get_file()
		var to_path = remote_dir.path_join(file_name)
		var rel_path = UFile.get_relative_path(to, to_path)
		var original_preload_call = 'preload("%s")' % preload_path
		if line.find('"%s"' % preload_path) == -1:
			original_preload_call = 'preload("%s")' % UFile.path_to_uid(preload_path)
		var new_preload_call = 'preload("%s")' % rel_path
		line = line.replace(original_preload_call, new_preload_call)
		var depen_data = {"from": preload_path, "to": to_path, RemoteData.dependent: remote_file}
		if dependencies.has(file_name) and dependencies[file_name].from != remote_file:
			printerr("WARNING: Filename collision detected for '%s'." % file_name)
			printerr("  Source 1: %s" % dependencies[file_name].from)
			printerr("  Source 2: %s" % preload_path)
			printerr("  The second file will overwrite the first in the destination directory.")
		dependencies[file_name] = depen_data
		
		if remote_file.get_file() == "filesystem.gd":
			print(original_preload_call, " ", new_preload_call)
	
	file_lines.append(line)
