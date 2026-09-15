@tool
extends RefCounted
## Release export: resolves the target's deps to pinned tags, exports from a workspace built out of
## those tags instead of the dev tree, then proves the output compiles on its own. The workspace
## export (PluginExporterStatic.export_by_name) is untouched - this is the build with go.work off.

const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")
const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const ExportFileUtils = UtilsLocal.ExportFileUtils

const DepResolver = preload("res://addons/plugin_exporter/src/class/release/dep_resolver.gd")
const RepoCache = preload("res://addons/plugin_exporter/src/class/release/repo_cache.gd")
const ReleaseWorkspace = preload("res://addons/plugin_exporter/src/class/release/release_workspace.gd")
const ReleaseRunner = preload("res://addons/plugin_exporter/src/class/release/release_runner.gd")
const CompileCheck = preload("res://addons/plugin_exporter/src/class/release/compile_check.gd")
const Toolchain = preload("res://addons/plugin_exporter/src/class/release/toolchain.gd")
const ReleaseCache = preload("res://addons/plugin_exporter/src/class/release/release_cache.gd")
const PackageFetcher = preload("res://addons/plugin_exporter/src/class/release/package_fetcher.gd")

const LOCK_FILE = ".export_lock.json"
const GIT_DETAILS_FILE = ".export_git_details"
const UNVERIFIED_SUFFIX = "-unverified"
const TOOLCHAIN_SCRIPTS = "res://addons/plugin_exporter/src/class/"

## Failure lines from the last export_release call, for callers that don't see the Output log.
static var messages:Array[String] = []


## `local` fetches every repo checked out in this project from that checkout rather than its
## remote - still by tag, so nothing uncommitted gets in, but nothing has to be pushed either.
static func export_release(plugin_name:String, refresh:bool = false, local:bool = false) -> bool:
	messages.clear()
	plugin_name = plugin_name.trim_prefix("/").trim_suffix("/")
	var started = Time.get_ticks_msec()
	var ok = _export_release(plugin_name, refresh, local)
	var seconds = (Time.get_ticks_msec() - started) / 1000.0
	if ok:
		print_rich("'%s' [color=25c225]release exported and verified[/color] (%.1fs)" % [plugin_name, seconds])
	else:
		print_rich("'%s' [color=b20f0f]release export failed[/color] (%.1fs)" % [plugin_name, seconds])
	return ok


static func _export_release(plugin_name:String, refresh:bool, local:bool) -> bool:
	var dev_dir = "res://addons/" + plugin_name
	var config_path = ExportFileUtils.get_export_config_path(plugin_name)
	if not FileAccess.file_exists(config_path):
		return _fail("no export config at " + config_path)
	var version = _cfg_version(dev_dir)
	if version == "":
		return _fail("no version= in %s plugin.cfg/version.cfg" % dev_dir)
	var url = DepResolver.origin_url(dev_dir)
	if url == "":
		return _fail("%s has no origin remote; release exports fetch the target by tag from it" % dev_dir)

	print("Release export: resolving %s %s" % [plugin_name, version])
	var cache = RepoCache.new("", refresh)
	var fetcher = PackageFetcher.new(cache, ReleaseCache.new(cache.root, refresh))
	var dev_repos = DepResolver.scan_dev_repos()
	var overrides = {}
	if local:
		for id in dev_repos:
			var local_url = "file://" + ProjectSettings.globalize_path(dev_repos[id])
			overrides[id] = local_url
			cache.local_urls[local_url] = true
	var resolver = DepResolver.new(fetcher, dev_repos, overrides)
	var lock = resolver.resolve(url, version, dev_dir)
	if lock.is_empty():
		for e in resolver.errors:
			_note("  " + e)
		return false
	if local:
		lock.local = true
		_warn_unpushed(lock, dev_repos)

	var config = ExportFileUtils.get_export_data(config_path)
	if not config is Dictionary:
		return false
	var options = config.get("options", {})
	_print_lock(lock)

	# Recorded in the lock before the workspace is keyed on it, so a new toolchain gets a new one.
	var toolchain = ""
	if lock.target.path != ReleaseWorkspace.TOOLCHAIN_PATH:
		var tc = Toolchain.new()
		var info = tc.resolve(options, cache.root, local, refresh, _local_toolchain_dir() if local else "")
		if info.is_empty():
			for e in tc.errors:
				_note("  " + e)
			return false
		toolchain = info.dir
		lock.toolchain = {"version": info.version, "source": info.source, "id": info.id}
		print("  toolchain %s %s (%s)" % [Toolchain.NAME, info.version, info.source])

	var workspace = ReleaseWorkspace.new(fetcher)
	var debug_section = ReleaseRunner.project_section(FileAccess.get_file_as_string("res://project.godot"), "debug")
	var export_root = ProjectSettings.globalize_path(config.get("export_root", ""))
	var ws = workspace.build(lock, plugin_name, toolchain, export_root, debug_section)
	if ws == "":
		for e in workspace.errors:
			_note("  " + e)
		return false

	print("Release export: exporting in " + ws)
	var run = ReleaseRunner.run_export(ws, plugin_name)
	if lock.has("toolchain"):
		var broken = ReleaseRunner.script_errors(run.output).filter(func(e): return TOOLCHAIN_SCRIPTS in e)
		if not broken.is_empty():
			for e in broken.slice(0, 8):
				_note("  " + e)
			return _fail("toolchain %s %s (%s) export scripts don't compile" % [
				Toolchain.NAME, lock.toolchain.version, lock.toolchain.source])
	if run.result.is_empty() or not run.result.get("ok", false):
		var errs = ReleaseRunner.script_errors(run.output)
		if errs.is_empty():
			printerr(run.output.right(4000))
		for e in errs.slice(0, 12):
			_note("  " + e)
		return _fail("export in workspace failed (exit %d): %s" % [run.exit, run.result.get("error", "see output above")])

	var full_export_path:String = run.result.full_export_path
	for e in run.result.exports:
		_finalize_export_dir(e.dir, lock)
	_rezip(full_export_path)

	print("Release export: verifying")
	# compile_require deps (and what they need) sit beside the export, as they would when installed.
	var verify_installs = {}
	for entry in lock.deps:
		if entry.get("verify", false):
			verify_installs[entry.path] = ws.path_join(entry.path.trim_prefix("res://"))
	var failures:Array[String] = []
	for exported in run.result.exports:
		var plugin_dir = String(exported.dir).trim_suffix("/")
		var label = plugin_dir.trim_prefix(full_export_path.trim_suffix("/") + "/")
		for b in CompileCheck.broken_references(plugin_dir, exported.install_path):
			failures.append("%s: missing reference %s" % [label, b])
		var work_dir = cache.root.path_join("verify").path_join(label.replace("/", "_"))
		var errs = CompileCheck.compile_errors(plugin_dir, exported.install_path, work_dir, verify_installs)
		for e in errs:
			failures.append("%s: %s" % [label, e])
		if errs.is_empty():
			ReleaseRunner.remove_dir(work_dir)
		else:
			_note("  compile check project kept at " + work_dir)

	if not failures.is_empty():
		for f in failures:
			_note("  " + f)
		_mark_unverified(full_export_path)
		return _fail("output does not compile on its own; moved to *%s" % UNVERIFIED_SUFFIX)
	return true


## Where this project exports plugin_exporter, for --local toolchains. Computed with the export
## pipeline (it resolves {{version}} templates), so it stays here rather than in Toolchain.
static func _local_toolchain_dir() -> String:
	var config_path = ExportFileUtils.get_export_config_path(Toolchain.NAME)
	if not FileAccess.file_exists(config_path):
		return ""
	var data = ExportFileUtils.get_export_data(config_path)
	if not data is Dictionary or data.get("exports", []).is_empty():
		return ""
	var entry = data.exports[0]
	var full = ExportFileUtils.get_full_export_path(data.export_root, data.plugin_folder, config_path)
	var package = full.path_join(ExportFileUtils.get_export_name(entry, data.plugin_folder, config_path))
	return package.path_join(ExportFileUtils.get_export_folder(entry, config_path)).trim_suffix("/")


## Swaps the dev-tree git snapshot for the lock. The released plugin.cfg is left alone: its
## require/deps are install-time, gdaddon's, and the build graph never came from them.
static func _finalize_export_dir(dir:String, lock:Dictionary) -> void:
	DirAccess.remove_absolute(dir.path_join(GIT_DETAILS_FILE))
	var file = FileAccess.open(dir.path_join(LOCK_FILE), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(lock, "\t"))
		file.close()


## Same packaging as PluginExporterStatic.export_plugin, redone because finalizing changed files.
static func _rezip(full_export_path:String) -> void:
	for dir in DirAccess.get_directories_at(full_export_path):
		var dir_path = full_export_path.path_join(dir)
		var search = UtilsRemote.GetFiles.open(dir_path)
		search.show_hidden = true
		search.enter_gdignore = true
		ExportFileUtils.write_zip_file(dir_path + ".zip", search.get_files())


## Keeps a failed release around for inspection, under a name nobody would ship by accident.
static func _mark_unverified(full_export_path:String) -> void:
	var src = full_export_path.trim_suffix("/")
	var dest = src + UNVERIFIED_SUFFIX
	if DirAccess.dir_exists_absolute(dest):
		ReleaseRunner.remove_dir(dest)
	DirAccess.rename_absolute(src, dest)


static func _cfg_version(dir:String) -> String:
	for nm in ["plugin.cfg", "version.cfg"]:
		var cfg = ConfigFile.new()
		if cfg.load(dir.path_join(nm)) == OK:
			return str(cfg.get_value("plugin", "version", ""))
	return ""


static func _print_lock(lock:Dictionary) -> void:
	for entry in [lock.target] + lock.deps:
		var role = "target" if entry == lock.target else ("compile" if entry.get("verify", false) else "bundled")
		var fetched = entry.get("kind", "source")
		if entry.get("asset", "") != "":
			fetched += " " + entry.asset
		print("  %-8s %-6s %s %s [%s] (%s) -> %s" % [role, entry.get("source", ""), entry.repo_id, entry.tag,
			fetched, entry.sha.substr(0, 7), entry.path])


## A local build is fine to try, but one others can't reproduce shouldn't pass silently - nor should
## a repo that quietly came from its remote when you expected your checkout.
static func _warn_unpushed(lock:Dictionary, dev_repos:Dictionary) -> void:
	for entry in [lock.target] + lock.deps:
		if entry.get("kind") == "release":
			print_rich("[color=e0b000]Release export: %s %s is a release asset (%s), fetched from GitHub[/color]" % [entry.repo_id, entry.tag, entry.asset])
			continue
		if entry.get("source") != "local":
			print_rich("[color=e0b000]Release export: %s %s has no local checkout with a matching origin; fetched from its remote[/color]" % [entry.repo_id, entry.tag])
			continue
		var output = []
		var dir = ProjectSettings.globalize_path(dev_repos[entry.repo_id])
		var code = OS.execute("git", ["-C", dir, "ls-remote", "--tags", "origin", "refs/tags/" + entry.tag], output)
		if code != 0:
			print_rich("[color=e0b000]Release export: couldn't check origin for %s %s[/color]" % [entry.repo_id, entry.tag])
		elif "".join(output).strip_edges() == "":
			print_rich("[color=e0b000]Release export: %s %s is not on origin yet[/color]" % [entry.repo_id, entry.tag])


static func _fail(message:String) -> bool:
	_note("Release export: " + message)
	return false


## printerr, and kept in `messages` so the console command can show why - Output alone is easy to miss.
static func _note(line:String) -> void:
	printerr(line)
	messages.append(line)
