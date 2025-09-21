extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"


var tscn_sub_resource_dpi_textures = {}

var _full_sub_resource_block_regex = RegEx.new()
var _source_regex := RegEx.new()
var _scene_header_regex := RegEx.new()
var _ext_resource_regex = RegEx.new()

func _init() -> void:
	var full_sub_pattern = '(\\[sub_resource type="DPITexture" id="([^"]+)"\\][\\s\\S]*?)(?=\\n\\n?\\[[a-z]|\\z)'
	_full_sub_resource_block_regex.compile(full_sub_pattern)
	
	var source_pattern = '_source = "((?:[^"\\\\]|\\\\.)*)"'
	_source_regex.compile(source_pattern)
	
	var scene_header_pattern = "(\\[gd_scene[^\\]]+\\])"
	_scene_header_regex.compile(scene_header_pattern)
	
	var ext_resource_pattern = '(\\[ext_resource type="Texture2D"[^p]+path=")([^"]+)("[^]]+\\])'
	_ext_resource_regex.compile(ext_resource_pattern)

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
	var content = "\n".join(file_lines)
	var original_content = content
	
	var dpi_texture_data = export_obj.shared_data.get("DPITextureBackport", {})
	var dpi_tex_paths = dpi_texture_data.keys()
	
	if not dpi_tex_paths.is_empty():
		# Get all [ext_resource] matches from the original content
		var ext_resource_matches = _ext_resource_regex.search_all(content)
		
		# Loop through each match and perform a conditional replacement
		for _match in ext_resource_matches:
			var original_path = _match.get_string(2)
			
			if original_path in dpi_tex_paths:
				var new_path = export_obj.adjusted_remote_paths.get(original_path)
				if new_path != null:
					# Construct the new line
					var new_line = _match.get_string(1) + new_path + _match.get_string(3)
					# Get the original full line that was matched
					var original_line = _match.get_string(0)
					# Replace the original line with the new one in our main content string
					content = content.replace(original_line, new_line)
	
	
	var generated_files_path = export_obj.remote_dir.path_join("generated/svg")
	var new_ext_resources = []
	var new_id_counter = 100
	
	var sub_resource_block_matches = _full_sub_resource_block_regex.search_all(content)
	if sub_resource_block_matches.is_empty():
		return file_lines
	for block_match in sub_resource_block_matches:
		var full_block_to_process = block_match.get_string(0)
		var sub_resource_id_string = block_match.get_string(2)
		
		var source_match = _source_regex.search(content)
		if not source_match:
			continue
		
		var svg_source = source_match.get_string(1).c_unescape()
		
		# 1. Generate a unique file name for the new SVG
		var hash_input = "%s_%s" % [file_path, sub_resource_id_string]
		var hash = UFile.hash_string(hash_input).substr(0, 10)
		var svg_file_name = "%s.svg" % hash
		
		var svg_resource_path = generated_files_path.path_join(svg_file_name)
		svg_resource_path = export_obj.get_renamed_path(svg_resource_path)
		var svg_output_path = export_obj.get_export_path(svg_resource_path)
		svg_output_path = export_obj.get_renamed_path(svg_output_path)
		# 2. Save the new SVG file
		if not DirAccess.dir_exists_absolute(svg_output_path.get_base_dir()):
			DirAccess.make_dir_recursive_absolute(svg_output_path.get_base_dir())
		var svg_file = FileAccess.open(svg_output_path, FileAccess.WRITE)
		if svg_file:
			svg_file.store_string(svg_source)
			svg_file.close()
		else:
			printerr("Failed to write SVG file: ", svg_output_path)
			return file_lines
		
		# 3. Generate a new ExtResource ID
		var new_id_suffix = hash.substr(0, 5) # e.g., "a1b2c"
		var new_id_full_string = "%d_%s" % [new_id_counter, new_id_suffix] # e.g., "100_a1b2c"
		new_id_counter += 1
		
		var new_ext_resource_def = '[ext_resource type="Texture2D" path="%s" id="%s"]' % [
			svg_resource_path,
			new_id_full_string
		]
		new_ext_resources.append(new_ext_resource_def)
		
		# 4. Perform replacements on the content string
		# Replace the SubResource reference with the new ExtResource reference
		content = content.replace('SubResource("%s")' % sub_resource_id_string, 'ExtResource("%s")' % new_id_full_string)
		
		# Remove the entire original sub-resource block
		content = content.replace(full_block_to_process, "")
	
	var header_match = _scene_header_regex.search(content)
	if header_match:
		var header_line = header_match.get_string(1)
		var new_res_block = "\n".join(new_ext_resources)
		var new_header = header_line + "\n\n" + new_res_block
		content = content.replace(header_line, new_header)
	
	
	# --- Part 2: Write changes back to the file ---
	if content != original_content:
		content = content.replace("\n\n\n", "\n\n")
		file_lines = content.split("\n")
	
	return file_lines

# second pass of post export. If extension is handled by default, line will be 
# modified already. If changes were made in post_export_edit_file, these will be
# present here, else, it will be the unmodified line from the file.
func post_export_edit_line(line:String) -> String:
	return line






	#var dpi_sub_resources = {}
	#
	#var in_dpi_sub_res:= false
	#for i in range(file_lines.size()):
		#var line:String = file_lines[i]
		#if in_dpi_sub_res and line.begins_with("["):
			#in_dpi_sub_res = false
		#
		#var line_starts_dpi_sub_res = line.find('[sub_resource type="DPITexture"') > -1
		#if line_starts_dpi_sub_res:
			#in_dpi_sub_res = true
		#elif not in_dpi_sub_res:
			#if line.find('SubResource("DPITexture') > -1:
				#line = line.replace("DPITexture", "PlaceholderTexture2D")
				#file_lines[i] = line
			#continue
		#
		#if line_starts_dpi_sub_res:
			#line = line.replace("DPITexture", "PlaceholderTexture2D")
			#file_lines[i] = line
			#continue
		#
		#line = ""
		#file_lines[i] = line
