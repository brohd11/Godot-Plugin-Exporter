@tool
extends Node

const UName = preload("res://addons/plugin_exporter/src/class/remote/addons/addon_lib/brohd/alib_runtime/utils/src/u_name.gd")
const MainScreen = preload("res://addons/plugin_exporter/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/editor_nodes/main_screen.gd")

var editor_plugin:EditorPlugin
var main_screen_button:Button

var plugin_buttons = {}

func _init(_editor_plugin) -> void:
	editor_plugin = _editor_plugin
	
	_connect_buttons()
	var main_bar = MainScreen.get_button_container()
	main_bar.child_entered_tree.connect(_child_entered_tree)
	for child in main_bar.get_children():
		if String(child.name) == editor_plugin._get_plugin_name():
			main_screen_button = child
			main_screen_button.hide()
			break


func clean_up():
	if is_instance_valid(main_screen_button):
		main_screen_button.text = editor_plugin._get_plugin_name()
	
	for button in plugin_buttons.keys():
		if is_instance_valid(button):
			button.queue_free()

func _child_entered_tree(c):
	_connect_buttons()

func _connect_buttons():
	var main_bar = MainScreen.get_button_container()
	for button:Button in main_bar.get_children():
		if not button.pressed.is_connected(_on_main_screen_bar_button_pressed):
			button.pressed.connect(_on_main_screen_bar_button_pressed.bind(button))
	for child in EditorInterface.get_editor_main_screen().get_children():
		if child is Control:
			if not child.visibility_changed.is_connected(_on_main_screen_control_vis_changed):
				child.visibility_changed.connect(_on_main_screen_control_vis_changed.bind(child))

func _on_main_screen_control_vis_changed(main_screen_control):
	if not main_screen_control.visible:
		return
	if not main_screen_control in plugin_buttons.values():
		_on_main_screen_bar_button_pressed(MainScreen.get_button_container().get_child(0))
		return
	for button in plugin_buttons:
		var plugin_control = plugin_buttons.get(button)
		if plugin_control.get_parent() != EditorInterface.get_editor_main_screen():
			continue
		if main_screen_control != plugin_control and main_screen_control.visible:
			plugin_control.hide()

func _on_main_screen_bar_button_pressed(button:Button):
	if button == main_screen_button and main_screen_button.button_pressed:
		return
	if not button in plugin_buttons:
		main_screen_button.hide()
		main_screen_button.text = editor_plugin._get_plugin_name()
		for plugin_button in plugin_buttons.keys():
			var plugin_control = plugin_buttons.get(plugin_button)
			plugin_control.hide()
			plugin_button.show()
			plugin_button.text = String(plugin_control.name)
		return
	for plugin_button in plugin_buttons.keys():
		var plugin_control = plugin_buttons.get(plugin_button)
		if button != plugin_button:
			plugin_button.show()
			plugin_control.hide()
		else:
			var main_bar:HBoxContainer = MainScreen.get_button_container()
			var main_bar_children = main_bar.get_children()
			var idx = 0
			for c in main_bar_children:
				if c == plugin_button:
					break
				idx += 1
			
			main_bar.move_child(main_screen_button, idx)
			plugin_button.hide()
			plugin_control.show()
			main_screen_button.text = String(plugin_control.name)
			main_screen_button.icon = _get_control_icon(plugin_control)
			main_screen_button.show()
			EditorInterface.set_main_screen_editor.call_deferred(main_screen_button.text)

func add_main_screen_control(control):
	_add_main_screen_button(control)
	#EditorInterface.get_editor_main_screen().add_child(control)
	control.hide()

func _add_main_screen_button(control):
	var plugin_button = Button.new()
	var main_bar = MainScreen.get_button_container()
	var unique_name = UName.incremental_name_check_in_nodes(control.name, main_bar)
	control.name = unique_name
	plugin_button.name = unique_name
	plugin_button.text = unique_name
	EditorInterface.get_editor_main_screen().add_child(control)
	control.hide()
	plugin_button.icon = _get_control_icon(control)
	plugin_button.theme_type_variation = MainScreen.get_button_theme()
	
	main_bar.add_child(plugin_button)
	
	plugin_buttons[plugin_button] = control
	_connect_buttons()

func remove_main_screen_control(control):
	_remove_main_screen_button(control)
	EditorInterface.get_editor_main_screen().remove_child(control)
	EditorInterface.set_main_screen_editor("Script")

func _remove_main_screen_button(control):
	for plugin_button in plugin_buttons.keys():
		var plugin_control = plugin_buttons.get(plugin_button)
		if plugin_control != control:
			continue
		plugin_buttons.erase(plugin_button)
		plugin_button.queue_free()
		if is_instance_valid(main_screen_button):
			main_screen_button.hide()
			main_screen_button.text = editor_plugin._get_plugin_name()
		return

func _get_control_icon(panel_control):
	var plugin_base_control = panel_control.get_child(0)
	if "icon" in plugin_base_control: # change load method to allow for editor nodes
		return plugin_base_control.icon
	elif "plugin_icon" in plugin_base_control:
		return plugin_base_control.plugin_icon
	else:
		return EditorInterface.get_base_control().get_theme_icon("Node", &"EditorIcons")
	

