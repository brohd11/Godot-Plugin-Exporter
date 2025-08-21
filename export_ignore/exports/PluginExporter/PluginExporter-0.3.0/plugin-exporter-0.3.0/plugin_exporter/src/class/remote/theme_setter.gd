@tool
extends Node

const ThemeColor = preload("theme_color.gd")
const UNode = preload("u_node.gd")

const style_box_types = ["panel", "normal"]

@export var overide_color = ThemeColor.Type.NONE:
	set(val):
		overide_color = val
		_set_theme()

@export var color_multiply:Color = Color(1,1,1)

func _ready() -> void:
	EditorInterface.get_base_control().theme_changed.connect(_on_scan_files)
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

func list_editor_theme_colors():
	#var tree = Tree.new()
	#add_child(tree)
	#var _n = tree.get_theme_stylebox("panel") as StyleBoxFlat
	#print(_n.bg_color)
	#tree.queue_free()
	var theme_names = EditorInterface.get_editor_theme().get_stylebox_list(&"Tree")
	for n in theme_names:
		var sb = EditorInterface.get_editor_theme().get_stylebox(n, &"Tree")
		print(n)
		if not "bg_color" in sb:
			continue
		var color = sb.bg_color
		
		print(color)
		if color == Color(0.1, 0.1, 0.1, 0.6):
			print("YERp")
		print("************")
	print(theme_names)

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












