extends GDSh.CommandBase

const RequireReport = preload("res://addons/plugin_exporter/src/class/release/require_report.gd")
const RequireUpdate = preload("res://addons/plugin_exporter/src/class/release/require_update.gd")
const PECommandUtils = preload("res://addons/plugin_exporter/src/editor_plugins/console_command/command_utils.gd")

const _HELP = \
"Write the packages the crawl found into the target's own build_require, in its _export_ignore (or
export_ignore) plugin_export config. Each tag is the required package's cfg version=, and a version
that isn't tagged in its checkout yet only warns. A \"@require\" in build_require is dropped rather
than expanded: plugin.cfg's require= is gdaddon's install-time list and may name optional deps.
Only the target is written; other packages stay reported by `require`.
Usage: plugin_exporter require update <plugin_name>"

var overwrite_flag := false
var prune_flag := false

static func get_command_name() -> String:
	return "update"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP + PECommandUtils.TARGET_HELP,
		&"positional_count": 1
	})

func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--overwrite", {&"help": "Re-pin entries the config already lists to their current tag."})
	options.add_option("--prune", {&"help": "Drop entries the crawl did not find."})
	return options.get_options()

func _get_completions(ctx:Completion):
	if _completion_last_is_flag(ctx):
		return _get_completion_std_w_context(ctx, false)
	return PECommandUtils.plugin_name_completion(self, ctx, PECommandUtils.TargetAddons.VALID)

func _execute(ctx:Context):
	var report = RequireReport.build(positional_args[0])
	if not report.errors.is_empty():
		for e in report.errors:
			ctx.append_error(e)
		return ExitCode.FAIL

	var result = RequireUpdate.apply(report, overwrite_flag, prune_flag)
	var lines:Array[String] = []
	for w in result.warnings:
		lines.append("warning: " + w)
	for dir in report.loose:
		lines.append("warning: %s is in no plugin.cfg/version.cfg package, so it can't be required" % dir)
	if not result.errors.is_empty():
		ctx.append_output("\n".join(lines))
		for e in result.errors:
			ctx.append_error(e)
		ctx.append_error("nothing was written")
		return ExitCode.FAIL

	for spec in result.added:
		lines.append("added      " + spec)
	for spec in result.repinned:
		lines.append("re-pinned  " + spec)
	for spec in result.pruned:
		lines.append("pruned     " + spec)
	if not result.kept.is_empty():
		lines.append("kept       %d" % result.kept.size())
	lines.append(("wrote " if result.changed else "already up to date: ") + result.path)
	ctx.append_output("\n".join(lines))
	return ExitCode.OK
