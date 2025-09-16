extends RefCounted

const Docks = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/editor_nodes/docks.gd") #>import docks.gd
const BottomPanel = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/editor_nodes/bottom_panel.gd") #>import bottom_panel.gd
const MainScreen = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/editor_nodes/main_screen.gd") #>import main_screen.gd
const FileSystem = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/editor_nodes/filesystem.gd") #>import filesystem.gd

static func get_current_dock(control):
	var parent = control.get_parent()
	if not parent:
		print("Parent is null.")
		return
	if parent == Docks.get_left_ul():
		return EditorPlugin.DockSlot.DOCK_SLOT_LEFT_UL
	elif parent == Docks.get_left_bl():
		return EditorPlugin.DockSlot.DOCK_SLOT_LEFT_BL
	elif parent == Docks.get_left_ur():
		return EditorPlugin.DockSlot.DOCK_SLOT_LEFT_UR
	elif parent == Docks.get_left_br():
		return EditorPlugin.DockSlot.DOCK_SLOT_LEFT_BR
	elif parent == Docks.get_right_ul():
		return EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_UL
	elif parent == Docks.get_right_bl():
		return EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_BL
	elif parent == Docks.get_right_ur():
		return EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_UR
	elif parent == Docks.get_right_br():
		return EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_BR
	elif parent == BottomPanel.get_bottom_panel():
		return -2
	elif parent == MainScreen.get_main_screen():
		return -1
	else:
		return -3

static func get_current_dock_control(control):
	var parent = control.get_parent()
	if not parent:
		print("Parent is null.")
		return
	if parent is TabContainer:
		return parent
	elif parent == BottomPanel.get_bottom_panel():
		return parent
	elif parent == MainScreen.get_main_screen():
		return parent

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_u_editor_nodes = "res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/u_editor_nodes.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
