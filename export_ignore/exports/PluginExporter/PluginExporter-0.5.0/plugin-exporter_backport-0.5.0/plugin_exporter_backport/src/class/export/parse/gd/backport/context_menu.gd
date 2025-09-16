extends "res://addons/plugin_exporter_backport/src/class/export/parse/parse_base.gd"

const PLUGIN_EXPORTER_TAG = "### PLUGIN EXPORTER CONTEXT BACKPORT"

const COMPAT_SING_NAME = "ContextPluginBackport"
const COMPAT_SING_PATH = "res://addons/plugin_exporter_backport/src/class/export/backport/context/context_backport.gd"

const COMPAT_CLASS_PATH = "res://addons/plugin_exporter_backport/src/class/export/backport/context/context_plugin_compat.gd"
const COMPAT_NAME = "EditorContextMenuPluginCompat"

const SLOT_ENUMS = {
	"EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE": 0,
	"EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM": 1,
	"EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR":2,
	"EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM_CREATE":3,
	"EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE": 4,
	"EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TABS": 5,
	"EditorContextMenuPlugin.CONTEXT_SLOT_2D_EDITOR": 6,
}

var backport_target := -1

var _method_regex:= RegEx.new()
var _slot_enum_regex:= RegEx.new()
var _context_menu_class_regex:= RegEx.new()

const METHOD_REPLACEMENT = "%s.$1" % COMPAT_SING_NAME

func _init() -> void:
	_string_regex = URegex.get_strings()
	
	var method_names = "add_context_menu_plugin|remove_context_menu_plugin"
	var pattern = "(?<!\\.)\\b(%s)\\b(?=\\s*\\()" % method_names
	_method_regex.compile(pattern)
	
	
	var escaped_keys = []
	for key in SLOT_ENUMS.keys():
		escaped_keys.append(URegex.escape_regex_meta_characters(key))
	var pattern_part = "|".join(escaped_keys)
	var full_pattern = "\\b(%s)\\b" % pattern_part
	_slot_enum_regex.compile(full_pattern)
	
	var _context_pattern = "\\b(%s)\\b" % "EditorContextMenuPlugin"
	_context_menu_class_regex.compile(_context_pattern)
	

# in parser_settings, create dictionary for extension of file,
# ie. if extension is foo, "parse_foo": {"my_setting": "value"}
func set_parse_settings(settings):
	backport_target = settings.get("backport_target", 100)

# logic to parse for files that are needed acts as a set, dependencies[my_dep_path] = {}
func get_direct_dependencies(file_path:String) -> Dictionary:
	var dependencies = {} 
	return dependencies

# runs right before export of files. Use for extension specific files.
func pre_export() -> void:
	pass

# first pass on post export, if the file ext is handle by default, file_lines will 
# contain modifies lines, for example, if you want to make a second pass on a gd file.
# If not handled by default, file_lines will be null. You can process and return the files lines
# or return the null value to default to the file's .
func post_export_edit_file(file_path:String, file_lines:Variant=null) -> Variant:
	if backport_target == 100:
		return file_lines
	
	var has_editor_context_plugin = false
	var is_editor_context_plugin = false
	var is_editor_plugin = false
	for i in range(file_lines.size()):
		var line = file_lines[i]
		if line.strip_edges() == "extends EditorContextMenuPlugin": # "" <- parser
			line = "extends %s" % COMPAT_NAME # "" <- parser
			file_lines[i] = line
			is_editor_context_plugin = true
		elif line.strip_edges() == "extends EditorPlugin": # "" <- parser
			is_editor_plugin = true
		elif line.find("EditorContextMenuPlugin") > -1:
			has_editor_context_plugin = true
	
	if is_editor_context_plugin:
		pass
	
	if is_editor_plugin:
		for i in range(file_lines.size()):
			var line = file_lines[i]
			var trimmed_line = line.strip_edges()
			if trimmed_line.begins_with("#") or trimmed_line.begins_with("func"):
				continue
			line = URegex.string_safe_regex_sub(line, _prefix_methods, _string_regex)
			file_lines[i] = line
		
	if is_editor_plugin or is_editor_context_plugin or has_editor_context_plugin:
		file_lines.append(PLUGIN_EXPORTER_TAG)
		var adj_sing_path = export_obj.adjusted_remote_paths.get(COMPAT_SING_PATH, COMPAT_SING_PATH)
		file_lines.append(_construct_pre(COMPAT_SING_NAME, adj_sing_path))
		var adj_compat_path = export_obj.adjusted_remote_paths.get(COMPAT_CLASS_PATH, COMPAT_CLASS_PATH)
		file_lines.append(_construct_pre(COMPAT_NAME, adj_compat_path))
		file_lines.append(PLUGIN_EXPORTER_TAG)
		file_lines.append("")
	
	
	return file_lines

# second pass of post export. If extension is handled by default, line will be 
# modified already. If changes were made in post_export_edit_file, these will be
# present here, else, it will be the unmodified line from the file.
func post_export_edit_line(line:String) -> String:
	line = URegex.string_safe_regex_sub(line, replace_slot_enums, _string_regex)
	line = URegex.string_safe_regex_sub(line, _replace_context_menu, _string_regex)
	return line



func _prefix_methods(line):
	return _method_regex.sub(line, METHOD_REPLACEMENT, true)

func replace_slot_enums(line: String) -> String:
	var matches: Array[RegExMatch] = _slot_enum_regex.search_all(line)
	
	if matches.is_empty():
		return line
	
	var new_line = line
	
	for i in range(matches.size() - 1, -1, -1):
		var _match: RegExMatch = matches[i]
		var key_found: String = _match.get_string(0)
		var value_to_sub = str(SLOT_ENUMS[key_found])
		
		var start_pos = _match.get_start(0)
		var end_pos = _match.get_end(0)
		
		new_line = new_line.substr(0, start_pos) + value_to_sub + new_line.substr(end_pos)
	
	return new_line

func _replace_context_menu(line:String):
	return _context_menu_class_regex.sub(line, COMPAT_NAME, true)

### PLUGIN EXPORTER CONTEXT BACKPORT
const ContextPluginBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/context/context_backport.gd")
const EditorContextMenuPluginCompat = preload("res://addons/plugin_exporter_backport/src/class/export/backport/context/context_plugin_compat.gd")
### PLUGIN EXPORTER CONTEXT BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BPSV_PATH_context_menu = "res://addons/plugin_exporter_backport/src/class/export/parse/gd/backport/context_menu.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

