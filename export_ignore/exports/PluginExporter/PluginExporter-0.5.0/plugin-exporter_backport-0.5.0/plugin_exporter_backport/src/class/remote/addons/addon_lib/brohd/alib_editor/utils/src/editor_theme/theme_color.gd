extends RefCounted

enum Type{
	NONE,
	BASE,
	ACCENT,
	DARK,
	BACKGROUND,
}

static func get_theme_color(color_type=Type.BASE):
	var base_control = _EIBackport.get_ins().ei.get_base_control()
	var color
	var color_string = ""
	if color_type == Type.BASE:
		color_string = "base_color"
	elif color_type == Type.ACCENT:
		color_string = "accent_color"
	elif color_type == Type.DARK:
		color_string = "dark_color"
	elif color_type == Type.BACKGROUND:
		color_string = "background"
	
	color = base_control.get_theme_color(color_string, &"Editor")
	return color


### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_theme_color = "res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/editor_theme/theme_color.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
