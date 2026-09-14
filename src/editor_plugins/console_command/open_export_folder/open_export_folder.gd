extends GDSh.CommandBase

const PluginExporter = preload("res://addons/plugin_exporter/src/class/plugin_exporter.gd")
const PECommandUtils = preload("res://addons/plugin_exporter/src/editor_plugins/console_command/command_utils.gd")

const _HELP = \
"Open export folder of plugin
Usage: plugin_exporter open_export_folder <plugin_name>"

static func get_command_name() -> String:
	return "open_export_folder"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1
	})

func _get_completions(ctx:Completion):
	return PECommandUtils.plugin_name_completion(self, ctx, PECommandUtils.TargetAddons.VALID)

func _execute(ctx:Context):
	var plugin_name = positional_args[0]
	PluginExporter.open_export_folder(plugin_name)
	return ExitCode.OK
