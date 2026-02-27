@tool
extends EditorPlugin

const PLUGIN_EXPORTED = false

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")

const CodeCompletion = preload("res://addons/plugin_exporter/src/editor_plugins/plugin_exporter_code_completion.gd")
var code_completion:CodeCompletion

const CONTEXT_MENU_PLUGIN = preload("res://addons/plugin_exporter/src/editor_plugins/plugin_exporter_context_menus.gd")
var context_plugin_inst:CONTEXT_MENU_PLUGIN

const ConsoleCommand = preload("res://addons/plugin_exporter/src/editor_plugins/console_command.gd")

const PLUGIN_EXPORT_GUI = preload("res://addons/plugin_exporter/src/plugin_export_gui.tscn")

const SHOW_TOOL_MENU_ITEM = "plugin/plugin_exporter/show_tool_menu_item"

const COMMENT_TAGS = ["#! remote", "#! ignore-remote", "#! dependency", "#! singleton-module"]

static var instance

var dm_instance_manager:DockManager.InstanceManager


func _get_plugin_name() -> String:
	return "Plugin Exporter"
func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_base_control().get_theme_icon("ActionCopy", &"EditorIcons")
func _has_main_screen() -> bool:
	return true
func _make_visible(visible: bool) -> void:
	dm_instance_manager.on_plugin_make_visible(visible)


func _enter_tree() -> void:
	instance = self
	
	dm_instance_manager = DockManager.InstanceManager.new(self)
	
	SyntaxPlusSingleton.register_node(self)
	SyntaxPlusSingleton.call_on_ready(_add_syntax_comment_tags)
	
	EditorCodeCompletion.register_plugin(self)
	code_completion = CodeCompletion.new()
	
	#EditorConsoleSingleton.register_node(self) # don't think this is needed, register plugin above should handle it
	EditorConsoleSingleton.call_on_ready(_register_editor_console)
	
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
	
	EditorCodeCompletion.unregister_plugin(self)
	
	for tag in COMMENT_TAGS:
		var prefix = tag.get_slice(" ", 0)
		var tag_name = tag.get_slice(" ", 1)
		SyntaxPlusSingleton.unregister_comment_tag(prefix, tag_name)
	SyntaxPlusSingleton.unregister_node(self)
	
	if is_instance_valid(dm_instance_manager):
		dm_instance_manager.clean_up()
	dm_instance_manager = null
	
	instance = null

func _on_tool_menu_pressed():
	new_gui_instance()

func new_gui_instance():
	var ins = dm_instance_manager.new_freeable_dock_manager(PLUGIN_EXPORT_GUI, DockManager.Slot.MAIN_SCREEN)
	ins.allow_scene_reload = true
	return ins

func _add_syntax_comment_tags():
	for tag in COMMENT_TAGS:
		var prefix = tag.get_slice(" ", 0)
		var tag_name = tag.get_slice(" ", 1)
		SyntaxPlusSingleton.register_comment_tag(prefix, tag_name)

func _register_editor_console():
	EditorConsoleSingleton.register_temp_scope("plugin_exporter", ConsoleCommand.new())
