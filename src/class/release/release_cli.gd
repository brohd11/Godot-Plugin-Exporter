extends SceneTree
## Headless release export, the entry CI runs:
##     godot --headless --path <project> --script res://addons/plugin_exporter/src/class/release/release_cli.gd -- <package dir> [--refresh] [--local]
## <package dir> is res://, project-relative (addons/_lib/x) or absolute inside the project. Exits 0
## once the release exported and verified, printing its zips as one OUTPUT_PREFIX line of JSON.

const ReleaseExport = preload("res://addons/plugin_exporter/src/class/release/release_export.gd")

const OUTPUT_PREFIX = "PE_RELEASE_OUTPUT "
const USAGE = "usage: release_cli.gd -- <package dir> [--refresh] [--local]"


func _init() -> void:
	var target = ""
	var refresh = false
	var local = false
	for arg in OS.get_cmdline_user_args():
		match arg:
			"--refresh": refresh = true
			"--local": local = true
			_:
				if arg.begins_with("--") or target != "":
					printerr(USAGE)
					quit(2)
					return
				target = arg
	if target == "":
		printerr(USAGE)
		quit(2)
		return

	var ok = ReleaseExport.export_release(to_res_path(target), refresh, local)
	print(OUTPUT_PREFIX + JSON.stringify(ReleaseExport.zips if ok else []))
	quit(0 if ok else 1)


## export_release's own resolution reads bare names under res://addons, so a project-relative path
## is anchored at res:// here, where a shell or workflow would mean it.
static func to_res_path(arg:String) -> String:
	arg = arg.strip_edges().replace("\\", "/")
	if arg.begins_with("res://"):
		return arg
	if arg.is_absolute_path():
		return ProjectSettings.localize_path(arg)
	return "res://" + arg.trim_prefix("./")
