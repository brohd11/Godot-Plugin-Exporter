@tool
extends RefCounted
## Resolves an addon's `deps`/`require` graph to pinned tags for a release export. Versions are
## picked Go-MVS style: each repo gets the highest tag any reachable requirement names. Parsing
## mirrors gdaddon (internal/addon/deps.go, source/parse.go) so both tools read a cfg the same way.
## Repo access goes through `fetcher` (RepoCache, or a fake in tests): tag_sha / read_file.

const DEFAULT_HOST = "github.com"
const CFG_NAMES = ["plugin.cfg", "version.cfg"]
const TAGS_INCOMPARABLE = -99

class Dep:
	var host:String
	var owner:String
	var repo:String
	var tag:String
	var repo_url:String
	var repo_id:String

var fetcher
var dev_paths:Dictionary = {} # repo_id -> res:// install dir, used when a cfg has no path=
var url_overrides:Dictionary = {} # repo_id -> clone url, e.g. a file:// mirror
var errors:Array[String] = []

var _cfg_cache:Dictionary = {} # "url@tag" -> cfg text, or null when the tag has none


func _init(fetcher_obj, dev_install_paths:Dictionary = {}, overrides:Dictionary = {}) -> void:
	fetcher = fetcher_obj
	dev_paths = dev_install_paths
	url_overrides = overrides


#region Parsing

## `owner/repo[@tag]` or `host/owner/repo[@tag]`; null for any other shape.
static func parse_dep(item:String) -> Dep:
	item = item.strip_edges()
	var repo_part = item
	var tag = ""
	var at = item.rfind("@")
	if at >= 0:
		repo_part = item.substr(0, at)
		tag = item.substr(at + 1).strip_edges()

	var parts = repo_part.lstrip("/").rstrip("/").split("/")
	var dep = Dep.new()
	if parts.size() == 2:
		dep.host = DEFAULT_HOST
		dep.owner = parts[0]
		dep.repo = parts[1]
	elif parts.size() == 3:
		dep.host = parts[0]
		dep.owner = parts[1]
		dep.repo = parts[2]
	else:
		return null
	if dep.owner == "" or dep.repo == "":
		return null

	dep.tag = tag
	dep.repo_url = "https://%s/%s/%s" % [dep.host, dep.owner, dep.repo]
	dep.repo_id = repo_id_from_url(dep.repo_url)
	return dep


## Godot-style `["a/b@v1", 'c/d']` list; malformed items are skipped, not fatal.
static func parse_dep_list(raw:String) -> Array[Dep]:
	var out:Array[Dep] = []
	raw = raw.strip_edges().trim_prefix("[").trim_suffix("]")
	for item in raw.split(","):
		item = item.strip_edges().lstrip("\"'").rstrip("\"'").strip_edges()
		if item == "":
			continue
		var dep = parse_dep(item)
		if dep != null:
			out.append(dep)
	return out


## `require` wins over `deps` whenever the key is present, even when empty.
static func deps_in_cfg_text(text:String) -> Array[Dep]:
	var keys = plugin_section(text)
	var key = "require" if keys.has("require") else "deps"
	return parse_dep_list(keys.get(key, ""))


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
	var owner = parts[0] if host != "local" else parts[0]
	var repo = (parts[1] if host != "local" else parts[1]).trim_suffix(".git")
	return ("%s/%s/%s" % [host, owner, repo]).to_lower()

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
## Entry = {repo_id, url, tag, sha, path, source}. Returns {} and fills `errors` on any failure - a
## partial lock would silently export whatever the dev tree had for the missing parts.
## `target_url` must be the canonical origin: ids come from it, so deps naming the target still
## match it even when url_overrides fetches it from somewhere else.
func resolve(target_url:String, version:String, target_path:String) -> Dictionary:
	errors.clear()
	var root_id = repo_id_from_url(target_url)
	var root_url = url_overrides.get(root_id, target_url)
	var root_tag = _find_tag(root_url, version)
	if root_tag == "":
		_error("%s: no tag for version %s (tried %s)%s" % [root_id, version, ", ".join(_tag_candidates(version)), _fetch_note()])
		return {}
	if _read_cfg(root_url, root_tag) == null:
		_error("%s@%s: no plugin.cfg or version.cfg at that tag" % [root_id, root_tag])
		return {}

	var required = _explore(root_id, root_url, root_tag)
	if not errors.is_empty():
		return {}
	var selected = _prune(root_id, root_url, root_tag, required)

	var deps = []
	for id in selected:
		var sel = selected[id]
		var path = _install_path(id, sel.url, sel.tag)
		if path == "":
			_error("%s@%s: no install path - add path=\"addons/...\" to its cfg, or keep a checkout of it in this project" % [id, sel.tag])
			continue
		deps.append(_entry(id, sel.url, sel.tag, path))
	if not errors.is_empty():
		return {}
	deps.sort_custom(func(a, b): return a.repo_id < b.repo_id)

	return {
		"target": _entry(root_id, root_url, root_tag, target_path),
		"deps": deps,
	}


## Walks every version any reachable cfg names, recording the highest per repo. Versions that lose
## still get walked: in MVS their requirements count toward the minimums too.
func _explore(root_id:String, root_url:String, root_tag:String) -> Dictionary:
	var required = {} # repo_id -> {url, tag}
	var visited = {}
	var queue = [[root_id, root_url, root_tag, root_id]]
	while not queue.is_empty():
		var node = queue.pop_front()
		var key = "%s@%s" % [node[0], node[2]]
		if visited.has(key):
			continue
		visited[key] = true

		var text = _read_cfg(node[1], node[2])
		if text == null:
			continue # a library with no cfg declares nothing
		for dep:Dep in deps_in_cfg_text(text):
			if dep.repo_id == root_id:
				continue
			var chain = "%s -> %s" % [node[3], dep.repo_id]
			if dep.tag == "":
				_error("untagged requirement (release exports need @tag): " + chain)
				continue
			var url = url_overrides.get(dep.repo_id, dep.repo_url)
			var tag = _find_tag(url, dep.tag)
			if tag == "":
				_error("tag %s not found%s: %s" % [dep.tag, _fetch_note(), chain])
				continue

			var current = required.get(dep.repo_id)
			if current == null:
				required[dep.repo_id] = {"url": url, "tag": tag}
			else:
				var cmp = compare_tags(tag, current.tag)
				if cmp == TAGS_INCOMPARABLE and tag != current.tag:
					_error("can't order tags %s and %s of %s: %s" % [tag, current.tag, dep.repo_id, chain])
				elif cmp > 0:
					required[dep.repo_id] = {"url": url, "tag": tag}
			queue.append([dep.repo_id, url, tag, chain])
	return required


## Keeps only repos reachable when every repo is taken at its selected tag, so a requirement that
## only an outvoted version made doesn't get bundled.
func _prune(root_id:String, root_url:String, root_tag:String, required:Dictionary) -> Dictionary:
	var selected = {}
	var stack = [[root_url, root_tag]]
	while not stack.is_empty():
		var node = stack.pop_back()
		var text = _read_cfg(node[0], node[1])
		if text == null:
			continue
		for dep:Dep in deps_in_cfg_text(text):
			if dep.repo_id == root_id or selected.has(dep.repo_id) or not required.has(dep.repo_id):
				continue
			selected[dep.repo_id] = required[dep.repo_id]
			stack.append([required[dep.repo_id].url, required[dep.repo_id].tag])
	return selected


func _entry(id:String, url:String, tag:String, path:String) -> Dictionary:
	var source = "local" if url_overrides.get(id) == url else "remote"
	return {"repo_id": id, "url": url, "tag": tag, "sha": fetcher.tag_sha(url, tag), "path": path, "source": source}


func _install_path(id:String, url:String, tag:String) -> String:
	var text = _read_cfg(url, tag)
	if text != null:
		var path = unquote(plugin_section(text).get("path", "")).strip_edges()
		if path != "":
			return path if path.begins_with("res://") else "res://" + path.lstrip("/")
	return dev_paths.get(id, "")


## The dep's own spelling first, then with the leading v toggled - gdaddon's tagEqual.
func _find_tag(url:String, want:String) -> String:
	for candidate in _tag_candidates(want):
		if fetcher.tag_sha(url, candidate) != "":
			return candidate
	return ""


static func _tag_candidates(want:String) -> Array:
	var bare = want.trim_prefix("v")
	var toggled = bare if want.begins_with("v") else "v" + bare
	return [want, toggled]


func _read_cfg(url:String, tag:String):
	var key = "%s@%s" % [url, tag]
	if _cfg_cache.has(key):
		return _cfg_cache[key]
	var text = null
	for nm in CFG_NAMES:
		text = fetcher.read_file(url, tag, nm)
		if text != null:
			break
	_cfg_cache[key] = text
	return text


func _fetch_note() -> String:
	var err = fetcher.get("last_error")
	return " (%s)" % err if err is String and err != "" else ""


func _error(message:String) -> void:
	errors.append(message)

#endregion


#region Dev project

## repo_id -> res:// dir for every git checkout under addons_dir, keyed by its origin remote.
## Nested repos (addons/addon_lib/*) are why this descends a few levels instead of one.
static func scan_dev_repos(addons_dir:String = "res://addons", max_depth:int = 3) -> Dictionary:
	var out = {}
	_scan_dev_repos(addons_dir, max_depth, out)
	return out


static func _scan_dev_repos(dir:String, depth:int, out:Dictionary) -> void:
	if depth <= 0:
		return
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with(".") or sub == "export_ignore":
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


## Stable hash of a lock, used to key reusable workspaces.
static func lock_hash(lock:Dictionary) -> String:
	return JSON.stringify(lock, "", true).sha256_text().substr(0, 16)

#endregion
