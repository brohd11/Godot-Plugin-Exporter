extends EditorConsoleSingleton.ConsoleCommandBase

const PluginExporter = preload("res://addons/plugin_exporter/src/class/plugin_exporter.gd")

const EXPORT = "export"
const GUI_OPEN = "gui_open"
const OPEN_EXPORT_FOLDER = "open_export_folder"
const PLUGIN_INIT = "plugin_init"
const NEW_PLUGIN = "new_plugin"

const _HELP_DICT = {
	"plugin_exporter":{
		"c":[EXPORT, GUI_OPEN, OPEN_EXPORT_FOLDER, PLUGIN_INIT, NEW_PLUGIN]
	},
	EXPORT: "export the selected plugin -- <plugin_dir_name String>",
	GUI_OPEN: "ppen PluginExporter gui instance with selected plugin  -- <plugin_dir_name String>",
	OPEN_EXPORT_FOLDER: "open export folder of plugin -- <plugin_dir_name String>",
	PLUGIN_INIT: "initialize plugin folder with required files -- <plugin_dir_name String>",
	NEW_PLUGIN: "create a new plugin from template and initialize -- <new_plugin_name String>"
	
}

func _get_valid_commands_for_index(completion_context:CompletionContext, cmd_idx:int) -> Dictionary:
	var commands = completion_context.commands
	var arguments = completion_context.arguments
	var command = commands[cmd_idx]
	var commands_object = Commands.new()
	
	if arguments.size() > 0 and not completion_context.execute:
		return {}
	match command:
		"plugin_exporter":
			commands_object.add_command(EXPORT, true, PluginExporter.export)
			commands_object.add_command(GUI_OPEN, true, PluginExporter.gui_open)
			commands_object.add_command(OPEN_EXPORT_FOLDER, true, PluginExporter.open_export_folder)
			commands_object.add_command(PLUGIN_INIT, true, PluginExporter.plugin_init)
			commands_object.add_command(NEW_PLUGIN, true, PluginExporter.new_plugin)
		NEW_PLUGIN: return {}
		_:
			if command in _HELP_DICT["plugin_exporter"]["c"]:
				if not completion_context.has_arg_delimiter:
					return Commands.get_arg_delimiter_command()
				var limit_to = "valid"
				if command == PLUGIN_INIT:
					limit_to = "not_valid"
				return _get_addons_dirs(limit_to)
		
	return commands_object.get_commands()


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

func _command_requires_arguments(_selected_command:String):
	return true

func _get_help_dict():
	return _HELP_DICT
