extends RefCounted

const CANCEL_STRING = "DIALOG_CANCELLED"
const cancel_string = CANCEL_STRING

var root_node
var dialog

signal handled(status)


func _set_root_node(_root_node):
	if _root_node == null:
		if Engine.is_editor_hint():
			var ed_int = Engine.get_singleton("EditorInterface")
			_root_node = ed_int.get_base_control()
		else:
			_root_node = Engine.get_main_loop().root
	root_node = _root_node

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(dialog):
			dialog.queue_free()


### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_handler_base = "res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_runtime/utils/src/dialog/handler_base.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
