extends Node

const NODE_NAME = "EIBackport"
var ei

static func get_ins() -> Node:
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
