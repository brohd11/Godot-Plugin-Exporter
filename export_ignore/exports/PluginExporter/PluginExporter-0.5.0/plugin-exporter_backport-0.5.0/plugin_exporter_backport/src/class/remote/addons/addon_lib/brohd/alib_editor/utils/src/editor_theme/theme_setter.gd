@tool
extends Node

const BACKPORTED = 0

const ThemeColor = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/editor_theme/theme_color.gd")
const UNode = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_runtime/utils/src/u_node.gd")

const style_box_types = ["panel", "normal"]

@export var overide_color = ThemeColor.Type.NONE:
	set(val):
		overide_color = val
		_set_theme()

@export var color_multiply:Color = Color(1,1,1)

func _ready() -> void:
	_EIBackport.get_ins().ei.get_base_control().theme_changed.connect(_on_scan_files)
	_set_theme()

func _on_scan_files():
	print("THEME CHANGED ", self.get_parent())
	_set_theme()

func _set_theme():
	var parent = get_parent()
	if not parent:
		return
	
	set_theme_color(parent, overide_color, color_multiply)

static func set_theme_color(node, overide_color_type:=ThemeColor.Type.NONE, color_multiply:=Color(1,1,1)):
	var color_type = ThemeColor.Type.BACKGROUND
	if overide_color_type != ThemeColor.Type.NONE:
		color_type = overide_color_type
	
	var color = ThemeColor.get_theme_color(color_type)
	color = color * color_multiply
	
	if node is ColorRect:
		node.color = color
		return
	
	var style_box_type
	for style in style_box_types:
		if node.has_theme_stylebox(style):
			style_box_type = style
			break
	if style_box_type:
		var stylebox:StyleBoxFlat = node.get_theme_stylebox(style_box_type).duplicate()
		stylebox.bg_color = color
		node.add_theme_stylebox_override(style_box_type, stylebox)

static func set_theme_setters_in_scene(root_node):
	var nodes = UNode.recursive_get_nodes(root_node)
	for node in nodes:
		var node_name = String(node.name)
		if node_name.begins_with("ThemeSet"):
			var theme_setter = new()
			node.add_child(theme_setter)
			var setting = node_name.get_slice("ThemeSet", 1)
			if setting == "":
				setting = "NONE"
			setting = setting.to_upper()
			theme_setter.overide_color = ThemeColor.Type.get(setting)

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_theme_setter = "res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/editor_theme/theme_setter.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
