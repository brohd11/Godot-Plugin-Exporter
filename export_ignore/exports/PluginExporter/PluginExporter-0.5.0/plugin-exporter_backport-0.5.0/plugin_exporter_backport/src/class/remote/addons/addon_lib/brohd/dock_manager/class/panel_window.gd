extends Window

const ThemeSetter = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/editor_theme/theme_setter.gd")



func _init(control, empty_panel:=true, window_size:=Vector2i(1200, 800)) -> void:
	
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	size = window_size
	_EIBackport.get_ins().ei.get_base_control().add_child(self)
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(panel)
	always_on_top = true
	
	var panel_sb = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	panel_sb.draw_center = true
	panel_sb.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", panel_sb)
	
	ThemeSetter.set_theme_color(panel, ThemeSetter.ThemeColor.Type.BASE)
	
	#if empty_panel:
		#var panel_sb = StyleBoxEmpty.new()
		#panel.add_theme_stylebox_override("panel", panel_sb)
	
	if is_instance_valid(control.get_parent()):
		control.reparent(panel)
	else:
		panel.add_child(control)
	
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	control.show()
	

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_panel_window = "res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/dock_manager/class/panel_window.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
