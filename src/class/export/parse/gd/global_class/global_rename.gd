extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"

#var suffix_hash:String

var rename_callables = []
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
	var plugin_name = export_obj.plugin_name
	if export_obj.rename_plugin:
		plugin_name = export_obj.new_plugin_name
	
	var suffix_hash = UFile.hash_string(plugin_name).substr(0,3)
	var global_classes_used = export_obj.global_classes_used.keys()
	for _class_name in export_obj.class_renames:
		if not _class_name in global_classes_used:
			continue
		var regex = RegEx.new()
		var reg_string = "\\b%s\\b" % _class_name
		var replace_name = "%s_%s" % [_class_name, suffix_hash]
		regex.compile(reg_string)
		var anon = func(line:String) -> String:
			return regex.sub(line, replace_name, true)
		
		rename_callables.append(anon)


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
	for callable in rename_callables:
		line = _string_safe_regex_sub(line, callable)
	return line
