@tool
extends EditorPlugin

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const DockManager = UtilsRemote.DockManager
var dock_manager: DockManager

const PLUGIN_EXPORT = preload("res://addons/plugin_exporter/src/plugin_export.tscn")

func _get_plugin_name() -> String:
	return "Plugin Exporter"

func _has_main_screen() -> bool:
	return true

func _enter_tree() -> void:
	DockManager.hide_main_screen_button(self)
	if EditorInterface.is_plugin_enabled("modular_browser"):
		return
	add_tool_menu_item("Plugin Exporter", _on_tool_menu_pressed)

func _exit_tree() -> void:
	remove_tool_menu_item("Plugin Exporter")
	
	if is_instance_valid(dock_manager):
		dock_manager.clean_up()

func _on_tool_menu_pressed():
	if is_instance_valid(dock_manager):
		return
	var can_be_freed = true
	dock_manager = DockManager.new(self, PLUGIN_EXPORT, DockManager.Slot.BOTTOM_PANEL, can_be_freed)
