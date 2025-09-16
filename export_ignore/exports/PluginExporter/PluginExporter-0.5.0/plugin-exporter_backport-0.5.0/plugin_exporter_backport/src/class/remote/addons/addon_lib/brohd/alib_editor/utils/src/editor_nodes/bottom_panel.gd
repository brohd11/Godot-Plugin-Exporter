extends RefCounted

static func get_bottom_panel() -> Control:
	var base = _EIBackport.get_ins().ei.get_base_control()
	var bp = base.get_child(0).get_child(1).get_child(1).get_child(1).get_child(0).get_child(0).get_child(1)
	var vbox = bp.get_child(0)
	return vbox

static func get_button_top_hbox():
	var bp = get_bottom_panel()
	var bp_children = bp.get_children()
	bp_children.reverse()
	var hbox = null
	for control in bp_children:
		var nested_children = control.get_children()
		for nc in nested_children:
			if nc.get_class() == "EditorToaster":
				hbox = control
				break
		if is_instance_valid(hbox):
			break
	return hbox

static func get_button_hbox():
	var hbox = get_button_top_hbox()
	var buttons_hbox = hbox.get_child(1).get_child(0, true)
	return buttons_hbox

static func get_panel(_class_name):
	var bottom_panel = get_bottom_panel()
	for p in bottom_panel.get_children():
		if p.get_class() == _class_name:
			return p
	push_error("Could not find %s" % _class_name)

static func show_first_panel():
	var hbox = get_button_hbox()
	for c in hbox.get_children():
		if not c is Button:
			continue
		if c.visible:
			c.toggled.emit(true)
			#c.toggled.emit(false)
			break

static func get_filter_line_edit():
	var editor_log = get_panel("EditorLog")
	var vbox = editor_log.get_child(1)
	var line_edit = vbox.get_child(1)
	return line_edit


### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_bottom_panel = "res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/editor_nodes/bottom_panel.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
