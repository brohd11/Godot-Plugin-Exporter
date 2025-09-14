extends RefCounted

const _UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd") #>remote
const _UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")

const Export = _UtilsLocal.ExportObj
const _ExportFileUtils = _UtilsLocal.ExportFileUtils
const _ExportFileKeys = _ExportFileUtils.ExportFileKeys

const _UEditor = _UtilsRemote.UEditor

var class_list_array = []
var class_list = {}

var class_rename_ignore = []
var class_renames = {}

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

var file_parser: _UtilsLocal.FileParser
var parser_settings:Dictionary = {}

var exports:Array[Export]

func _init(export_config_path):
	var export_data = _ExportFileUtils.get_export_data(export_config_path)
	if not export_data:
		return
	
	export_root = export_data.get(_ExportFileKeys.export_root)
	plugin_folder = export_data.get(_ExportFileKeys.plugin_folder)
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
	
	options = export_data.get(_ExportFileKeys.options)
	overwrite = options.get(_ExportFileKeys.overwrite, false)
	include_uid = options.get(_ExportFileKeys.include_uid, true)
	include_import = options.get(_ExportFileKeys.include_import, true)
	parser_settings = options.get(_ExportFileKeys.parser_settings, {})
	
	var parse_gd_settings = parser_settings.get("parse_gd", {})
	class_rename_ignore = parse_gd_settings.get("class_rename_ignore", [])
	_get_class_list()
	
	var exports_array = export_data.get(_ExportFileKeys.exports)
	for export in exports_array:
		var export_obj:Export = Export.new()
		export_obj.export_data = self
		export_obj.source = export.get(_ExportFileKeys.source)
		
		if not export_obj.source.ends_with("/"):
			export_obj.source = export_obj.source + "/"
		
		if not DirAccess.dir_exists_absolute(export_obj.source):
			_UEditor.push_toast(export_obj.source + " does not exist.",2)
			return
		export_obj.export_folder = export.get(_ExportFileKeys.export_folder)
		if export_obj.export_folder == "":
			export_obj.export_folder = export_obj.source.get_base_dir().get_file()
		
		export_obj.export_folder = _ExportFileUtils.replace_version(export_obj.export_folder, export_config_path)
		if export_obj.export_folder == "":
			return
		
		var plugin_name = export_obj.source.trim_suffix("/").get_file()
		var export_plugin_name = export_obj.export_folder.trim_suffix("/").get_file()
		if plugin_name != export_plugin_name and true: # add bool in json?
			export_obj.rename_plugin = true
			export_obj.plugin_name = "res://addons/%s/" % plugin_name
			export_obj.new_plugin_name = "res://addons/%s/" % export_plugin_name
		
		if not export_obj.export_folder.ends_with("/"):
			export_obj.export_folder = export_obj.export_folder + "/"
		
		var exclude = export.get(_ExportFileKeys.exclude)
		export_obj.exclude_directories = exclude.get(_ExportFileKeys.directories)
		export_obj.exclude_file_extensions = exclude.get(_ExportFileKeys.file_extensions)
		export_obj.exclude_files = exclude.get(_ExportFileKeys.files)
		export_obj.remote_dir = export.get(_ExportFileKeys.remote_dir, "")
		export_obj.source_files = _UtilsRemote.UFile.scan_for_files(export_obj.source, [])
		export_obj.export_dir_path = full_export_path.path_join(export_obj.export_folder)
		export_obj.other_transfers = export.get(_ExportFileKeys.other_transfers, [])
		
		export_obj.file_parser = _UtilsLocal.FileParser.new()
		export_obj.file_parser.set_export_obj(export_obj)
		var overide_settings:Dictionary = export.get(_ExportFileKeys.parser_overide_settings, {})
		overide_settings.merge(parser_settings)
		export_obj.parser_overide_settings = overide_settings
		export_obj.file_parser.set_parser_settings(overide_settings)
		
		
		export_obj.get_valid_files_for_transfer()
		export_obj.sort_valid_files()
		export_obj.get_global_classes_used_in_valid_files()
		export_obj.get_file_dependencies()
		export_obj.get_global_class_export_paths()
		
		exports.append(export_obj)
	
	data_valid = true

func _get_class_list():
	var global_class_list = ProjectSettings.get_global_class_list()
	for class_dict in global_class_list:
		var _class_name = class_dict.get("class")
		var path = class_dict.get("path")
		class_list[String(_class_name)] = path
		if _class_name not in class_list_array:
			class_list_array.append(_class_name)
		if _class_name not in class_rename_ignore:
			class_renames[_class_name] = ""
