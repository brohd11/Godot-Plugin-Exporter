extends EditorConsoleSingleton.CommandBase


const PluginExporter = preload("res://addons/plugin_exporter/src/class/plugin_exporter.gd")
const ExportData = PluginExporter.PluginExporterStatic.ExportData
const Export = ExportData.Export

const VersionScanner = preload("res://addons/plugin_exporter/src/editor_plugins/console_command/min_version/version_scanner.gd")
const VersionApi = preload("res://addons/plugin_exporter/src/editor_plugins/console_command/min_version/version_api.gd")

const _HELP = \
"Report the minimum Godot version a plugin's exports can run on.
Scans every file in each export package for version-gated syntax and API usage.
Usage: min_version <addon_name> [--verbose] [--full]
  --verbose  List every occurrence with its file:line location.
  --full     Future GDScript-parser deep scan (variable type inference); not yet
             implemented — currently runs the standard scan."

var verbose_flag := false
var full_flag := false

static func get_command_name():
	return "min_version"

static func get_self_command_data():
	return _command_data({
		&"help": _HELP,
		&"positional_count": 1,
	})


func _get_flags() -> Dictionary:
	var options = Options.new()
	options.add_option("--verbose", {&"help": "List every occurrence with its file:line location."})
	options.add_option("--full", {&"help": "Future parser-based deep scan (not yet implemented)."})
	return options.get_options()

func _process_flag(flag:String):
	if flag == "--verbose":
		verbose_flag = true
	elif flag == "--full":
		full_flag = true

func _get_completions(ctx:CompletionContext):
	var options = Options.new()
	var addon_dirs = PluginExporter.get_addons_dirs("valid")
	for d in addon_dirs:
		options.add_option(d)
	return options.get_options()

func _execute(ctx:CompletionContext):
	var addon_name = positional_args[0]
	var export_data = PluginExporter.PluginExporterStatic.get_export_data_by_name(addon_name)

	if not is_instance_valid(export_data) or not export_data.data_valid:
		ctx.append_output("Could not get export data for: " + addon_name)
		return ExitCode.FAIL

	var scanner = VersionScanner.new()
	if not scanner.api.has_index():
		ctx.append_error("No extension_api/api_min_version.json index found — run extract_api.gd (build) first.")
		return ExitCode.FAIL

	if full_flag:
		ctx.append_output("(--full parser-based deep scan not yet implemented; running standard scan)")

	var overall := VersionApi.BASELINE

	for export:Export in export_data.exports:
		var export_min := VersionApi.BASELINE
		var all_findings := []    # every occurrence: {feature, version, location}

		for file_path:String in export.files_to_copy.keys():
			var r = scanner.scan_file(file_path)
			export_min = VersionApi.max_version(export_min, r["min_version"])
			for fnd in r["findings"]:
				all_findings.append({
					"feature": fnd["feature"], "version": fnd["version"],
					"location": "%s:%d" % [file_path, fnd["line"]],
				})

		overall = VersionApi.max_version(overall, export_min)

		var label = export.export_folder if export.export_folder != "" else export.source
		ctx.append_output("")
		ctx.append_output("Export: %s  ->  %s" % [label, export_min])

		if verbose_flag:
			# Every occurrence, with location, highest version first.
			all_findings.sort_custom(func(a, b):
				var ca = VersionApi.version_code(a["version"])
				var cb = VersionApi.version_code(b["version"])
				if ca != cb:
					return ca > cb
				return a["feature"] < b["feature"])
			for data in all_findings:
				ctx.append_output("  %s  %s  ([url=%s]%s[/url])" % [data["version"], data["feature"], data["location"], data["location"].get_file()])
		else:
			# Distinct reasons only, no location, highest version first.
			var reasons := {}
			for data in all_findings:
				reasons[data["feature"]] = data["version"]
			var features := reasons.keys()
			features.sort_custom(func(a, b):
				var ca = VersionApi.version_code(reasons[a])
				var cb = VersionApi.version_code(reasons[b])
				if ca != cb:
					return ca > cb
				return a < b)
			for feature in features:
				ctx.append_output("  %s  %s" % [reasons[feature], feature])

	ctx.append_output("")
	ctx.append_output("Minimum Godot version: %s" % overall)
	return ExitCode.OK
