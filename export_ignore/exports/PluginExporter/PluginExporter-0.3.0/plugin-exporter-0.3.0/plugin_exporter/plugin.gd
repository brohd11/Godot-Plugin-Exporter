@tool
extends EditorPlugin

const PLUGIN_EXPORTED = true

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const DockManager = UtilsRemote.DockManager
var dock_manager: DockManager

const CONTEXT_MENU_PLUGIN = preload("res://addons/plugin_exporter/src/editor_plugins/plugin_exporter_context_menus.gd")
var context_plugin_inst:CONTEXT_MENU_PLUGIN

const PLUGIN_EXPORT_GUI = preload("res://addons/plugin_exporter/src/plugin_export_gui.tscn")

func _get_plugin_name() -> String:
	return "Plugin Exporter"
func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_base_control().get_theme_icon("ActionCopy", &"EditorIcons")
func _has_main_screen() -> bool:
	return true

func _enter_tree() -> void:
	DockManager.hide_main_screen_button(self)
	
	context_plugin_inst = CONTEXT_MENU_PLUGIN.new()
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE, context_plugin_inst)
	
	if not PLUGIN_EXPORTED:
		return
	if EditorInterface.is_plugin_enabled("modular_browser"):
		return
	add_tool_menu_item("Plugin Exporter", _on_tool_menu_pressed)

func _exit_tree() -> void:
	remove_context_menu_plugin(context_plugin_inst)
	remove_tool_menu_item("Plugin Exporter")
	
	if is_instance_valid(dock_manager):
		dock_manager.clean_up()

func _on_tool_menu_pressed():
	if is_instance_valid(dock_manager):
		return
	var can_be_freed = true
	dock_manager = DockManager.new(self, PLUGIN_EXPORT_GUI, DockManager.Slot.MAIN_SCREEN, can_be_freed)

