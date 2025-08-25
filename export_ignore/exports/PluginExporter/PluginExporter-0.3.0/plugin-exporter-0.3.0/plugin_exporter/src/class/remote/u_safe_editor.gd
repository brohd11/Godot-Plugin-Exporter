extends RefCounted

static func get_editor_interface():
	var ed_interface = Engine.get_singleton(&"EditorInterface")
	if ed_interface:
		return ed_interface
	return null


static func scan_files():
	var editor_interface = get_editor_interface()
	if not editor_interface:
		return
	editor_interface.get_resource_filesystem().scan()


static func get_edited_scene_root():
	var editor_interface = get_editor_interface()
	if not editor_interface:
		return
	return editor_interface.get_edited_scene_root()


enum ToastSeverity{
	INFO,
	WARNING,
	ERROR
}
static func push_toast(message, severity:ToastSeverity=ToastSeverity.INFO, print=true):
	var editor_interface = get_editor_interface()
	if not editor_interface:
		return
	var sev = severity as int
	editor_interface.get_editor_toaster().push_toast(message, sev)
	if print == true:
		if sev == 0:
			print(message)
		elif sev == 1:
			print_warn(message)
		elif sev == 2:
			printerr(message)

static func print_warn(message):
	print_rich("[color=#fedd66]Warning: %s[/color]" % message)

static func dummy_node(target=null):
	var editor_interface = get_editor_interface()
	if not editor_interface:
		return
	var root = editor_interface.get_edited_scene_root()
	if target == null:
		target = root
	var dummy = Node3D.new()
	target.add_child(dummy)
	dummy.owner = root
	dummy.queue_free()


static func get_script_editor() -> CodeEdit:
	var editor_interface = get_editor_interface()
	if not editor_interface:
		return
	var se = editor_interface.get_script_editor()
	if se:
		var current_editor = se.get_current_editor()
		if current_editor:
			return current_editor.get_base_editor()
	return


static func get_editor_node_path(node):
	var editor_interface = get_editor_interface()
	if not editor_interface:
		return
	var editor_scene_root = editor_interface.get_edited_scene_root()
	if node == editor_scene_root or node.owner == editor_scene_root:
		var path:NodePath = editor_scene_root.get_path_to(node)
		return path
	return null


static func get_editor_node_by_path(node_path):
	var editor_interface = get_editor_interface()
	if not editor_interface:
		return
	var editor_scene_root = editor_interface.get_edited_scene_root()
	if node_path is not NodePath:
		node_path = NodePath(node_path)
	if editor_scene_root.has_node(node_path):
		var node = editor_scene_root.get_node(node_path)
		return node
	return null



