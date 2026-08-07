extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"

func set_parse_settings(settings):
	pass

func get_direct_dependencies(file_path:String) -> Dictionary:
	_read_script_class(file_path)
	return edges_to_dependencies(scan_direct_edges(file_path), {})

# The scanner is run without a class map, so the [gd_resource] header is read here. It is
# always the first line.
func _read_script_class(file_path:String) -> void:
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	if not file_access:
		printerr("Could not open file: %s" % file_path)
		return
	var line = file_access.get_line()
	if line.find("[gd_resource") == -1 or line.find(' script_class="') == -1:
		return
	var script_class = line.get_slice(' script_class="', 1)
	script_class = script_class.get_slice('"', 0)
	if not export_obj.global_classes_used.has(script_class):
		export_obj.global_classes_used[script_class] = {
			#ExportFileKeys.dependent: file_path,
			ExportFileKeys.path: file_path
		}
	# erase from renames, keeps resource class global
	export_obj.class_renames.erase(script_class)

func post_export_edit_line(line:String) -> String:
	return line

func post_export_edit_file(file_path:String, file_lines:Variant=null) -> Variant:
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	
	if not file_access:
		printerr("ParseTSCN - Issue reading file: %s" % file_path)
		return
	
	var file_dependencies_keys = export_obj.file_dependencies.keys()
	var adjusted_file_lines = []
	while not file_access.eof_reached():
		var line = file_access.get_line()
	
		if line.find('[gd_resource') > -1:
			var uid = line.get_slice(' uid="', 1)
			uid = uid.get_slice('"', 0)
			var path = UFile.uid_to_path(uid)
			if path in file_dependencies_keys:
				var new_uid = ResourceUID.id_to_text(ResourceUID.create_id())
				var old_uid_line = 'uid="%s"' % uid
				var new_uid_line = 'uid="%s"' % new_uid
				line = line.replace(old_uid_line, new_uid_line)
		elif line.find('[ext_resource') > -1:
			var type = line.get_slice(' type="', 1)
			type = type.get_slice('"', 0)
			var path = line.get_slice('path="', 1)
			path = path.get_slice('"', 0)
			var id = line.get_slice(' id="', 1)
			id = id.get_slice('"', 0)
			
			var new_path = get_adjusted_path_or_old_renamed(path)
			line = RES_LINE_TEMPLATE % [type, new_path, id]
		
		adjusted_file_lines.append(line)
	
	return adjusted_file_lines

func _update_file_export_flags(line:String) -> String:
	return line
