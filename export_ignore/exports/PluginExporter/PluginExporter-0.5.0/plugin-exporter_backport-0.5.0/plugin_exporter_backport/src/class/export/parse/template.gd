extends "res://addons/plugin_exporter_backport/src/class/export/parse/parse_base.gd"

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
	return line

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BPSV_PATH_template = "res://addons/plugin_exporter_backport/src/class/export/parse/template.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

