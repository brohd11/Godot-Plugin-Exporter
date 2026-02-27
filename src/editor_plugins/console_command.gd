extends EditorConsoleSingleton.ConsoleCommandBase

const PluginExporter = preload("res://addons/plugin_exporter/src/class/plugin_exporter.gd")

const _CONSOLE_SCOPE = "plugin_exporter"
const _CONSOLE_HELP = "Plugin Exporter available commands:
export - Export the selected plugin
gui_open - Open Plugin Exporter gui instance with selected plugin.
open_export_folder - Open export folder of plugin
plugin_init - Initialize plugin folder with required files
new_plugin - Create a new plugin from template and initialize"

func get_commands() -> Dictionary:
	var commands_object = Commands.new()
	commands_object.add_command("export", true, PluginExporter.export)
	commands_object.add_command("gui_open", true, PluginExporter.gui_open)
	commands_object.add_command("open_export_folder", true, PluginExporter.open_export_folder)
	commands_object.add_command("plugin_init", true, PluginExporter.plugin_init)
	commands_object.add_command("new_plugin", true, PluginExporter.new_plugin)
	return commands_object.get_commands()

func get_completion(raw_text, cmds, args):
	var commands_object = Commands.new()
	var cmd_1 = cmds[0]
	if cmd_1 == "global":
		if " --" and "call" in raw_text:
			if args.size() == 1 and args[0] != "new_plugin":
				return _get_addons_dirs()
	elif cmd_1 == _CONSOLE_SCOPE:
		if cmds.size() == 1:
			return get_commands()
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

func parse(commands, args):
	if _display_help(commands, args):
		return
	#if args.size() == 0:
		#if commands.size() == 1:
			#print(_CONSOLE_HELP)
		#else:
			#var standard_msg = "Pass plugin name as argument"
			#var cmd_2 = commands[1]
			#match cmd_2:
				#"export": print(standard_msg)
				#"gui_open": print(standard_msg)
				#"open_export_folder": print(standard_msg)
				#"plugin_init": print(standard_msg)
				#"new_plugin": print("Pass a new plugin name as argument")
		#return
	
	if commands.size() == 2:
		_call_standard_command(commands, args)
		#var arg_1 = args[0]
		#var cmd_2 = commands[1]
		#match cmd_2:
			#"export": PluginExporter.export(arg_1)
			#"gui_open": PluginExporter.gui_open(arg_1)
			#"open_export_folder": PluginExporter.open_export_folder(arg_1)
			#"plugin_init": PluginExporter.plugin_init(arg_1)
			#"new_plugin": PluginExporter.new_plugin(arg_1)

func get_help_message(commands:Array, arguments:Array, invalid_commands:=false):
	
	if commands.size() == 1:
		return _CONSOLE_HELP
	else:
		var standard_msg = "Pass plugin name as argument"
		var cmd_2 = commands[1]
		match cmd_2:
			"export": return standard_msg
			"gui_open": return standard_msg
			"open_export_folder": return standard_msg
			"plugin_init": return standard_msg
			"new_plugin": return "Pass a new plugin name as argument"
	return
