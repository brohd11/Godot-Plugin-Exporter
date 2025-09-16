
extends RefCounted

static func get_current_script_editor():
	return EditorInterface.get_script_editor().get_current_editor()
static func get_current_script():
	return EditorInterface.get_script_editor().get_current_script()


static func get_popup():
	var current = get_current_script_editor()
	if not is_instance_valid(current):
		return
	if UVersion.get_minor_version() <= 4: #4.4
		return current.get_child(1)
	elif UVersion.get_minor_version() == 5:
		return current.get_child(2)


static func get_menu_bar():
	var script_editor = get_current_script_editor()
	var minor = UVersion.get_minor_version()
	if minor == 4 or minor == 5: #4.4
		return script_editor.get_parent().get_parent().get_parent().get_parent().get_child(0)


static func get_syntax_hl_popup() -> PopupMenu:
	var menu_bar = get_menu_bar()
	var menu_hboxes = menu_bar.get_children()
	var menu_hbox:HBoxContainer
	for child in menu_hboxes:
		if child.visible and child is HBoxContainer:
			menu_hbox = child
	
	var menu_popup:PopupMenu
	var menu_buttons = menu_hbox.get_children()
	var minor = UVersion.get_minor_version()
	for button:MenuButton in menu_buttons:
		var popup = button.get_popup()
		if minor == 4 or minor == 5:
			if popup.get_child_count() == 5:
				menu_popup = popup
				break
	if not menu_popup:
		#print("Could not find edit menu popup.")
		return
	var syntax_popup = menu_popup.get_child(menu_popup.get_child_count() - 1) as PopupMenu
	return syntax_popup



### Plugin Exporter Global Classes
const UVersion = preload("res://addons/plugin_exporter/src/class/remote/addons/addon_lib/brohd/alib_runtime/utils/src/u_version.gd")
### Plugin Exporter Global Classes

