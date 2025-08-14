extends RefCounted

const PLUGIN_EXPORT_FLAT = false

static func get_exported_file_path(file_path:String) ->String:
	if not PLUGIN_EXPORT_FLAT:
		if FileAccess.file_exists(file_path):
			return file_path
		else:
			printerr("Missing file path: %s" % file_path)
			return ""
	var file_nm = file_path.get_file()
	var self_script = new().get_script() as GDScript
	var script_dir = self_script.resource_path.get_base_dir()
	var new_path = script_dir.path_join(file_nm)
	if FileAccess.file_exists(new_path):
		return new_path
	else:
		printerr("Missing file path: %s" % new_path)
		return ""
