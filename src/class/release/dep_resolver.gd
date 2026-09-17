@tool
extends RefCounted
## Resolves an addon's build dependency graph to pinned tags for a release export. Requirements are
## `build_require` / `compile_require` in each package's export_ignore/plugin_export.* - plugin.cfg's
## `require` is install-time only (gdaddon's) unless build_require names `@require`. Versions are
## picked Go-MVS style: each repo gets the
## highest tag any reachable requirement names. Repo access goes through `fetcher` (PackageFetcher,
## or a fake in tests); each package's addon folder and install path come from PackageLayout.

const PackageLayout = preload("res://addons/plugin_exporter/src/class/release/package_layout.gd")
const ExportIgnore = preload("res://addons/plugin_exporter/src/class/export/export_ignore.gd")

const DEFAULT_HOST = "github.com"
const CFG_NAMES = ["plugin.cfg", "version.cfg"]
const CONFIG_NAMES = ["plugin_export.yml", "plugin_export.yaml", "plugin_export.json"]
const BUILD_KEY = "build_require"
const COMPILE_KEY = "compile_require"
const REQUIRE_REF = "@require" # build_require item standing for the package cfg's require list
const TAGS_INCOMPARABLE = -99
const KIND_AUTO = "auto"
const KIND_SOURCE = "source"

class Dep:
	var host:String
	var owner:String
	var repo:String
	var tag:String
	var kind:String = "auto"
	var repo_url:String
	var repo_id:String

var fetcher
var dev_paths:Dictionary = {} # repo_id -> res:// dir of a checkout in this project
var url_overrides:Dictionary = {} # repo_id -> clone url, e.g. a file:// checkout for --local
var errors:Array[String] = []

var _packages:Dictionary = {} # "kind|url|tag" -> {info, src, dest} or {error}
var _cfg_texts:Dictionary = {} # "id|dir" -> cfg text
var _requires_cache:Dictionary = {} # "id|src" -> {requires, error}


func _init(fetcher_obj, dev_install_paths:Dictionary = {}, overrides:Dictionary = {}) -> void:
	fetcher = fetcher_obj
	dev_paths = dev_install_paths
	url_overrides = overrides


#region Parsing

## `owner/repo[/source][@tag]`, optionally led by a host (`gitlab.com/owner/repo`). A first segment
## only counts as a host when it has a dot - that is what keeps `owner/repo/source` apart from
## gdaddon's `host/owner/repo`. Plain means the release gdaddon would install; `/source` forces
## the tag's tree. null for any other shape.
static func parse_dep(item:String) -> Dep:
	item = item.strip_edges()
	var repo_part = item
	var tag = ""
	var at = item.rfind("@")
	if at >= 0:
		repo_part = item.substr(0, at)
		tag = item.substr(at + 1).strip_edges()

	var parts = Array(repo_part.strip_edges().lstrip("/").rstrip("/").split("/"))
	var dep = Dep.new()
	dep.host = DEFAULT_HOST
	if parts.size() >= 3 and "." in parts[0]:
		dep.host = parts.pop_front()
	if parts.size() == 3 and parts[2] == KIND_SOURCE:
		dep.kind = KIND_SOURCE
		parts.pop_back()
	if parts.size() != 2 or parts[0] == "" or parts[1] == "":
		return null

	dep.owner = parts[0]
	dep.repo = parts[1]
	dep.tag = tag
	dep.repo_url = "https://%s/%s/%s" % [dep.host, dep.owner, dep.repo]
	dep.repo_id = repo_id_from_url(dep.repo_url)
	return dep


## {requires: [{dep, compile}], error} from export config text. Each key holds a list of specs or a
## single spec; malformed specs are skipped. A repo in both keys yields both entries, and the
## compile one wins when verify flags are worked out. `@require` under build_require expands to
## `cfg_text`'s require list - the package's own plugin.cfg/version.cfg.
static func requires_in_export_config(text:String, ext:String, cfg_text:String = "") -> Dictionary:
	var data = null
	if ext == "json":
		var json = JSON.new()
		if json.parse(text) != OK:
			return {"requires": [], "error": "invalid JSON: %s (line %d)" % [json.get_error_message(), json.get_error_line()]}
		data = json.data
	else:
		var parser = YAMLParser.new()
		if parser.parse(text) != OK:
			return {"requires": [], "error": "invalid YAML"}
		data = parser.data
	if data == null:
		data = {}
	if not data is Dictionary:
		return {"requires": [], "error": "the top level is not a mapping"}

	var out = []
	var errors = []
	for key in [BUILD_KEY, COMPILE_KEY]:
		var value = data.get(key, [])
		var items = value if value is Array else ([value] if value is String and value != "" else [])
		var specs = []
		for item in items:
			if str(item).strip_edges() != REQUIRE_REF:
				specs.append(str(item))
			elif key == COMPILE_KEY:
				errors.append("%s is only valid under %s" % [REQUIRE_REF, BUILD_KEY])
			elif cfg_text == "":
				errors.append("%s needs the package's plugin.cfg or version.cfg" % REQUIRE_REF)
			else:
				specs.append_array(cfg_require(cfg_text))
		for spec in specs:
			var dep = parse_dep(spec)
			if dep != null:
				out.append({"dep": dep, "compile": key == COMPILE_KEY})
	return {"requires": out, "error": "; ".join(errors)}


## Specs in the [plugin] section's `require` array, as gdaddon writes it: one line or several, with
## a trailing comma allowed. Collected up to the closing bracket, so plugin_section() can't read it.
static func cfg_require(cfg_text:String) -> Array[String]:
	var out:Array[String] = []
	var in_plugin = false
	var array_text = ""
	var collecting = false
	for line in cfg_text.split("\n"):
		var stripped = line.strip_edges()
		if collecting:
			if not stripped.begins_with(";"):
				array_text += "\n" + stripped
		elif stripped.begins_with("["):
			in_plugin = stripped == "[plugin]"
			continue
		elif in_plugin and "=" in stripped and stripped.get_slice("=", 0).strip_edges() == "require":
			collecting = true
			array_text = stripped.substr(stripped.find("=") + 1)
		if collecting and "]" in array_text:
			break
	for m in RegEx.create_from_string('"([^"]*)"').search_all(array_text):
		if m.get_string(1).strip_edges() != "":
			out.append(m.get_string(1).strip_edges())
	return out


## Raw `key=value` strings of a cfg's [plugin] section. Hand-read rather than ConfigFile, which
## rejects values gdaddon's ini reader accepts.
static func plugin_section(text:String) -> Dictionary:
	var keys = {}
	var in_plugin = false
	for line in text.split("\n"):
		line = line.strip_edges()
		if line.begins_with("["):
			in_plugin = line == "[plugin]"
			continue
		if not in_plugin or line == "" or line.begins_with(";") or not "=" in line:
			continue
		keys[line.get_slice("=", 0).strip_edges()] = line.substr(line.find("=") + 1).strip_edges()
	return keys


static func unquote(value:String) -> String:
	if value.length() >= 2 and value[0] in ["\"", "'"] and value[-1] == value[0]:
		return value.substr(1, value.length() - 2)
	return value


## `host/owner/repo`, lowercased, `www.` and `.git` dropped - gdaddon's source.RepoID. scp-style
## remotes are accepted; a file:// url has no host, so it is keyed under `local/`.
static func repo_id_from_url(url:String) -> String:
	url = url.strip_edges()
	var host = ""
	var path = ""
	if url.begins_with("file://"):
		host = "local"
		path = url.trim_prefix("file://")
	elif "://" in url:
		var rest = url.get_slice("://", 1)
		host = rest.get_slice("/", 0)
		path = rest.substr(host.length())
	elif "@" in url and ":" in url:
		host = url.get_slice("@", 1).get_slice(":", 0)
		path = url.get_slice(":", 1)
	else:
		return ""
	host = host.get_slice("@", host.get_slice_count("@") - 1).trim_prefix("www.")

	var parts = Array(path.lstrip("/").rstrip("/").split("/", false))
	if parts.size() < 2:
		return ""
	if host == "local":
		parts = parts.slice(parts.size() - 2) # keep it short; the full path is still the clone url
	return ("%s/%s/%s" % [host, parts[0], String(parts[1]).trim_suffix(".git")]).to_lower()

#endregion


#region Versions

## Dotted numeric parts with a leading v and -pre/+build suffix dropped, or [] when not a version.
## The suffix is only stripped after a dot, so a date like 2024-01-02 stays incomparable.
static func version_parts(v:String) -> Array[int]:
	var out:Array[int] = []
	v = v.strip_edges().trim_prefix("v").trim_prefix("V")
	var cut = -1
	for i in v.length():
		if v[i] in ["-", "+"]:
			cut = i
			break
	if cut >= 0 and "." in v.substr(0, cut):
		v = v.substr(0, cut)
	if v == "":
		return out
	for p in v.split("."):
		p = p.strip_edges()
		if not p.is_valid_int():
			return [] as Array[int]
		out.append(p.to_int())
	return out


## 1 / 0 / -1, or TAGS_INCOMPARABLE when either side isn't a version. Missing parts count as 0.
static func compare_tags(a:String, b:String) -> int:
	var na = version_parts(a)
	var nb = version_parts(b)
	if na.is_empty() or nb.is_empty():
		return TAGS_INCOMPARABLE
	for i in maxi(na.size(), nb.size()):
		var x = na[i] if i < na.size() else 0
		var y = nb[i] if i < nb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0

#endregion


#region Resolve

## Lock for a target at `version`: {target: Entry, deps: [Entry]}, deps sorted by repo_id, where
## Entry = {repo_id, url, tag, sha, kind, asset, package, path, source, verify}. Returns {} and
## fills `errors` on any failure - a partial lock would silently export whatever the dev tree had.
## `target_url` must be the canonical origin: ids come from it, so deps naming the target still
## match it even when url_overrides fetches it from somewhere else. The target is always source.
func resolve(target_url:String, version:String, target_path:String) -> Dictionary:
	errors.clear()
	_packages.clear()
	_requires_cache.clear()
	var root_id = repo_id_from_url(target_url)
	var root_url = url_overrides.get(root_id, target_url)
	var root_tag = _find_tag(root_url, version, KIND_SOURCE, target_url)
	if root_tag == "":
		_error("%s: no tag for version %s (tried %s)%s" % [root_id, version, ", ".join(tag_candidates(version)), _fetch_note()])
		return {}
	var root_pkg = _package(root_id, root_url, root_tag, KIND_SOURCE, target_url, target_path)
	if root_pkg.has("error"):
		_error("%s@%s: %s" % [root_id, root_tag, root_pkg.error])
		return {}
	if root_pkg.dest != target_path:
		_error("%s@%s: its addon installs at %s, but this project has it at %s" % [root_id, root_tag, root_pkg.dest, target_path])
		return {}
	var root = [root_id, root_url, root_tag, KIND_SOURCE, target_url]
	var root_requires = _requires(root, target_path)
	if root_requires.error != "":
		_error("%s@%s: %s" % [root_id, root_tag, root_requires.error])
		return {}

	var required = _explore(root, target_path)
	if not errors.is_empty():
		return {}
	var pruned = _prune(root, target_path, required)

	var deps = []
	for id in pruned.selected:
		var sel = pruned.selected[id]
		var pkg = _package(id, sel.url, sel.tag, sel.kind, sel.canonical)
		if pkg.has("error"):
			_error("%s@%s: %s (%s)" % [id, sel.tag, pkg.error, sel.chain])
			continue
		var reqs = _requires([id, sel.url, sel.tag, sel.kind, sel.canonical], "")
		if reqs.error != "":
			_error("%s@%s: %s (%s)" % [id, sel.tag, reqs.error, sel.chain])
			continue
		deps.append(_entry(id, pkg, pruned.verify.has(id)))
	if not errors.is_empty():
		return {}
	deps.sort_custom(func(a, b): return a.repo_id < b.repo_id)
	return {"target": _entry(root_id, root_pkg, false), "deps": deps}


## Walks every version any reachable config names, recording the highest per repo. Versions that
## lose still get walked: in MVS their requirements count toward the minimums too.
## A node is [id, url, tag, kind, canonical url].
func _explore(root:Array, root_path:String) -> Dictionary:
	var required = {} # repo_id -> {url, tag, kind, canonical, chain}
	var visited = {}
	var queue = [root + [root[0]]]
	while not queue.is_empty():
		var node = queue.pop_front()
		var key = "%s|%s@%s" % [node[3], node[0], node[2]]
		if visited.has(key):
			continue
		visited[key] = true

		for req in _requires(node, root_path if node[0] == root[0] else "").requires:
			var dep:Dep = req.dep
			if dep.repo_id == root[0]:
				continue
			var chain = "%s -> %s" % [node[5], dep.repo_id]
			if dep.tag == "":
				_error("untagged requirement (release exports need @tag): " + chain)
				continue
			var current = required.get(dep.repo_id)
			if current != null and current.kind != dep.kind:
				_error("%s is required as both %s and %s: %s; %s" % [dep.repo_id, current.kind, dep.kind, current.chain, chain])
				continue
			var url = url_overrides.get(dep.repo_id, dep.repo_url)
			var tag = _find_tag(url, dep.tag, dep.kind, dep.repo_url)
			if tag == "":
				_error("no usable tag %s%s: %s" % [dep.tag, _fetch_note(), chain])
				continue

			var entry = {"url": url, "tag": tag, "kind": dep.kind, "canonical": dep.repo_url, "chain": chain}
			if current == null:
				required[dep.repo_id] = entry
			else:
				var cmp = compare_tags(tag, current.tag)
				if cmp == TAGS_INCOMPARABLE and tag != current.tag:
					_error("can't order tags %s and %s of %s: %s" % [tag, current.tag, dep.repo_id, chain])
				elif cmp > 0:
					required[dep.repo_id] = entry
			queue.append([dep.repo_id, url, tag, dep.kind, dep.repo_url, chain])
	return required


## {selected, verify}: the repos reachable when every repo is taken at its selected tag (so a
## requirement only an outvoted version made isn't bundled), and which of them the compile check
## needs. A compile_require marks its target, and everything that target needs is needed too.
func _prune(root:Array, root_path:String, required:Dictionary) -> Dictionary:
	var selected = {}
	var edges = [] # [from id, to id, compile]
	var stack = [root]
	while not stack.is_empty():
		var node = stack.pop_back()
		for req in _requires(node, root_path if node[0] == root[0] else "").requires:
			var dep:Dep = req.dep
			if dep.repo_id == root[0] or not required.has(dep.repo_id):
				continue
			edges.append([node[0], dep.repo_id, req.compile])
			if selected.has(dep.repo_id):
				continue
			var sel = required[dep.repo_id]
			selected[dep.repo_id] = sel
			stack.append([dep.repo_id, sel.url, sel.tag, sel.kind, sel.canonical])

	var verify = {}
	var queue = []
	for e in edges:
		if e[2] and not verify.has(e[1]):
			verify[e[1]] = true
			queue.append(e[1])
	while not queue.is_empty():
		var id = queue.pop_back()
		for e in edges:
			if e[0] == id and not verify.has(e[1]):
				verify[e[1]] = true
				queue.append(e[1])
	return {"selected": selected, "verify": verify}


## {requires, error} from a node's located package's export config; no config means no
## requirements. A package that can't be located declares nothing here - that error is reported
## on its own if the version ends up selected.
func _requires(node:Array, default_dest:String) -> Dictionary:
	var pkg = _package(node[0], node[1], node[2], node[3], node[4], default_dest)
	if pkg.has("error"):
		return {"requires": [], "error": ""}
	var key = "%s|%s" % [pkg.info.id, pkg.src]
	if _requires_cache.has(key):
		return _requires_cache[key]
	var result = {"requires": [], "error": ""}
	for rel in ExportIgnore.candidates(pkg.src, CONFIG_NAMES):
		var text = fetcher.read_file(pkg.info, rel)
		if text != null:
			result = requires_in_export_config(text, rel.get_extension(), _cfg_text(pkg.info, pkg.src))
			if result.error != "":
				result.error = "%s: %s" % [rel, result.error]
			break
	_requires_cache[key] = result
	return result


## {info, src, dest} for a repo at a tag, or {error}. `default_dest` lets the target's own root cfg
## go without path=, since where it installs is already known.
func _package(id:String, url:String, tag:String, kind:String, canonical:String, default_dest:String = "") -> Dictionary:
	var key = "%s|%s|%s" % [kind, url, tag]
	if _packages.has(key):
		return _packages[key]
	var result = {}
	var info = fetcher.lookup(url, tag, kind, canonical)
	if info.is_empty():
		result = {"error": "could not be fetched%s" % _fetch_note()}
	else:
		var cfg_value = func(dir:String, cfg_key:String) -> String:
			return unquote(plugin_section(_cfg_text(info, dir)).get(cfg_key, ""))
		var located = PackageLayout.locate(fetcher.files(info), id, cfg_value, repo_id_from_url, default_dest)
		result = located if located.has("error") else {"info": info, "src": located.src, "dest": located.dest}
	_packages[key] = result
	return result


func _cfg_text(info:Dictionary, dir:String) -> String:
	var key = "%s|%s" % [info.id, dir]
	if _cfg_texts.has(key):
		return _cfg_texts[key]
	var text = ""
	for nm in CFG_NAMES:
		var found = fetcher.read_file(info, dir.path_join(nm) if dir != "" else nm)
		if found != null:
			text = found
			break
	_cfg_texts[key] = text
	return text


func _entry(id:String, pkg:Dictionary, verify:bool) -> Dictionary:
	var info = pkg.info
	return {
		"repo_id": id,
		"url": info.url,
		"tag": info.tag,
		"sha": info.id,
		"kind": info.kind,
		"asset": info.get("asset", ""),
		"package": pkg.src,
		"path": pkg.dest,
		"source": "local" if url_overrides.get(id) == info.url else "remote",
		"verify": verify,
	}


## The dep's own spelling first, then with the leading v toggled - gdaddon's tagEqual.
func _find_tag(url:String, want:String, kind:String, canonical:String) -> String:
	for candidate in tag_candidates(want):
		if not fetcher.lookup(url, candidate, kind, canonical).is_empty():
			return candidate
	return ""


static func tag_candidates(want:String) -> Array:
	var bare = want.trim_prefix("v")
	var toggled = bare if want.begins_with("v") else "v" + bare
	return [want, toggled]


func _fetch_note() -> String:
	var err = fetcher.get("last_error")
	return " (%s)" % err if err is String and err != "" else ""


func _error(message:String) -> void:
	errors.append(message)

#endregion


#region Dev project

## repo_id -> res:// dir for every git checkout under addons_dir, keyed by its origin remote.
## Nested repos go deep here (addons/addon_lib/gdsh_lib/utils), hence the generous default.
static func scan_dev_repos(addons_dir:String = "res://addons", max_depth:int = 6) -> Dictionary:
	var out = {}
	_scan_dev_repos(addons_dir, max_depth, out)
	return out


static func _scan_dev_repos(dir:String, depth:int, out:Dictionary) -> void:
	if depth <= 0:
		return
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with(".") or ExportIgnore.is_name(sub):
			continue
		var path = dir.path_join(sub)
		var git_path = path.path_join(".git")
		if DirAccess.dir_exists_absolute(git_path) or FileAccess.file_exists(git_path):
			var url = origin_url(path)
			var id = repo_id_from_url(url)
			if id != "" and not out.has(id):
				out[id] = path
		_scan_dev_repos(path, depth - 1, out)


static func origin_url(dir:String) -> String:
	var output = []
	var code = OS.execute("git", ["-C", ProjectSettings.globalize_path(dir), "remote", "get-url", "origin"], output)
	return "".join(output).strip_edges() if code == 0 else ""


## Whether a checkout already carries one of the tag's spellings locally. False for a dir that is no
## checkout at all, so a caller has to know which case it is in before reporting one.
static func local_tag_exists(dir:String, tag:String) -> bool:
	for candidate in tag_candidates(tag):
		var output = []
		var code = OS.execute("git", ["-C", ProjectSettings.globalize_path(dir), "tag", "--list", candidate], output)
		if code == 0 and "".join(output).strip_edges() != "":
			return true
	return false


## Stable hash of a lock, used to key reusable workspaces.
static func lock_hash(lock:Dictionary) -> String:
	return JSON.stringify(lock, "", true).sha256_text().substr(0, 16)

#endregion
