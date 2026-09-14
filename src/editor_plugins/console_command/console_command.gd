extends GDSh.CommandBase

const PluginExporter = preload("res://addons/plugin_exporter/src/class/plugin_exporter.gd")

const _HELP = \
"Execute PluginExporter commands"

static func get_command_name() -> String:
	return "plugin_exporter"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
	})
