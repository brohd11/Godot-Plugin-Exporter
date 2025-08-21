extends RefCounted

const ThemeSetter = preload("theme_setter.gd")

static func get_icon(icon_name:String, theme_type:String=&"EditorIcons"):
	var icon = EditorInterface.get_editor_theme().get_icon(icon_name, theme_type)
	return icon

static func get_icon_name(icon, theme_type:String=&"EditorIcons"):
	var icon_list = EditorInterface.get_editor_theme().get_icon_list(theme_type)
	for icon_name in icon_list:
		if icon == get_icon(icon_name, theme_type):
			return icon_name

static func set_menu_button_to_editor_theme(menu_button:MenuButton):
	menu_button.flat = false
	var b = Button.new()
	menu_button.add_child(b)
	var overides = ["normal", "pressed"]
	for o in overides:
		menu_button.add_theme_stylebox_override(o, b.get_theme_stylebox(o))
	b.queue_free()












