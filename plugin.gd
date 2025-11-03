@tool
extends EditorPlugin

const PLUGIN_EXPORTED = false

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const DockManager = UtilsRemote.DockManager
var dock_manager_instances: Array[DockManager]
var main_screen_handler: DockManager.MainScreenHandlerMulti

const CodeCompletion = preload("res://addons/plugin_exporter/src/editor_plugins/plugin_exporter_code_completion.gd")
var code_completion:CodeCompletion

const CONTEXT_MENU_PLUGIN = preload("res://addons/plugin_exporter/src/editor_plugins/plugin_exporter_context_menus.gd")
var context_plugin_inst:CONTEXT_MENU_PLUGIN


const PLUGIN_EXPORT_GUI = preload("res://addons/plugin_exporter/src/plugin_export_gui.tscn")

const SHOW_TOOL_MENU_ITEM = "plugin/plugin_exporter/show_tool_menu_item"

const COMMENT_TAGS = ["#! remote", "#! ignore-remote", "#! dependency", "#! singleton-module"]

static var instance

var syntax_plus:SyntaxPlus


func _get_plugin_name() -> String:
	return "Plugin Exporter"
func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_base_control().get_theme_icon("ActionCopy", &"EditorIcons")
func _has_main_screen() -> bool:
	return true
func _make_visible(visible: bool) -> void:
	main_screen_handler.on_plugin_make_visible(visible)

func _enable_plugin() -> void:
	if PLUGIN_EXPORTED:
		SubPluginManager.toggle_plugins("res://addons/plugin_exporter/sub_plugins", true)

func _disable_plugin() -> void:
	if PLUGIN_EXPORTED:
		SubPluginManager.toggle_plugins("res://addons/plugin_exporter/sub_plugins", false)

func _enter_tree() -> void:
	instance = self
	DockManager.hide_main_screen_button(self)
	main_screen_handler = DockManager.MainScreenHandlerMulti.new(self)
	
	syntax_plus = SyntaxPlus.register_node(self)
	SyntaxPlus.call_on_ready(_add_syntax_comment_tags)
	
	code_completion = CodeCompletion.new()
	
	context_plugin_inst = CONTEXT_MENU_PLUGIN.new()
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE, context_plugin_inst)
	
	var ed_settings = EditorInterface.get_editor_settings()
	if not ed_settings.has_setting(SHOW_TOOL_MENU_ITEM):
		ed_settings.set_setting(SHOW_TOOL_MENU_ITEM, true)
	
	if ed_settings.get_setting(SHOW_TOOL_MENU_ITEM):
		add_tool_menu_item("Plugin Exporter", _on_tool_menu_pressed)

func _exit_tree() -> void:
	remove_context_menu_plugin(context_plugin_inst)
	remove_tool_menu_item("Plugin Exporter")
	
	if is_instance_valid(code_completion):
		code_completion.clean_up()
	
	if is_instance_valid(syntax_plus):
		for tag in COMMENT_TAGS:
			var prefix = tag.get_slice(" ", 0)
			var tag_name = tag.get_slice(" ", 1)
			SyntaxPlus.unregister_comment_tag(prefix, tag_name)
		syntax_plus.unregister_node(self)
	
	for dock_manager:DockManager in dock_manager_instances:
		if is_instance_valid(dock_manager):
			dock_manager.clean_up()
	
	main_screen_handler.queue_free()
	instance = null

func _on_tool_menu_pressed():
	new_gui_instance()

func new_gui_instance():
	var can_be_freed = true
	var dock_manager = DockManager.new(self, PLUGIN_EXPORT_GUI, DockManager.Slot.MAIN_SCREEN, can_be_freed, main_screen_handler)
	dock_manager_instances.append(dock_manager)
	
	return dock_manager

func _add_syntax_comment_tags():
	for tag in COMMENT_TAGS:
		var prefix = tag.get_slice(" ", 0)
		var tag_name = tag.get_slice(" ", 1)
		SyntaxPlus.register_comment_tag(prefix, tag_name)
