extends Node

const NODE_NAME = "EIBackport"
var ei

static func get_ins():
	var root = Engine.get_main_loop().root
	var instance = root.get_node_or_null(NODE_NAME)
	
	if not is_instance_valid(instance):
		var plugin = EditorPlugin.new()
		root.add_child(plugin)
		instance = new(plugin)
		instance.name = NODE_NAME
		root.add_child(instance)
		plugin.queue_free()
	
	return instance



static func reset_instance(re_instance:bool=true):
	var root = Engine.get_main_loop().root
	if root.has_node(NODE_NAME):
		var ins = root.get_node(NODE_NAME)
	
	if re_instance:
		get_ins()

func _init(plugin:EditorPlugin):
	var engine_version = Engine.get_version_info()
	if engine_version.minor < 2:
		ei = plugin.get_editor_interface()
	else:
		ei = EditorInterface


func is_part_of_edited_scene_compat(node_to_check:Node):
	var ed_scene_root:Node = ei.get_edited_scene_root()
	if not is_instance_valid(ed_scene_root):
		return false
	if ed_scene_root.is_ancestor_of(node_to_check):
		return true
	return false

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_ei_backport = "res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
