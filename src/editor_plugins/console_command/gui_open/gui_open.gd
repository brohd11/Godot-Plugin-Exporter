extends GDSh.CommandBase

const PluginExporter = preload("res://addons/plugin_exporter/src/class/plugin_exporter.gd")
const PECommandUtils = preload("res://addons/plugin_exporter/src/editor_plugins/console_command/command_utils.gd")

const _HELP = \
"Open PluginExporter gui instance with selected plugin
Usage: plugin_exporter gui_open <plugin_name>"

static func get_command_name() -> String:
	return "gui_open"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP + PECommandUtils.TARGET_HELP,
		&"positional_count": 1
	})

func _get_completions(ctx:Completion):
	return PECommandUtils.plugin_name_completion(self, ctx, PECommandUtils.TargetAddons.VALID)

func _execute(ctx:Context):
	var plugin_name = positional_args[0]
	PluginExporter.gui_open(plugin_name)
	return ExitCode.OK
