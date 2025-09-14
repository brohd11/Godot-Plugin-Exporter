class_name PluginExporter

const MiscBackport = preload("res://addons/plugin_exporter/src/class/export/backport/misc_backport_class.gd")

const Plugin = preload("res://addons/plugin_exporter/plugin.gd")
const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")
const PluginExporterStatic = UtilsLocal.PluginExporterStatic

static func get_completion(raw_text, cmds, args, console):
	if " --" and "call" in raw_text:
		if args.size() == 1 and args[0] != "new_plugin":
			var data = {}
			var addons = DirAccess.get_directories_at("res://addons")
			for dir in addons:
				data[dir] = {}
			return data
	
	return {}

static func export(plugin_name:String):
	PluginExporterStatic.export_by_name(plugin_name)

static func new_plugin(plugin_name:String):
	PluginExporterStatic.new_plugin(plugin_name)

static func plugin_init(plugin_name:String):
	UtilsLocal.ExportFileUtils.plugin_init(plugin_name)

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
	
	gui_instance.load_export_file(export_file_path)
