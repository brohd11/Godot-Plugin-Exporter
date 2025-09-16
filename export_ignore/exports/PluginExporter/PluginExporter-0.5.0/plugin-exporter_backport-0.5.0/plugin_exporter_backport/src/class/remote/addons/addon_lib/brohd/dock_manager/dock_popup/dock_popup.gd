@tool
extends PopupPanel

const CANCEL_STRING = "CANCEL_STRING"

@onready var left_ul: Button = %LeftUL
@onready var left_bl: Button = %LeftBL
@onready var left_ur: Button = %LeftUR
@onready var left_br: Button = %LeftBR
@onready var main_screen: Button = %MainScreen
@onready var bottom_panel: Button = %BottomPanel
@onready var right_ul: Button = %RightUL
@onready var right_bl: Button = %RightBL
@onready var right_ur: Button = %RightUR
@onready var right_br: Button = %RightBR
@onready var make_floating_button: Button = %MakeFloatingButton
@onready var free_instance_button: Button = %FreeInstanceButton

var timer:Timer
var _mouse_in_panel := true

var option_chosen := false

signal handled(arg)

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	popup_hide.connect(_on_popup_hide)
	
	timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.8
	timer.one_shot = true
	
	left_ul.pressed.connect(_button_pressed.bind(0))
	left_bl.pressed.connect(_button_pressed.bind(1))
	left_ur.pressed.connect(_button_pressed.bind(2))
	left_br.pressed.connect(_button_pressed.bind(3))
	main_screen.pressed.connect(_button_pressed.bind(-1))
	bottom_panel.pressed.connect(_button_pressed.bind(-2))
	right_ul.pressed.connect(_button_pressed.bind(4))
	right_bl.pressed.connect(_button_pressed.bind(5))
	right_ur.pressed.connect(_button_pressed.bind(6))
	right_br.pressed.connect(_button_pressed.bind(7))
	
	make_floating_button.pressed.connect(_button_pressed.bind(-3))
	free_instance_button.pressed.connect(_button_pressed.bind(20))
	
	if not _EIBackport.get_ins().is_part_of_edited_scene_compat(self):
		make_floating_button.icon = _EIBackport.get_ins().ei.get_base_control().get_theme_icon("MakeFloating", &"EditorIcons")
		free_instance_button.icon = _EIBackport.get_ins().ei.get_base_control().get_theme_icon("Clear", &"EditorIcons")
		

func disable_main_screen():
	main_screen.disabled = true

func hide_make_floating():
	size.y = size.y - make_floating_button.size.y
	make_floating_button.hide()

func can_be_freed():
	size.y = size.y + free_instance_button.size.y
	free_instance_button.show()

func _button_pressed(chosen):
	option_chosen = true
	handled.emit(chosen)
	hide_and_free()

func _on_mouse_entered():
	_mouse_in_panel = true
	if not timer.is_stopped():
		timer.timeout.emit()
	timer.stop()

func _on_mouse_exited():
	if option_chosen:
		return
	_mouse_in_panel = false
	timer.start()
	await timer.timeout
	if _mouse_in_panel:
		return
	
	handled.emit(CANCEL_STRING)
	hide_and_free()

func _on_popup_hide():
	hide_and_free()

func hide_and_free():
	hide()
	queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		pass


### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_dock_popup = "res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/dock_manager/dock_popup/dock_popup.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
