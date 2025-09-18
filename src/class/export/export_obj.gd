const _UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const _UEditor = _UtilsRemote.UEditor
const _UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")
const _ExportFileUtils = _UtilsLocal.ExportFileUtils
const _ExportFileKeys = _ExportFileUtils.ExportFileKeys
const _ExportData = _UtilsLocal.ExportData
const _FileParser = _UtilsLocal.FileParser

var export_data: _ExportData
var source:String
var remote_dir:String
var export_folder:String
var export_dir_path:String
var exclude_directories:Array
var exclude_file_extensions:Array
var exclude_files:Array
var source_files:Array
var other_transfers:Array
var other_transfers_data:Dictionary
var valid_files_for_transfer:Dictionary = {}

var ignore_dependencies:= false

var rename_plugin := false
var plugin_name := ""
var new_plugin_name := ""

var parser_overide_settings:Dictionary = {}
var file_parser:_FileParser

var files_to_copy:Dictionary = {}
var files_to_process_for_paths:Dictionary = {}
var file_dependencies:Dictionary = {}

var adjusted_remote_paths:Dictionary = {}
var global_classes_used:Dictionary = {}

func get_batch_files(backport_target):
	var required_backport_files = _UtilsLocal.Backport.get_required_files(backport_target)
	
	for file in required_backport_files:
		if file in source_files:
			continue
		
		var export_path = remote_dir.path_join(file.trim_prefix("res://"))
		other_transfers.append({
			_ExportFileKeys.from: file,
			_ExportFileKeys.to: export_path,
			_ExportFileKeys.custom_tree_message:" <- (Backport Dependency)"
		})


func get_valid_files_for_transfer():
	for file in source_files:
		if file.get_extension() == "uid" or file.get_extension() == "import":
			continue
		
		var l_path = ProjectSettings.localize_path(file)
		if _ExportFileUtils.check_ignore(l_path, self):
			continue
		
		var export_path = l_path.replace(source, export_dir_path)
		#if rename_plugin:
			#adjusted_remote_paths[l_path] = l_path.replace(plugin_name, new_plugin_name)
		
		if FileAccess.file_exists(export_path) and not export_data.overwrite:
			_UEditor.push_toast("File exists, aborting: " + export_path, 2)
			return
		
		if FileAccess.file_exists(l_path): # check that it is file vs dir
			valid_files_for_transfer[l_path] = {_ExportFileKeys.to:export_path}
			if rename_plugin:
				adjusted_remote_paths[l_path] = l_path.replace(plugin_name, new_plugin_name)
			
			
	
	other_transfers_data = _ExportFileUtils.get_other_transfer_data(self)
	for to in other_transfers_data.keys():
		var data = other_transfers_data.get(to)
		var from_files = data.get(_ExportFileKeys.from_files)
		var single_from = data.get(_ExportFileKeys.single)
		var custom_message = data.get(_ExportFileKeys.custom_tree_message)
		for from in from_files:
			if not FileAccess.file_exists(from):
				_UEditor.push_toast("File_doesn't exist, aborting: " + from, 2)
				return
			
			var to_path = to
			if not single_from:
				to_path = to.path_join(from.get_file())
			
			if FileAccess.file_exists(to_path) and not export_data.overwrite:
				_UEditor.push_toast("File exists, aborting: " + to_path, 2)
				return
			
			var export_path = to_path.replace(source, export_dir_path)
			valid_files_for_transfer[from] = {_ExportFileKeys.to:export_path}
			if custom_message:
				valid_files_for_transfer[from][_ExportFileKeys.custom_tree_message] = custom_message
			
			files_to_process_for_paths[from] = {_ExportFileKeys.to:export_path}
			
			var adj_path = to_path
			if rename_plugin:
				adj_path = adj_path.replace(plugin_name, new_plugin_name)
			adjusted_remote_paths[from] = adj_path
			




func sort_valid_files():
	for file:String in valid_files_for_transfer.keys():
		var standard_export_path = file.replace(source, export_dir_path)
		#if rename_plugin:
			#adjusted_remote_paths[file] = file.replace(plugin_name, new_plugin_name)
		
		if not file_parser.check_file_valid(file):
			files_to_copy[file] = valid_files_for_transfer.get(file)
			#files_to_copy[file] = {_ExportFileKeys.to: standard_export_path}
			continue
		
		var file_access = FileAccess.open(file, FileAccess.READ)
		var first_line = file_access.get_line()
		
		
		if first_line.find("#! remote") == -1:
			files_to_copy[file] = valid_files_for_transfer.get(file)
			#files_to_process_for_paths[file] = valid_files_for_transfer.get(file) # TODO is this ok?
		else:
			var is_remote = false
			while not file_access.eof_reached():
				var line = file_access.get_line()
				var extend_idx = line.find("extends ") # ""
				var class_idx = line.find("class ") # ""
				
				if extend_idx > -1 and line.count('"') == 2 and (class_idx == -1 or class_idx > extend_idx):
					var remote_file_path = line.get_slice('"', 1)
					remote_file_path = remote_file_path.get_slice('"', 0)
					if FileAccess.file_exists(remote_file_path):
						var file_export_data = {
							_ExportFileKeys.to: standard_export_path,
							_ExportFileKeys.replace_with: remote_file_path
							}
						files_to_process_for_paths[file] = file_export_data
						files_to_copy[file] = valid_files_for_transfer.get(file)
						files_to_copy[file][_ExportFileKeys.replace_with] = remote_file_path
						is_remote = true
						break
					else:
						printerr("Extended file could not be found: %s" % remote_file_path)
						break
			
			if not is_remote:
				files_to_process_for_paths[file] = {_ExportFileKeys.to: standard_export_path}
				files_to_copy[file] = valid_files_for_transfer.get(file)
				#files_to_copy[file] = {_ExportFileKeys.to: standard_export_path}
			
		file_access.close()


func get_global_classes_used_in_valid_files():
	if ignore_dependencies:
		return
		
	for file:String in valid_files_for_transfer.keys():
		if not file_parser.check_file_valid(file):
			continue
		var classes_used = _ExportFileUtils.scan_file_for_global_classes(file, self)
		for class_nm in classes_used:
			var remote_path = classes_used.get(class_nm)
			global_classes_used[class_nm] = {
				_ExportFileKeys.dependent: file,
				_ExportFileKeys.path: remote_path
				}
			if _UtilsRemote.UFile.is_file_in_directory(remote_path, source):
				if not _is_remote_file(remote_path):
					continue
			files_to_process_for_paths[remote_path] = {}


func get_file_dependencies():
	if ignore_dependencies:
		return
		
	var scanned_files = {}
	for file_path in files_to_process_for_paths.keys():
		file_parser.get_dependencies(file_path, file_dependencies, scanned_files)
	
	for remote_path:String in file_dependencies.keys():
		var data = file_dependencies.get(remote_path, {})
		var dependent:String = data.get(_ExportFileKeys.dependent, "")
		var dependency_dir = data.get(_ExportFileKeys.dependency_dir)
		if _UtilsRemote.UFile.is_file_in_directory(remote_path, source):
			continue
		
		if dependent != "":
			var dep_data = files_to_copy.get(dependent, {})
			var replace_with = dep_data.get(_ExportFileKeys.replace_with)
			if replace_with != null:
				if replace_with == remote_path:
					continue # stop remote classes from creating extra copy in remote
		
		if dependent == remote_path: # new system has full paths, can use full path? ^^
			continue
		var stripped_path = remote_path.trim_prefix("res://")
		var remote_dir_path = remote_dir.path_join(stripped_path)
		if dependency_dir == "current":
			remote_dir_path = dependent.get_base_dir().path_join(remote_path.get_file())
		elif dependency_dir != null and dependency_dir != "":
			remote_dir_path = dependency_dir.path_join(remote_path.get_file())
		
		var adjusted_path = remote_dir_path
		if rename_plugin:
			adjusted_path = adjusted_path.replace(plugin_name, new_plugin_name)
		adjusted_remote_paths[remote_path] = adjusted_path
		
		var export_path = remote_dir_path.replace(source, export_dir_path)
		files_to_copy[remote_path] = {
			_ExportFileKeys.to: export_path,
			_ExportFileKeys.dependent: dependent
			}


func get_global_class_export_paths():
	for name in global_classes_used.keys():
		if name in export_data.class_renames.keys():
			var data = global_classes_used.get(name)
			var remote_path = data.get(_ExportFileKeys.path)
			var dependent = data.get(_ExportFileKeys.dependent)
			var stripped_path = remote_path.trim_prefix("res://")
			var remote_dir_path = remote_dir.path_join(stripped_path)
			
			if _UtilsRemote.UFile.is_file_in_directory(remote_path, source):
				remote_dir_path = remote_path # if in plugin, do not move to remote
				dependent = null # if in plugin, no dependent, will be transferred regardless
			elif dependent == remote_path:
				dependent = null # if global class was found in self, no dependent
			var adjusted_path = remote_dir_path
			if rename_plugin:
				adjusted_path = adjusted_path.replace(plugin_name, new_plugin_name)
			adjusted_remote_paths[remote_path] = adjusted_path
			export_data.class_renames[name] = remote_path
			
			var export_path = remote_dir_path.replace(source, export_dir_path)
			files_to_copy[remote_path] = {
				_ExportFileKeys.to: export_path,
				_ExportFileKeys.dependent: dependent,
				}


func export_files():
	var files_to_process_keys = files_to_process_for_paths.keys()
	var include_uid = export_data.include_uid
	var include_import = export_data.include_import
	var file_dep_keys = file_dependencies.keys()
	var global_paths = []
	for nm in global_classes_used.keys():
		var data = global_classes_used.get(nm, {})
		global_paths.append(data.get(_ExportFileKeys.path, ""))
	file_dep_keys.append_array(global_paths)
	
	for file_path in files_to_copy.keys():
		file_parser.current_file_path_parsing = file_path
		file_parser.current_adjusted_file_path = adjusted_remote_paths.get(file_path, file_path)
		
		var file_data = files_to_copy.get(file_path)
		var export_path = file_data.get(_ExportFileKeys.to)
		var replace_with = file_data.get(_ExportFileKeys.replace_with)
		
		var file_uid = include_uid
		var file_import = include_import
		if replace_with == null:
			var is_dep = false
			if file_path in file_dep_keys:
				is_dep = true
				file_uid = false
				file_import = false # should this be?
			
			_simple_export(file_path, export_path, file_uid, file_import)
			
			if is_dep and FileAccess.file_exists(file_path + ".uid"):
				_ExportFileUtils.write_new_uid(export_path + ".uid")
			
		else:
			_simple_export(replace_with, export_path, false, false)
			if FileAccess.file_exists(replace_with + ".uid"):
				_ExportFileUtils.write_new_uid(export_path + ".uid")
		
		file_parser.post_export_edit_file(export_path)
	##
	


static func _simple_export(from, export_path, export_uid_file, export_import_file):
	var export_path_dir = export_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(export_path_dir):
		DirAccess.make_dir_recursive_absolute(export_path_dir)
	DirAccess.copy_absolute(from, export_path)
	
	var from_uid = from + ".uid"
	var export_path_uid = export_path + ".uid"
	if FileAccess.file_exists(from_uid) and export_uid_file:
		DirAccess.copy_absolute(from_uid, export_path_uid)
	var from_import = from + ".import"
	var export_path_import = export_path + ".import"
	if FileAccess.file_exists(from_import) and export_uid_file:
		DirAccess.copy_absolute(from_import, export_path_import)

static func _is_remote_file(file_path:String):
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	var first_line = file_access.get_line()
	file_access.close()
	if first_line.find("#! remote") == -1:
		return false
	return true
	
