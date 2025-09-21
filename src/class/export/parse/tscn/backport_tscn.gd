extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"

const DPITexBackportTscn = preload("res://addons/plugin_exporter/src/class/export/parse/tscn/backport/dpi_texture.gd")
var dpi_tex_backport_tscn:DPITexBackportTscn

var backport_target:= 100

func _init() -> void:
	dpi_tex_backport_tscn = DPITexBackportTscn.new()

# in parser_settings, create dictionary for extension of file,
# ie. if extension is foo, "parse_foo": {"my_setting": "value"}
func set_parse_settings(settings):
	backport_target = settings.get("backport_target", 100)
	
	dpi_tex_backport_tscn.export_obj = export_obj

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
	
	if backport_target < 5:
		file_lines = dpi_tex_backport_tscn.post_export_edit_file(file_path, file_lines)
	
	return file_lines

# second pass of post export. If extension is handled by default, line will be 
# modified already. If changes were made in post_export_edit_file, these will be
# present here, else, it will be the unmodified line from the file.
func post_export_edit_line(line:String) -> String:
	return line
