@tool
extends RefCounted
## The throwaway project a release export runs in: every lock entry extracted at its tag into its
## install path, the standalone exporter as toolchain, and a minimal project.godot. Keyed by lock
## hash and reused, so an unchanged lock keeps its .godot import cache between exports.

const DepResolver = preload("res://addons/plugin_exporter/src/class/release/dep_resolver.gd")
const ReleaseRunner = preload("res://addons/plugin_exporter/src/class/release/release_runner.gd")

const READY_MARKER = ".pe_release_ready"
const TOOLCHAIN_PATH = "res://addons/plugin_exporter"
const CONFIG_NAMES = ["plugin_export.yml", "plugin_export.yaml", "plugin_export.json"]

var cache # RepoCache
var errors:Array[String] = []


func _init(repo_cache) -> void:
	cache = repo_cache


func workspace_dir(target_name:String, lock:Dictionary) -> String:
	return cache.root.path_join("workspaces").path_join("%s-%s" % [target_name, DepResolver.lock_hash(lock)])


## Builds (or reuses) the workspace and points its export at export_root_abs. `toolchain_dir` may be
## "" only when the target is plugin_exporter itself, whose pinned checkout is then the toolchain.
## Returns the absolute workspace dir, or "" with `errors` filled.
func build(lock:Dictionary, target_name:String, toolchain_dir:String, export_root_abs:String, debug_section:String) -> String:
	errors.clear()
	var ws = workspace_dir(target_name, lock)
	_prune_other_workspaces(target_name, ws)
	if not FileAccess.file_exists(ws.path_join(READY_MARKER)):
		if DirAccess.dir_exists_absolute(ws):
			ReleaseRunner.remove_dir(ws) # a half-built one from an interrupted run
		if not _populate(ws, lock, toolchain_dir):
			return ""
		FileAccess.open(ws.path_join(READY_MARKER), FileAccess.WRITE).close()

	# Redone on reuse too: all cheap, and the export root is the one input not in the lock.
	if not _write_project(ws, target_name, debug_section):
		return ""
	if not ReleaseRunner.write_export_autorun(ws):
		errors.append("could not write the autorun plugin into " + ws)
		return ""
	if not _point_export_root(ws.path_join(lock.target.path.trim_prefix("res://")), export_root_abs):
		return ""
	return ws


func _populate(ws:String, lock:Dictionary, toolchain_dir:String) -> bool:
	for entry in [lock.target] + lock.deps:
		if entry != lock.target and entry.path == TOOLCHAIN_PATH:
			errors.append("%s installs at %s, where the toolchain has to live" % [entry.repo_id, TOOLCHAIN_PATH])
			return false
		var dest = ws.path_join(entry.path.trim_prefix("res://"))
		if not cache.extract(entry.url, entry.tag, dest):
			errors.append("%s@%s: %s" % [entry.repo_id, entry.tag, cache.last_error])
			return false

	if lock.target.path != TOOLCHAIN_PATH:
		if toolchain_dir == "" or not ReleaseRunner.copy_dir(toolchain_dir, ws.path_join("addons/plugin_exporter")):
			errors.append("could not copy the standalone exporter from '%s'" % toolchain_dir)
			return false
	return true


## Only the autorun is enabled. The exporter is loaded as plain scripts, so its EditorPlugin (and
## the singleton modules it registers with) never has to start up in the workspace.
func _write_project(ws:String, target_name:String, debug_section:String) -> bool:
	var project = ReleaseRunner.project_godot("PE Release %s" % target_name, [
		"res://addons/%s/plugin.cfg" % ReleaseRunner.EXPORT_AUTORUN_DIR,
	], debug_section)
	var file = FileAccess.open(ws.path_join("project.godot"), FileAccess.WRITE)
	if file == null:
		errors.append("could not write project.godot in " + ws)
		return false
	file.store_string(project)
	file.close()
	return true


## Rewrites the target config's export_root in place so output lands where a workspace export puts
## it. A line edit rather than a parse/dump, which would drop the config's comments.
func _point_export_root(target_dir:String, export_root_abs:String) -> bool:
	var config_path = ""
	for nm in CONFIG_NAMES:
		var p = target_dir.path_join("export_ignore").path_join(nm)
		if FileAccess.file_exists(p):
			config_path = p
			break
	if config_path == "":
		errors.append("no plugin_export config in the tagged checkout at " + target_dir.path_join("export_ignore"))
		return false

	var text = FileAccess.get_file_as_string(config_path)
	var regex = RegEx.new()
	regex.compile(r'(?m)^(\s*"?export_root"?\s*:\s*)"[^"]*"')
	if regex.search(text) == null:
		errors.append("no export_root in " + config_path)
		return false
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	file.store_string(regex.sub(text, '$1"%s"' % export_root_abs))
	file.close()
	return true


## One workspace per target: re-tagging under --local changes the lock hash on every attempt.
## Matches `<target>-<16 hex>` exactly, so plugin_exporter never prunes plugin_exporter_test's.
func _prune_other_workspaces(target_name:String, keep:String) -> void:
	var dir = keep.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		return
	var prefix = target_name + "-"
	for d in DirAccess.get_directories_at(dir):
		var suffix = d.trim_prefix(prefix)
		if not d.begins_with(prefix) or suffix.length() != 16 or not suffix.is_valid_hex_number():
			continue
		if dir.path_join(d) != keep:
			ReleaseRunner.remove_dir(dir.path_join(d))
