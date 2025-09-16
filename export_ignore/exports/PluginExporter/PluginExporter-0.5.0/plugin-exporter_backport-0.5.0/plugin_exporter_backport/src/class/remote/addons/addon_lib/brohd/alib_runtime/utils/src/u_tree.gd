extends RefCounted

static func get_all_children_items(tree_item:TreeItem) -> Array[TreeItem]:
	return _get_all_children_items(tree_item)
static func get_all_visible_children_items(tree_item:TreeItem) -> Array[TreeItem]:
	return _get_all_children_items(tree_item, true)
static func _get_all_children_items(tree_item:TreeItem, limit_to_visible:=false) -> Array[TreeItem]:
	var items:Array[TreeItem] = []
	if not tree_item:
		return items
	if tree_item.get_child_count() > 0:
		var children:Array[TreeItem] = tree_item.get_children()
		for c in children:
			if limit_to_visible:
				if c.visible:
					items.append(c)
					items.append_array(_get_all_children_items(c, limit_to_visible))
			else:
				items.append(c)
				items.append_array(_get_all_children_items(c, limit_to_visible))
		
	return items


static func check_filter(text:String, filter_text:String) -> bool:
	if filter_text == "":
		return true # true == don't hide
	text = text.to_lower()
	if text.find(filter_text) > -1:
		return true
	return false

static func check_filter_split(text:String, filter_text:String) -> bool:
	if filter_text == "":
		return true # true == don't hide
	text = text.to_lower()
	var f_split := filter_text.split(" ", false)
	for s in f_split:
		if text.find(s) == -1:
			return false
	return true

static func uncollapse_items(items:Array, item_collapsed_callable:Callable):
	for item in items:
		var parent = item.get_parent()
		while parent:
			parent.collapsed = false
			item_collapsed_callable.call(parent)
			parent = parent.get_parent()

static func get_click_data_standard(selected_items):
	var right_click_data = []
	for i in selected_items:
		right_click_data.append(i)
		var child_items = get_all_visible_children_items(i)
		right_click_data.append_array(child_items)
	
	var item_data_array = []
	for item in right_click_data:
		var data = item.get_metadata(0)
		if not data:
			continue
		item_data_array.append(data)
	
	return item_data_array


class get_drop_data:
	static func files(selected_item_paths, from_node):
		var selected_paths = []
		for path in selected_item_paths:
			if path.get_extension() != "":
				selected_paths.append(path)
		var data = {"type":"files", "files":selected_paths, "from":from_node}
		
		return data

class can_drop_data:
	static func files(at_position: Vector2, data: Variant, extensions:Array=[]) -> bool:
		var type = data.get("type")
		if type == "files":
			if extensions == []:
				return true
			var files = data.get("files")
			for f in files:
				var ext = f.get_extension()
				if ext in extensions:
					return true
		return false


### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_u_tree = "res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_runtime/utils/src/u_tree.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
