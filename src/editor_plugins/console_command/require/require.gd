extends GDSh.CommandBase

const RequireReport = preload("res://addons/plugin_exporter/src/class/release/require_report.gd")
const PECommandUtils = preload("res://addons/plugin_exporter/src/editor_plugins/console_command/command_utils.gd")

const _HELP = \
"List the packages (dirs with a plugin.cfg or version.cfg) a plugin's export pulls in, grouped by
the package whose export_ignore/plugin_export config should list them under build_require. Identity
is the git origin, or the cfg url= for a release package. Runs the export crawl only (nothing is
written) and reports without tags.
Usage: plugin_exporter require <plugin_name>"

static func get_command_name() -> String:
	return "require"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1
	})

func _get_completions(ctx:Completion):
	return PECommandUtils.plugin_name_completion(self, ctx, PECommandUtils.TargetAddons.VALID)

func _execute(ctx:Context):
	var report = RequireReport.build(positional_args[0])
	if not report.errors.is_empty():
		for e in report.errors:
			ctx.append_error(e)
		return ExitCode.FAIL
	ctx.append_output(RequireReport.format(report))
	return ExitCode.OK
