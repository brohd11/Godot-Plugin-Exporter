extends EditorConsoleSingleton.CommandBase

const PluginExporter = preload("res://addons/plugin_exporter/src/class/plugin_exporter.gd")

const _HELP = \
"Execute PluginExporter commands"

static func get_command_name() -> String:
	return "plugin_exporter"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": _HELP,
	})
