
const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")

const UFile = UtilsRemote.UFile
const ConfirmationDialogHandler = UtilsRemote.ConfirmationDialogHandler

const ExportFileUtils = UtilsLocal.ExportFileUtils
const ExportFileKeys = ExportFileUtils.ExportFileKeys

static func new_plugin(plugin_dir_name, create_export:=true):
	var new_plugin_path = "res://addons/%s" % plugin_dir_name
	if DirAccess.dir_exists_absolute(new_plugin_path):
		print("Plugin already exists.")
		return
	
	DirAccess.make_dir_recursive_absolute(new_plugin_path)
	var plugin_cap_name = plugin_dir_name.capitalize()
	
	var plugin_gd_path = new_plugin_path.path_join("plugin.gd")
	var file_access = FileAccess.open(plugin_gd_path, FileAccess.WRITE)
	file_access.store_string(_NewPluginText.PLUGIN_GD_TEXT % plugin_cap_name)
	file_access.close()
	
	var plugin_cfg_path = new_plugin_path.path_join("plugin.cfg")
	
	var cfg_file_access = FileAccess.open(plugin_cfg_path, FileAccess.WRITE)
	cfg_file_access.store_string(_NewPluginText.PLUGIN_CFG_TEXT % plugin_cap_name)
	cfg_file_access.close()
	
	print("Created plugin: %s" % plugin_cap_name)
	
	if create_export:
		plugin_init(plugin_dir_name)
	
	EditorInterface.get_resource_filesystem().scan()

static func plugin_init(plugin_name:=""):
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
	
	var pre_post_f = FileAccess.open(export_pre_post, FileAccess.WRITE)
	pre_post_f.store_string(_NewPluginText.PRE_POST_TEMPLATE_TEXT)
	pre_post_f.close()
	
	var export_dir_name = export_dir.trim_suffix("/").get_file()
	var template_data = PluginExportJSON.get_body_data()
	template_data[ExportFileKeys.export_root] = export_ignore_dir.path_join("exports")
	var plugin_folder = export_dir_name.capitalize().replace(" ", "")
	template_data[ExportFileKeys.plugin_folder] = "%s{{version=%s}}" % [plugin_folder, export_dir_name]
	
	var export = PluginExportJSON.get_export_obj_data()
	export[ExportFileKeys.source] = export_dir
	export[ExportFileKeys.remote_dir] = export_dir.path_join("src/remote")
	var export_dir_name_dash = export_dir_name.replace("_", "-")
	var export_folder = "%s{{version=%s}}/%s" % [export_dir_name_dash, export_dir_name, export_dir_name]
	export[ExportFileKeys.export_folder] = export_folder
	
	var exclude = export.get(ExportFileKeys.exclude)
	exclude[ExportFileKeys.directories] = [export_ignore_dir]
	
	template_data[ExportFileKeys.exports].append(export)
	template_data[ExportFileKeys.pre_script] = export_pre_post
	template_data[ExportFileKeys.post_script] = export_pre_post
	
	UFile.write_to_json(template_data, export_config_path)
	
	EditorInterface.get_resource_filesystem().scan()
	
	print("Plugin init complete: %s" % plugin_dir)
	return export_config_path


class _NewPluginText:
	const PLUGIN_GD_TEXT = \
'@tool' + \
'\nextends EditorPlugin' + \
'
func _get_plugin_name() -> String:
	return "%s"
func _get_plugin_icon() -> Texture2D:' + \
'\n\treturn EditorInterface.get_base_control().get_theme_icon("Node", &"EditorIcons")' + \
'\nfunc _has_main_screen() -> bool:
	return true

func _make_visible(visible:bool) -> void:
	pass

func _enable_plugin() -> void:
	pass

func _disable_plugin() -> void:
	pass

func _enter_tree() -> void:
	pass

func _exit_tree() -> void:
	pass'

	const PLUGIN_CFG_TEXT = \
'[plugin]

name="%s"
description=""
author=""
version="0.1.0"
script="plugin.gd"'

	const PRE_POST_TEMPLATE_TEXT = \
"@tool" + \
"\nextends Node" + \
"
func pre_export():
	pass

func post_export():
	pass

"


class PluginExportJSON:
	static func get_body_data():
		return {
			"export_root": "",
			"plugin_folder": "",
			"exports": [],
			"options": {
				"overwrite": true,
				"include_uid": true,
				"include_import": true,
				"parser_settings":{
					"use_relative_paths":false,
					"backport_target": 100,
					"parse_cs":{
						"namespace_rename":{}
						},
					"parse_gd":{
						"replace_editor_interface":false,
						"class_rename_ignore":[],
						"backport_string_renames":{},
						},
					"parse_tscn":{},
					"parse_tres":{},
				}
			}
		}
	
	static func get_export_obj_data():
		return {
			"source": "",
			"export_folder": "",
			"exclude": {
				"directories": [],
				"file_extensions": [],
				"files": [],
				},
			"other_transfers":[],
			"parser_overide_settings":{
				"parse_cs":{},
				"parse_gd":{},
				"parse_tscn":{},
				"parse_tres":{},
			}
		}
