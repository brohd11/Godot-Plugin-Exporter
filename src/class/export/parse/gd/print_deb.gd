extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"



func _init() -> void:
	pass

# in parser_settings, create dictionary for extension of file,
# ie. if extension is foo, "parse_foo": {"my_setting": "value"}
func set_parse_settings(_settings:Dictionary) -> void:
	pass

# logic to parse for files that are needed acts as a set, dependencies[my_dep_path] = {}
func get_direct_dependencies(_file_path:String) -> Dictionary:
	var dependencies:Dictionary = {}
	return dependencies

# runs right before export of files. Use for extension specific files.
func pre_export() -> void:
	pass


# first pass on post export, if the file ext is handle by default, file_lines will 
# contain modifies lines, for example, if you want to make a second pass on a gd file.
# If not handled by default, file_lines will be null. You can process and return the files lines
# or return the null value to default to the file's .
func post_export_edit_file(_file_path:String, file_lines:Variant=null) -> Variant:
	return file_lines

# second pass of post export. If extension is handled by default, line will be 
# modified already. If changes were made in post_export_edit_file, these will be
# present here, else, it will be the unmodified line from the file.
func post_export_edit_line(line:String) -> String:
	var stripped:String = line.strip_edges()
	if stripped.begins_with("print_deb(") or stripped.begins_with("print_deb_err("):
		var print_idx:int = line.find("print_deb")
		line = line.insert(print_idx, "pass # ")
	return line
