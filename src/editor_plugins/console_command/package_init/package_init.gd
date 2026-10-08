extends GDSh.CommandBase

const PluginExporter = preload("res://addons/plugin_exporter/src/class/plugin_exporter.gd")
const PECommandUtils = preload("res://addons/plugin_exporter/src/editor_plugins/console_command/command_utils.gd")

const _HELP = \
"Initialize a folder as a library package: version.cfg, git init, src/, then plugin_init
Usage: plugin_exporter package_init <folder>"

static func get_command_name() -> String:
	return "package_init"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP + PECommandUtils.TARGET_HELP,
		&"positional_count": 1
	})

func _get_completions(ctx:Completion):
	return PECommandUtils.dir_completion(self, ctx, PluginExporter.get_unpackaged_dirs())

func _execute(ctx:Context):
	var target = positional_args[0]
	PluginExporter.package_init(target)
	return ExitCode.OK
