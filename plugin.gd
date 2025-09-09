@tool
extends EditorPlugin

const PLUGIN_EXPORTED = false

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const DockManager = UtilsRemote.DockManager
var dock_manager_instances: Array[DockManager]
var main_screen_handler: DockManager.MainScreenHandlerMultiClass

const CONTEXT_MENU_PLUGIN = preload("res://addons/plugin_exporter/src/editor_plugins/plugin_exporter_context_menus.gd")
var context_plugin_inst:CONTEXT_MENU_PLUGIN

const PLUGIN_EXPORT_GUI = preload("res://addons/plugin_exporter/src/plugin_export_gui.tscn")

static var instance

func _get_plugin_name() -> String:
	return "Plugin Exporter"
func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_base_control().get_theme_icon("ActionCopy", &"EditorIcons")
func _has_main_screen() -> bool:
	return true

func _enable_plugin() -> void:
	if PLUGIN_EXPORTED:
		SubPluginManager.toggle_plugins("res://addons/plugin_exporter/sub_plugins", true)

func _disable_plugin() -> void:
	if PLUGIN_EXPORTED:
		SubPluginManager.toggle_plugins("res://addons/plugin_exporter/sub_plugins", false)

func _enter_tree() -> void:
	instance = self
	DockManager.hide_main_screen_button(self)
	main_screen_handler = DockManager.MainScreenHandlerMultiClass.new(self)
	
	context_plugin_inst = CONTEXT_MENU_PLUGIN.new()
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE, context_plugin_inst)
	
	#if not PLUGIN_EXPORTED:
		#return
	#if EditorInterface.is_plugin_enabled("modular_browser"):
		#return
	add_tool_menu_item("Plugin Exporter", _on_tool_menu_pressed)

func _exit_tree() -> void:
	remove_context_menu_plugin(context_plugin_inst)
	remove_tool_menu_item("Plugin Exporter")
	
	for dock_manager in dock_manager_instances:
		if is_instance_valid(dock_manager):
			dock_manager.clean_up()
	
	main_screen_handler.queue_free()
	instance = null

func _on_tool_menu_pressed():
	new_gui_instance()

func new_gui_instance():
	#if is_instance_valid(dock_manager):
		#return
	
	var can_be_freed = true
	var dock_manager = DockManager.new(self, PLUGIN_EXPORT_GUI, DockManager.Slot.MAIN_SCREEN, can_be_freed, main_screen_handler)
	dock_manager_instances.append(dock_manager)
	
	return dock_manager
