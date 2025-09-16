extends Node

const _ContextBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/context/context_backport.gd")


func _popup_menu(paths: PackedStringArray) -> void: # give node path to desired node from root
	
	pass


func add_context_menu_item(_name, callback, icon=null):
	_ContextBackport.get_instance().add_popup_item(self, _name, callback, icon)

func add_context_submenu_item(_name, submenu, icon=null):
	_ContextBackport.get_instance().add_popup_submenu(self, _name, submenu, icon)

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_context_plugin_compat = "res://addons/plugin_exporter_backport/src/class/export/backport/context/context_plugin_compat.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
