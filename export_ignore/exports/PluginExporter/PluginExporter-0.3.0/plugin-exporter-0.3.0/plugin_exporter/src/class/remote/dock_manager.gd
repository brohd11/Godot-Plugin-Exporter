@tool
extends Node

const UFile = preload("u_file.gd")
const DockPopupHandler = preload("dock_popup_handler.gd")
const Docks = preload("docks.gd")
const BottomPanel = preload("bottom_panel.gd")
const _MainScreenHandlerClass = preload("main_screen_handler.gd")
const MainScreenHandlerMultiClass = preload("main_screen_handler_multi.gd")
const PanelWindow = preload("panel_window.gd")

var MainScreenHandler #>class_inst
var external_main_screen_flag := false

var plugin:EditorPlugin
var plugin_control:Control
var dock_button:Button
var default_dock:int
var last_dock:int
var can_be_freed:bool

var _default_window_size:= Vector2i(1200,800)

enum Slot{
	FLOATING,
	BOTTOM_PANEL,
	MAIN_SCREEN,
	DOCK_SLOT_LEFT_UL,
	DOCK_SLOT_LEFT_BL,
	DOCK_SLOT_LEFT_UR,
	DOCK_SLOT_LEFT_BR,
	DOCK_SLOT_RIGHT_UL,
	DOCK_SLOT_RIGHT_BL,
	DOCK_SLOT_RIGHT_UR,
	DOCK_SLOT_RIGHT_BR,
}
const _slot = {
	Slot.FLOATING: -3,
	Slot.BOTTOM_PANEL: -2,
	Slot.MAIN_SCREEN: -1,
	Slot.DOCK_SLOT_LEFT_UL: EditorPlugin.DockSlot.DOCK_SLOT_LEFT_UL,
	Slot.DOCK_SLOT_LEFT_BL: EditorPlugin.DockSlot.DOCK_SLOT_LEFT_BL,
	Slot.DOCK_SLOT_LEFT_UR: EditorPlugin.DockSlot.DOCK_SLOT_LEFT_UR,
	Slot.DOCK_SLOT_LEFT_BR: EditorPlugin.DockSlot.DOCK_SLOT_LEFT_BR,
	Slot.DOCK_SLOT_RIGHT_UL: EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_UL,
	Slot.DOCK_SLOT_RIGHT_BL: EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_BL,
	Slot.DOCK_SLOT_RIGHT_UR: EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_UR,
	Slot.DOCK_SLOT_RIGHT_BR: EditorPlugin.DockSlot.DOCK_SLOT_RIGHT_BR,
}

signal free_requested(dock_manager)

static func hide_main_screen_button(_plugin):
	_MainScreenHandlerClass.hide_main_screen_button(_plugin)

func _init(_plugin:EditorPlugin, _control, _dock:Slot=Slot.BOTTOM_PANEL, 
_can_be_freed:=false, _main_screen_handler=null, add_to_tree:=true) -> void:
	plugin = _plugin
	if _control is Control:
		plugin_control = _control
	elif _control is PackedScene:
		plugin_control = _control.instantiate()
	
	default_dock = _slot.get(_dock)
	last_dock = default_dock
	can_be_freed = _can_be_freed
	
	if _main_screen_handler != null:
		MainScreenHandler = _main_screen_handler
		external_main_screen_flag = true
	
	if add_to_tree:
		post_init()

func post_init():
	plugin.add_child(plugin_control)
	await plugin.get_tree().process_frame
	plugin.remove_child(plugin_control)
	
	if "dock_button" in plugin_control:
		dock_button = plugin_control.dock_button
		dock_button.icon = EditorInterface.get_base_control().get_theme_icon("MakeFloating", &"EditorIcons")
		dock_button.pressed.connect(_on_dock_button_pressed)
	else:
		print("Need dock button in scene to use Dock Manager.")
	if not is_instance_valid(MainScreenHandler):
		plugin_control.name = plugin._get_plugin_name()
		MainScreenHandler = _MainScreenHandlerClass.new(plugin, plugin_control)
		plugin.add_child(MainScreenHandler)
	
	var layout_data = load_layout_data()
	var dock_target = layout_data.get("current_dock", default_dock)
	if dock_target == null:
		dock_target = default_dock
	if dock_target > -3:
		dock_instance(int(dock_target))
	else:
		undock_instance()

func set_default_window_size(size:Vector2i):
	_default_window_size = size

func _ready() -> void:
	plugin.add_child(self)

func clean_up():
	save_layout_data()
	_remove_control_from_parent()
	plugin_control.queue_free()
	if not external_main_screen_flag:
		MainScreenHandler.clean_up()
		MainScreenHandler.queue_free()
	
	queue_free()

func free_instance():
	clean_up()

func get_plugin_control():
	return plugin_control

func load_layout_data():
	if not FileAccess.file_exists(_get_layout_file_path()):
		var dir = _get_layout_file_path().get_base_dir()
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
			UFile.write_to_json({}, _get_layout_file_path())
		return {}
	var data = UFile.read_from_json(_get_layout_file_path())
	var scene_data = data.get(plugin_control.scene_file_path, {})
	return scene_data

func save_layout_data():
	if not is_instance_valid(plugin_control):
		return
	var current_dock = _get_current_dock()
	#if current_dock == -3:
		#return
	var data = {}
	if FileAccess.file_exists(_get_layout_file_path()):
		data = UFile.read_from_json(_get_layout_file_path())
	var scene_data = {"current_dock": current_dock}
	data[plugin_control.scene_file_path] = scene_data
	UFile.write_to_json(data, _get_layout_file_path())

func _get_layout_file_path():
	#var script = self.get_script() as Script
	var script = plugin.get_script()
	var path = script.resource_path
	var dir = path.get_base_dir()
	var layout_path = dir.path_join(".dock_manager/layout.json")
	return layout_path

func _on_dock_button_pressed():
	var dock_popup_handler = DockPopupHandler.new(plugin_control)
	if can_be_freed:
		dock_popup_handler.can_be_freed()
	
	var handled = await dock_popup_handler.handled
	if handled is String:
		return
	
	var current_dock
	if plugin_control.get_parent() is PanelWrapper:
		current_dock = _slot.get(Slot.MAIN_SCREEN)
	else:
		current_dock = Docks.get_current_dock(plugin_control)
	if current_dock == handled:
		return
	if handled == 20:
		free_instance.call_deferred()
		#free_requested.emit(self)
	elif handled == _slot.get(Slot.FLOATING):
		undock_instance()
	else:
		dock_instance(handled)
	
	save_layout_data()

func dock_instance(target_dock:int):
	var window = plugin_control.get_window()
	_remove_control_from_parent()
	if target_dock > -1:
		plugin.add_control_to_dock(target_dock, plugin_control)
	elif target_dock == -1:
		var panel_wrapper = PanelWrapper.new(plugin_control)
		panel_wrapper.name = plugin_control.name
		MainScreenHandler.add_main_screen_control(panel_wrapper)
	elif target_dock == -2:
		var name = plugin_control.name
		plugin.add_control_to_bottom_panel(plugin_control, name)
	
	if is_instance_valid(window):
		if window is PanelWindow:
			window.queue_free()


func undock_instance():
	_remove_control_from_parent()
	var window = PanelWindow.new(plugin_control, true, _default_window_size)
	window.close_requested.connect(window_close_requested)
	#window.mouse_entered.connect(_on_window_mouse_entered.bind(window))
	#window.mouse_exited.connect(_on_window_mouse_exited)
	
	return window

func _remove_control_from_parent():
	var window = plugin_control.get_window()
	var current_dock = _get_current_dock()
	if current_dock != null:
		last_dock = current_dock
	var control_parent = plugin_control.get_parent()
	if is_instance_valid(control_parent):
		if current_dock > -1:
			plugin.remove_control_from_docks(plugin_control)
		elif current_dock == -1:
			var panel_wrapper = plugin_control.get_parent()
			MainScreenHandler.remove_main_screen_control(panel_wrapper)
			panel_wrapper.remove_child(plugin_control)
			panel_wrapper.queue_free()
		elif current_dock == -2:
			plugin.remove_control_from_bottom_panel(plugin_control)
			BottomPanel.show_first_panel()
		else:
			control_parent.remove_child(plugin_control)
	
	if is_instance_valid(window):
		if window is PanelWindow:
			window.queue_free()

func _get_current_dock():
	if plugin_control.get_parent() is PanelWrapper:
		return _slot.get(Slot.MAIN_SCREEN)
	else:
		return Docks.get_current_dock(plugin_control)

func window_close_requested() -> void:
	dock_instance(last_dock)
func _on_window_mouse_entered(window):
	window.grab_focus()
func _on_window_mouse_exited():
	EditorInterface.get_base_control().get_window().grab_focus()

class PanelWrapper extends PanelContainer:
	func _init(control) -> void:
		add_child(control)
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		
	func _ready() -> void:
		var panel_sb = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		panel_sb.content_margin_left = 4
		panel_sb.content_margin_right = 4
		add_theme_stylebox_override("panel", panel_sb)



