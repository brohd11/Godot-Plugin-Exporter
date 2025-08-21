extends RefCounted

const DOCK_POPUP = preload("dock_popup.tscn")
#const DockPopup = preload("res://addons/addon_lib/brohd/dock_manager/dock_popup/dock_popup.gd")

const FREE_VALUE = 20

signal handled(arg)

var dock_popup

func _init(node) -> void:
	dock_popup = DOCK_POPUP.instantiate()
	dock_popup.hide()
	var window = node.get_window()
	if window == EditorInterface.get_base_control().get_window():
		EditorInterface.get_base_control().add_child(dock_popup)
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












