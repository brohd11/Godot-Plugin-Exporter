
const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")

const ExportData = UtilsLocal.ExportData
const FileParser = UtilsLocal.FileParser

const UFile = UtilsRemote.UFile
const UConfig = UtilsRemote.UConfig
const UEditor = UtilsRemote.UEditor
const EditorFileDialogHandler = UtilsRemote.EditorFileDialogHandler


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


static func scan_file_for_global_classes(file_path:String, export_obj:ExportData.Export):
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	var class_names = export_obj.export_data.class_list.keys()
	
	var classes_used = {}
	
	while not file_access.eof_reached():
		var line = file_access.get_line()
		var tokens = Tokenizer.words_only(line)
		for tok:String in tokens:
			if tok in class_names:
				var path = export_obj.export_data.class_list.get(tok)
				#export_obj.global_classes_used[tok] = path
				classes_used[tok] = path
	
	return classes_used


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
				printerr("Path not file or dir: %s" % from_files)
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


static func plugin_init(plugin_name:=""):
	if not FileAccess.file_exists(UtilsLocal.EXPORT_TEMPLATE_PATH):
		printerr("Export template missing: %s" % UtilsLocal.EXPORT_TEMPLATE_PATH)
		return
	
	if not FileAccess.file_exists(UtilsLocal.CONFIG_FILE_PATH):
		if not DirAccess.dir_exists_absolute(UtilsLocal.CONFIG_FILE_PATH.get_base_dir()):
			DirAccess.make_dir_recursive_absolute(UtilsLocal.CONFIG_FILE_PATH.get_base_dir())
		UFile.write_to_json({}, UtilsLocal.CONFIG_FILE_PATH)
	
	var plugin_dir = ""
	if plugin_name != "":
		plugin_dir = "res://addons".path_join(plugin_name)
		if not DirAccess.dir_exists_absolute(plugin_dir):
			printerr("Plugin directory does not exist: %s" % plugin_dir)
			return
	else:
		var dialog = EditorFileDialogHandler.Dir.new()
		dialog.dialog.title = "Pick plugin folder..."
		var handled = await dialog.handled
		if handled == dialog.cancel_string:
			return
		plugin_dir = handled
	
	var export_dir:String = ProjectSettings.localize_path(plugin_dir)
	var export_ignore_dir = export_dir.path_join("export_ignore")
	if not DirAccess.dir_exists_absolute(export_ignore_dir):
		DirAccess.make_dir_recursive_absolute(export_ignore_dir)
	
	var export_config_path = export_ignore_dir.path_join("plugin_export.json")
	if FileAccess.file_exists(export_config_path):
		var conf = ConfirmationDialogHandler.new("Overwrite: %s?" % export_config_path)
		var conf_handled = await conf.handled
		if not conf_handled:
			return
	
	var export_pre_post = export_ignore_dir.path_join("pre_post_export.gd")
	if FileAccess.file_exists(export_pre_post):
		var conf = ConfirmationDialogHandler.new("Overwrite: %s?" % export_pre_post)
		var conf_handled = await conf.handled
		if not conf_handled:
			return
	
	#DirAccess.copy_absolute(UtilsLocal.PRE_POST_TEMPLATE_PATH, export_pre_post)
	var pre_post_f = FileAccess.open(export_pre_post, FileAccess.WRITE)
	pre_post_f.store_string(_PRE_POST_TEMPLATE_TEXT)
	pre_post_f.close()
	
	var export_dir_name = export_dir.trim_suffix("/").get_file()
	var template_data = UFile.read_from_json(UtilsLocal.EXPORT_TEMPLATE_PATH)
	#template_data["export_root"] = root_handled
	template_data[ExportFileKeys.export_root] = export_ignore_dir.path_join("exports")
	var plugin_folder = export_dir_name.capitalize().replace(" ", "")
	template_data[ExportFileKeys.plugin_folder] = "%s{{version=%s}}" % [plugin_folder, export_dir_name]
	
	var parser_settings = {
		"parse_cs":{"namespace_rename":{}},
		"parse_gd":{
			"class_rename_ignore":[],
			"backport_target": 100,
			},
		"parse_tscn":{}
	}
	template_data[ExportFileKeys.options][ExportFileKeys.parser_settings] = parser_settings
	
	var export = template_data.get(ExportFileKeys.exports)[0]
	export[ExportFileKeys.source] = export_dir
	export[ExportFileKeys.remote_dir] = export_dir.path_join("src/remote")
	var export_dir_name_dash = export_dir_name.replace("_", "-")
	var export_folder = "%s{{version=%s}}/%s" % [export_dir_name_dash, export_dir_name, export_dir_name]
	#export_folder = export_folder.path_join(export_dir_name)
	export[ExportFileKeys.export_folder] = export_folder
	var parser_overide_settings = {
		"parse_cs":{},
		"parse_gd":{},
		"parse_tscn":{}
	}
	export[ExportFileKeys.parser_overide_settings] = parser_overide_settings
	var exclude = export.get(ExportFileKeys.exclude)
	exclude[ExportFileKeys.directories] = [export_ignore_dir]
	
	template_data[ExportFileKeys.pre_script] = export_pre_post
	template_data[ExportFileKeys.post_script] = export_pre_post
	
	UFile.write_to_json(template_data, export_config_path)
	
	EditorInterface.get_resource_filesystem().scan()
	
	print("Plugin init complete: %s" % plugin_dir)
	return export_config_path

const _PRE_POST_TEMPLATE_TEXT = \
"@tool
extends Node

func pre_export():
	pass

func post_export():
	pass

"

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
