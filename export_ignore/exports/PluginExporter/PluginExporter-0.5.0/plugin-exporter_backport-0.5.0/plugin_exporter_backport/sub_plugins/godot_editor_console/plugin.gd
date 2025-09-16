@tool
extends EditorPlugin

const GUI_SCENE = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/terminal_gui.tscn")

const UtilsLocal = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/utils/console_utils_local.gd")

const UtilsRemote = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/utils/console_utils_remote.gd")


var editor_console


func _get_plugin_name() -> String:
	return "Godot Console"

func _enter_tree() -> void:
	editor_console = EditorConsole.get_instance(self)



func _exit_tree() -> void:
	if is_instance_valid(editor_console):
		editor_console.clear_reference(self)



### Plugin Exporter Global Classes
const EditorConsole = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/editor_console.gd")
### Plugin Exporter Global Classes

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER CONTEXT BACKPORT
const ContextPluginBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/context/context_backport.gd")
const EditorContextMenuPluginCompat = preload("res://addons/plugin_exporter_backport/src/class/export/backport/context/context_plugin_compat.gd")
### PLUGIN EXPORTER CONTEXT BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_plugin = "res://addons/plugin_exporter_backport/sub_plugins/godot_editor_console/plugin.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
