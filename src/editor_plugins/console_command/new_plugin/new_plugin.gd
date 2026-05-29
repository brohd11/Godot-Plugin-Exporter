extends EditorConsoleSingleton.CommandBase

const PluginExporter = preload("res://addons/plugin_exporter/src/class/plugin_exporter.gd")

const _HELP = \
"create a new plugin from template and initialize
Usage: plugin_exporter new_plugin <plugin_name>"

static func get_command_name() -> String:
	return "new_plugin"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": _HELP,
		&"positional_count": 1
	})

func _get_completions(ctx:CompletionContext):
	return {}

func _execute(ctx:CompletionContext):
	var plugin_name = positional_args[0]
	PluginExporter.new_plugin(plugin_name)
