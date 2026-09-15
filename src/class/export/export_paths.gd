@tool
extends RefCounted
## Rules for the paths an export config names. No preloads, so the export pipeline, release code
## and headless tests can all share it without dragging each other in.


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
