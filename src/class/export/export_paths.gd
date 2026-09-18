@tool
extends RefCounted
## Rules for the paths an export config names. No preloads, so the export pipeline, release code
## and headless tests can all share it without dragging each other in.

const DEFAULT_BASE = "res://addons"


## Command targets are addon-relative unless absolute. Only project resources can be exported.
## Empty means invalid; existence is checked by the caller so discovery and init can share this.
static func resolve_target(raw:String) -> String:
	var path = raw.strip_edges().replace("\\", "/")
	if path == "" or ("://" in path and not path.begins_with("res://")):
		return ""
	if not path.is_absolute_path():
		path = DEFAULT_BASE.path_join(path)
	var absolute = ProjectSettings.globalize_path(path).simplify_path()
	var root = ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	if absolute != root and not absolute.begins_with(root + "/"):
		return ""
	return ProjectSettings.localize_path(absolute).trim_suffix("/") if absolute != root else "res://"


## A flat, collision-resistant cache name independent of how the caller spelled the target.
static func workspace_key(target:String) -> String:
	var path = resolve_target(target)
	if path == "":
		return ""
	return path.trim_suffix("/").get_file().validate_filename() + "-" + path.sha256_text().left(12)


## Why a configured export_folder can't be an install path, or "" when it can (empty means source).
## Takes the raw value, since a {{...}} template there is the old "<package>/<folder>" form.
static func export_folder_error(raw:String) -> String:
	var path = raw.strip_edges().trim_prefix("res://")
	if path.begins_with("/") or (path.length() > 1 and path[1] == ":"):
		return "is an absolute path"
	if ".." in path.split("/"):
		return "leaves the project"
	if "{{" in path:
		return "contains a {{...}} template - old \"<package>/<folder>\" form? move the package part to export_name"
	return ""
