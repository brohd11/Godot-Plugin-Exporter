

static func toggle_plugins(sub_plugin_dir:String, enabled:bool):
	var sub_plugin_path = sub_plugin_dir.trim_prefix("res://addons/").trim_suffix("/")
	var sub_plugins = DirAccess.get_directories_at(sub_plugin_dir)
	for plugin_dir in sub_plugins:
		var plugin_name = sub_plugin_path.path_join(plugin_dir)
		_EIBackport.get_ins().ei.set_plugin_enabled(plugin_name, enabled)

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_sub_plugin_manager = "res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/editor_plugin_manager/sub_plugin_manager.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
