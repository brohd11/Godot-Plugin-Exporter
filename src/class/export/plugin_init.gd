
const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")

const UFile = UtilsRemote.UFile
const ConfirmationDialogHandler = UtilsRemote.ConfirmationDialogHandler

const ExportFileUtils = UtilsLocal.ExportFileUtils
const KeysConfig = ExportFileUtils.KeysConfig
const ExportIgnore = ExportFileUtils.ExportIgnore
const ExportPaths = ExportFileUtils.ExportPaths

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
	var plugin_dir = ""
	if plugin_name != "":
		plugin_dir = ExportPaths.resolve_target(plugin_name)
		if plugin_dir == "":
			printerr("Invalid package target (expected a path inside this project): " + plugin_name)
			return
		if not DirAccess.dir_exists_absolute(plugin_dir):
			printerr("Plugin directory does not exist: %s" % plugin_dir)
			return
	else:
		var dialog = EditorFileDialogHandler.Dir.new()
		dialog.dialog.title = "Pick plugin folder..."
		var handled = await dialog.handled
		if handled == dialog.cancel_string:
			return
		plugin_dir = ExportPaths.resolve_target(handled)
		if plugin_dir == "":
			printerr("Selected package must be inside this project: " + handled)
			return
	
	var export_dir:String = ProjectSettings.localize_path(plugin_dir)
	var export_ignore_dir = ExportIgnore.dir_or_default(export_dir) # keeps an existing folder's name
	if not DirAccess.dir_exists_absolute(export_ignore_dir):
		DirAccess.make_dir_recursive_absolute(export_ignore_dir)
	
	#var export_config_path = export_ignore_dir.path_join("plugin_export.json")
	var export_config_path = export_ignore_dir.path_join(ExportIgnore.CONFIG_NAMES[0])
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
	template_data[KeysConfig.EXPORT_ROOT] = export_ignore_dir.path_join("exports")
	var plugin_folder = export_dir_name.capitalize().replace(" ", "")
	template_data[KeysConfig.PLUGIN_FOLDER] = "%s{{version=%s}}" % [plugin_folder, export_dir]
	
	var export = PluginExportJSON.get_export_obj_data()
	export[KeysConfig.Export.SOURCE] = export_dir
	export[KeysConfig.Export.REMOTE_DIR] = export_dir.path_join("src/remote")
	var export_dir_name_dash = export_dir_name.replace("_", "-")
	export[KeysConfig.Export.EXPORT_NAME] = "%s{{version=%s}}" % [export_dir_name_dash, export_dir]
	export[KeysConfig.Export.EXPORT_FOLDER] = export_dir.trim_prefix("res://").trim_suffix("/")
	
	var exclude = export.get(KeysConfig.Export.EXCLUDE)
	exclude[KeysConfig.Export.Exclude.DIRECTORIES] = [export_ignore_dir]
	
	template_data[KeysConfig.EXPORTS].append(export)
	template_data[KeysConfig.PRE_SCRIPT] = export_pre_post
	template_data[KeysConfig.POST_SCRIPT] = export_pre_post
	
	#UFile.write_to_json(template_data, export_config_path)
	YAMLParser.dump_to_file(template_data, export_config_path)
	
	var gitignore_fa = FileAccess.open(export_ignore_dir.path_join(".gitignore"), FileAccess.WRITE)
	gitignore_fa.store_line("exports/")
	gitignore_fa.close()
	
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
	static func _optimizer_defaults() -> Dictionary:
		var settings:Dictionary = UtilsRemote.GDScriptOptimizer.Config.DEFAULTS.duplicate(true)
		settings.enabled = true
		return settings

	static func get_body_data():
		return {
			KeysConfig.EXPORT_ROOT: "",
			KeysConfig.PLUGIN_FOLDER: "",
			KeysConfig.PRE_SCRIPT: "",
			KeysConfig.POST_SCRIPT: "",
			KeysConfig.BUILD_REQUIRE: "@require", # plugin.cfg's require list (DepResolver.REQUIRE_REF)
			KeysConfig.COMPILE_REQUIRE: [],
			KeysConfig.OPTIONS: {
				KeysConfig.Options.OVERWRITE: true,
				KeysConfig.Options.INCLUDE_UID: true,
				KeysConfig.Options.INCLUDE_IMPORT: true,
				KeysConfig.Options.IGNORE_SRC: true,
				KeysConfig.Options.USE_TAG_IN_CFG: true,
				KeysConfig.Options.EXPORTED_DEPS: [],
				KeysConfig.Options.INCLUDE_MIN_VERSION: true,
				KeysConfig.Options.MOVE_GLOBAL_FILES: true,
				KeysConfig.Options.INCLUDE_DOCS: true,
				KeysConfig.Options.INCLUDE_PROJECT_LICENSE: false,
				KeysConfig.Options.PARSER_SETTINGS:{
					"use_relative_paths":false,
					"backport_target": 100,
					"parse_cs":{
						"namespace_rename":{}
						},
					"parse_gd":{
						"replace_editor_interface":false,
						"optimizer": _optimizer_defaults(),
						"class_rename_ignore":[],
						"backport_string_renames":{},
						},
					"parse_tscn":{},
					"parse_tres":{},
				}
			},
			"exports": [],
		}
	
	static func get_export_obj_data():
		return {
			KeysConfig.Export.SOURCE: "",
			KeysConfig.Export.EXPORT_NAME: "",
			KeysConfig.Export.EXPORT_FOLDER: "",
			KeysConfig.Export.EXCLUDE: {
				KeysConfig.Export.Exclude.DIRECTORIES: [],
				KeysConfig.Export.Exclude.FILE_EXTENSIONS: [],
				KeysConfig.Export.Exclude.FILES: [],
				},
			KeysConfig.Export.OTHER_TRANSFERS:[],
			KeysConfig.Options.PARSER_OVERIDE_SETTINGS:{
				"parse_cs":{},
				"parse_gd":{},
				"parse_tscn":{},
				"parse_tres":{},
			}
		}
