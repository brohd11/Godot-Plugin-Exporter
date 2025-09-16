extends RefCounted

static func get_main_screen():
	return _EIBackport.get_ins().ei.get_editor_main_screen()

static func get_title_bar():
	return _EIBackport.get_ins().ei.get_base_control().get_child(0).get_child(0)
	
static func get_button_container():
	var system = OS.get_name()
	if system == "macOS":
		return get_title_bar().get_child(3)
	else:
		return get_title_bar().get_child(2)

static func get_button_theme():
	var button
	var system = OS.get_name()
	if system == "macOS":
		button = get_title_bar().get_child(3).get_child(0) as Button
	else:
		button = get_title_bar().get_child(2).get_child(0) as Button
	return button.theme_type_variation


### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_main_screen = "res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/editor_nodes/main_screen.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
