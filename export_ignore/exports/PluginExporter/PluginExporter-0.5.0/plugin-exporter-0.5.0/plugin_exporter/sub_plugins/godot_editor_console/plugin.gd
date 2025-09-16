@tool
extends EditorPlugin

const GUI_SCENE = preload("res://addons/plugin_exporter/src/class/remote/addons/editor_console/src/terminal_gui.tscn")

const UtilsLocal = preload("res://addons/plugin_exporter/src/class/remote/addons/editor_console/src/utils/console_utils_local.gd")

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/remote/addons/editor_console/src/utils/console_utils_remote.gd")


var editor_console


func _get_plugin_name() -> String:
	return "Godot Console"

func _enter_tree() -> void:
	editor_console = EditorConsole.get_instance(self)



func _exit_tree() -> void:
	if is_instance_valid(editor_console):
		editor_console.clear_reference(self)



### Plugin Exporter Global Classes
const EditorConsole = preload("res://addons/plugin_exporter/src/class/remote/addons/editor_console/src/editor_console.gd")
### Plugin Exporter Global Classes

