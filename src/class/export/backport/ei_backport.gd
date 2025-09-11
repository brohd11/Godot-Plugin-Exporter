extends Node

const SELF_CLASS = preload("res://addons/plugin_exporter/src/class/export/backport/ei_backport.gd")

const NODE_NAME = "EIBackport"
var ei

static func get_ins() -> SELF_CLASS:
	var root = Engine.get_main_loop().root
	if not root.has_node(NODE_NAME):
		var plugin = EditorPlugin.new()
		root.add_child(plugin)
		var ins = new(plugin)
		ins.name = NODE_NAME
		root.add_child(ins)
		plugin.queue_free()
		return ins
	else:
		var ins = root.get_node(NODE_NAME)
		return ins


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
	if ed_scene_root.is_ancestor_of(node_to_check):
		return true
	return false
