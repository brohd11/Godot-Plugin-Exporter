extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"

func set_parse_settings(settings) -> void:
	pass

func get_direct_dependencies(file_path:String) -> Dictionary:
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	if not file_access:
		printerr("Could not open file: %s" % file_path)
		return {}
	var direct_dependencies = {}
	while not file_access.eof_reached():
		var line = file_access.get_line()
		if line.find('[ext_resource') > -1:
			var path = line.get_slice('path="', 1)
			path = path.get_slice('"', 0)
			var file_name = path.get_file()
			direct_dependencies[path] = {}
	
	return direct_dependencies


func post_export_edit_file(file_path:String, file_lines:Variant=null) -> Variant:
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	
	if not file_access:
		printerr("ParseTSCN - Issue reading file: %s" % file_path)
		return
	
	var adjusted_file_lines = []
	while not file_access.eof_reached():
		var line = file_access.get_line()
	
		if line.find('[gd_scene') > -1:
			var uid = line.get_slice(' uid="', 1)
			uid = uid.get_slice('"', 0)
			var path = UFile.uid_to_path(uid)
			if path in export_obj.file_dependencies.keys():
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
			
			var new_path = get_adjusted_path_or_old_renamed(path) # this should be able to replace
			line = RES_LINE_TEMPLATE % [type, new_path, id]
		
		adjusted_file_lines.append(line)
	
	return adjusted_file_lines
