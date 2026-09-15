extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"
## `#! struct` - a tagged data-only class exports as a plain Array: its fields become an unnamed
## enum plus a static create(), constructors become array literals, type hints become Array and field
## reads index with the enum. Planned against source files in pre_export, where a failure can still
## abort the export, and replayed onto the export's copies. Text work: struct/struct_rewrite.gd.

const TAG = "struct"
const TagRegistry = UtilsLocal.TagRegistry
const StructRewrite = preload("res://addons/plugin_exporter/src/class/export/parse/gd/struct/struct_rewrite.gd")
const StructTypes = preload("res://addons/plugin_exporter/src/class/export/parse/gd/struct/struct_types.gd")
const GDScriptParser = UtilsRemote.GDScriptParser

const INJECT_HEADER = "### Plugin Exporter Structs"

## {files_to_copy key: {ops, bodies:[{class_path, start, end, expect, lines}], injected:{name: {key, tail}}}}
var _plans:Dictionary = {}
## Shared by this export's parsers, so a script parsed for one file's lookups is reused by the next.
var _parser_cache:Dictionary = {}


func pre_export() -> void:
	_plans.clear()
	_parser_cache.clear()
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
			def.key = key
			export_obj.structs[entry.identity] = def
	if _fail(errors) or export_obj.structs.is_empty():
		return

	var reach = _struct_reach(sources.values())
	for key in sources:
		var plan = _plan_file(sources[key], reach.has(sources[key]), errors)
		if not plan.is_empty():
			_plans[key] = plan
	_fail(errors)


## Field access and the flow check first, on the source text the parser sees; then phase-1 sites on
## that result, while line indexes still match; then each struct body here, bottom first.
func _plan_file(source:String, reachable:bool, errors:Array) -> Dictionary:
	var lines = FileAccess.get_file_as_string(source).split("\n")
	var owners = []
	TagRegistry.scan_lines(lines, source, owners)
	var script = load(source) as GDScript
	var cache = {}
	var names = {} # class path -> how this file already spells it at file scope
	var resolve = func(head:String, line:int) -> String:
		var found = _resolve(script, source, owners, head, line, cache)
		if found != "" and not names.has(found) and line < owners.size() and owners[line] == source:
			names[found] = head
		return found

	var ops = {}
	var injected = {}
	var sites = lines
	if reachable:
		StructRewrite.rewrite_lines(lines, resolve, export_obj.structs) # only fills `names`
		var types = StructTypes.new(GDScriptParser, source, export_obj.structs, _parser_cache)
		for err in StructRewrite.check_flow(lines, types.type_of, types.raw_type, types.return_path, types.params):
			errors.append("%s %s" % [source, err])
		var name_for = func(path:String) -> String:
			if not names.has(path):
				names[path] = _injection(path, lines, injected)
			return names[path]
		var access = StructRewrite.rewrite_access(lines, types.type_of, export_obj.structs, name_for)
		ops = access.ops
		sites = access.lines

	var result = StructRewrite.rewrite_lines(sites, resolve, export_obj.structs)
	for err in result.errors:
		errors.append("%s %s" % [source, err])
	for line in result.ops:
		ops.get_or_add(line, []).append_array(result.ops[line])

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

	if ops.is_empty() and bodies.is_empty() and injected.is_empty():
		return {}
	return {"ops": ops, "bodies": bodies, "injected": injected}


## Files whose references reach a struct script. Only these can hold a value the parser types as a
## struct - a type travels through preloads, extends and global classes - so only these are parsed.
func _struct_reach(roots:Array) -> Dictionary:
	var class_list:Dictionary = export_obj.export_data.class_list
	var refs = {}
	var queue = roots.duplicate()
	while not queue.is_empty():
		var path:String = queue.pop_back()
		if refs.has(path) or path.get_extension() != "gd" or not FileAccess.file_exists(path):
			continue
		var out = []
		for edge in scan_direct_edges(path):
			if edge.to != "":
				out.append(edge.to)
		var globals:Dictionary = ExportFileUtils._get_global_classes_in_file(path, class_list)
		globals.erase("global_class_definition")
		for cls in globals:
			if class_list.has(cls):
				out.append(class_list[cls])
		refs[path] = out
		queue.append_array(out)

	var reach = {}
	for def in export_obj.structs.values():
		reach[def.file] = true
	var changed = true
	while changed:
		changed = false
		for path in refs:
			if reach.has(path):
				continue
			for target in refs[path]:
				if reach.has(target):
					reach[path] = true
					changed = true
					break
	return reach


## How a file that never spells a struct reaches its enum: a global class name that survives the
## export is used as is, anything else gets a const preload appended to the file.
func _injection(path:String, lines:PackedStringArray, injected:Dictionary) -> String:
	var def:Dictionary = export_obj.structs[path]
	var tail = path.substr(def.file.length() + 1) if path.length() > def.file.length() else ""
	var base:String
	if tail != "":
		base = tail.get_slice(".", tail.get_slice_count(".") - 1)
	else:
		var global_name:String = export_obj.export_data.class_path_lookup.get(def.file, "")
		if global_name != "" and not export_obj.class_renames.has(global_name):
			return global_name
		base = global_name if global_name != "" else def.file.get_file().get_basename().to_pascal_case()

	var text = "\n".join(lines)
	var const_name = base
	var n = 1
	while injected.has(const_name) or get_class_token_regex(const_name).search(text) != null:
		const_name = "%sStruct%s" % [base, "" if n == 1 else str(n)]
		n += 1
	injected[const_name] = {"key": def.key, "tail": tail}
	return const_name


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

	if not plan.injected.is_empty():
		var const_names = plan.injected.keys()
		const_names.sort() # the same export twice writes the same file
		file_lines.append("")
		file_lines.append(INJECT_HEADER)
		for const_name in const_names:
			var inj = plan.injected[const_name]
			var line = 'const %s = preload("%s")' % [const_name, get_adjusted_path_or_old_renamed(inj.key)]
			if inj.tail != "":
				line += "." + inj.tail
			file_lines.append(line)
	return file_lines


func _fail(errors:Array) -> bool:
	if errors.is_empty():
		return false
	for err in errors:
		printerr("Plugin Exporter - #! struct - " + err)
	export_obj.invalidate()
	return true
