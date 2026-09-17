extends GDSh.CommandBase

const RequireReport = preload("res://addons/plugin_exporter/src/class/release/require_report.gd")
const RequireUpdate = preload("res://addons/plugin_exporter/src/class/release/require_update.gd")
const PECommandUtils = preload("res://addons/plugin_exporter/src/editor_plugins/console_command/command_utils.gd")

const _HELP = \
"List the packages (dirs with a plugin.cfg or version.cfg) a plugin's export pulls in, grouped by
the package whose _export_ignore (or export_ignore) plugin_export config should list them under build_require. Identity
is the git origin, or the cfg url= for a release package. Runs the export crawl only; use the
update subcommand to write the target's build_require.
Usage: plugin_exporter require <plugin_name>"

var self_flag := false

static func get_command_name() -> String:
	return "require"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--self", {&"help": "Only the target's own list, one require@tag per line, nothing else."})
	return options.get_options()

func _get_completions(ctx:Completion):
	if _completion_last_is_flag(ctx):
		return _get_completion_std_w_context(ctx, false)
	var options = PECommandUtils.plugin_name_completion(self, ctx, PECommandUtils.TargetAddons.VALID)
	if positional_arg_index == 0:
		options.merge(get_commands(true))
	return options

func _execute(ctx:Context):
	var report = RequireReport.build(positional_args[0])
	if not report.errors.is_empty():
		for e in report.errors:
			ctx.append_error(e)
		return ExitCode.FAIL
	if self_flag:
		ctx.append_output("\n".join(RequireUpdate.self_list(report)))
		return ExitCode.OK
	ctx.append_output(RequireReport.format(report))
	return ExitCode.OK
