extends "res://addons/plugin_exporter/src/class/export/parse_base.gd"

func set_parse_settings(settings) -> void:
	pass

func edit_dep_file(line:String, to:String, remote_file:String, remote_dir:String, dependencies:Dictionary) -> String:
	if line.find('[gd_scene') > -1:
		var uid = line.get_slice(' uid="', 1)
		uid = uid.get_slice('"', 0)
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
		
		var file_name = path.get_file()
		var to_path = remote_dir.path_join(file_name)
		var depen_data = {"from": path, "to": to_path, RemoteData.dependent: remote_file}
		dependencies[file_name] = depen_data
		var rel_path = UFile.get_relative_path(to, to_path)
		line = '[ext_resource type="%s" path="./%s" id="%s"]' % [type, rel_path, id]
	
	return line
	#file_lines.append(line)
