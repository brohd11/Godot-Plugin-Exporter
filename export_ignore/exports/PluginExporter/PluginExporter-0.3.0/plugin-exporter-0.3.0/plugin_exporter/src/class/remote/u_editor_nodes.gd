extends RefCounted

const Docks = preload("docks.gd") #>import docks.gd
const BottomPanel = preload("bottom_panel.gd") #>import bottom_panel.gd
const MainScreen = preload("main_screen.gd") #>import main_screen.gd
const FileSystem = preload("filesystem.gd") #>import filesystem.gd

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












