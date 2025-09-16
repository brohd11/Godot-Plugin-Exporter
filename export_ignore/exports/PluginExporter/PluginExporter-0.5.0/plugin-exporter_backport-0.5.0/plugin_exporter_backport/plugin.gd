@tool
extends EditorPlugin

const PLUGIN_EXPORTED = true

const UtilsRemote = preload("res://addons/plugin_exporter_backport/src/class/utils_remote.gd")
const DockManager = UtilsRemote.DockManager
var dock_manager_instances: Array[DockManager]
var main_screen_handler: DockManager.MainScreenHandlerMultiClass

const CONTEXT_MENU_PLUGIN = preload("res://addons/plugin_exporter_backport/src/editor_plugins/plugin_exporter_context_menus.gd")
var context_plugin_inst:CONTEXT_MENU_PLUGIN

const PLUGIN_EXPORT_GUI = preload("res://addons/plugin_exporter_backport/src/plugin_export_gui.tscn")

const SHOW_TOOL_MENU_ITEM = "plugin/plugin_exporter/show_tool_menu_item"

#static var instance<- Backport Static Var


func _get_plugin_name() -> String:
	return "Plugin Exporter"
func _get_plugin_icon() -> Texture2D:
	return _EIBackport.get_ins().ei.get_base_control().get_theme_icon("ActionCopy", &"EditorIcons")
func _has_main_screen() -> bool:
	return true

func _enable_plugin() -> void:
	if PLUGIN_EXPORTED:
		SubPluginManager.toggle_plugins("res://addons/plugin_exporter_backport/sub_plugins", true)

func _disable_plugin() -> void:
	if PLUGIN_EXPORTED:
		SubPluginManager.toggle_plugins("res://addons/plugin_exporter_backport/sub_plugins", false)

func _enter_tree() -> void:
	set_instance(self)
	DockManager.hide_main_screen_button(self)
	main_screen_handler = DockManager.MainScreenHandlerMultiClass.new(self)
	
	context_plugin_inst = CONTEXT_MENU_PLUGIN.new()
	ContextPluginBackport.add_context_menu_plugin(4, context_plugin_inst)
	
	var ed_settings = _EIBackport.get_ins().ei.get_editor_settings()
	if not ed_settings.has_setting(SHOW_TOOL_MENU_ITEM):
		ed_settings.set_setting(SHOW_TOOL_MENU_ITEM, true)
	
	if ed_settings.get_setting(SHOW_TOOL_MENU_ITEM):
		add_tool_menu_item("Plugin Exporter", _on_tool_menu_pressed)

func _exit_tree() -> void:
	ContextPluginBackport.remove_context_menu_plugin(context_plugin_inst)
	remove_tool_menu_item("Plugin Exporter")
	
	for dock_manager in dock_manager_instances:
		if is_instance_valid(dock_manager):
			dock_manager.clean_up()
	
	main_screen_handler.queue_free()
	set_instance(null)

func _on_tool_menu_pressed():
	new_gui_instance()

func new_gui_instance():
	var can_be_freed = true
	var dock_manager = DockManager.new(self, PLUGIN_EXPORT_GUI, DockManager.Slot.MAIN_SCREEN, can_be_freed, main_screen_handler)
	dock_manager_instances.append(dock_manager)
	
	return dock_manager



### Plugin Exporter Global Classes
const SubPluginManager = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/editor_plugin_manager/sub_plugin_manager.gd")
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
const _BPSV_PATH_plugin = "res://addons/plugin_exporter_backport/plugin.gd"

static func get_instance():
	return _BackportStaticVar.get_ins().get_var(_BPSV_PATH_plugin, 'instance', null)
static func set_instance(value):
	return _BackportStaticVar.get_ins().set_var(_BPSV_PATH_plugin, 'instance', value)
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
