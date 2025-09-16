extends RefCounted

enum Type{
	NONE,
	BASE,
	ACCENT,
	DARK,
	BACKGROUND,
}

static func get_theme_color(color_type=Type.BASE):
	var base_control = EditorInterface.get_base_control()
	var color
	var color_string = ""
	if color_type == Type.BASE:
		color_string = "base_color"
	elif color_type == Type.ACCENT:
		color_string = "accent_color"
	elif color_type == Type.DARK:
		color_string = "dark_color"
	elif color_type == Type.BACKGROUND:
		color_string = "background"
	
	color = base_control.get_theme_color(color_string, &"Editor")
	return color


