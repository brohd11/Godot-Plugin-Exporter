
const CommandBase = GDSh.CommandBase
const Completion = CommandBase.Completion

const PluginExporter = preload("res://addons/plugin_exporter/src/class/plugin_exporter.gd")
const TargetAddons = PluginExporter.TargetAddons
const TARGET_HELP = "\nTargets are relative to res://addons/ (e.g. _lib/brohd), or absolute res:// / filesystem paths inside this project."

static func plugin_name_completion(cmd:CommandBase, ctx:Completion,target_addons:=TargetAddons.VALID, target_position:int=0):
	if not _completing_target(cmd, ctx, target_position):
		return {}
	return dir_completion(cmd, ctx, PluginExporter.get_addons_dirs(target_addons), target_position)

static func dir_completion(cmd:CommandBase, ctx:Completion, dirs:Dictionary, target_position:int=0):
	if not _completing_target(cmd, ctx, target_position):
		return {}
	var options = CommandBase.Options.new()
	for d in dirs.keys():
		options.add_option(d)
	return options.get_options()

static func _completing_target(cmd:CommandBase, ctx:Completion, target_position:int) -> bool:
	if not cmd.positional_arg_index in [target_position, target_position - 1]:
		return false
	return not (cmd.positional_arg_index == target_position - 1 and not ctx.char_before_cursor == " ")
