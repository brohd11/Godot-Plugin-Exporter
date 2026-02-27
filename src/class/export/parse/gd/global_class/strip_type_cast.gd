extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"

var _editor_console_regex := RegEx.new()
var _editor_node_ref := RegEx.new()

const CAST_STRIP_NAMES = ["PE_STRIP_CAST_SCRIPT"]
var _cast_strip_names = []

var _cast_strip_callables = []

func _init() -> void:
	pass


# in parser_settings, create dictionary for extension of file,
# ie. if extension is foo, "parse_foo": {"my_setting": "value"}
func set_parse_settings(settings):
	_cast_strip_names = settings.get("strip_cast", [])
	_cast_strip_names.append_array(CAST_STRIP_NAMES.duplicate())
	for nm in CAST_STRIP_NAMES:
		if not nm in _cast_strip_names:
			_cast_strip_names.append(nm)
	
	for file in ExportFileUtils.get_global_singleton_module_scripts():
		var script = load(file) as GDScript
		var global_name = script.get_global_name()
		if global_name != "" and not global_name in _cast_strip_names:
			_cast_strip_names.append(global_name)
	
	_build_regexes()

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
	for callable in _cast_strip_callables:
		line = _string_safe_regex_sub(line, callable)
	return line


func _build_regexes():
	for _class_name in _cast_strip_names:
		var strip_pattern = r"\s*(?:->|:)\s*%s(\.\w+)*\b\s*" % _class_name
		var regex = RegEx.new()
		regex.compile(strip_pattern)
		var anon = func(line:String) -> String:
			return regex.sub(line, "", true)
		
		_cast_strip_callables.append(anon)
