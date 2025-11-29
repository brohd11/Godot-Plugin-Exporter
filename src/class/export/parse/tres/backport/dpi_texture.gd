extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"

var backport_target:= 100

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
	var dpi_texture_files = {}
	var files_to_copy = export_obj.files_to_copy.keys()
	var generated_files_path = export_obj.remote_dir.path_join("generated/svg")
	for file:String in files_to_copy:
		if not file.get_extension() == "tres":
			continue
		
		var f = FileAccess.open(file, FileAccess.READ)
		var first_line = f.get_line()
		if not first_line.find('[gd_resource type="DPITexture"') > -1:
			continue
		var file_data = {}
		var is_remote = not UFile.is_file_in_directory(file, export_obj.source)
		
		var file_name = file.get_basename().get_file()
		var path_hash = UFile.hash_string(file).substr(0, 8)
		var export_file_name = "%s_%s.svg" % [file_name, path_hash]
		
		var original_svg_path = file.get_base_dir().path_join(export_file_name)
		var svg_path = original_svg_path
		
		if is_remote:
			svg_path = generated_files_path.path_join(export_file_name)
		
		var export_path = export_obj.get_export_path(svg_path)
		var renamed_path = export_obj.get_renamed_path(svg_path)
		export_obj.adjusted_remote_paths[file] = renamed_path
		
		file_data[ExportFileKeys.to] = export_path
		export_obj.check_file_has_valid_path(original_svg_path, export_path)
		
		dpi_texture_files[file] = file_data
	
	for file in dpi_texture_files.keys():
		export_obj.files_to_copy.erase(file)
	
	export_obj.shared_data["DPITextureBackport"] = dpi_texture_files
	
	if not export_obj.export_valid:
		return
	
	for file in dpi_texture_files.keys():
		var data = dpi_texture_files.get(file)
		var dpi_tex = load(file)
		
		var source = dpi_tex.get_source()
		var export_path = data.get(ExportFileKeys.to)
		if not DirAccess.dir_exists_absolute(export_path.get_base_dir()):
			DirAccess.make_dir_recursive_absolute(export_path.get_base_dir())
		
		var file_access = FileAccess.open(export_path, FileAccess.WRITE)
		file_access.store_string(source)
		

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
