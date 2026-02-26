
const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")

const ExportData = UtilsLocal.ExportData
const FileParser = UtilsLocal.FileParser

const UFile = UtilsRemote.UFile
const UString = UtilsRemote.UString
const UConfig = UtilsRemote.UConfig
const UEditor = UtilsRemote.UEditor
const UClassDetail = UtilsRemote.UClassDetail

const ConfirmationDialogHandler = UtilsRemote.ConfirmationDialogHandler

static var _global_class_regex:RegEx
static var _lookback_regex:RegEx

static var string_maps = {}


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
		UEditor.print_warn("Multiple exports, defaulting to first.")
	if desired_export == -1:
		desired_export = 0
	if desired_export > exports.size() - 1:
		printerr("Desired export index greater than exports in file.")
		return
	
	var export = exports[desired_export] as ExportData.Export
	var local_path = ProjectSettings.localize_path(file_path)
	if local_path not in export.valid_files_for_transfer.keys():
		UEditor.print_warn("File path not a valid export: %s" % file_path)
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
		UEditor.push_toast("Plugin or version file not present: " + plugin_cfg_path + ", Aborting.", 2)
		return
	
	var plugin_data = UConfig.load_config_data(plugin_cfg_path)
	if not plugin_data:
		UEditor.push_toast("Issue getting plugin data. Aborting.", 2)
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
		UEditor.push_toast("%s script file not found." % func_name, 2)
		return false
	var loaded_script = load(script_path)
	var script_ins = loaded_script.new()
	var script_valid = script_ins.has_method(func_name)
	script_ins.queue_free()
	if not script_valid:
		UEditor.push_toast("%s script does not have method: post_export." % func_name, 2)
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


#static func scan_file_for_global_classes(file_path:String, export_obj:ExportData.Export):
	#var file_access = FileAccess.open(file_path, FileAccess.READ)
	#var class_names = export_obj.export_data.class_list.keys()
	#
	#var classes_used = {}
	##var global_classes_in_files = 
	#
	#while not file_access.eof_reached():
		#var line = file_access.get_line()
		#var tokens = Tokenizer.words_only(line)
		#for tok:String in tokens:
			#if tok in class_names:
				#var path = export_obj.export_data.class_list.get(tok)
				##export_obj.global_classes_used[tok] = path
				#classes_used[tok] = path
	#
	#return classes_used


static func get_other_transfer_data(export_obj:ExportData.Export):
	var other_transfers_array = export_obj.other_transfers
	var export_dir_path = export_obj.export_dir_path
	var export_source_path = export_obj.source
	
	var other_transfer_data = {}
	for other in other_transfers_array:
		var custom_message = other.get(ExportFileKeys.custom_tree_message)
		var to:String = other.get(ExportFileKeys.to)
		#if not to.begins_with(export_dir_path):
			#to = export_dir_path.path_join(to)
		if not to.begins_with(export_source_path):
			to = export_source_path.path_join(to)
			
		var from_files = other.get(ExportFileKeys.from)
		if from_files == null:
			if to.get_file() == ".gdignore":
				from_files = ExportFileKeys.PE_VIRTUAL_GDIGNORE
				custom_message = " (virtual file)"
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
			elif from_files.begins_with(ExportFileKeys.PE_VIRTUAL):
				from_files = [from_files]
				single_from = true
			else:
				printerr("Path not file or dir: %s" % from_files)
				return {}
		elif from_files is Array:
			for file in from_files:
				if not FileAccess.file_exists(file):
					printerr("File doesn't exist, aborting: %s" % file)
					return {}
		
		if from_files is not Array:
			printerr("Issues with other transfers, destination: %s" % to)
			return {}
		
		#if to in other_transfer_data.keys():
		if other_transfer_data.has(to):
			var to_data = other_transfer_data[to]
			var single = to_data.get(ExportFileKeys.single)
			if single:
				printerr("Error with other transfers file, exporting multiple files to single file: %s" % to)
				return {}
			to_data[ExportFileKeys.from_files].append_array(from_files)
		else:
			other_transfer_data[to] = {ExportFileKeys.from_files:from_files, ExportFileKeys.single:single_from}
			if custom_message:
				other_transfer_data[to][ExportFileKeys.custom_tree_message] = custom_message
	
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
			f_path = f_path.trim_prefix("/") # what is this for??
		zip.start_file(f_path)
		var f_content = FileAccess.get_file_as_bytes(f)
		zip.write_file(f_content)
		zip.close_file()
	
	zip.close()
	return OK

static func write_new_uid(uid_path):
	var id = ResourceUID.create_id()
	var uid = ResourceUID.id_to_text(id)
	var f = FileAccess.open(uid_path, FileAccess.WRITE)
	f.store_string(uid)

static func is_remote_file(file_path:String):
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	var count = 0
	while not file_access.eof_reached() and count < 10:
		var line = file_access.get_line()
		if line.begins_with("#! remote"):
			return true
		count += 1
	
	return false
	
	#var first_line = file_access.get_line()
	#file_access.close()
	#if first_line.find("#! remote") == -1:
		#return false
	#return true

static func name_to_export_config_path(plugin_name:String):
	return "res://addons".path_join(plugin_name).path_join("export_ignore").path_join("plugin_export.json")

static func get_global_classes_in_file(file_path:String, global_class_dict:Dictionary):
	var class_data = _get_global_classes_in_file(file_path, global_class_dict)
	class_data.erase("global_class_definition")
	return class_data.keys()

static func _get_global_classes_in_file(file_path:String, global_class_dict:Dictionary):
	if not is_instance_valid(_global_class_regex):
		_global_class_regex = RegEx.new()
		_global_class_regex.compile("\\b[a-zA-Z_]\\w*\\b")
	
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	if not file_access:
		printerr("Could not open file: %s" % file_path)
		return {}
	var file_as_string = file_access.get_as_text()
	var string_map = get_string_map(file_as_string)
	var found_classes = {}
	
	var matches = _global_class_regex.search_all(file_as_string)
	for m in matches:
		var start_index = m.get_start()
		var word = m.get_string()
		if not global_class_dict.has(word):
			continue
		if string_map.index_in_string_or_comment(start_index):
			continue
		#if string_map.comment_mask[start_index] == 1:
			#continue
		#if string_map.string_mask[start_index] == 1:
			#continue
		if is_class_definition(file_as_string, start_index):
			found_classes["global_class_definition"] = word
			continue
		
		found_classes[word] = true
	
	return found_classes

static func get_string_map(text:String):
	if not is_instance_valid(string_maps):
		string_maps = {}
	if string_maps.has(text):
		return string_maps[text]
	var string_map = UString.get_string_map(text, UString.StringMap.Mode.STRING)
	string_maps[text] = string_map
	return string_map

static func is_class_definition(text: String, current_index: int) -> bool:
	if not is_instance_valid(_lookback_regex):
		_lookback_regex = RegEx.new()
		_lookback_regex.compile("\\bclass_name\\s*$")
	
	if current_index < 10:
		return false
	var lookback_amount = 20
	var start = max(0, current_index - lookback_amount)
	var length = current_index - start
	var preceding_text = text.substr(start, length)
	# Check if that chunk ends with "class_name" + whitespace
	return _lookback_regex.search(preceding_text) != null

static func get_scripts_in_ser_file(file_path:String):
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	var scripts = {}
	
	while not file_access.eof_reached():
		var line = file_access.get_line()
		if line.begins_with('[ext_resource'):
			var path = line.get_slice('path="', 1)
			path = path.get_slice('"', 0)
			if path.get_extension() == "gd":
				scripts[path] = true
	
	return scripts.keys()

static func get_global_singleton_module_scripts():
	var global_classes = UClassDetail.get_all_global_class_paths()
	var valid = []
	for path in global_classes.values():
		if is_singleton_module_script(path):
			valid.append(path)
	return valid

static func is_singleton_module_script(file_path:String):
	if not file_path.get_extension() == "gd": return false
	var singleton_scripts = ["singleton_base.gd", "singleton_ref_count.gd"]
	if file_path.get_file() in singleton_scripts:
		return false
	var script = load(file_path) as GDScript
	var base_type = script.get_base_script()
	if base_type == null: return false
	return base_type.resource_path.get_file() in singleton_scripts


class ExportFileKeys:
	const export_root = "export_root"
	const plugin_folder = "plugin_folder"
	const pre_script = "pre_script"
	const post_script = "post_script"
	
	const exports = "exports"
	const source = "source"
	const remote_dir = "remote_dir"
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
	
	const path = "path"
	const replace_with = "replace_with"
	const adjusted_remote_path = "adjusted_remote_path"
	const dependent = "dependent"
	const dependency_dir = "dependency_dir"
	
	const custom_tree_message = "custom_tree_message"
	
	const options = "options"
	const include_import = "include_import"
	const include_uid = "include_uid"
	const overwrite = "overwrite"
	const ignore_dependencies = "ignore_dependencies"
	
	const parser_settings = "parser_settings"
	const parser_overide_settings = "parser_overide_settings"
	
	# virtual file keys
	const PE_VIRTUAL = "PE_VIRTUAL"
	const PE_VIRTUAL_GDIGNORE = PE_VIRTUAL + "_GDIGNORE"
