extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"

const REPLACEMENT_TEXT = 'Engine.get_singleton(&"EditorInterface")'

var _ei_regex:= RegEx.new()
var string_regex:RegEx

var _replace_editor_interface:=false

func _init() -> void:
	string_regex = URegex.get_strings()
	
	var ei_pattern = "\\bEditorInterface\\b"
	_ei_regex.compile(ei_pattern)

# in parser_settings, create dictionary for extension of file,
# ie. if extension is foo, "parse_foo": {"my_setting": "value"}
func set_parse_settings(settings):
	_replace_editor_interface = settings.get("replace_editor_interface", false)

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
	return file_lines

# second pass of post export. If extension is handled by default, line will be 
# modified already. If changes were made in post_export_edit_file, these will be
# present here, else, it will be the unmodified line from the file.
func post_export_edit_line(line:String) -> String:
	if _replace_editor_interface:
		line = replace_editor_interface(line)
	return line


func replace_editor_interface(line: String) -> String:
	#if line.strip_edges() == "ei = EditorInterface":
		#return line #^ should be fine to replace
	
	var processor = func(code: String):
		return _ei_regex.sub(code, REPLACEMENT_TEXT, true)
	return URegex.string_safe_regex_sub(line, processor, string_regex)
