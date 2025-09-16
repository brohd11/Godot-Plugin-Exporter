

static func toggle_plugins(sub_plugin_dir:String, enabled:bool):
	var sub_plugin_path = sub_plugin_dir.trim_prefix("res://addons/").trim_suffix("/")
	var sub_plugins = DirAccess.get_directories_at(sub_plugin_dir)
	for plugin_dir in sub_plugins:
		var plugin_name = sub_plugin_path.path_join(plugin_dir)
		EditorInterface.set_plugin_enabled(plugin_name, enabled)

