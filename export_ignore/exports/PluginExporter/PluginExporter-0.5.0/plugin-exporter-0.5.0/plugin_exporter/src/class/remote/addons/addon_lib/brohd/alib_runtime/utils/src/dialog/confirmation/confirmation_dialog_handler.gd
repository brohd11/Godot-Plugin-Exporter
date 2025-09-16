@tool

extends "res://addons/plugin_exporter/src/class/remote/addons/addon_lib/brohd/alib_runtime/utils/src/dialog/handler_base.gd"

var cancel_button:Button

func _init(dialog_text, _root_node=null) -> void:
	_set_root_node(_root_node)
	_create_dialog(dialog_text)



func _create_dialog(dialog_text) -> void:
	dialog = ConfirmationDialog.new()
	dialog.confirmed.connect(_on_confirmed)
	dialog.canceled.connect(_on_canceled)
	
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	cancel_button = dialog.get_cancel_button()
	
	var ok_button = dialog.get_ok_button()
	ok_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var label = dialog.get_label()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	dialog.dialog_text = dialog_text
	root_node.add_child(dialog)
	dialog.show()
	
	ok_button.focus_mode = Control.FOCUS_NONE
	cancel_button.focus_mode = Control.FOCUS_NONE

func is_acknowledge():
	cancel_button.hide()

func non_exclusive():
	dialog.exclusive = false

func _on_confirmed():
	self.handled.emit(true)
	dialog.queue_free()
	
func _on_canceled():
	self.handled.emit(false)
	dialog.queue_free()

