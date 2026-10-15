extends GDSh.CommandBase

const PluginExporter = preload("res://addons/package_exporter/src/class/plugin_exporter.gd")

const _HELP = \
"Execute PackageExporter commands"

static func get_command_name() -> String:
	return "package_exporter"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
	})
