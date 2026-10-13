@tool
extends RefCounted
## The cfg that makes a dir a package, matching gdaddon: the first of NAMES found is the only one
## read. Package keys live in [plugin] or [addon]; [addon] wins key by key, so a plugin.cfg can keep
## Godot's own [plugin] keys and still carry package metadata. New keys go to [plugin] for now.

const NAMES = ["plugin.cfg", "addon.cfg", "version.cfg"]
const SECTIONS = ["addon", "plugin"] # precedence order
const DEFAULT_SECTION = "plugin"


## Path of the package cfg in `dir`, or "".
static func find(dir:String) -> String:
	for nm in NAMES:
		var path = dir.path_join(nm)
		if FileAccess.file_exists(path):
			return path
	return ""


static func has_cfg(dir:String) -> bool:
	return find(dir) != ""


## Raw `key=value` strings of the package sections, [addon] over [plugin]. Hand-read rather than
## ConfigFile, which rejects values gdaddon's ini reader accepts.
static func section(text:String) -> Dictionary:
	var by_section = _sections(text)
	var keys = {}
	for i in range(SECTIONS.size() - 1, -1, -1):
		keys.merge(by_section.get(SECTIONS[i], {}), true)
	return keys


## The section a write of `key` belongs in: the first in SECTIONS already holding it, else
## DEFAULT_SECTION.
static func key_section(text:String, key:String) -> String:
	var by_section = _sections(text)
	for s in SECTIONS:
		if by_section.get(s, {}).has(key):
			return s
	return DEFAULT_SECTION


static func get_value(cfg:ConfigFile, key:String, default = null):
	for s in SECTIONS:
		if cfg.has_section_key(s, key):
			return cfg.get_value(s, key)
	return default


## `key`'s value from `dir`'s package cfg, or `default` when there is no cfg, it won't parse, or
## neither section has the key.
static func dir_value(dir:String, key:String, default = null):
	var path = find(dir)
	if path == "":
		return default
	var cfg = ConfigFile.new()
	if cfg.load(path) != OK:
		return default
	return get_value(cfg, key, default)


static func _sections(text:String) -> Dictionary:
	var out = {}
	var current = ""
	for line in text.split("\n"):
		line = line.strip_edges()
		if line.begins_with("["):
			current = line.trim_prefix("[").trim_suffix("]").strip_edges()
			continue
		if not current in SECTIONS or line == "" or line.begins_with(";") or not "=" in line:
			continue
		if not out.has(current):
			out[current] = {}
		out[current][line.get_slice("=", 0).strip_edges()] = line.substr(line.find("=") + 1).strip_edges()
	return out
