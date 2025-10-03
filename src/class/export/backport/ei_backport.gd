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
