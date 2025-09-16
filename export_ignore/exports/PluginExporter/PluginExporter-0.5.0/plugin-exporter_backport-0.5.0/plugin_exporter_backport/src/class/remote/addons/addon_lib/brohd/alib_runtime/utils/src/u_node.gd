extends RefCounted

static func recursive_set_owner(node:Node, current_root:Node, new_root:Node) -> void:
	if node.owner == current_root:
		node.owner = new_root
	
	if node.get_child_count() > 0:
		var children = node.get_children()
		for c in children:
			recursive_set_owner(c, current_root, new_root)


static func recursive_get_nodes(node: Node) -> Array:
	var children_array = []
	children_array.append(node) # Add the current node to the array
	
	if node.get_child_count() > 0:
		var children = node.get_children()
		for c in children:
			var child_nodes = recursive_get_nodes(c) 
			children_array += child_nodes 
	
	return children_array


static func find_first_node_of_type(node: Node3D,type:Variant):
	if is_instance_of(node, type):
		return node 
	
	for child in node.get_children():
		if not child is Node3D:
			continue
		var next_node = find_first_node_of_type(child, type)
		if next_node:
			return next_node
	
	return null  # No node of type found in this branch


static func connect_signal(callable:Callable, _signal:Signal):
	if not _signal.is_connected(callable):
		_signal.connect(callable)

static func disconnect_signal(callable:Callable, _signal:Signal):
	if _signal.is_connected(callable):
		_signal.disconnect(callable)


### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_u_node = "res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_runtime/utils/src/u_node.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
