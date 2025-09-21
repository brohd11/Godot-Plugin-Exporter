extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"

const StripTypeCast = preload("res://addons/plugin_exporter/src/class/export/parse/gd/global_class/strip_type_cast.gd")
var strip_type_cast:StripTypeCast

const GlobalRename = preload("res://addons/plugin_exporter/src/class/export/parse/gd/global_class/global_rename.gd")
var global_rename:GlobalRename

func _init() -> void:
	strip_type_cast = StripTypeCast.new()
	global_rename = GlobalRename.new()

# in parser_settings, create dictionary for extension of file,
# ie. if extension is foo, "parse_foo": {"my_setting": "value"}
func set_parse_settings(settings):
	
	strip_type_cast.export_obj = export_obj
	global_rename.export_obj = export_obj

# logic to parse for files that are needed acts as a set, dependencies[my_dep_path] = {}
func get_direct_dependencies(file_path:String) -> Dictionary:
	var dependencies = {} 
	return dependencies

# runs right before export of files. Use for extension specific files.
func pre_export() -> void:
	global_rename.pre_export()
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
	line = strip_type_cast.post_export_edit_line(line)
	line = global_rename.post_export_edit_line(line)
	return line
