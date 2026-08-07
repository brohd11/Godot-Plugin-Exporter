extends RefCounted


const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")
const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd") #>remote
const UFile = UtilsRemote.UFile
const UString = UtilsRemote.UString
const URegex = UtilsRemote.URegex
const UClassDetail = UtilsRemote.UClassDetail
const ExportFileUtils = UtilsLocal.ExportFileUtils
const ExportFileKeys = ExportFileUtils.ExportFileKeys
const CompatData = UtilsLocal.CompatData
const DependencyTags = UtilsLocal.DependencyTags

const Dependencies = UtilsRemote.Dependencies
const DepEdge = Dependencies.DepEdge
const DepKind = DepEdge.Kind

## Edge kinds that mean "copy this file". LOAD is deliberately absent - a load() target
## compiles without the file, so it is only pulled in when tagged "#! dependency".
const DEP_KINDS = [DepKind.PRELOAD, DepKind.EXTENDS_PATH, DepKind.EXT_RESOURCE, DepKind.TAG]

const RES_LINE_TEMPLATE = '[ext_resource type="%s" path="%s" id="%s"]'

static var preload_regex:RegEx
static var _reduction_regexes:Dictionary = {}

var _string_regex:RegEx

var _dep_scanner
var _dep_scanner_export

var export_obj: UtilsLocal.ExportData.Export

func _init() -> void:
	preload_regex = UtilsRemote.URegex.get_preload_path()
	

func set_parse_settings(settings) -> void:
	pass

func get_direct_dependencies(file_path:String) -> Dictionary:
	var direct_dependencies = {}
	return direct_dependencies

## Direct references out of `file_path`, as DepEdges. Strings and comments are masked, uid and
## relative paths resolved, "#!" tags dispatched to their handler - so parsers no longer count
## quotes. Only one hop: file_parser.get_dependencies() drives the recursion.
func scan_direct_edges(file_path:String) -> Array:
	var scanner = _get_dep_scanner()
	scanner.roots = [file_path]
	var graph = scanner.get_graph()
	for edge in graph.unresolved:
		printerr('Unresolved reference "%s" in %s:%s' % [edge.raw, edge.from, edge.line_no])
	return graph.get_out_edges(file_path)

# One scanner per Export, reused across files by reassigning roots.
func _get_dep_scanner():
	if _dep_scanner == null or _dep_scanner_export != export_obj:
		var class_map = {}
		if export_obj != null and export_obj.reduce_access_paths:
			class_map = export_obj.export_data.class_list
		_dep_scanner = build_dep_scanner(class_map)
		_dep_scanner_export = export_obj
	return _dep_scanner

## `class_map` non-empty turns on access-path resolution: the scan then reports where a dotted
## path like "ALibRuntime.Utils.UFile" actually lands, which is what reduce_access_paths needs.
## Left empty, the scan does no global-class work at all - parse_gd's own pass owns that.
static func build_dep_scanner(class_map:Dictionary = {}):
	var scanner = Dependencies.new()
	# depth of 1, called per file, so only need direct dependencies for each
	scanner.max_depth = 1
	scanner.include_missing = false # a file that is not on disk must never reach files_to_copy
	scanner.use_project_classes = false # the export's own class list is the authority
	scanner.class_map = class_map
	scanner.resolve_access_paths = not class_map.is_empty()
	scanner.add_tag_handler(DependencyTags.TAG, DependencyTags.dependency_dir())
	return scanner

## Folds scanned edges into the legacy {path: {"dependency_dir"?: dir}} shape.
static func edges_to_dependencies(edges:Array, out:Dictionary) -> Dictionary:
	for edge in edges:
		if edge.to == "":
			continue
		# An access-path edge is a GLOBAL_CLASS/EXTENDS_CLASS kind, but unlike a bare class
		# reference it names a file the export has to copy in its own right - the hub the head
		# resolves to may not survive reduction. Bare ones stay parse_gd's business.
		if not DEP_KINDS.has(edge.kind) and not edge.meta.has(DepEdge.META_RESOLVED_FROM):
			continue
		var entry = out.get(edge.to)
		if entry == null:
			entry = {}
			out[edge.to] = entry
		# 'preload("x") #! dependency current' emits a PRELOAD and a TAG edge for the same
		# file, so the directory is only ever written - never cleared by whichever lands last.
		var dependency_dir = edge.meta.get(DependencyTags.DIR_KEY, "")
		if dependency_dir != "":
			entry[ExportFileKeys.dependency_dir] = dependency_dir
	return out

## What each dotted access path in a file reduces to: {expression: {name, path, tail}}.
## `name` is the segment that landed on a real file and becomes the injected const; `tail` is
## whatever the walk could not follow - an inner class, an enum, a plain const - and is kept on
## the end of the rewritten expression.
##
## Two kinds of expression are deliberately left alone:
##
## - one whose head is already the deepest file it names. Reducing
##   "FileSystemSingleton.FileData.FAVORITES_META" would rewrite it to itself, and the head is a
##   genuine use of that class rather than a pass-through.
## - one that walks through a file's own const preloads rather than a global class. A plugin's
##   "UtilsRemote.URegex" is its own deliberate indirection, which "#! remote" already rewrites
##   on export; only a global-class head can be the namespace hub this exists to get rid of.
static func edges_to_reductions(edges:Array, out:Dictionary) -> Dictionary:
	for edge in edges:
		var expression:String = edge.meta.get(DepEdge.META_RESOLVED_FROM, "")
		if expression == "" or edge.to == "" or out.has(expression):
			continue
		if not edge.meta.get(DepEdge.META_HEAD_FROM_CLASS_MAP, false):
			continue
		var consumed:int = edge.meta.get(DepEdge.META_CONSUMED, 0)
		if consumed < 2:
			continue
		var parts = expression.split(".", false)
		if consumed > parts.size():
			continue
		out[expression] = {
			"name": parts[consumed - 1],
			# the segment above it, the first fallback when two reductions want the same name
			"parent": parts[consumed - 2] if consumed >= 2 else "",
			"path": edge.to,
			"tail": Array(parts.slice(consumed)),
		}
	return out


## Matches an expression as a whole dotted token. The lookbehind keeps it off a longer chain
## that merely ends with it ("Other.ALibRuntime.Utils"), and the trailing boundary keeps
## "A.B.UFile" from matching inside "A.B.UFileWatcher".
static func get_reduction_regex(expression:String) -> RegEx:
	var regex = _reduction_regexes.get(expression)
	if regex == null:
		regex = RegEx.new()
		regex.compile("(?<![.\\w])%s\\b" % expression.replace(".", "\\."))
		_reduction_regexes[expression] = regex
	return regex


## The text a reduced expression becomes: the bound name, plus whatever the walk could not
## follow. "Hub.Utils.UProfile.TimeFunction" -> "UProfile.TimeFunction".
static func reduction_replacement(name:String, tail:Array) -> String:
	if tail.is_empty():
		return name
	return name + "." + ".".join(tail)

func pre_export() -> void:
	return

func post_export_edit_line(line:String) -> String:
	return line

func post_export_edit_file(file_path:String, file_lines:Variant=null) -> Variant:
	return file_lines

func _update_file_export_flags(line:String) -> String:
	return line

func get_adjusted_path_or_old_renamed(file_path:String) -> String:
	var new_path = export_obj.adjusted_remote_paths.get(file_path, file_path)
	new_path = export_obj.get_rel_or_absolute_path(new_path)
	if not export_obj.use_relative_paths:
		new_path = export_obj.get_renamed_path(new_path)
	return new_path

func _string_safe_regex_sub(line: String, processor: Callable) -> String:
	if not is_instance_valid(_string_regex):
		_string_regex = URegex.get_strings()
	line = URegex.string_safe_regex_sub(line, processor, _string_regex)
	return line
	
	var code_part = line
	var comment_part = ""
	var comment_pos = line.find("#")
	if comment_pos != -1:
		code_part = line.substr(0, comment_pos)
		comment_part = line.substr(comment_pos)
	
	# find all string matches and store values and positions
	var string_matches = _string_regex.search_all(code_part)
	var string_literals = []
	for _match in string_matches:
		string_literals.append(_match.get_string())
	
	# replace with placeholders by POSITION, iterating BACKWARDS
	var sanitized_code = code_part
	for i in range(string_matches.size() - 1, -1, -1):
		var _match = string_matches[i]
		var placeholder = "__STRING_PLACEHOLDER_%d__" % i
		# Reconstruct the string using the match's start and end positions
		sanitized_code = sanitized_code.left(_match.get_start()) + placeholder + sanitized_code.substr(_match.get_end())
	
	# call the provided callable on the sanitized code
	var converted_code = processor.call(sanitized_code)
	
	# restore strings
	var final_code = converted_code
	for i in range(string_literals.size()):
		var placeholder = "__STRING_PLACEHOLDER_%d__" % i
		final_code = final_code.replace(placeholder, string_literals[i])
	
	return final_code + comment_part


func file_extends_class(file_lines:Array, backport_target:=100) -> bool:
	var global_class_names = export_obj.export_data.class_list.keys()
	var extends_class = false
	for i in range(file_lines.size()):
		var line = file_lines[i]
		
		var _class = get_extended_class(line)
		if _class:
			if _class.find('"') > -1:
				extends_class = true
			else:
				if _class in global_class_names:
					extends_class = true
				elif _class not in ClassDB.get_class_list():
					extends_class = true
				if backport_target < 4:
					if _class in CompatData.COMPAT_CLASSES:
						extends_class = true
				
				break
	return extends_class

static func _check_for_comment(line, check_array) -> bool:
	if check_array is String:
		check_array = [check_array]
	var comment_index = line.find("#")
	if comment_index == -1:
		return false
	for text in check_array:
		var index = line.find(text)
		if index == -1:
			continue
		if comment_index < index:
			return true
	
	return false


static func _check_text_valid(line:String, to_check:String) -> bool:
	if line.begins_with("#"):
		return false
	var string_map = ExportFileUtils.get_string_map(line) as UString.StringMap
	var idx = line.find(to_check)
	if idx == -1:
		return false
	if string_map.string_mask[idx] == 1:
		return false
	var com_idx = string_map.get_comment_index(0)
	#var com_idx = string_map.comment_mask.find(1)
	if com_idx > -1 and com_idx < idx:
		return false
	return true


static func _strip_comment(line:String):
	var string_map = ExportFileUtils.get_string_map(line) as UString.StringMap
	#var com_idx = string_map.comment_mask.find(1)
	var com_idx = string_map.get_comment_index(0)
	if com_idx == -1:
		return line
	return line.substr(0, com_idx)


static func get_preload_path(line):
	if not is_instance_valid(preload_regex):
		preload_regex = UtilsRemote.URegex.get_preload_path()
	
	if not _check_text_valid(line, "preload("):
		return
	
	var _match = preload_regex.search(line)
	if _match:
		var file_path = _match.get_string(2)
		return file_path

static func _construct_pre(class_nm:String, path:String):
	var c = "const"
	var p = 'preload("%s")' % path
	var constructed = "%s %s = %s" % [c, class_nm, p]
	return constructed

static func get_extended_class(line:String):
	if not _check_text_valid(line, "extends"):
		return
	var _class = line.get_slice("extends ", 1).strip_edges()
	return _class

static func line_has_tag(line:String, tag:String, prefix:="#!") -> bool:
	var pre_idx = line.find(prefix)
	if pre_idx == -1:
		return false
	var tags = line.substr(pre_idx)
	return tags.find(tag) > -1
