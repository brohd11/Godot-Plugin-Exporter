extends RefCounted

static func incremental_name_check(save_path:String) -> String:

	if FileAccess.file_exists(save_path):
		var folder = save_path.get_base_dir()
		var files = DirAccess.get_files_at(folder)
		var file_nm = save_path.get_file().get_basename()
		var file_ex = "." + save_path.get_extension()
		
		var count = 0
		for f in files:
			if file_nm in f:
				count += 1
				save_path = folder.path_join(file_nm + "_" + str(count) + file_ex)
			if not FileAccess.file_exists(save_path):
				break
	return save_path


static func incremental_name_check_in_array(name:String, array:Array) -> String:
	var count = 1
	var new_name = name
	while new_name in array:
		new_name = name + "_" + str(count)
		
		count += 1
	
	return new_name


static func incremental_dir_check(dir:String) -> String:
	var count = 0
	if DirAccess.dir_exists_absolute(dir):
		var par_dir = dir.get_base_dir()
		
		var dirs = DirAccess.get_directories_at(par_dir)
		var dir_name = dir.get_file()
		for d in dirs:
			if dir_name in d:
				count += 1
				dir = par_dir.path_join(dir_name+"_"+str(count))
			if not DirAccess.dir_exists_absolute(dir):
				break
	return dir


static func incremental_name_check_in_nodes(name:String, parent_node:Node) -> String:
	var count = 1
	var name_array = []
	for node in parent_node.get_children():
		name_array.append(node.name)
		
	var new_name = name
	while new_name in name_array:
		new_name = name + "_" + str(count)
		
		count += 1
	
	return new_name


### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_u_name = "res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_runtime/utils/src/u_name.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
