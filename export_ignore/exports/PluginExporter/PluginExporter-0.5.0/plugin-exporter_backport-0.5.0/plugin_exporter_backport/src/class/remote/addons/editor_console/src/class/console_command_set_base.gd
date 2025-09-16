const UtilsLocal = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/utils/console_utils_local.gd")
const UtilsRemote = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/utils/console_utils_remote.gd")


static func register_scopes():
	return {}

static func register_variables():
	return {}

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_console_command_set_base = "res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/class/console_command_set_base.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
