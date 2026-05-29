extends EditorConsoleSingleton.CommandBase

const PluginExporter = preload("res://addons/plugin_exporter/src/class/plugin_exporter.gd")

const _HELP = \
"Export the selected plugin
Usage: plugin_exporter export <plugin_name>"

static func get_command_name() -> String:
	return "export"

static func get_self_command_data() -> Dictionary:
	return Options.get_single_option_dict(get_command_name(), {
		&"help": _HELP,
		&"positional_count": 1
	})

func _get_completions(ctx:CompletionContext):
	var options = Options.new()
	var addon_dirs = PluginExporter.get_addons_dirs("valid")
	for d in addon_dirs:
		options.add_option(d)
	return options.get_options()

func _execute(ctx:CompletionContext):
	var plugin_name = positional_args[0]
	PluginExporter.export(plugin_name)
	
