## `#!` tag handlers for the dependency scan. Registered on a Dependencies instance with
## add_tag_handler(), which documents the handler contract - a Callable taking one context
## dict and returning the metadata to hang on the edges it emits.

## Tag name without the "#!" prefix, the form add_tag_handler() takes.
const TAG = "dependency"
## The key the handler hangs on the edges it emits; parse_base maps it onto the export dict's
## own key. Naming it here rather than reaching for KeysData is what leaves this file
## with no imports, so registering the handler cannot pull the export pipeline in behind it.
const DIR_KEY = "dir"


## `#! dependency [dir]` - marks a path on the line as a dependency and optionally names the
## directory it should land in. "current" places the file beside the one declaring it, anything
## else is read as a directory; see export_obj.get_file_dependencies().
static func dependency_dir() -> Callable:
	return func(ctx:Dictionary) -> Variant:
		if ctx.raws.is_empty():
			return null
		var value:String = ctx.value
		# The path may sit after the tag (`#! dependency "res://x.png" assets`) - drop it,
		# it is already in raws, and keep what follows as the directory.
		if value.begins_with('"') or value.begins_with("'"):
			var end = value.find(value[0], 1)
			value = value.substr(end + 1) if end > -1 else ""
		value = value.strip_edges()
		if value == "":
			return {}
		return {DIR_KEY: value}
