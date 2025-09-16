extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"

var _editor_console_regex := RegEx.new()

func _init() -> void:
	var ec_pattern = ":\\s*EditorConsole"
	_editor_console_regex.compile(ec_pattern)
	


# in parser_settings, create dictionary for extension of file,
# ie. if extension is foo, "parse_foo": {"my_setting": "value"}
func set_parse_settings(settings):
	pass

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
	line = _string_safe_regex_sub(line, _remove_editor_console)
	return line

func _remove_editor_console(line:String):
	return _editor_console_regex.sub(line, "", true)



### Plugin Exporter Global Classes
const EditorConsole = preload("res://addons/plugin_exporter/src/class/remote/addons/editor_console/src/editor_console.gd")
### Plugin Exporter Global Classes

