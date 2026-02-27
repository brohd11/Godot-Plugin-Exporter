class_name PluginExporterAPI

const MiscBackport = preload("res://addons/plugin_exporter/src/class/export/backport/misc_backport_class.gd")

const Plugin = preload("res://addons/plugin_exporter/plugin.gd")
const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")
const PluginExporterStatic = UtilsLocal.PluginExporterStatic
const PluginInit = UtilsLocal.PluginInit

static func export(plugin_name:String):
	PluginExporterStatic.export_by_name(plugin_name)

static func new_plugin(plugin_name:String):
	PluginExporterStatic.new_plugin(plugin_name)

static func plugin_init(plugin_name:String):
	PluginInit.plugin_init(plugin_name)

static func gui_open(plugin_name:String):
	var export_file_path = "res://addons/%s/export_ignore/plugin_export.json" % plugin_name
	if not FileAccess.file_exists(export_file_path):
		printerr("File does not exist: %s" % export_file_path)
		return
	if not is_instance_valid(Plugin.instance):
		printerr("PluginExporter instance not found. Make sure plugin is enabled.")
		return
	
	var dock_manager = Plugin.instance.new_gui_instance()
	var gui_instance = dock_manager.get_plugin_control()
	
	var read_file = true
	gui_instance.load_export_file(export_file_path, read_file)

static func open_export_folder(plugin_name:String):
	var export_config_path = UtilsLocal.ExportFileUtils.name_to_export_config_path(plugin_name)
	if not FileAccess.file_exists(export_config_path):
		printerr("Could not find file: %s" % export_config_path)
		return
	PluginExporterStatic.open_export_dir(export_config_path)
