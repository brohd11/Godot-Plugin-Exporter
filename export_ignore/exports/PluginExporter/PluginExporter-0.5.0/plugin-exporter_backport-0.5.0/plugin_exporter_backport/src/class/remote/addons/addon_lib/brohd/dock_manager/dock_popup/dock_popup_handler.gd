extends RefCounted

const DOCK_POPUP = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/dock_manager/dock_popup/dock_popup.tscn")

const FREE_VALUE = 20

signal handled(arg)

var dock_popup

func _init(node) -> void:
	dock_popup = DOCK_POPUP.instantiate()
	dock_popup.hide()
	var window = node.get_window()
	if window == _EIBackport.get_ins().ei.get_base_control().get_window():
		_EIBackport.get_ins().ei.get_base_control().add_child(dock_popup)
	else:
		window.get_child(0).add_child(dock_popup)
		dock_popup.hide_make_floating()
	
	var popup_pos = DisplayServer.mouse_get_position() - (dock_popup.size / 2)
	dock_popup.position = popup_pos
	
	if window.current_screen == 0: ##prefer manual hide and show for slow machines
		dock_popup.popup(Rect2i(popup_pos, dock_popup.size))
	
	dock_popup.show()
	dock_popup.handled.connect(_on_handled)

func disable_main_screen():
	dock_popup.disable_main_screen()

func can_be_freed():
	dock_popup.can_be_freed()

func _on_handled(arg):
	handled.emit(arg)

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_dock_popup_handler = "res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/dock_manager/dock_popup/dock_popup_handler.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
