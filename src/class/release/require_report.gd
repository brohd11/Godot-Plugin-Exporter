@tool
extends RefCounted
## What a plugin's `require` entries need to say: runs the normal export crawl (nothing is written)
## and maps every dependency file to the package it belongs to - the nearest dir with a plugin.cfg
## or version.cfg - so 50 files of one release come back as one package. Packages are grouped by the
## package whose files pull them in, since that one's cfg is where the entry belongs.
## The crawl keeps one dependent per file, so a package needed from two places may list under one.

const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")
const ExportFileUtils = UtilsLocal.ExportFileUtils
const ExportData = UtilsLocal.ExportData
const DepResolver = preload("res://addons/plugin_exporter/src/class/release/dep_resolver.gd")

const CFG_NAMES = ["plugin.cfg", "version.cfg"]


## {target, groups: {from_package: [{dir, id, via, files, declared}]}, loose: {dir: files},
## unused: {from_package: [id]}, errors}. A from_package of "" is a dependent outside any package.
static func build(plugin_name:String) -> Dictionary:
	var report = {"target": "", "groups": {}, "loose": {}, "unused": {}, "errors": []}
	plugin_name = plugin_name.trim_prefix("/").trim_suffix("/")
	var config_path = ExportFileUtils.get_export_config_path(plugin_name)
	if not FileAccess.file_exists(config_path):
		report.errors.append("no export config at " + config_path)
		return report
	var data = ExportData.new(config_path)
	if not data.data_valid:
		report.errors.append("the export crawl failed for %s; see the output log" % plugin_name)
		return report

	var cache = {}
	var target = _package_dir("res://addons/%s/plugin.cfg" % plugin_name, cache)
	report.target = target
	var needed = {target: {}} # from package -> {required package -> file count}

	for export in data.exports:
		for file:String in export.file_dependencies:
			var package = _package_dir(file, cache)
			if package == target and package != "":
				continue # the plugin's own files are never a requirement
			var dependent = export.file_dependencies[file].get("dependent")
			var from = _package_dir(dependent, cache) if dependent is String and dependent != "" else target
			if package == from and package != "":
				continue
			if package == "":
				report.loose[file.get_base_dir()] = report.loose.get(file.get_base_dir(), 0) + 1
				continue
			if not needed.has(from):
				needed[from] = {}
			needed[from][package] = needed[from].get(package, 0) + 1

	var identities = {}
	for from in needed:
		var declared = _declared_ids(from)
		var needed_ids = {}
		var rows = []
		for package in needed[from]:
			if not identities.has(package):
				identities[package] = package_identity(package)
			var identity = identities[package]
			needed_ids[identity.id] = true
			rows.append({"dir": package, "id": identity.id, "via": identity.via,
				"files": needed[from][package], "declared": declared.has(identity.id)})
		rows.sort_custom(func(a, b): return a.id < b.id if a.id != b.id else a.dir < b.dir)
		report.groups[from] = rows
		var unused = declared.keys().filter(func(i): return not needed_ids.has(i))
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
		var rows:Array = report.groups.get(from, [])
		if rows.is_empty():
			continue
		lines.append(from if from != "" else "(dependents outside any package)")
		for r in rows:
			var name = r.id.trim_prefix("github.com/") if r.id != "" else "(no git origin or url=)"
			var state = "n/a" if from == "" or r.id == "" else ("declared" if r.declared else "MISSING")
			lines.append("    %-40s %-8s %3d file%s  %s%s" % [name, state, r.files, " " if r.files == 1 else "s",
				r.dir, "  [url=]" if r.via == "url=" else ""])

	if not report.loose.is_empty():
		lines.append("Files outside any plugin.cfg/version.cfg package:")
		var dirs = report.loose.keys()
		dirs.sort()
		for dir in dirs:
			lines.append("    %s  %d file%s" % [dir, report.loose[dir], "" if report.loose[dir] == 1 else "s"])

	if not report.unused.is_empty():
		lines.append("Declared but not needed by the crawl:")
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
	while dir.begins_with("res://") and dir != "res://":
		if cache.has(dir):
			found = cache[dir]
			break
		walked.append(dir)
		if CFG_NAMES.any(func(nm): return FileAccess.file_exists(dir.path_join(nm))):
			found = dir
			break
		dir = dir.get_base_dir()
	for w in walked:
		cache[w] = found
	return found


static func _declared_ids(dir:String) -> Dictionary:
	var ids = {}
	for dep in DepResolver.deps_in_cfg_text(_cfg_text(dir)):
		ids[dep.repo_id] = true
	return ids


static func _cfg_value(dir:String, key:String) -> String:
	return DepResolver.unquote(DepResolver.plugin_section(_cfg_text(dir)).get(key, ""))


static func _cfg_text(dir:String) -> String:
	if dir == "":
		return ""
	for nm in CFG_NAMES:
		if FileAccess.file_exists(dir.path_join(nm)):
			return FileAccess.get_file_as_string(dir.path_join(nm))
	return ""
