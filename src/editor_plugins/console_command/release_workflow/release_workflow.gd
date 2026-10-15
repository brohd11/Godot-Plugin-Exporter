extends GDSh.CommandBase

const PluginExporter = preload("res://addons/package_exporter/src/class/plugin_exporter.gd")
const PECommandUtils = preload("res://addons/package_exporter/src/editor_plugins/console_command/command_utils.gd")

const _HELP = \
"Opt a package into CI releases: writes .github/workflows/release.yml at its repo root, calling
PackageExporter's reusable workflow on version tags. Never overwrites an existing file.
Usage: package_exporter release_workflow <plugin_name>"

static func get_command_name() -> String:
	return "release_workflow"

static func get_self_command_data() -> Dictionary:
	return _command_data({
		&"help": _HELP + PECommandUtils.TARGET_HELP,
		&"positional_count": 1
	})

func _get_completions(ctx:Completion):
	return PECommandUtils.plugin_name_completion(self, ctx, PECommandUtils.TargetAddons.VALID)

func _execute(ctx:Context):
	var path = PluginExporter.add_release_workflow(positional_args[0])
	if path == "":
		ctx.append_error("No workflow written; see Output.")
		return ExitCode.FAIL
	return ExitCode.OK
