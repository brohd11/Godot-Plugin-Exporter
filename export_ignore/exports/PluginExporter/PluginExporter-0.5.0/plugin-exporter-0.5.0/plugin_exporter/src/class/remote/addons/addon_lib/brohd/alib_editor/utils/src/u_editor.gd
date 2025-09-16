extends RefCounted

const BACKPORTED = false

enum ToastSeverity{
	INFO,
	WARNING,
	ERROR
}
static func push_toast(message, severity:ToastSeverity=ToastSeverity.INFO, print=true):
	var sev = severity #as int
	EditorInterface.get_editor_toaster().push_toast(message, sev)
	if print == true and not BACKPORTED:
		if sev == 0:
			print(message)
		elif sev == 1:
			print_warn(message)
		elif sev == 2:
			printerr(message)

static func print_warn(message):
	print_rich("[color=#fedd66]Warning: %s[/color]" % message)

static func dummy_node(target=null):
	var root = EditorInterface.get_edited_scene_root()
	if target == null:
		target = root
	var dummy = Node3D.new()
	target.add_child(dummy)
	dummy.owner = root
	dummy.queue_free()


static func get_editor_node_path(node):
	var editor_scene_root = EditorInterface.get_edited_scene_root()
	if node == editor_scene_root or node.owner == editor_scene_root:
		var path:NodePath = editor_scene_root.get_path_to(node)
		return path
	return null


static func get_editor_node_by_path(node_path):
	var editor_scene_root = EditorInterface.get_edited_scene_root()
	if node_path is not NodePath:
		node_path = NodePath(node_path)
	if editor_scene_root.has_node(node_path):
		var node = editor_scene_root.get_node(node_path)
		return node
	return null

