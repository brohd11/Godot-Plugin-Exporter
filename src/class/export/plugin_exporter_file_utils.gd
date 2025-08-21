
const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")

const ExportData = UtilsLocal.ExportData
const FileParser = UtilsLocal.FileParser

const UFile = UtilsRemote.UFile
const UConfig = UtilsRemote.UConfig
const USafeEditor = UtilsRemote.USafeEditor

static func get_export_data(export_config_path):
	if not FileAccess.file_exists(export_config_path):
		print("Export file path does not exist.")
		return
	var export_file = FileAccess.open(export_config_path, FileAccess.READ)
	if export_file == null:
		printerr("Error opening export configuration file: " + export_config_path)
		return
	
	var config_string = export_file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(config_string)
	if parse_result != OK:
		printerr("Plugin Exporter - Error parsing JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		return
	return json.data

static func get_file_export_path(file_path:String, export_config_path:String, desired_export:int=-1, export_data:ExportData=null):
	if not FileAccess.file_exists(file_path):
		printerr("Plugin Exporter - File doesn't exist: %s" % file_path)
		return
	if export_data == null:
		export_data = ExportData.new(export_config_path)
	if not export_data.data_valid:
		printerr("Issue with export data.")
		return
	
	var exports = export_data.exports
	if exports.size() > 1 and desired_export == -1:
		USafeEditor.print_warn("Multiple exports, defaulting to first.")
	if desired_export == -1:
		desired_export = 0
	if desired_export > exports.size() - 1:
		printerr("Desired export index greater than exports in file.")
		return
	
	var export = exports[desired_export] as ExportData.Export
	var local_path = ProjectSettings.localize_path(file_path)
	if local_path not in export.valid_files_for_transfer.keys():
		USafeEditor.print_warn("File path not a valid export: %s" % file_path)
		return
	else:
		var export_file_data = export.valid_files_for_transfer.get(local_path)
		var export_path = export_file_data.get(ExportFileKeys.to)
		return export_path


static func get_version(folder, export_config_file):
	var addons_folder = "res://addons"
	var target_folder = addons_folder.path_join(folder)
	var plugin_cfg_path = target_folder.path_join("plugin.cfg")
	if not FileAccess.file_exists(plugin_cfg_path):
		plugin_cfg_path = target_folder.path_join("version.cfg")
	if not FileAccess.file_exists(plugin_cfg_path):
		plugin_cfg_path = export_config_file.get_base_dir().path_join("version.cfg")
	if not FileAccess.file_exists(plugin_cfg_path):
		plugin_cfg_path = export_config_file.get_base_dir().get_base_dir().path_join("version.cfg")
	
	if not FileAccess.file_exists(plugin_cfg_path):
		USafeEditor.push_toast("Plugin or version file not present: " + plugin_cfg_path + ", Aborting.", 2)
		return
	
	var plugin_data = UConfig.load_config_data(plugin_cfg_path)
	if not plugin_data:
		USafeEditor.push_toast("Issue getting plugin data. Aborting.", 2)
		return 
	return plugin_data.get_value("plugin", "version", "No version")


static func replace_version(input_text: String, export_config_file) -> String:
	var output_text = ""
	var slice_count = input_text.get_slice_count("/")
	var regex = RegEx.new()
	var pattern = r"\{\{version=([^}]*)\}\}"
	regex.compile(pattern)
	for i in range(slice_count):
		var slice = input_text.get_slice("/", i)
		var edited_slice
		if slice.find("{{version=") > -1:
			var _match = regex.search(slice)
			var version_target = _match.get_string(1)
			var version = get_version(version_target, export_config_file)
			if version:
				version = "-" + version
				edited_slice = regex.sub(slice, version)
			else:
				edited_slice = regex.sub(slice, "{{version error}}")
				return ""
		elif slice.find("{{version}}") > -1:
			var version_target = slice.replace("{{version}}", "")
			var version = get_version(version_target, export_config_file)
			if version:
				version = "-" + version
				edited_slice = slice.replace("{{version}}", version)
			else:
				edited_slice = slice.replace("{{version}}", "{{version error}}")
				return ""
		else:
			edited_slice = slice
		if edited_slice != "":
			output_text += edited_slice + "/"
	
	return output_text


static func get_full_export_path(export_root, plugin_folder, export_config_path):
	export_root = ProjectSettings.globalize_path(export_root)
	var full_export_path = export_root.path_join(plugin_folder)
	full_export_path = replace_version(full_export_path, export_config_path)
	if full_export_path == "":
		return ""
	if not full_export_path.ends_with("/"):
		full_export_path = full_export_path + "/"
	
	var os_name = OS.get_name()
	if os_name == "Linux" or os_name == "macOS": # not sure about mac
		if not full_export_path.begins_with("/"):
			full_export_path = "/" + full_export_path
	
	return full_export_path


static func run_export_script(script_path, func_name):
	if not check_export_script_valid(script_path, func_name):
		return
	_run_export_script(script_path, func_name)

static func check_export_script_valid(script_path, func_name):
	if not FileAccess.file_exists(script_path):
		USafeEditor.push_toast("%s script file not found." % func_name, 2)
		return false
	var loaded_script = load(script_path)
	var script_ins = loaded_script.new()
	var script_valid = script_ins.has_method(func_name)
	script_ins.queue_free()
	if not script_valid:
		USafeEditor.push_toast("%s script does not have method: post_export." % func_name, 2)
		return false
	return true

static func _run_export_script(script_path, func_name):
	var script = load(script_path)
	var script_ins = script.new()
	EditorInterface.get_base_control().add_child(script_ins)
	await script_ins.call(func_name)
	script_ins.queue_free()


static func check_ignore(local_path, export_obj:ExportData.Export):
	for d in export_obj.exclude_directories:
		if local_path.find(d) > -1:
			return true
	var file_ext = local_path.get_extension()
	for ext in export_obj.exclude_file_extensions:
		if ext == file_ext:
			return true
	for f in export_obj.exclude_files:
		if f == local_path:
			return true
	
	return false


static func export_file(from, to, export_uid_file, export_import_file):
	var to_dir = to.get_base_dir()
	if not DirAccess.dir_exists_absolute(to_dir):
		DirAccess.make_dir_recursive_absolute(to_dir)
	DirAccess.copy_absolute(from, to)
	
	var from_uid = from + ".uid"
	var to_uid = to + ".uid"
	if FileAccess.file_exists(from_uid) and export_uid_file:
		DirAccess.copy_absolute(from_uid, to_uid)
	var from_import = from + ".import"
	var to_import = to + ".import"
	if FileAccess.file_exists(from_import) and export_uid_file:
		DirAccess.copy_absolute(from_import, to_import)

static func export_remote_file(original_from, to, remote_file_data, include_uid, include_import, file_parser):
	var remote_dir = remote_file_data.get(RemoteData.dir, "")
	if remote_dir == "":
		remote_dir = to.get_base_dir()
	var remote_class = remote_file_data.get(RemoteData.single_class)
	var remote_files = remote_file_data.get(RemoteData.files, [])
	var other_deps = remote_file_data.get(RemoteData.other_deps, [])
	if remote_files != []:
		if remote_class == null:
			export_file(original_from, to, include_uid, include_import)
			file_parser.copy_remote_dependencies(true, original_from, to, to, remote_dir)
		else: # allows for remote file to have preloads that will be copied to remote dir, will not be present in final file
			for remote_file in remote_files:
				var to_path = remote_dir.path_join(remote_file.get_file())
				export_file(remote_file, to_path, include_uid, include_import)
				file_parser.copy_remote_dependencies(true, remote_file, to_path, to, remote_dir)
	
	if remote_class != null:
		export_file(remote_class, to, false, false) # do not include uid and import files
		FileParser.write_new_uid(to + ".uid")
		file_parser.copy_remote_dependencies(true, remote_class, to, to, remote_dir)
	
	if other_deps != []:
		for dep in other_deps:
			var dep_from = dep.get(RemoteData.from)
			var dep_to = dep.get(RemoteData.to)
			export_file(dep_from, dep_to, include_uid, include_import)

static func pre_export_file_parse(export_obj:ExportData.Export):
	_get_used_global_classes(export_obj)
	export_obj.other_transfers_data = get_other_transfer_data(export_obj)
	export_obj.all_remote_files = _get_all_remote_files(export_obj)

static func _get_used_global_classes(export_obj:ExportData.Export):
	for file in export_obj.source_files:
		_scan_file_for_global_class(file, export_obj)
	
	for to_path in export_obj.other_transfers_data.keys():
		var file_data = export_obj.other_transfers_data.get(to_path)
		var from_files = file_data.get(ExportFileKeys.from_files, [])
		for file in from_files:
			_scan_file_for_global_class(file, export_obj)
	

static func _scan_file_for_global_class(file_path:String, export_obj:ExportData.Export):
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	var class_names = export_obj.export_data.class_list.keys()
	
	while not file_access.eof_reached():
		var line = file_access.get_line()
		var tokens = Tokenizer.words_only(line)
		for tok:String in tokens:
			if tok in class_names:
				var path = export_obj.export_data.class_list.get(tok)
				if not path in export_obj.global_classes.keys():
					export_obj.global_classes[tok] = path


static func get_remote_file(path, export_obj:ExportData.Export):
	
	if not path.get_extension() in FileParser.TEXT_FILE_TYPES:
		return
	var file_access = FileAccess.open(path, FileAccess.READ)
	if file_access:
		var remote_dec_line = file_access.get_line()
		file_access.close()
		if remote_dec_line.find("#! remote") == -1:
			return _get_global_remote_files(path, export_obj)
		else:
			return _get_declared_remote_file(path, export_obj)
	

static func _get_declared_remote_file(path, export_obj:ExportData.Export):
	var source = export_obj.source
	var export_dir_path = export_obj.export_dir_path
	var remote_files = []
	var other_deps = []
	var remote_file_data = {}
	
	if not path.get_extension() in FileParser.TEXT_FILE_TYPES:
		return
		
	var file_access = FileAccess.open(path, FileAccess.READ)
	if file_access:
		var remote_dec_line = file_access.get_line()
		if remote_dec_line.find("#! remote") == -1:
			return _get_global_remote_files(path, export_obj)
		var remote_dir = remote_dec_line.get_slice("#! remote", 1).strip_edges()
		if remote_dir == "":
			remote_dir = export_obj.remote_dir
		if remote_dir != "":
			remote_dir = remote_dir.replace(source, export_dir_path)
		else:
			remote_dir = path.get_base_dir().replace(source, export_dir_path)
		
		remote_file_data[RemoteData.dir] = remote_dir
		
		while not file_access.eof_reached():
			var line = file_access.get_line()
			if line.find('extends "') > -1:
				var remote_file = line.replace("extends", "").replace('"',"").strip_edges()
				remote_file_data[RemoteData.single_class] = remote_file
				#return remote_file_data
			elif line.find("preload(") > -1:
				var preload_path = UtilsLocal.ParseBase.get_preload_path(line)
				if preload_path != null:
					remote_files.append(preload_path)
			elif line.find("#! remote-dep") > -1 and line.count('"') == 2:
				var dep_index = line.find("#! remote-dep")
				var com_index = line.find("#")
				if com_index < dep_index:
					continue
				var dep_path = line.get_slice('"', 1)
				dep_path = dep_path.get_slice('"', 0)
				var dep_dest = line.get_slice("#! remote-dep", 1).strip_edges()
				if dep_dest == "":
					dep_dest = remote_dir
					if dep_dest == "":
						dep_dest = "current"
				
				if dep_dest == "current":
					dep_dest = path.get_base_dir().replace(source, export_dir_path)
				else:
					if remote_dir == "":
						if dep_dest.find(source) == -1:
							printerr("Dependency destination must be within 'source' folder: %s File: %s" % [dep_dest, dep_path])
							continue
						dep_dest = dep_dest.replace(source, export_dir_path)
				
				dep_dest = dep_dest.path_join(dep_path.get_file())
				
				other_deps.append({"from":dep_path, "to": dep_dest})
		
	remote_file_data[RemoteData.files] = remote_files
	remote_file_data[RemoteData.other_deps] = other_deps
	return remote_file_data

static func _get_global_remote_files(path, export_obj:ExportData.Export):
	var file_access = FileAccess.open(path, FileAccess.READ)
	var is_global_class:= false
	if not file_access:
		return
	while not file_access.eof_reached():
		var line = file_access.get_line()
		if line.find("class_name ") > -1:
			var class_nm = line.get_slice("class_name ", 1).strip_edges()
			if class_nm in export_obj.export_data.class_list.keys():
				is_global_class = true
				break
	
	if not is_global_class:
		return
	if UFile.is_file_in_directory(path, export_obj.source):
		return # not remote file, don't need to get deps
	
	var remote_file_data = {}
	var r_dir = export_obj.remote_dir.replace(export_obj.source, export_obj.export_dir_path)
	remote_file_data[RemoteData.dir] = r_dir
	remote_file_data[RemoteData.single_class] = path
	var remote_files = []
	file_access.seek(0)
	
	return remote_file_data


static func _get_all_remote_files(export_obj:ExportData.Export):
	var source_files = export_obj.source_files
	var source = export_obj.source
	var export_dir_path = export_obj.export_dir_path
	var all_remote_files = export_obj.all_remote_files
	
	if all_remote_files == null:
		all_remote_files = []
	
	for file in source_files:
		var local_path = ProjectSettings.localize_path(file)
		var remote_files = get_remote_file(local_path, export_obj)
		_add_remote_files_to_array(remote_files, all_remote_files)
	
	for to_path in export_obj.other_transfers_data.keys():
		var file_data = export_obj.other_transfers_data.get(to_path)
		var from_files = file_data.get(ExportFileKeys.from_files, [])
		for from in from_files:
			var remote_files = get_remote_file(from, export_obj)
			_add_remote_files_to_array(remote_files, all_remote_files)
	
	## I think redundant, global classes are already remote, unless in source, which is checked
	#for class_nm in export_obj.global_classes.keys():
		#var file_path = export_obj.global_classes.get(class_nm)
		#var remote_files = get_remote_file(file_path, export_obj)
		#_add_remote_files_to_array(remote_files, all_remote_files)
	
	return all_remote_files

static func _add_remote_files_to_array(remote_file_data, all_remote_files):
	if remote_file_data == null:
		return
	var remote_class = remote_file_data.get(RemoteData.single_class)
	var remote_files = remote_file_data.get(RemoteData.files)
	if remote_class != null:
		if not remote_class in all_remote_files:
			all_remote_files.append(remote_class)
	elif remote_files != null:
		for remote_file in remote_files:
			if not remote_file in all_remote_files:
				all_remote_files.append(remote_file)

static func get_other_transfer_data(export_obj:ExportData.Export):
	var other_transfers_array = export_obj.other_transfers
	var source = export_obj.source
	var export_dir_path = export_obj.export_dir_path
	var all_remote_files = export_obj.all_remote_files

	var other_transfer_data = {}
	for other in other_transfers_array:
		var to:String = other.get(ExportFileKeys.to)
		if not to.begins_with(export_dir_path):
			to = export_dir_path.path_join(to)
		var from_files = other.get(ExportFileKeys.from)
		if from_files == null:
			if to.get_file() == ".gdignore":
				from_files = UtilsLocal.DUMMY_GDIGNORE_FILE
		var single_from = false
		if from_files is String:
			if FileAccess.file_exists(from_files):
				from_files = [from_files]
				single_from = true
			elif DirAccess.dir_exists_absolute(from_files):
				var files_at_dir = DirAccess.get_files_at(from_files)
				var file_array = []
				for f in files_at_dir:
					var ext = f.get_extension()
					if ext == "uid" or ext == "import":
						continue
					var path = from_files.path_join(f)
					file_array.append(path)
				from_files = file_array
			else:
				printerr("Path is not file or dir: %s" % from_files)
				return
		elif from_files is Array:
			for file in from_files:
				if not FileAccess.file_exists(file):
					printerr("File doesn't exist, aborting: %s" % file)
					return
		
		if from_files is not Array:
			printerr("Issues with other transfers, destination: %s" % to)
			return
		
		if to in other_transfer_data.keys():
			var to_data = other_transfer_data[to]
			var single = to_data.get(ExportFileKeys.single)
			if single:
				printerr("Error with other transfers file, exporting multiple files to single file: %s" % to)
				return
			to_data[ExportFileKeys.from_files].append_array(from_files)
		else:
			other_transfer_data[to] = {ExportFileKeys.from_files:from_files, ExportFileKeys.single:single_from}
	
	return other_transfer_data


static func write_zip_file(path:String, files):
	var zip = ZIPPacker.new()
	var err = zip.open(path)
	if err != OK:
		return err
	var base_dir = path.get_basename()
	for f in files:
		var f_path:String = f.replace(base_dir, "")
		if f_path.begins_with("/"):
			f_path = f_path.erase(0)
		zip.start_file(f_path)
		var f_content = FileAccess.get_file_as_bytes(f)
		zip.write_file(f_content)
		zip.close_file()
	
	zip.close()
	return OK


class RemoteData:
	const dir = "remote_dir"
	const single_class = "remote_class"
	const files = "remote_files"
	const other_deps = "other_deps"
	const to = "to"
	const from = "from"
	const dependent = "dependent"

class ExportFileKeys:
	const export_root = "export_root"
	const plugin_folder = "plugin_folder"
	const pre_script = "pre_script"
	const post_script = "post_script"
	
	const exports = "exports"
	const source = "source"
	const export_folder = "export_folder"
	const exclude = "exclude"
	const directories = "directories"
	const file_extensions = "file_extensions"
	const files = "files"
	
	const other_transfers = "other_transfers"
	const from = "from"
	const to = "to"
	const from_files = "from_files"
	const single = "single"
	
	const options = "options"
	const include_import = "include_import"
	const include_uid = "include_uid"
	const overwrite = "overwrite"
