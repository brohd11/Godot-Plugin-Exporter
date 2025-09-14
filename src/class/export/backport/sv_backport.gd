extends Node

const NODE_NAME = "StaticVarBackport"
#var _instance = null

# The central data store.
# Structure: { "script_path": { "var_name": value } }
var data_store: Dictionary = {}


static func get_ins():
	var root = Engine.get_main_loop().root
	var instance = root.get_node_or_null(NODE_NAME)
	
	if not is_instance_valid(instance):
		instance = new()
		instance.name = NODE_NAME
		root.add_child(instance)
		
	return instance

# INSTANCE METHODS (called on the singleton instance)
func get_var(script_path: String, var_name: String, default_value):
	if not data_store.has(script_path):
		data_store[script_path] = {}
	
	if not data_store[script_path].has(var_name):
		data_store[script_path][var_name] = default_value
	
	return data_store[script_path][var_name]

func set_var(script_path: String, var_name: String, new_value):
	if not data_store.has(script_path):
		data_store[script_path] = {}
	
	data_store[script_path][var_name] = new_value
