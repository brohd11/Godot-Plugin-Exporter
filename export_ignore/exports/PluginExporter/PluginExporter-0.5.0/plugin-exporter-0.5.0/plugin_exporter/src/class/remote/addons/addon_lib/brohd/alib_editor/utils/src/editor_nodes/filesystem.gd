extends RefCounted

const node = preload("res://addons/plugin_exporter/src/class/remote/addons/addon_lib/brohd/alib_runtime/utils/src/u_node.gd")

class PopupNode extends Node:
	pass
class DialogsNode extends Node:
	pass
static var dialogs_node:DialogsNode
static var popup_node:PopupNode

static func get_dialogs():
	if is_instance_valid(dialogs_node):
		return dialogs_node
	else:
		var nodes = node.recursive_get_nodes(EditorInterface.get_file_system_dock())
		for n in nodes:
			if n is DialogsNode:
				dialogs_node = n
				return n
		
		printerr("Error getting FileSystem Dialogs.")

static func get_tree():
	var tree = EditorInterface.get_file_system_dock().get_child(3).get_child(0)
	if tree is not Tree:
		tree = EditorInterface.get_file_system_dock().get_child(2).get_child(0)
	if tree is Tree:
		return tree
	else:
		printerr("Error getting FileSystem Tree.")

static func get_tree_line_edit():
	var tree = get_tree()
	var line = tree.get_child(1, true).get_child(0, true).get_child(0, true)
	if line is LineEdit:
		return line
	else:
		print("Not a line edit.")

static func populate_popup(calling_node:Control):
	get_popup()
	if calling_node.get_window() != popup_node.get_window():
		popup_node.reparent(calling_node.get_window().get_child(0))
	var tree = get_tree() as Tree
	tree.item_mouse_selected.emit(Vector2.ZERO, 2)
	var popup = popup_node.get_child(0)
	popup.hide()
	popup_node.reparent(EditorInterface.get_file_system_dock())

static func get_popup():
	if is_instance_valid(popup_node):
		return popup_node.get_child(0)
	else:
		var nodes = node.recursive_get_nodes(EditorInterface.get_file_system_dock())
		for n in nodes:
			if n is PopupNode:
				popup_node = n
				return n.get_child(0)
		
		printerr("Error getting FileSystem Popup.")

static func reset_dialogs():
	if is_instance_valid(dialogs_node):
		dialogs_node.reparent(EditorInterface.get_file_system_dock())


static func scan_fs_dock(FileSystemItemDict, FileDataDict, preview_object=null):
	FileSystemItemDict.clear()
	FileDataDict.clear()
	var EditorResSys = EditorInterface.get_resource_filesystem()
	var fs_tree: Tree = get_tree()
	if not fs_tree:
		printerr("FileSystemDock Tree not found.")
		return
	var root: TreeItem = fs_tree.get_root()
	if not root:
		printerr("FileSystemDock Tree has no root item.")
		return
	
	_recursive_scan_tree_item(root, FileSystemItemDict, FileDataDict, EditorResSys, preview_object)

static func _recursive_scan_tree_item(item: TreeItem, FileSystemItemDict, FileDataDict, EditorResSys, preview_object=null):
	if item == null:
		return
	var file_path = item.get_metadata(0)
	if file_path != null:
		if file_path.ends_with("/") and not file_path == "res://":
			file_path = file_path.trim_suffix("/")
		FileSystemItemDict[file_path] = item
		
		var icon = item.get_icon(0)
		var file_type = EditorResSys.get_file_type(file_path)
		if file_type == "":
			file_type = "Folder"
		
		#print(file_type)
		var file_data = {
			"item_path": file_path,
			"File Icon": icon,
			"File Type": file_type,
			"File Custom Icon": false,
		}
		if preview_object != null:
			EditorInterface.get_resource_previewer().queue_resource_preview(file_path, preview_object, "_receive_previews", file_data)
		FileDataDict[file_path] = file_data
		
	
	var child: TreeItem = item.get_first_child()
	while child != null:
		_recursive_scan_tree_item(child, FileSystemItemDict, FileDataDict, EditorResSys, preview_object)
		child = child.get_next() # Move to the next sibling

