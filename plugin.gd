@tool
extends EditorPlugin

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const DockManager = UtilsRemote.DockManager
var dock_manager: DockManager

const EditorPluginManager = preload("res://addons/plugin_exporter/src/class/remote/editor_plugin_manager.gd")
const EDITOR_PLUGINS_PATH = "res://addons/plugin_exporter/src/editor_plugins/plugin_exporter_editor_plugins.json"
var editor_plugin_manager: EditorPluginManager

const PLUGIN_EXPORT = preload("res://addons/plugin_exporter/src/plugin_export.tscn")

func _get_plugin_name() -> String:
	return "Plugin Exporter"
func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_base_control().get_theme_icon("ActionCopy", &"EditorIcons")
func _has_main_screen() -> bool:
	return true

func _enter_tree() -> void:
	editor_plugin_manager = EditorPluginManager.new(self, EDITOR_PLUGINS_PATH, true)
	DockManager.hide_main_screen_button(self)
	#if EditorInterface.is_plugin_enabled("modular_browser"):
		#return
	add_tool_menu_item("Plugin Exporter", _on_tool_menu_pressed)

func _exit_tree() -> void:
	editor_plugin_manager.remove_plugins()
	remove_tool_menu_item("Plugin Exporter")
	
	if is_instance_valid(dock_manager):
		dock_manager.clean_up()

func _on_tool_menu_pressed():
	if is_instance_valid(dock_manager):
		return
	var can_be_freed = true
	dock_manager = DockManager.new(self, PLUGIN_EXPORT, DockManager.Slot.BOTTOM_PANEL, can_be_freed)
