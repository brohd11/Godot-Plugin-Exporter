
const CommandBase = EditorConsoleSingleton.CommandBase
const CompletionContext = EditorConsoleSingleton.CompletionContext

const PluginExporter = preload("res://addons/plugin_exporter/src/class/plugin_exporter.gd")
const TargetAddons = PluginExporter.TargetAddons

static func plugin_name_completion(cmd:CommandBase, ctx:CompletionContext, target_addons:=TargetAddons.VALID, target_position:int=0):
	if not cmd.positional_arg_index in [target_position, target_position - 1]:
		return {}
	if cmd.positional_arg_index == target_position - 1 and not ctx.char_before_cursor == " ":
		return {}
	var dirs = PluginExporter.get_addons_dirs(target_addons)
	var options = CommandBase.Options.new()
	for d in dirs.keys():
		options.add_option(d)
	return options.get_options()
