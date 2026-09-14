@tool
extends RefCounted
## One view of a dependency at a tag, however it is fetched. `source` is the git tree at the tag
## (RepoCache). `auto` is what gdaddon would install: the release's single uploaded asset
## (ReleaseCache), or the tree when the tag has no release or the release uploaded nothing.
## lookup() returns the info the other calls take; lock entries carry the same keys.

var repos # RepoCache
var releases # ReleaseCache
var root:String
var last_error:String = ""

var _lookups:Dictionary = {}


func _init(repo_cache, release_cache) -> void:
	repos = repo_cache
	releases = release_cache
	root = repo_cache.root


## {kind: "source"|"release", url, tag, id, asset} for a tag that can be fetched, or {} with
## last_error set. `canonical_url` is the repo's real remote - a --local checkout url can't be
## asked about GitHub releases, so releases always come from the remote.
func lookup(url:String, tag:String, kind:String, canonical_url:String) -> Dictionary:
	var key = "%s|%s|%s" % [kind, url, tag]
	if _lookups.has(key):
		return _lookups[key]
	var info = {}
	if kind != "source":
		var rel = releases.lookup(canonical_url, tag)
		if rel.state == "error":
			last_error = releases.last_error
			return {}
		if rel.state == "asset":
			info = {"kind": "release", "url": canonical_url, "tag": tag, "id": rel.sha, "asset": rel.asset}
	if info.is_empty():
		var sha = repos.tag_sha(url, tag)
		if sha == "":
			last_error = repos.last_error
			return {}
		info = {"kind": "source", "url": url, "tag": tag, "id": sha, "asset": ""}
	_lookups[key] = info
	return info


## Every file path in the package, relative to its root.
func files(info:Dictionary) -> Array:
	if info.kind == "release":
		return releases.files(info.url, info.tag, info.asset)
	return repos.list_files(info.url, info.tag)


## A file's text, or null when the package has no such file.
func read_file(info:Dictionary, rel_path:String):
	if info.kind == "release":
		var dir = releases.stage(info.url, info.tag, info.asset)
		var path = dir.path_join(rel_path)
		return FileAccess.get_file_as_string(path) if dir != "" and FileAccess.file_exists(path) else null
	return repos.read_file(info.url, info.tag, rel_path)


## An absolute dir holding the whole package, extracted once and cached; "" with last_error set.
func stage(info:Dictionary) -> String:
	var release = info.get("kind") == "release"
	var dir = releases.stage(info.url, info.tag, info.asset) if release else repos.stage(info.url, info.tag)
	if dir == "":
		last_error = releases.last_error if release else repos.last_error
	return dir
