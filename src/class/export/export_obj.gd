const PLUGIN_EXPORTED = false

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

var virtual_files:Dictionary = {}

var ignore_dependencies:= false

var rename_plugin := false
var plugin_name := ""
var new_plugin_name := ""

var use_relative_paths := false

var parser_overide_settings:Dictionary = {}
var file_parser:_FileParser

var files_to_copy:Dictionary = {}
var files_to_process_for_paths:Dictionary = {}

var replace_with_files:Dictionary = {}

var file_dependencies:Dictionary = {}

var adjusted_remote_paths:Dictionary = {}
var global_classes_used:Dictionary = {}
var global_classes_used_paths:Dictionary = {}

var class_rename_ignore:Array = []
var class_renames:Dictionary = {}

var unique_files:Array = []

var shared_data:Dictionary = {}

var export_file_data:Dictionary = {}

var export_valid = true

func get_backport_files(backport_target):
	var required_backport_files = _UtilsLocal.Backport.get_required_files(backport_target)
	
	for file in required_backport_files:
		if file in source_files:
			continue
		unique_files.append(file)
		var export_path = get_remote_file_local_path(file)
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
		
		var export_path = get_export_path(l_path)
		
		if FileAccess.file_exists(export_path) and not export_data.overwrite:
			_UEditor.push_toast("File exists, aborting: " + export_path, 2)
			return
		
		if FileAccess.file_exists(l_path): # check that it is file vs dir
			valid_files_for_transfer[l_path] = {_ExportFileKeys.to:export_path}
			if rename_plugin:
				adjusted_remote_paths[l_path] = get_renamed_path(l_path)
			
			
	
	other_transfers_data = _ExportFileUtils.get_other_transfer_data(self)
	for to in other_transfers_data.keys():
		var data = other_transfers_data.get(to)
		var from_files = data.get(_ExportFileKeys.from_files)
		var single_from = data.get(_ExportFileKeys.single)
		var custom_message = data.get(_ExportFileKeys.custom_tree_message)
		for from in from_files:
			if not FileAccess.file_exists(from):
				if not from.begins_with("PE_VIRTUAL"):
					_UEditor.push_toast("File_doesn't exist, aborting: " + from, 2)
					return
				var virtual_file_type = from
				var virtual_export_path = get_export_path(to)
				if not virtual_files.has(virtual_file_type):
					virtual_files[virtual_file_type] = {}
				virtual_files[virtual_file_type][to] = {
					_ExportFileKeys.to: virtual_export_path,
					_ExportFileKeys.custom_tree_message: custom_message
				}
				continue
			
			var to_path = to
			if not single_from:
				to_path = to.path_join(from.get_file())
			
			if FileAccess.file_exists(to_path) and not export_data.overwrite:
				_UEditor.push_toast("File exists, aborting: " + to_path, 2)
				return
			
			var export_path = get_export_path(to_path)
			valid_files_for_transfer[from] = {_ExportFileKeys.to:export_path}
			if custom_message:
				valid_files_for_transfer[from][_ExportFileKeys.custom_tree_message] = custom_message
			
			files_to_process_for_paths[from] = {_ExportFileKeys.to:export_path}
			
			var adj_path = get_renamed_path(to_path)
			adjusted_remote_paths[from] = adj_path
			




func sort_valid_files():
	for file:String in valid_files_for_transfer.keys():
		var standard_export_path = file.replace(source, export_dir_path)
		
		if not file_parser.check_file_valid(file):
			files_to_copy[file] = valid_files_for_transfer.get(file)
			#files_to_copy[file] = {_ExportFileKeys.to: standard_export_path}
			continue
		
		var file_ext = file.get_extension()
		if file_ext == "tres" or file_ext == "tscn":
			files_to_process_for_paths[file] = {_ExportFileKeys.to: standard_export_path}
			files_to_copy[file] = valid_files_for_transfer.get(file)
			continue
		
		var file_needs_processing = _ExportFileUtils.is_remote_file(file)
		if not file_needs_processing:
			files_to_copy[file] = valid_files_for_transfer.get(file)
			#files_to_process_for_paths[file] = valid_files_for_transfer.get(file) # TODO is this ok?
		else: #^ is the same as above but excludes gd, I think want to exclude, but tscn and tres should be processed no matter
			var file_access = FileAccess.open(file, FileAccess.READ)
			var is_remote = false
			while not file_access.eof_reached():
				var line = file_access.get_line()
				var extend_idx = line.find("extends ") # ""
				var class_idx = line.find("class ") # ""
				var comment_idx = line.find("#")
				if comment_idx > -1 and comment_idx < extend_idx:
					continue
				
				if extend_idx > -1 and line.count('"') == 2 and (class_idx == -1 or class_idx > extend_idx):
					var remote_file_path = line.get_slice('"', 1)
					remote_file_path = remote_file_path.get_slice('"', 0)
					if not remote_file_path.is_absolute_path():
						var absolute = ensure_absolute_path(remote_file_path, file)
						print("Not absolute path: %s -> %s" % [remote_file_path, absolute])
						remote_file_path = absolute
					
					if FileAccess.file_exists(remote_file_path):
						var file_export_data = {
							_ExportFileKeys.to: standard_export_path,
							_ExportFileKeys.replace_with: remote_file_path
							}
						files_to_process_for_paths[file] = file_export_data # process file for dependencies
						files_to_copy[file] = valid_files_for_transfer.get(file)
						files_to_copy[file][_ExportFileKeys.replace_with] = remote_file_path # when copying, replace with remote
						replace_with_files[remote_file_path] = file # add to point files where this is dependency to this path
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
		
		var file_ext = file.get_extension()
		var classes_used
		if file_ext == "gd":
			classes_used = _ExportFileUtils.get_global_classes_in_file(file, export_data.class_list)
		elif file_ext == "tres" or file_ext == "tscn":
			var classes = {}
			var scripts = _ExportFileUtils.get_scripts_in_ser_file(file)
			for path in scripts:
				var class_nm = export_data.class_path_lookup.get(path)
				if class_nm != null:
					classes[class_nm] = true
			
			classes_used = classes.keys()
			if classes_used.is_empty():
				continue
		
		if classes_used == null:
			continue
		
		for class_nm in classes_used:
			var remote_path = export_data.class_list.get(class_nm)
			if global_classes_used.has(class_nm):
				continue
			global_classes_used[class_nm] = {
				_ExportFileKeys.dependent: file,
				_ExportFileKeys.path: remote_path
				}
			global_classes_used_paths[remote_path] = class_nm
			if _UtilsRemote.UFile.is_file_in_directory(remote_path, source):
				if not _ExportFileUtils.is_remote_file(remote_path):
					continue
			files_to_process_for_paths[remote_path] = {}


func get_file_dependencies():
	if ignore_dependencies:
		return
		
	var scanned_files = {}
	for file_path in files_to_process_for_paths.keys():
		file_parser.get_dependencies(file_path, file_dependencies, scanned_files)
	
	for remote_path:String in file_dependencies.keys():
		if replace_with_files.has(remote_path): #^ if it is in the replace files, then it is probably out of remote folder
			var replace_path = replace_with_files.get(remote_path) #^ get the to be replaced file path
			adjusted_remote_paths[remote_path] = get_renamed_path(replace_path) #^ set the adjusted path to the replace path
			continue #^ and don't copy another to remote
		
		var data = file_dependencies.get(remote_path, {})
		var dependent:String = data.get(_ExportFileKeys.dependent, "")
		var dependency_dir = data.get(_ExportFileKeys.dependency_dir)
		if _UtilsRemote.UFile.is_file_in_directory(remote_path, source):
			continue
		
		if dependent != "":
			var dep_data = files_to_copy.get(dependent, {})
			var replace_dep_with = dep_data.get(_ExportFileKeys.replace_with)
			if replace_dep_with != null:
				if replace_dep_with == remote_path:
					continue # stop remote classes from creating extra copy in remote
		
		
		var remote_dir_path = get_remote_file_local_path(remote_path)
		if dependency_dir == "current":
			remote_dir_path = dependent.get_base_dir().path_join(remote_path.get_file())
		elif dependency_dir != null and dependency_dir != "":
			remote_dir_path = dependency_dir.path_join(remote_path.get_file())
		
		var adjusted_path = get_renamed_path(remote_dir_path)
		var export_path = get_export_path(remote_dir_path)
		adjusted_remote_paths[remote_path] = adjusted_path
		
		files_to_copy[remote_path] = {
			_ExportFileKeys.to: export_path,
			_ExportFileKeys.dependent: dependent
			}


func get_global_class_export_paths():
	for name in global_classes_used.keys():
		if name in class_renames.keys():
			var data = global_classes_used.get(name)
			var remote_path = data.get(_ExportFileKeys.path)
			var dependent = data.get(_ExportFileKeys.dependent)
			var remote_dir_path = get_remote_file_local_path(remote_path)
			
			if _UtilsRemote.UFile.is_file_in_directory(remote_path, source):
				remote_dir_path = remote_path # if in plugin, do not move to remote
				dependent = null # if in plugin, no dependent, will be transferred regardless
			elif dependent == remote_path:
				dependent = null # if global class was found in self, no dependent
			var adjusted_path = remote_dir_path
			adjusted_path = get_renamed_path(adjusted_path)
			adjusted_remote_paths[remote_path] = adjusted_path
			class_renames[name] = remote_path
			
			var export_path = get_export_path(remote_dir_path)
			files_to_copy[remote_path] = {
				_ExportFileKeys.to: export_path,
				_ExportFileKeys.dependent: dependent,
				}

func check_all_files_have_valid_path():
	for file_path in files_to_copy.keys():
		var file_data = files_to_copy.get(file_path)
		var export_path = file_data.get(_ExportFileKeys.to)
		var replace_with = file_data.get(_ExportFileKeys.replace_with)
		var source_path = file_path
		if replace_with != null:
			source_path = replace_with
		
		check_file_has_valid_path(source_path, export_path)

func get_singleton_modules():
	var all_data = []
	for file_path:String in files_to_copy.keys():
		if not file_parser.check_file_valid(file_path):
			continue
		var file_access = FileAccess.open(file_path, FileAccess.READ)
		var count = 0
		while not file_access.eof_reached() and count < 10:
			var line = file_access.get_line()
			if line.find("class_name") == -1:
				continue
			if line.find("#! singleton-module") == -1:
				break
			var _class_name = line.get_slice("class_name", 1).get_slice("#!", 0).strip_edges()
			var version = line.get_slice("#! singleton-module", 1).strip_edges()
			if version == "":
				var base_dir = file_path.get_base_dir()
				while base_dir != "res://":
					var config_path = base_dir.path_join("plugin.cfg")
					if not FileAccess.file_exists(config_path):
						config_path = base_dir.path_join("version.cfg")
					if not FileAccess.file_exists(config_path):
						base_dir = base_dir.get_base_dir()
					else:
						version = _UtilsRemote.UConfig.load_val_from_config("plugin", "version", "0.0.0", config_path)
						break
			
			var adjusted_path = adjusted_remote_paths.get(file_path, file_path)
			var singleton_data = {
				"name":_class_name,
				"version": str(version),
				"path": adjusted_path
			}
			all_data.append(singleton_data)
			break
	
	export_file_data["singleton_modules"] = all_data

func write_export_data_file():
	var all_data_path = export_dir_path.path_join(".export_data")
	_UtilsRemote.UFile.write_to_json(export_file_data, all_data_path)


func check_file_has_valid_path(source_path:String, export_path:String) -> void:
	var globalized_source = ProjectSettings.globalize_path(source_path)
	var globalized_export = ProjectSettings.globalize_path(export_path)
	
	if globalized_export.is_relative_path():
		print("Issue with file export, export path is relative path: %s" % globalized_export)
		export_valid = false
	if globalized_source == globalized_export:
		print("Issue with file export, export path == source path: %s" % globalized_source)
		export_valid = false


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
			if file_path in file_dep_keys or file_path in unique_files:
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
	
	for virtual_file_type in virtual_files.keys():
		var virtual_file_type_data = virtual_files[virtual_file_type]
		for local_file_path in virtual_file_type_data.keys():
			var export_file_data = virtual_file_type_data.get(local_file_path)
			var export_path = export_file_data.get(_ExportFileKeys.to)
			
			_write_virtual_file(virtual_file_type, export_path)
	

##

func get_class_renames():
	for _class_name in export_data.class_list_array:
		if _class_name not in class_rename_ignore:
			class_renames[_class_name] = ""

func get_remote_file_local_path(file_path:String) -> String:
	var stripped_path = file_path.trim_prefix("res://")
	
	var remote_count = stripped_path.count("/remote/") ## This will remove duplicate files from exported plugins
	if remote_count > 0:
		stripped_path = stripped_path.get_slice("/remote/", remote_count)
	
	var remote_dir_path = remote_dir.path_join(stripped_path)
	
	return remote_dir_path

func get_renamed_path(file_path:String) -> String:
	if not rename_plugin:
		return file_path
	if file_path.begins_with(plugin_name):
		file_path = new_plugin_name.path_join(file_path.trim_prefix(plugin_name))
	return file_path

func get_export_path(file_path:String) -> String:
	file_path = file_path.replace(source, export_dir_path)
	return file_path

func get_relative_path(file_path:String) -> String:
	var current_file = file_parser.current_file_path_parsing
	var current_file_export = adjusted_remote_paths.get(current_file, current_file)
	var new_path = _UtilsRemote.UFile.get_relative_path(current_file_export, file_path)
	return new_path

func ensure_absolute_path(file_path:String, current_file_path:String):
	if file_path.begins_with("uid:"):
		return _UtilsRemote.UFile.uid_to_path(file_path)
	var abs = _UtilsRemote.UFile.path_from_relative(file_path, current_file_path)
	#if not file_path.is_absolute_path() and not PLUGIN_EXPORTED:
		#print("Rel to Abs: %s -> %s" % [file_path, abs])
	return abs

func get_rel_or_absolute_path(path:String) -> String:
	if use_relative_paths:
		var rel = get_relative_path(path)
		if not rel.begins_with("."):
			rel = "./" + rel
		return rel
	else:
		return ensure_absolute_path(path, file_parser.current_file_path_parsing)


func invalidate():
	export_valid = false

##

func _simple_export(from, export_path, export_uid_file, export_import_file):
	if FileAccess.file_exists(export_path): ## this message prints when a duplicate is replaced with get_remote_file_local_path ^^
		var raw_path = export_dir_path.get_base_dir().get_base_dir()
		var msg = "Overwriting duplicate file: %s with %s" % [export_path.replace(raw_path, "").trim_prefix("/"), from]
		_UtilsRemote.UEditor.print_warn(msg)
	
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


func _write_virtual_file(virtual_file_type:String, export_path:String):
	var export_path_dir = export_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(export_path_dir):
		DirAccess.make_dir_recursive_absolute(export_path_dir)
	
	if virtual_file_type == _ExportFileKeys.PE_VIRTUAL_GDIGNORE:
		var fa = FileAccess.open(export_path, FileAccess.WRITE)
		fa.close()
