@tool
extends RefCounted
## Proves a release export stands alone: installs it into an empty project (plus runtime deps),
## loads every script and resource there, and collects parse/compile errors from the output.
## load() hands back a non-null GDScript even when compilation fails, so output is the real signal.

const ReleaseRunner = preload("res://addons/plugin_exporter/src/class/release/release_runner.gd")

const PROBE_DIR = "pe_compile_probe"
const LOAD_FAIL_PREFIX = "PE_LOAD_FAIL "
const LOAD_EXTENSIONS = ["gd", "tscn", "tres"]

const _PROBE = """@tool
extends EditorPlugin
# Written by PluginExporter's release compile check: loads every file of one plugin, then quits.

func _enter_tree() -> void:
	_run.call_deferred()

func _run() -> void:
	var fs = EditorInterface.get_resource_filesystem()
	await get_tree().process_frame
	while fs.is_scanning():
		await get_tree().process_frame
	for path in _walk("res://addons/%s"):
		if path.get_extension() in %s:
			if ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) == null:
				print("%s" + path)
	print("%s{}")
	get_tree().quit()

func _walk(dir:String) -> Array:
	var out = []
	for f in DirAccess.get_files_at(dir):
		out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_walk(dir.path_join(d)))
	return out
"""


## Preload/ext_resource targets that point inside the plugin but don't exist. Cheap, so it runs
## before a Godot process is spent. Same walk as export_fixture_test's every-reference check.
static func broken_references(plugin_dir:String) -> Array[String]:
	plugin_dir = plugin_dir.trim_suffix("/")
	var preload_regex = RegEx.new()
	preload_regex.compile(r'(?:preload|load)\(\s*"([^"]+)"\s*\)')
	var ext_resource_regex = RegEx.new()
	ext_resource_regex.compile(r'\[ext_resource[^\]]*\bpath="([^"]+)"')

	var broken:Array[String] = []
	for file in _walk(plugin_dir):
		var ext = file.get_extension()
		if not ext in LOAD_EXTENSIONS:
			continue
		var regex = preload_regex if ext == "gd" else ext_resource_regex
		for m in regex.search_all(FileAccess.get_file_as_string(file)):
			var target = m.get_string(1)
			var resolved = _resolve(target, file, plugin_dir)
			if resolved != "" and not FileAccess.file_exists(resolved):
				broken.append("%s -> %s" % [file.trim_prefix(plugin_dir + "/"), target])
	return broken


## Errors from loading the export in a clean project at work_dir; [] means it compiled.
## `extra_installs` maps res:// install paths to source dirs, for runtime deps like GDExtensions.
static func compile_errors(plugin_dir:String, work_dir:String, extra_installs:Dictionary = {}) -> Array[String]:
	plugin_dir = plugin_dir.trim_suffix("/")
	var plugin_name = plugin_dir.get_file()
	var errors:Array[String] = []

	if DirAccess.dir_exists_absolute(work_dir):
		ReleaseRunner.remove_dir(work_dir)
	if not ReleaseRunner.copy_dir(plugin_dir, work_dir.path_join("addons").path_join(plugin_name)):
		errors.append("could not install %s into %s" % [plugin_dir, work_dir])
		return errors
	for install_path in extra_installs:
		ReleaseRunner.copy_dir(extra_installs[install_path], work_dir.path_join(install_path.trim_prefix("res://")))

	var probe = _PROBE % [plugin_name, str(LOAD_EXTENSIONS), LOAD_FAIL_PREFIX, ReleaseRunner.RESULT_PREFIX]
	ReleaseRunner.write_plugin(work_dir, PROBE_DIR, probe)
	var project = ReleaseRunner.project_godot("PE Compile Check", ["res://addons/%s/plugin.cfg" % PROBE_DIR])
	var file = FileAccess.open(work_dir.path_join("project.godot"), FileAccess.WRITE)
	file.store_string(project)
	file.close()

	var imported = ReleaseRunner.godot(work_dir, ["--import"])
	var run = ReleaseRunner.godot(work_dir, ["--editor"])
	var output = imported.output + run.output

	if not ReleaseRunner.RESULT_PREFIX in run.output:
		errors.append("compile probe never finished (exit %d)" % run.exit)
	for line in output.split("\n"):
		if line.begins_with(LOAD_FAIL_PREFIX):
			errors.append("failed to load " + line.trim_prefix(LOAD_FAIL_PREFIX))
	for err in ReleaseRunner.script_errors(output):
		if not "res://addons/%s/" % PROBE_DIR in err:
			errors.append(err)
	return errors


## A reference as written, mapped back onto disk. res://addons/<plugin>/ means the export dir once
## installed; other plugins and non-addon paths aren't this check's business.
static func _resolve(target:String, from_file:String, plugin_dir:String) -> String:
	if target.begins_with("uid://"):
		return ""
	if target.begins_with("res://addons/"):
		var rest = target.trim_prefix("res://addons/")
		var name = rest.get_slice("/", 0)
		if name != plugin_dir.get_file() or not rest.begins_with(name + "/"):
			return ""
		return plugin_dir.path_join(rest.trim_prefix(name + "/"))
	if target.begins_with("./") or target.begins_with("../"):
		return from_file.get_base_dir().path_join(target).simplify_path()
	return ""


static func _walk(dir:String) -> Array[String]:
	var out:Array[String] = []
	for f in DirAccess.get_files_at(dir):
		out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_walk(dir.path_join(d)))
	return out
