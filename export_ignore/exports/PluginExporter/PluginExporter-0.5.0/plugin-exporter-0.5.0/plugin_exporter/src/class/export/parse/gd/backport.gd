extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"

const EI_BACKPORT_PATH = "res://addons/plugin_exporter/src/class/export/backport/ei_backport.gd"
const EI_BACKPORT = "_EIBackport"

const MISC_BACKPORT_PATH = "res://addons/plugin_exporter/src/class/export/backport/misc_backport_class.gd"
const MISC_BACKPORT = "MiscBackport"

const Backport4_0 = preload("res://addons/plugin_exporter/src/class/export/parse/gd/backport/4_0_backports.gd")
var backport4_0:Backport4_0

const BackportContext = preload("res://addons/plugin_exporter/src/class/export/parse/gd/backport/context_menu.gd")
var backport_context:BackportContext

const BackportStaticVar = preload("res://addons/plugin_exporter/src/class/export/parse/gd/backport/static_var_backport.gd")
var backport_static_var:BackportStaticVar

const Backport4_4 = preload("res://addons/plugin_exporter/src/class/export/parse/gd/backport/4_4_backports.gd")
var backport4_4:Backport4_4

const MiscBackportParse = preload("res://addons/plugin_exporter/src/class/export/parse/gd/backport/misc_backport.gd")
var misc_backport:MiscBackportParse

var backport_target:= -1


func _init() -> void:
	backport4_0 = Backport4_0.new()
	backport4_4 = Backport4_4.new()
	backport_static_var = BackportStaticVar.new()
	backport_context = BackportContext.new()
	misc_backport = MiscBackportParse.new()


# in parser_settings, create dictionary for extension of file,
# ie. if extension is foo, "parse_foo": {"my_setting": "value"}
func set_parse_settings(settings):
	backport_target = settings.get("backport_target", 100)
	
	backport4_0.set_parse_settings(settings)
	
	backport_static_var.export_obj = export_obj
	backport_static_var.set_parse_settings(settings)
	
	backport_context.export_obj = export_obj
	backport_context.set_parse_settings(settings)
	
	misc_backport.set_parse_settings(settings)


# logic to parse for files that are needed acts as a set, dependencies[my_dep_path] = {}
func get_direct_dependencies(file_path:String) -> Dictionary:
	var dependencies = {} 
	return dependencies

func pre_export():
	backport_static_var.pre_export()


# first pass on post export, if the file ext is handled by default, file_lines will 
# contain modifies lines, for example, if you want to make a second pass on a gd file.
# If not handled by default, file_lines will be null. You can process and return the files lines
# or return the null value to default to the file's .
func post_export_edit_file(file_path:String, file_lines:Variant=null) -> Variant:
	if backport_target == 100:
		return file_lines
	
	var extends_class = file_extends_class(file_lines, backport_target)
	if backport_target < 4:
		backport4_0.current_file_path = export_obj.file_parser.current_file_path_parsing
		
		for i in range(file_lines.size()):
			var line = file_lines[i]
			line = backport_context.post_export_edit_line(line)
			file_lines[i] = line
		
		var file_as_text = "\n".join(file_lines)
		var converted_file = backport4_0.backport_raw_strings(file_as_text)
		file_lines = converted_file.split("\n")
		
		
		if not extends_class:
			file_lines.append("### PLUGIN EXPORTER EDITORINTERFACE BACKPORT")
			var adj_path = export_obj.adjusted_remote_paths.get(EI_BACKPORT_PATH, EI_BACKPORT_PATH)
			file_lines.append(_construct_pre(EI_BACKPORT, adj_path))
			file_lines.append("### PLUGIN EXPORTER EDITORINTERFACE BACKPORT")
			file_lines.append("")
		
		file_lines = backport_context.post_export_edit_file(file_path, file_lines) # internal check for version
		
	## END < 4
	
	if backport_target < 2:
		file_lines = backport_static_var.post_export_edit_file(file_path, file_lines) # internal check for version
		
	
	
	if backport_target < 5:
		file_lines = backport4_4.post_export_edit_file(file_path, file_lines)
		
	
	if not extends_class:
		var has_backport_preloaded := false
		for line in file_lines:
			if line.begins_with("const %s" % MISC_BACKPORT): 
				has_backport_preloaded =  true
		
		if not has_backport_preloaded:
			file_lines.append("### PLUGIN EXPORTER MISC BACKPORT")
			var misc_adj_path = export_obj.adjusted_remote_paths.get(MISC_BACKPORT_PATH, MISC_BACKPORT_PATH)
			file_lines.append(_construct_pre(MISC_BACKPORT, misc_adj_path))
			file_lines.append("### PLUGIN EXPORTER MISC BACKPORT")
	
	for i in range(file_lines.size()):
		var line = file_lines[i]
		if line.strip_edges() == "const BACKPORTED = 100":
			line = "const BACKPORTED = %s" % backport_target
			file_lines[i] = line
			break
	
	return file_lines


# second pass of post export. If extension is handled by default, line will be 
# modified already. If changes were made in post_export_edit_file, these will be
# present here, else, it will be the unmodified line from the file.
func post_export_edit_line(line:String) -> String:
	
	if backport_target < 4:
		line = backport4_0.post_export_edit_line(line)
	if backport_target < 5:
		line = backport4_4.post_export_edit_line(line)
	
	line = misc_backport.post_export_edit_line(line)
	
	return line

