extends Node

const NODE_NAME = "EditorContextPluginBackport"

const SLOT_SCENE_TREE = EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE
const SLOT_SCENE_TABS = EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TABS
const SLOT_FILE_SYSTEM = EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM
const SLOT_FILE_SYSTEM_CREATE = EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM_CREATE
const SLOT_SCRIPT_EDITOR = EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR
const SLOT_SCRIPT_EDITOR_CODE = EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE
const SLOT_2D_EDITOR = EditorContextMenuPlugin.CONTEXT_SLOT_2D_EDITOR


# {target_popup: plugin}
var plugins = {}
# { 4 : popup}
var popups = {}
var submenus = []

var popup_temp_data = {}
var base_id = 5000

var script_editor_code_popup:PopupMenu
var script_editor_popup:PopupMenu

static func get_instance():
	var root = Engine.get_main_loop().root
	var instance = root.get_node_or_null(NODE_NAME)
	
	if not is_instance_valid(instance):
		instance = new()
		instance.name = NODE_NAME
		root.add_child(instance)
	
	return instance

func _ready() -> void:
	EditorNodeRef.call_on_ready(_set_nodes)

func _set_nodes():
	EditorNodeRef.get_instance().script_editor_updated.connect(_set_script_editor_references)
	
	_set_script_editor_references()
	_set_file_system_popup()
	_set_file_system_create_popup()
	_set_2d_editor_popup()
	_set_scene_tabs_popup()
	_set_scene_tree_popup()


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
		target_popup.id_pressed.connect(_on_popup_clicked.bind(target_slot))
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


func _on_popup_clicked(id, target_slot):
	if id < base_id:
		return
	var callable = popup_temp_data.get(id) as Callable
	if callable != null:
		var args = []
		
		if target_slot == SLOT_SCRIPT_EDITOR_CODE:
			args.append(EditorInterface.get_script_editor().get_current_editor().get_base_editor())
		elif target_slot == SLOT_SCRIPT_EDITOR:
			args.append(EditorInterface.get_script_editor().get_current_script())
		elif target_slot == SLOT_2D_EDITOR:
			args.append(null)
		elif target_slot == SLOT_FILE_SYSTEM:
			var current_paths  = EditorInterface.get_selected_paths()
			args.append(current_paths)
		elif target_slot == SLOT_FILE_SYSTEM_CREATE:
			var current_paths  = EditorInterface.get_selected_paths()
			args.append(current_paths)
		elif target_slot == SLOT_SCENE_TABS:
			args.append(get_current_scene_path())
		elif target_slot == SLOT_SCENE_TREE:
			args.append(_get_selected_node_paths())
		
		var bound_args = callable.get_bound_arguments()
		args.append_array(bound_args)
		callable.callv(args)
	else:
		printerr("Error getting callable, id pressed: %s" % id)

func _on_target_popup_hide(popup:PopupMenu, old_callable):
	base_id = 5000
	popup_temp_data.clear()
	if popup.id_pressed.is_connected(old_callable):
		await get_tree().process_frame
		popup.id_pressed.disconnect(old_callable)
	
	for submenu in submenus:
		submenu.queue_free()
	submenus.clear()


func _set_file_system_popup():
	var popup = EditorNodeRef.get_registered(EditorNodeRef.Nodes.FILESYSTEM_POPUP)
	if is_instance_valid(popup):
		popups[SLOT_FILE_SYSTEM] = popup
		popup.about_to_popup.connect(_on_file_system_about_to_popup)
	EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM

func _on_file_system_about_to_popup():
	var current_paths  = EditorInterface.get_selected_paths()
	_call_plugin_popup_menu(SLOT_FILE_SYSTEM, current_paths)


func _set_file_system_create_popup():
	var popup = EditorNodeRef.get_registered(EditorNodeRef.Nodes.FILESYSTEM_CREATE_POPUP)
	if is_instance_valid(popup):
		popups[SLOT_FILE_SYSTEM_CREATE] = popup
		popup.about_to_popup.connect(_on_file_system_create_about_to_popup)

func _on_file_system_create_about_to_popup() -> void:
	var current_paths  = EditorInterface.get_selected_paths()
	_call_plugin_popup_menu(SLOT_FILE_SYSTEM_CREATE, current_paths)


func _set_scene_tabs_popup():
	var popup = EditorNodeRef.get_registered(EditorNodeRef.Nodes.SCENE_TABS_POPUP)
	if is_instance_valid(popup):
		popups[SLOT_SCENE_TABS] = popup
		popup.about_to_popup.connect(_on_scene_tabs_about_to_popup)

func _on_scene_tabs_about_to_popup():
	var current_scene_path = get_current_scene_path()
	_call_plugin_popup_menu(SLOT_SCENE_TABS, [current_scene_path])


func _set_scene_tree_popup():
	var popup = EditorNodeRef.get_registered(EditorNodeRef.Nodes.SCENE_TREE_POPUP)
	if is_instance_valid(popup):
		popups[SLOT_SCENE_TREE] = popup
		popup.about_to_popup.connect(_on_scene_tree_about_to_popup)

func _on_scene_tree_about_to_popup():
	_call_plugin_popup_menu(SLOT_SCENE_TREE, _get_selected_node_paths())


func _set_2d_editor_popup(): # not working, maybe not worth it
	return
	var popup
	if is_instance_valid(popup):
		popups[SLOT_2D_EDITOR] = popup
		popup.about_to_popup.connect(_on_2d_editor_about_to_popup)

func _on_2d_editor_about_to_popup():
	_call_plugin_popup_menu(SLOT_2D_EDITOR, null)


func _set_script_editor_references():
	_set_script_editor_popup()
	_set_script_editor_code_popup()

func _set_script_editor_popup():
	## SCRIPT EDITOR CODE
	if is_instance_valid(script_editor_code_popup):
		if script_editor_code_popup.about_to_popup.is_connected(_on_script_editor_code_popup_about_to_popup):
			script_editor_code_popup.about_to_popup.disconnect(_on_script_editor_code_popup_about_to_popup)
	script_editor_code_popup = EditorNodeRef.get_registered(EditorNodeRef.Nodes.SCRIPT_EDITOR_CODE_POPUP)
	if not is_instance_valid(script_editor_code_popup):
		return
	popups[SLOT_SCRIPT_EDITOR_CODE] = script_editor_code_popup
	script_editor_code_popup.about_to_popup.connect(_on_script_editor_code_popup_about_to_popup)
func _set_script_editor_code_popup():
	## SCRIPT EDITOR FILE LIST
	if is_instance_valid(script_editor_popup):
		if script_editor_popup.about_to_popup.is_connected(_on_script_editor_popup_about_to_popup):
			script_editor_popup.about_to_popup.disconnect(_on_script_editor_popup_about_to_popup)
	script_editor_popup = EditorNodeRef.get_registered(EditorNodeRef.Nodes.SCRIPT_EDITOR_POPUP)
	if not is_instance_valid(script_editor_popup):
		return
	popups[SLOT_SCRIPT_EDITOR] = script_editor_popup
	script_editor_popup.about_to_popup.connect(_on_script_editor_popup_about_to_popup)


func _on_script_editor_code_popup_about_to_popup():
	var root = Engine.get_main_loop().root
	var node_path = root.get_path_to(EditorInterface.get_script_editor().get_current_editor().get_base_editor())
	_call_plugin_popup_menu(SLOT_SCRIPT_EDITOR_CODE, [node_path])


func _on_script_editor_popup_about_to_popup():
	var current_script_path = EditorInterface.get_script_editor().get_current_script().resource_path
	_call_plugin_popup_menu(SLOT_SCRIPT_EDITOR, [current_script_path])


func _call_plugin_popup_menu(slot, argument):
	var plugin_instances = plugins.get(slot, [])
	for plugin in plugin_instances:
		plugin._popup_menu(argument)


func _get_selected_node_paths():
	var current_selected_nodes = EditorInterface.get_selection().get_selected_nodes()
	var node_paths = []
	for node in current_selected_nodes:
		node_paths.append(get_editor_node_path(node))
	return node_paths

static func get_current_scene_path():
	var open_scenes = EditorInterface.get_open_scenes()
	var scene_tabs = EditorNodeRef.get_registered(EditorNodeRef.Nodes.SCENE_TABS)
	var tab_bar = scene_tabs.get_child(0).get_child(0).get_child(0) as TabBar
	var current_tab_name = tab_bar.get_tab_title(tab_bar.current_tab)
	for scene_path in open_scenes:
		var base_name = scene_path.get_basename()
		if base_name.ends_with(current_tab_name):
			return scene_path

static func get_editor_node_path(node):
	var editor_scene_root = EditorInterface.get_edited_scene_root()
	if node == editor_scene_root or node.owner == editor_scene_root:
		var path:NodePath = editor_scene_root.get_path_to(node)
		return path
	return null
