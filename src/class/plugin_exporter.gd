class_name PluginExporter

const MiscBackport = preload("res://addons/plugin_exporter/src/class/export/backport/misc_backport_class.gd")

const Plugin = preload("res://addons/plugin_exporter/plugin.gd")
const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")
const PluginExporterStatic = UtilsLocal.PluginExporterStatic
const PluginInit = UtilsLocal.PluginInit

const _CONSOLE_SCOPE = "plugin_exporter"
const _CONSOLE_HELP = "Plugin Exporter available commands:
export - Export the selected plugin
gui_open - Open Plugin Epxorter gui instance with selected plugin.
open_export_folder - Open export folder of plugin
plugin_init - Initialize plugin folder with required files
new_plugin - Create a new plugin from template and initialize"

static func get_completion(raw_text, cmds, args, console):
	var cmd_1 = cmds[0]
	if cmd_1 == "global":
		if " --" and "call" in raw_text:
			if args.size() == 1 and args[0] != "new_plugin":
				return _get_addons_dirs()
	elif cmd_1 == _CONSOLE_SCOPE:
		if cmds.size() == 1:
			var data = {
				"export":{},
				"gui_open":{},
				"open_export_folder":{},
				"plugin_init":{},
				"new_plugin":{},
			}
			for d in data.keys():
				data[d]["add_args"] = true
			return data
		elif cmds.size() == 2:
			var cmd_2 = cmds[1]
			if args.size() > 0:
				return {}
			match cmd_2:
				"export": return _get_addons_dirs()
				"gui_open": return _get_addons_dirs()
				"open_export_folder": return _get_addons_dirs()
				"plugin_init": return _get_addons_dirs("not_valid")
				"new_plugin": return {}
	return {}

static func _get_addons_dirs(limit_to:="valid"):
	var addons_dirs = DirAccess.get_directories_at("res://addons")
	var data = {}
	for dir in addons_dirs:
		var plugin_export_path = "res://addons".path_join(dir).path_join("export_ignore/plugin_export.json")
		if limit_to == "valid":
			if not FileAccess.file_exists(plugin_export_path):
				continue
		elif limit_to == "not_valid":
			if FileAccess.file_exists(plugin_export_path):
				continue
		elif limit_to != "all":
			continue
		data[dir] = {}
	return data

static func parse(commands, args, editor_console):
	if args.size() == 0:
		if commands.size() == 1:
			print(_CONSOLE_HELP)
		else:
			var standard_msg = "Pass plugin name as argument"
			var cmd_2 = commands[1]
			match cmd_2:
				"export": print(standard_msg)
				"gui_open": print(standard_msg)
				"open_export_folder": print(standard_msg)
				"plugin_init": print(standard_msg)
				"new_plugin": print("Pass a new plugin name as argument")
		return
	
	if commands.size() == 2:
		var arg_1 = args[0]
		var cmd_2 = commands[1]
		match cmd_2:
			"export": export(arg_1)
			"gui_open": gui_open(arg_1)
			"open_export_folder": open_export_folder(arg_1)
			"plugin_init": plugin_init(arg_1)
			"new_plugin": new_plugin(arg_1)


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
