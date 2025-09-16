extends "res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/class/console_command_base.gd"

const MISC_HELP = \
"Misc commands - Available:
color-picker - Open a color picker in a window, selecting a color copies the html string to clipboard."

static func register_commands():
	return {
	"color-picker": {
		"callable": _color_picker
		}
	}

static func get_completion(raw_text:String, commands:Array, arguments:Array, editor_console):
	var completion_data = {}
	var registered = register_commands()
	if commands.size() == 1:
		return register_commands()


static func parse(commands:Array, arguments:Array, editor_console):
	if commands.size() == 1 or UtilsLocal.check_help(commands):
		print(MISC_HELP)
		return
	
	var c_2 = commands[1]
	var script_commands = register_commands()
	var command_data = script_commands.get(c_2)
	if not command_data:
		print("Unrecognized command: %s" % c_2)
		return
	var callable = command_data.get("callable")
	if callable:
		callable.call(commands, arguments, editor_console)



#region Color Picker

static func _color_picker(commands, arg, editor_console):
	var win = Window.new()
	var color = ColorPicker.new()
	win.size = Vector2i(400,600)
	win.add_child(color)
	win.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color.can_add_swatches = false
	color.deferred_mode = true
	#color.can_add_swatches = false
	#color.presets_visible = false
	var hex_button:Button = color.get_child(0, true).get_child(0).get_child(4).get_child(1)
	hex_button.pressed.connect(_on_hex_pressed.bind(color))
	color.color_changed.connect(_on_color_changed.bind(color))
	win.close_requested.connect(_on_color_close_requested.bind(win))
	_EIBackport.get_ins().ei.get_base_control().add_child(win)
	win.title = "Color Picker"
	win.show()

static func _on_hex_pressed(color_picker:ColorPicker):
	color_picker.color_changed.emit(color_picker.color)

static func _on_color_changed(color:Color, color_picker:ColorPicker):
	var line_edit:LineEdit = color_picker.get_child(0, true).get_child(0).get_child(4).get_child(2)
	if line_edit.editable:
		DisplayServer.clipboard_set(color.to_html(color.a < 1))
	else:
		if color.a == 1:
			var color_string = "(%.3f, %.3f, %.3f)" % [color.r, color.g, color.b]
			DisplayServer.clipboard_set("Color%s" % color_string)
		else:
			DisplayServer.clipboard_set("Color%s" % color)
	
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(color_picker.size.x,0)
	panel.top_level = true
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color.BLACK # - Color(0,0,0,0.5)
	panel.add_theme_stylebox_override("panel", sb)
	var label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label_text = "Color Set to Clipboard: %s" % DisplayServer.clipboard_get()
	label.text = label_text
	var timer = Timer.new()
	timer.timeout.connect(panel.queue_free)
	timer.wait_time = 2
	
	panel.add_child(label)
	label.add_child(timer)
	color_picker.add_child(panel)
	timer.start()

static func _on_color_close_requested(window) -> void:
	window.queue_free()

#endregion

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BPSV_PATH_console_misc = "res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/default_commands/console_misc.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

