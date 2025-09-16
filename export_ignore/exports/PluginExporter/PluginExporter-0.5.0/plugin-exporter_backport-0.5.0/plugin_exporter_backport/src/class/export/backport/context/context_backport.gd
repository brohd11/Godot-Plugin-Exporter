extends Node

const ScriptEd = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/editor_nodes/script_editor.gd")

const NODE_NAME = "EditorContextPluginBackport"

# {target_popup: plugin}
var plugins = {}
# { 4 : popup}
var popups = {}
var submenus = []

var popup_temp_data = {}
var base_id = 5000

var script_editor_code_popup:PopupMenu

static func get_instance():
	var root = Engine.get_main_loop().root
	var instance = root.get_node_or_null(NODE_NAME)
	
	if not is_instance_valid(instance):
		instance = new()
		instance.name = NODE_NAME
		root.add_child(instance)
	
	return instance

func _ready() -> void:
	_EIBackport.get_ins().ei.get_script_editor().editor_script_changed.connect(_set_script_editor_popup)
	_set_script_editor_popup(null)
	plugins[4] = []
	


static func add_context_menu_plugin(target_slot, plugin):
	var instance = get_instance()
	if not instance.plugins.has(target_slot):
		instance.plugins[target_slot] = []
	
	instance.add_child.call_deferred(plugin)
	instance.plugins[target_slot].append(plugin)

static func remove_context_menu_plugin(plugin):
	var instance = get_instance()
	var target_array:Array
	for array in instance.plugins.values():
		for i in array:
			if i == plugin:
				target_array = array
	
	if target_array != null:
		var idx = target_array.find(plugin)
		target_array.remove_at(idx)
		plugin.queue_free()
	else:
		printerr("Could not find context compat plugin to remove.")


static func get_plugin_slot(plugin):
	var instance = get_instance()
	var target_slot = -1
	for slot in instance.plugins.keys():
		var array = instance.plugins.get(slot)
		for i in array:
			if i == plugin:
				target_slot = slot
				break
	
	return target_slot


func add_popup_item(plugin_ins, _name, callable, icon=null):
	var target_slot = get_plugin_slot(plugin_ins)
	var target_popup = popups.get(target_slot)
	if target_popup == null:
		printerr("Error getting context compat popup: %s" % target_slot)
		return
	
	if not target_popup.id_pressed.is_connected(_on_popup_clicked):
		target_popup.id_pressed.connect(_on_popup_clicked)
	if not target_popup.popup_hide.is_connected(_on_target_popup_hide):
		target_popup.popup_hide.connect(_on_target_popup_hide.bind(target_popup, _on_popup_clicked))
	
	if icon:
		target_popup.add_icon_item(icon, _name, base_id)
	else:
		target_popup.add_item(_name, base_id)
	
	popup_temp_data[base_id] = callable
	base_id += 1

func add_popup_submenu(plugin_ins, _name, submenu, icon=null):
	var target_slot = get_plugin_slot(plugin_ins)
	var target_popup = popups.get(target_slot)
	if target_popup == null:
		printerr("Error getting context compat popup: %s" % target_slot)
		return
	target_popup = target_popup as PopupMenu
	
	if not target_popup.popup_hide.is_connected(_on_target_popup_hide):
		target_popup.popup_hide.connect(_on_target_popup_hide.bind(target_popup, _on_popup_clicked))
	
	submenu.name = _name
	target_popup.add_child(submenu)
	target_popup.add_submenu_item(_name, _name, base_id)
	submenus.append(submenu)
	base_id += 1


func _on_popup_clicked(id):
	if id < base_id:
		return
	var callable = popup_temp_data.get(id)
	if callable != null:
		# get node path and pass
		callable.call()
	else:
		printerr("Error getting callable, id pressed: %s" % id)

func _on_target_popup_hide(popup:PopupMenu, old_callable):
	base_id = 5000
	if popup.id_pressed.is_connected(old_callable):
		await get_tree().process_frame
		popup.id_pressed.disconnect(old_callable)
	
	for submenu in submenus:
		submenu.queue_free()
	submenus.clear()





func _set_script_editor_popup(script):
	if is_instance_valid(script_editor_code_popup):
		if script_editor_code_popup.about_to_popup.is_connected(_on_script_editor_popup_about_to_popup):
			script_editor_code_popup.about_to_popup.disconnect(_on_script_editor_popup_about_to_popup)
	script_editor_code_popup = ScriptEd.get_popup()
	if not is_instance_valid(script_editor_code_popup):
		return
	popups[4] = script_editor_code_popup
	script_editor_code_popup.about_to_popup.connect(_on_script_editor_popup_about_to_popup)


func _on_script_editor_popup_about_to_popup():
	var root = Engine.get_main_loop().root
	var node_path = root.get_path_to(_EIBackport.get_ins().ei.get_script_editor().get_current_editor().get_base_editor())
	var script_editor_plugins = plugins.get(4, [])
	for plugin in script_editor_plugins:
		plugin._popup_menu([node_path])
	

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_context_backport = "res://addons/plugin_exporter_backport/src/class/export/backport/context/context_backport.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
