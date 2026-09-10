extends RefCounted

const _UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const _UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")

const Export = _UtilsLocal.ExportObj
const _ExportFileUtils = _UtilsLocal.ExportFileUtils
const KeysConfig = _ExportFileUtils.KeysConfig

const _UEditor = _UtilsRemote.UEditor

var class_list_array = []
var class_list = {}
var class_path_lookup = {}

var data_valid:bool = false

var export_root:String = ""
var plugin_folder:String = ""
var full_export_path:String = ""
var pre_script:String
var post_script:String

var options:Dictionary = {}
var overwrite:bool = true
var include_uid:bool = true
var include_import:bool = true
var move_global_files:bool = true
var ignore_src:bool = true
var include_docs:bool = true
var include_project_license:bool = false

var file_parser: _UtilsLocal.FileParser
var parser_settings:Dictionary = {}

var exports:Array[Export]

func _init(export_config_path):
	var export_data = _ExportFileUtils.get_export_data(export_config_path)
	if not export_data:
		return
	
	_ExportFileUtils.string_maps = {}
	
	export_root = export_data.get(KeysConfig.EXPORT_ROOT)
	plugin_folder = export_data.get(KeysConfig.PLUGIN_FOLDER)
	full_export_path = _ExportFileUtils.get_full_export_path(export_root, plugin_folder, export_config_path)
	if full_export_path == "":
		return
	
	post_script = export_data.get("post_script","")
	if post_script != "":
		if not _ExportFileUtils.check_export_script_valid(post_script, "post_export"):
			return
	
	pre_script = export_data.get("pre_script","")
	if pre_script != "":
		if not _ExportFileUtils.check_export_script_valid(pre_script, "pre_export"):
			return
	
	var strip_cast_path = export_config_path.get_base_dir().path_join("strip_cast.txt")
	var strip_cast_names = []
	if FileAccess.file_exists(strip_cast_path):
		var file = FileAccess.get_file_as_string(strip_cast_path)
		strip_cast_names = file.split("\n", false)
		for i in range(strip_cast_names.size()):
			strip_cast_names[i] = strip_cast_names[i].strip_edges()
	
	options = export_data.get(KeysConfig.OPTIONS)
	overwrite = options.get(KeysConfig.Options.OVERWRITE, false)
	include_uid = options.get(KeysConfig.Options.INCLUDE_UID, true)
	include_import = options.get(KeysConfig.Options.INCLUDE_IMPORT, true)
	move_global_files = options.get(KeysConfig.Options.MOVE_GLOBAL_FILES, true)
	ignore_src = options.get(KeysConfig.Options.IGNORE_SRC, false)
	include_docs = options.get(KeysConfig.Options.INCLUDE_DOCS, true)
	include_project_license = options.get(KeysConfig.Options.INCLUDE_PROJECT_LICENSE, false)

	# The config always sits in the export_ignore dir, so the doc folder is found beside it.
	var doc_source_dir = export_config_path.get_base_dir().path_join("doc")

	parser_settings = options.get(KeysConfig.Options.PARSER_SETTINGS, {})
	
	if not strip_cast_names.is_empty():
		parser_settings["parse_gd"]["strip_cast"] = strip_cast_names
	
	parser_settings = _sort_settings_dict(parser_settings)
	
	_get_class_list()
	
	var exports_array = export_data.get(KeysConfig.EXPORTS)
	for export in exports_array:
		var export_obj:Export = Export.new()
		export_obj.export_data = self
		export_obj.source = export.get(KeysConfig.Export.SOURCE)
		
		if not export_obj.source.ends_with("/"):
			export_obj.source = export_obj.source + "/"
		
		if not DirAccess.dir_exists_absolute(export_obj.source):
			_UEditor.push_toast(export_obj.source + " does not exist.",2)
			return
		export_obj.export_folder = export.get(KeysConfig.Export.EXPORT_FOLDER)
		if export_obj.export_folder == "":
			export_obj.export_folder = export_obj.source.get_base_dir().get_file()
		
		export_obj.export_folder = _ExportFileUtils.replace_version(export_obj.export_folder, export_config_path)
		if export_obj.export_folder == "":
			return
		
		var plugin_name = export_obj.source.trim_suffix("/").get_file()
		export_obj.plugin_name = "res://addons/%s/" % plugin_name
		var export_plugin_name = export_obj.export_folder.trim_suffix("/").get_file()
		if plugin_name != export_plugin_name and true: # add bool in json?
			export_obj.rename_plugin = true
			export_obj.new_plugin_name = "res://addons/%s/" % export_plugin_name
		
		if not export_obj.export_folder.ends_with("/"):
			export_obj.export_folder = export_obj.export_folder + "/"
		
		var exclude = export.get(KeysConfig.Export.EXCLUDE)
		export_obj.exclude_directories = exclude.get(KeysConfig.Export.Exclude.DIRECTORIES)
		export_obj.exclude_file_extensions = exclude.get(KeysConfig.Export.Exclude.FILE_EXTENSIONS)
		export_obj.exclude_files = exclude.get(KeysConfig.Export.Exclude.FILES)
		
		var default_remote_dir = export_obj.source.path_join("src/remote")
		export_obj.remote_dir = export.get(KeysConfig.Export.REMOTE_DIR, default_remote_dir)
		if not export_obj.remote_dir.begins_with(export_obj.source):
			export_obj.remote_dir = export_obj.source.path_join(export_obj.remote_dir)
		
		export_obj.source_files = _UtilsRemote.GetFiles.scan(export_obj.source)
		export_obj.export_dir_path = full_export_path.path_join(export_obj.export_folder)
		export_obj.other_transfers = export.get(KeysConfig.Export.OTHER_TRANSFERS, [])
		if ignore_src and DirAccess.dir_exists_absolute(plugin_folder.path_join("src")): # TEST to hide the files of src, but leave globals available
			export_obj.other_transfers.append({"to": "src/.gdignore"})
		export_obj.ignore_dependencies = export.get(KeysConfig.Options.IGNORE_DEPENDENCIES, false)
		
		export_obj.file_parser = _UtilsLocal.FileParser.new()
		export_obj.file_parser.set_export_obj(export_obj)
		var overide_settings:Dictionary = export.get(KeysConfig.Options.PARSER_OVERIDE_SETTINGS, {})
		#overide_settings = _sort_settings_dict(overide_settings)
		
		for parse_key in parser_settings.keys():
			if not parse_key.begins_with("parse_"):
				continue
			# Copied so every export gets settings of its own.
			var parse_data:Dictionary = parser_settings.get(parse_key, {}).duplicate(true)
			if overide_settings.has(parse_key):
				overide_settings[parse_key].merge(parse_data)
			else:
				overide_settings[parse_key] = parse_data
		
		# Runs after the merge so untyped settings in the settings-dict body override per-ext ones.
		overide_settings = _sort_settings_dict(overide_settings)
		
		var parse_gd_settings = overide_settings.get("parse_gd", {})
		export_obj.class_rename_ignore = parse_gd_settings.get("class_rename_ignore", [])
		export_obj.get_class_renames()
		export_obj.use_relative_paths = parse_gd_settings.get("use_relative_paths", false)
		export_obj.reduce_access_paths = parse_gd_settings.get("reduce_access_paths", false)
		
		export_obj.parser_overide_settings = overide_settings
		export_obj.file_parser.set_parser_settings(overide_settings)
		
		var backport_target = parse_gd_settings.get("backport_target", 100)
		export_obj.get_backport_files(backport_target)
		
		export_obj.get_valid_files_for_transfer()
		export_obj.sort_valid_files()
		export_obj.get_global_classes_used_in_valid_files()
		export_obj.get_file_dependencies()
		export_obj.build_access_bindings()
		export_obj.get_global_class_export_paths()
		
		export_obj.gather_licenses()

		if include_docs and DirAccess.dir_exists_absolute(doc_source_dir):
			export_obj.gather_docs(doc_source_dir)

		export_obj.check_all_files_have_valid_path()
		
		export_obj.get_singleton_modules()
		
		if not export_obj.export_valid:
			return
		
		exports.append(export_obj)
	
	
	data_valid = true

func _sort_settings_dict(dict:Dictionary):
	var sorted_dict = {}
	var untyped_keys = []
	for parse_key in dict.keys():
		if not parse_key.begins_with("parse_"):
			untyped_keys.append(parse_key)
			continue
		
		sorted_dict[parse_key] = dict[parse_key]
	
	for parse_key in sorted_dict.keys():
		# Copied rather than written through: folding the untyped keys into the caller's dict
		# is how one export's settings used to leak into the next.
		var data:Dictionary = (sorted_dict[parse_key] as Dictionary).duplicate()

		for key in untyped_keys:
			data[key] = dict[key]
		sorted_dict[parse_key] = data

	return sorted_dict

func _get_class_list():
	var global_class_list = ProjectSettings.get_global_class_list()
	for class_dict in global_class_list:
		var _class_name = class_dict.get("class")
		var path = class_dict.get("path")
		var str_class_nm = String(_class_name)
		class_list[str_class_nm] = path
		class_path_lookup[path] = str_class_nm
		if _class_name not in class_list_array:
			class_list_array.append(_class_name)

func  should_move_global():
	return move_global_files or ignore_src
