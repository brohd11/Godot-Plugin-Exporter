extends RefCounted

const BACKPORTED = false

enum ToastSeverity{
	INFO,
	WARNING,
	ERROR
}
static func push_toast(message, severity:ToastSeverity=ToastSeverity.INFO, print=true):
	var sev = severity #as int
	print(message)
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
	var root = _EIBackport.get_ins().ei.get_edited_scene_root()
	if target == null:
		target = root
	var dummy = Node3D.new()
	target.add_child(dummy)
	dummy.owner = root
	dummy.queue_free()


static func get_editor_node_path(node):
	var editor_scene_root = _EIBackport.get_ins().ei.get_edited_scene_root()
	if node == editor_scene_root or node.owner == editor_scene_root:
		var path:NodePath = editor_scene_root.get_path_to(node)
		return path
	return null


static func get_editor_node_by_path(node_path):
	var editor_scene_root = _EIBackport.get_ins().ei.get_edited_scene_root()
	if not node_path is NodePath:
		node_path = NodePath(node_path)
	if editor_scene_root.has_node(node_path):
		var node = editor_scene_root.get_node(node_path)
		return node
	return null

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_u_editor = "res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/u_editor.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
