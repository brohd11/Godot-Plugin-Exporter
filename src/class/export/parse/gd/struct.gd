extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"
## `#! struct` - a tagged data-only class exports as a plain Array: its fields become an unnamed
## enum plus a static create(), constructors become array literals and type hints become Array.
## Planned against source files in pre_export, where a failure can still abort the export, and
## replayed onto the export's copies. The text work lives in struct/struct_rewrite.gd.

const TAG = "struct"
const TagRegistry = UtilsLocal.TagRegistry
const StructRewrite = preload("res://addons/plugin_exporter/src/class/export/parse/gd/struct/struct_rewrite.gd")

## {files_to_copy key: {ops, bodies:[{class_path, start, end, expect, lines}]}}
var _plans:Dictionary = {}


func pre_export() -> void:
	_plans.clear()
	export_obj.structs.clear()
	var registry:TagRegistry = export_obj.export_data.tag_registry

	var sources = {} # files_to_copy key -> the file actually copied
	for key:String in export_obj.files_to_copy:
		var source:String = export_obj.files_to_copy[key].get(KeysData.REPLACE_WITH, key)
		if source.get_extension() == "gd":
			sources[key] = source
	registry.scan_files(sources.values())

	var errors = []
	for key in sources:
		var source:String = sources[key]
		for entry:Dictionary in registry.get_file_entries(source):
			if entry.tag != TAG:
				continue
			if entry.attach == TagRegistry.ATTACH_LINE or entry.identity.contains(TagRegistry.MEMBER_DELIM):
				errors.append("%s:%d: put #! struct on its own line above a class" % [source, entry.line + 1])
				continue
			var lines = FileAccess.get_file_as_string(source).split("\n")
			var def = StructRewrite.parse_def(lines, entry.target, entry.attach == TagRegistry.ATTACH_FILE, entry.identity)
			for err in def.errors:
				errors.append("%s %s" % [source, err])
			def.file = source
			export_obj.structs[entry.identity] = def
	if _fail(errors) or export_obj.structs.is_empty():
		return

	for key in sources:
		var plan = _plan_file(sources[key], errors)
		if not plan.is_empty():
			_plans[key] = plan
	_fail(errors)


## Sites are rewritten on the whole file first, while line indexes still match the source, then
## each struct body here is swapped for its generated form, bottom first.
func _plan_file(source:String, errors:Array) -> Dictionary:
	var lines = FileAccess.get_file_as_string(source).split("\n")
	var owners = []
	TagRegistry.scan_lines(lines, source, owners)
	var script = load(source) as GDScript
	var cache = {}
	var resolve = func(head:String, line:int) -> String:
		return _resolve(script, source, owners, head, line, cache)

	var result = StructRewrite.rewrite_lines(lines, resolve, export_obj.structs)
	for err in result.errors:
		errors.append("%s %s" % [source, err])

	var bodies = []
	for def:Dictionary in export_obj.structs.values():
		if def.file != source:
			continue
		var body_resolve = func(head:String, _line:int) -> String:
			return resolve.call(head, def.body_start)
		var body = StructRewrite.rewrite_lines(StructRewrite.build_body(def), body_resolve, export_obj.structs)
		bodies.append({
			"class_path": def.class_path, "start": def.body_start, "end": def.body_end,
			"expect": result.lines[def.body_start], "lines": body.lines,
		})
	bodies.sort_custom(func(a, b): return a.start > b.start)

	if result.ops.is_empty() and bodies.is_empty():
		return {}
	return {"ops": result.ops, "bodies": bodies}


## An unqualified name is tried as an inner class from the innermost enclosing class outward, as
## GDScript scopes it; anything else goes through the script's consts and the global classes.
func _resolve(script:GDScript, source:String, owners:Array, head:String, line:int, cache:Dictionary) -> String:
	var owner:String = owners[line] if line >= 0 and line < owners.size() else source
	var cache_key = owner + "|" + head
	if cache.has(cache_key):
		return cache[cache_key]

	var found = ""
	var scope = owner
	while true:
		if export_obj.structs.has(scope + "." + head):
			found = scope + "." + head
			break
		if scope.length() <= source.length():
			break
		scope = scope.substr(0, scope.rfind("."))
	if found == "" and script != null:
		var resolved = UClassDetail.resolve_script_access_path(script, head)
		if resolved is String and export_obj.structs.has(resolved):
			found = resolved
	cache[cache_key] = found
	return found


func post_export_edit_file(file_path:String, file_lines:Variant=null) -> Variant:
	var plan = _plans.get(export_obj.file_parser.current_file_path_parsing)
	if plan == null:
		return file_lines
	if file_lines == null:
		file_lines = Array(FileAccess.get_file_as_string(file_path).split("\n"))

	for err in StructRewrite.apply_ops(file_lines, plan.ops):
		printerr("Plugin Exporter - #! struct - %s %s" % [file_path, err])
	for body in plan.bodies:
		if body.start >= file_lines.size() or file_lines[body.start] != body.expect:
			printerr("Plugin Exporter - #! struct - %s: could not find the body of %s, left as a class" % [file_path, body.class_path])
			continue
		var edited = file_lines.slice(0, body.start)
		edited.append_array(body.lines)
		edited.append_array(file_lines.slice(body.end + 1))
		file_lines = edited
	return file_lines


func _fail(errors:Array) -> bool:
	if errors.is_empty():
		return false
	for err in errors:
		printerr("Plugin Exporter - #! struct - " + err)
	export_obj.invalidate()
	return true
