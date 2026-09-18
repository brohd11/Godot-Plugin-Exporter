@tool
extends RefCounted
## What a plugin's build requirements need to say: scans everything the plugin exports and maps
## each reference to the package it lands in - the nearest dir with a plugin.cfg or version.cfg -
## so 50 files of one release come back as one package. Packages are grouped by the package making
## the reference, since that one's export_ignore/plugin_export.* is where `build_require` belongs.
## Its own graph keeps every dependent, so cross-package references cannot overwrite each other.

const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")
const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const ExportFileUtils = UtilsLocal.ExportFileUtils
const ExportData = UtilsLocal.ExportData
const DependencyTags = UtilsLocal.DependencyTags
const Dependencies = UtilsRemote.Dependencies
const DepEdge = Dependencies.DepEdge
const DepResolver = preload("res://addons/plugin_exporter/src/class/release/dep_resolver.gd")

const CFG_NAMES = ["plugin.cfg", "version.cfg"]


## {target, plugin_name, config_path, groups: {from_package: {config, rows: [{dir, id, via, files,
## declared}]}}, loose: {dir: files}, unused: {from_package: [id]}, errors}. `declared` is "build",
## "compile" or "". A from_package of "" is a dependent outside any package.
static func build(plugin_name:String) -> Dictionary:
	var report = {"target": "", "plugin_name": "", "config_path": "", "groups": {}, "loose": {},
		"unused": {}, "errors": []}
	var package_dir = ExportFileUtils.ExportPaths.resolve_target(plugin_name)
	if package_dir == "":
		report.errors.append("Invalid package target (expected a path inside this project): " + plugin_name)
		return report
	var config_path = ExportFileUtils.get_export_config_path(plugin_name)
	report.plugin_name = package_dir
	report.config_path = config_path
	if not FileAccess.file_exists(config_path):
		report.errors.append("no export config at " + config_path)
		return report
	var data = ExportData.new(config_path)
	if not data.data_valid:
		report.errors.append("the export crawl failed for %s; see the output log" % plugin_name)
		return report

	var cache = {}
	var target = _package_dir(package_dir.path_join("plugin.cfg"), cache)
	report.target = target
	var needed = {target: {}} # from package -> {required package -> file count}

	var roots = {}
	for export in data.exports:
		for file:String in export.valid_files_for_transfer:
			roots[file] = true
	var graph = _scan_files(roots.keys(), data.class_list)

	# Every edge, so a file referenced from inside and outside its package still counts the outside.
	var counted = {}
	for edge in graph.edges:
		# a load() target compiles without the file - same rule as the export, it needs "#! dependency"
		if edge.to == "" or edge.kind == DepEdge.Kind.LOAD:
			continue
		var package = _package_dir(edge.to, cache)
		if package == target and package != "":
			continue # the plugin's own files are never a requirement
		var from = _package_dir(edge.from, cache)
		if package == from and package != "":
			continue
		var key = "%s|%s" % [edge.to, from]
		if counted.has(key):
			continue
		counted[key] = true
		if package == "":
			report.loose[edge.to.get_base_dir()] = report.loose.get(edge.to.get_base_dir(), 0) + 1
			continue
		if not needed.has(from):
			needed[from] = {}
		needed[from][package] = needed[from].get(package, 0) + 1

	var identities = {}
	for from in needed:
		var declared = _declared(from)
		var needed_ids = {}
		var rows = []
		for package in needed[from]:
			if not identities.has(package):
				identities[package] = package_identity(package)
			var identity = identities[package]
			needed_ids[identity.id] = true
			var state = "compile" if declared.compile.has(identity.id) else ("build" if declared.build.has(identity.id) else "")
			rows.append({"dir": package, "id": identity.id, "via": identity.via, "files": needed[from][package], "declared": state})
		rows.sort_custom(func(a, b): return a.id < b.id if a.id != b.id else a.dir < b.dir)
		report.groups[from] = {"config": declared.config, "rows": rows}
		# Only the target: this crawl reaches just part of any other package, so its declarations
		# can't be judged here. compile_require entries are expected not to be crawled at all.
		if from == target:
			var unused = declared.build.keys().filter(func(i): return not needed_ids.has(i))
			if not unused.is_empty():
				report.unused[from] = unused
	return report


## {id, via}: the git origin when the package dir is itself a checkout, else its cfg `url=` (a
## release package installed from a zip). Never the nearest .git further up - in this project that
## is the dev monorepo, which says nothing about where the package comes from.
static func package_identity(dir:String) -> Dictionary:
	var git = dir.path_join(".git")
	if DirAccess.dir_exists_absolute(git) or FileAccess.file_exists(git):
		var id = DepResolver.repo_id_from_url(DepResolver.origin_url(dir))
		if id != "":
			return {"id": id, "via": "git"}
	var from_url = DepResolver.repo_id_from_url(_cfg_value(dir, "url"))
	return {"id": from_url, "via": "url=" if from_url != "" else ""}


static func format(report:Dictionary) -> String:
	var lines:Array[String] = []
	var froms = report.groups.keys()
	froms.sort()
	froms.erase(report.target)
	froms.push_front(report.target)

	for from in froms:
		var group = report.groups.get(from, {})
		var rows:Array = group.get("rows", [])
		if rows.is_empty():
			continue
		var header = from if from != "" else "(dependents outside any package)"
		if from != "" and not group.config:
			header += "  (no plugin_export config - it declares nothing)"
		lines.append(header)
		for r in rows:
			var name = r.id.trim_prefix("github.com/") if r.id != "" else "(no git origin or url=)"
			var state = "n/a"
			if from != "" and r.id != "":
				state = "declared (%s)" % r.declared if r.declared != "" else "MISSING"
			lines.append("    %-40s %-18s %3d file%s  %s%s" % [name, state, r.files, " " if r.files == 1 else "s",
				r.dir, "  [url=]" if r.via == "url=" else ""])

	if not report.loose.is_empty():
		lines.append("Files outside any plugin.cfg/version.cfg package:")
		var dirs = report.loose.keys()
		dirs.sort()
		for dir in dirs:
			lines.append("    %s  %d file%s" % [dir, report.loose[dir], "" if report.loose[dir] == 1 else "s"])

	if not report.unused.is_empty():
		lines.append("In build_require but not needed by the crawl:")
		for from in report.unused:
			for id in report.unused[from]:
				lines.append("    %s: %s" % [from, id.trim_prefix("github.com/")])

	if lines.is_empty():
		lines.append("Nothing outside %s is pulled in." % report.target)
	return "\n".join(lines)


## Nearest ancestor dir holding a plugin.cfg or version.cfg; "" when none does. Memoized per
## directory - a crawl visits the same few dirs hundreds of times.
static func _package_dir(path:String, cache:Dictionary) -> String:
	var dir = path.get_base_dir()
	var walked = []
	var found = ""
	while dir.begins_with("res://"):
		if cache.has(dir):
			found = cache[dir]
			break
		walked.append(dir)
		if CFG_NAMES.any(func(nm): return FileAccess.file_exists(dir.path_join(nm))):
			found = dir
			break
		if dir == "res://":
			break
		dir = dir.get_base_dir()
	for w in walked:
		cache[w] = found
	return found


static func _scan_files(roots:Array, class_map:Dictionary):
	var scanner = Dependencies.open_many(roots)
	scanner.class_map = class_map
	scanner.include_missing = false # a file not on disk can't be packaged
	scanner.follow_load = false
	scanner.ignore_line_tags = [DependencyTags.IGNORE_REMOTE]
	scanner.ignore_dir_names = DepResolver.ExportIgnore.NAMES.duplicate()
	scanner.add_tag_handler(DependencyTags.TAG, DependencyTags.dependency_dir())
	return scanner.get_graph()


## {config, build, compile}: whether the package has an export config, and the repo ids it lists
## under each key.
static func _declared(dir:String) -> Dictionary:
	var out = {"config": false, "build": {}, "compile": {}}
	if dir == "":
		return out
	for path in DepResolver.ExportIgnore.candidates(dir, DepResolver.CONFIG_NAMES):
		if not FileAccess.file_exists(path):
			continue
		out.config = true
		var parsed = DepResolver.requires_in_export_config(FileAccess.get_file_as_string(path), path.get_extension(), _cfg_text(dir))
		for req in parsed.requires:
			out["compile" if req.compile else "build"][req.dep.repo_id] = true
		break
	return out


static func _cfg_value(dir:String, key:String) -> String:
	return DepResolver.unquote(DepResolver.plugin_section(_cfg_text(dir)).get(key, ""))


static func _cfg_text(dir:String) -> String:
	if dir == "":
		return ""
	for nm in CFG_NAMES:
		if FileAccess.file_exists(dir.path_join(nm)):
			return FileAccess.get_file_as_string(dir.path_join(nm))
	return ""
