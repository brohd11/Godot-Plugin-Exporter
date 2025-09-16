
extends Node

const UtilsLocal = preload("res://addons/plugin_exporter/src/class/remote/addons/editor_console/src/utils/console_utils_local.gd")
const UtilsRemote = preload("res://addons/plugin_exporter/src/class/remote/addons/editor_console/src/utils/console_utils_remote.gd")
const BottomPanel = UtilsRemote.BottomPanel

const MiscBackport = preload("res://addons/plugin_exporter/src/class/export/backport/misc_backport_class.gd")

var instance_refs = []

#region Old plugin.gd vars

const TOGGLE_CONSOLE = "Toggle Console"
const TOGGLE_FILTER = "Toggle Filter"
const OS_MODE = "OS/Toggle Mode"
const TOGGLE_OS_LABEL = "OS/Toggle Label Squish"

const button_right_click_menu_items = {
	TOGGLE_CONSOLE:{},
	TOGGLE_FILTER:{},
	OS_MODE:{},
	TOGGLE_OS_LABEL:{}
}

var filter_line_edit:LineEdit
var main_hsplit:HSplitContainer
var console_line_container:UtilsLocal.ConsoleLineContainer
var show_filter:bool = true

#endregion

## GDTERM
var gd_term_instance
##

var console_line_edit:UtilsLocal.ConsoleLineContainer.ConsoleLineEdit
var last_command:String
var previous_commands = []
var current_command_index:int = -1

const OS_LAB_CONSOLE_STR = "[color=%s]Console$[/color]"
const OS_LAB_OS_STR = "[color=%s]%s[/color]:[color=%s]~%s[/color]$"

var os_label:RichTextLabel
var os_mode:= false
var os_user:String
var os_string_raw:String
var os_string:String
var os_home_dir:String
var os_cwd:String:
	set(value):
		value = value.trim_suffix("/")
		os_cwd = value
		_update_os_string()


var scope_dict = {}
var hidden_scope_dict = {}
var _temp_scope_dict = {}

var variable_dict = {}
var working_variable_dict = {}

const COLOR_OS_USER = "88e134"
const COLOR_OS_PATH = "659cce"

const COLOR_VAR_GREEN = "96f442"
const COLOR_VAR_RED = "cc000c"
const COLOR_VAR_GREY = "6d6d6d"
const COLOR_ACCENT_MUTE = "4d819a"
var _accent_color:String

var tokenizer:UtilsLocal.ConsoleTokenizer

func _init() -> void:
	if not FileAccess.file_exists(UtilsLocal.EDITOR_CONSOLE_SCOPE_PATH):
		DirAccess.make_dir_recursive_absolute(UtilsLocal.EDITOR_CONSOLE_SCOPE_PATH.get_base_dir())
		UtilsRemote.UFile.write_to_json({}, UtilsLocal.EDITOR_CONSOLE_SCOPE_PATH)
	
	os_user = UtilsLocal.ConsoleOS.get_os_string()
	os_cwd = ProjectSettings.globalize_path("res://")
	os_home_dir = UtilsLocal.ConsoleOS.get_os_home_dir()
	_update_os_string()
	tokenizer = UtilsLocal.ConsoleTokenizer.new()
	tokenizer.editor_console = self
	
	_accent_color = EditorInterface.get_editor_theme().get_color("accent_color", &"Editor").to_html()
	
	_load_default_commands()
	
	
	
	# add func to load user config

static func get_instance(plugin:EditorPlugin):
	var root = Engine.get_main_loop().root
	var has_autoload = root.has_node("EditorConsole")
	var instance
	if has_autoload:
		instance = root.get_node("EditorConsole")
		
	else:
		instance = new()
		instance.name = "EditorConsole"
		root.add_child(instance)
		instance._add_console_line_edit()
	
	instance.instance_refs.append(plugin)
	return instance

func clear_reference(plugin):
	instance_refs.erase(plugin)
	
	if instance_refs.is_empty():
		_remove_console_line_edit()
		queue_free()


func register_temp_scope(scope_data:Dictionary) -> void: # for plugins
	for key in scope_data.keys():
		var data = scope_data.get(key)
		var script = data.get("script")
		var callable = data.get("callable")
		_temp_scope_dict[key] = {
			"script":script,
			"callable": callable
		}
	#set_var_highlighter()
	_load_default_commands()


func remove_temp_scope(scope_name:String): # for plugins
	if not scope_name in _temp_scope_dict.keys():
		print("Scope not in temp scope data: %s" % scope_name)
		return
	_temp_scope_dict.erase(scope_name)
	_load_default_commands()


func _load_default_commands():
	scope_dict.clear()
	hidden_scope_dict.clear()
	variable_dict.clear()
	
	_get_scope_set_data(UtilsLocal.DefaultCommands)
	scope_dict.merge(_temp_scope_dict, true)
	
	var scope_data = UtilsLocal.get_scope_data()
	var scopes = scope_data.get("scopes", {})
	for scope in scopes.keys():
		var data = scopes.get(scope)
		var script_path = data.get("script")
		if not FileAccess.file_exists(script_path):
			printerr("Could not find script: %s" % script_path)
			continue
		var script = load(script_path)
		scope_dict[scope] = {"script": script}
	
	var sets = scope_data.get("sets", [])
	for script_path in sets:
		_get_scope_set_data(script_path)
	
	if is_instance_valid(console_line_edit):
		set_var_highlighter()
	
	return true


func set_var_highlighter():
	var syn:UtilsLocal.SyntaxHl = console_line_edit.syntax_highlighter
	syn.scope_names = scope_dict.keys()
	syn.hidden_scope_names = hidden_scope_dict.keys()
	syn.var_names = variable_dict.keys()
	syn.clear_highlighting_cache()
	
	console_line_edit.scope_dict = scope_dict
	console_line_edit.variable_dict = variable_dict
	console_line_edit.editor_console = self


func register_persistent_scope(scope_name:String, script_path:String):
	if not FileAccess.file_exists(script_path):
		print("Could not load script: %s" % script_path)
		return
	var scope_data = UtilsLocal.get_scope_data()
	var scopes = scope_data.get("scopes", {})
	if scope_name in scopes.keys():
		print("Scope already registered: %s" % scope_name)
		return
	scopes[scope_name] = {"script": script_path}
	scope_data["scopes"] = scopes
	UtilsLocal.save_scope_data(scope_data)
	_load_default_commands()

func remove_persistent_scope(scope_name):
	var scope_data = UtilsLocal.get_scope_data()
	var scopes = scope_data.get("scopes", {})
	
	if not scope_name in scopes.keys():
		print("Scope not registered: %s" % scope_name)
		return
	
	scopes.erase(scope_name)
	scope_data["scopes"] = scopes
	UtilsLocal.save_scope_data(scope_data)
	_load_default_commands()

func register_persistent_scope_set(script_path:String):
	if not FileAccess.file_exists(script_path):
		print("Could not load script: %s" % script_path)
		return
	var scope_data = UtilsLocal.get_scope_data()
	var sets = scope_data.get("sets", [])
	if script_path in sets:
		print("Script already registered as set: %s" % script_path)
		return
	
	sets.append(script_path)
	scope_data["sets"] = sets
	UtilsLocal.save_scope_data(scope_data)
	_load_default_commands()

func remove_persistent_scope_set(script_path:String) -> void:
	var scope_data = UtilsLocal.get_scope_data()
	var sets = scope_data.get("sets", [])
	if not script_path in sets:
		print("Script set not registered: %s" % script_path)
		return
	
	var idx = sets.find(script_path)
	sets.remove_at(idx)
	
	scope_data["sets"] = sets
	UtilsLocal.save_scope_data(scope_data)
	_load_default_commands()



func _get_scope_set_data(path_or_script):
	var script:Script
	if path_or_script is Script:
		script = path_or_script
	else:
		script = load(path_or_script)
	
	if MiscBackport.has_static_method_compat("register_scopes", script):
		var register_scopes = script.register_scopes()
		scope_dict.merge(_process_scope_data(script, register_scopes))
	
	if MiscBackport.has_static_method_compat("register_hidden_scopes", script):
		var register_hidden_scopes = script.register_hidden_scopes()
		hidden_scope_dict.merge(_process_scope_data(script, register_hidden_scopes))
	
	if MiscBackport.has_static_method_compat("register_variables", script):
		var register_variables = script.register_variables()
		variable_dict.merge(register_variables)

func _process_scope_data(script:Script, scope_data_dict:Dictionary) -> Dictionary:
	var scope_dict_keys = scope_dict.keys()
	var temp_dict = {}
	for scope in scope_data_dict.keys():
		if scope in scope_dict_keys:
			print("Scope name conflict: %s" % scope)
		var scope_data = scope_data_dict.get(scope)
		var scope_script = scope_data.get("script")
		var scope_callable = scope_data.get("callable")
		temp_dict[scope] = {}
		if scope_callable != null:
			temp_dict[scope]["callable"] = scope_callable
		elif scope_script != null:
			temp_dict[scope]["script"] = scope_script
		else:
			temp_dict[scope]["script"] = script
	return temp_dict


func _update_os_string():
	var os_name = OS.get_name()
	var display_cwd = os_cwd.trim_prefix(os_home_dir)
	if display_cwd == "":
		display_cwd = "/"
	os_string_raw = "%s:~%s$ " % [os_user, display_cwd]
	var user_col = COLOR_OS_USER
	var path_col = COLOR_OS_PATH
	os_string = OS_LAB_OS_STR % [user_col, os_user, path_col, display_cwd]
	if os_label:
		os_label.text = os_string

func _toggle_os_mode():
	os_mode = not os_mode
	console_line_edit.syntax_highlighter.os_mode = os_mode
	console_line_edit.os_mode = os_mode
	if os_mode:
		_update_os_string()
		print_rich("%s Entered OS mode." % OS_LAB_CONSOLE_STR % _accent_color)
		if console_line_edit.visible:
			os_label.show()
	else:
		os_label.text = OS_LAB_CONSOLE_STR % _accent_color
		print_rich("%s Exited OS mode." % OS_LAB_CONSOLE_STR % _accent_color)


func _set_console_text(text):
	console_line_edit.text = text
	await console_line_edit.get_tree().process_frame
	console_line_edit.set_caret_column(text.length())

## Command order - clear, os, help, command_dict, finally check global
func parse_input(terminal_input:String) -> void:
	working_variable_dict.clear()
	
	current_command_index = -1
	terminal_input = terminal_input.strip_edges()
	if terminal_input == "": return
	
	last_command = terminal_input
	var cmd_index = previous_commands.rfind(terminal_input)
	if cmd_index == -1:
		previous_commands.append(terminal_input)
	else:
		previous_commands.remove_at(cmd_index)
		previous_commands.append(terminal_input)
	
	var parsed_commands = tokenizer.parse_command_string(terminal_input)
	var commands:Array = parsed_commands.commands
	var arguments:Array = parsed_commands.args
	var display_text = parsed_commands.display
	if commands.size() == 0:
		return
	
	var c_1 = commands[0]
	if c_1 == "clear":
		if UtilsLocal.check_help(commands):
			print_rich("%s %s" % [OS_LAB_CONSOLE_STR % _accent_color, display_text])
		UtilsLocal.ConsoleCfg.clear_console(commands, arguments, self)
		return
	
	if terminal_input == "os":
		toggle_os_mode()
		return
	if os_mode:
		UtilsLocal.ConsoleOS.parse(commands, arguments, self)
		return
	
	if c_1.to_lower() == "help":
		c_1 = c_1.to_lower()
	var formatted_console_input
	print_rich("%s %s" % [OS_LAB_CONSOLE_STR % _accent_color, display_text])
	if c_1 in scope_dict.keys():
		var cmd_data = scope_dict.get(c_1)
		var script = cmd_data.get("script")
		var callable = cmd_data.get("callable")
		if callable:
			var result = callable.call(commands, arguments, self)
		else:
			var result = script.call("parse", commands, arguments, self)
	elif c_1 in hidden_scope_dict.keys():
		var cmd_data = hidden_scope_dict.get(c_1)
		var script = cmd_data.get("script")
		var callable = cmd_data.get("callable")
		if callable:
			var result = callable.call(commands, arguments, self)
		else:
			var result = script.call("parse", commands, arguments, self)
	else:
		UtilsLocal.ConsoleGlobalClass.parse(commands, arguments, self)
	
	if scope_dict.is_empty():
		printerr("Need to load command set.")



func _console_gui_input(event: InputEvent) -> void:
	if not console_line_edit.has_focus():
		return
	if event is InputEventKey:
		if event.is_pressed() and event.as_text_keycode() == "Enter":
			_on_console_text_submitted(console_line_edit.text)
	
	if event is InputEventKey:
		if not event.is_pressed():
			return
		var keycode = event.as_text_keycode()
		if keycode == "Up":
			prev_command()
		elif keycode == "Down":
			next_command()
		elif keycode == "Ctrl+Shift+Up":
			prev_valid_command()
		elif keycode == "Ctrl+Shift+Down":
			next_valid_command()


func _on_console_text_changed():
	pass

func _on_console_text_submitted(new_text:String) -> void:
	parse_input(new_text)
	
	var console_text = get_console_text_box() as RichTextLabel
	console_text.scroll_to_line(console_text.get_line_count())
	await console_line_edit.get_tree().process_frame
	console_line_edit.clear()

func prev_command():
	current_command_index -= 1
	if current_command_index < -1:
		current_command_index = previous_commands.size() - 1
	if current_command_index == -1:
		console_line_edit.clear()
		return
	if current_command_index < previous_commands.size():
		_set_console_text(previous_commands[current_command_index])

func next_command():
	current_command_index += 1
	if current_command_index > previous_commands.size() - 1:
		current_command_index = -1
		console_line_edit.clear()
		return
	if current_command_index < previous_commands.size():
		_set_console_text(previous_commands[current_command_index])


## UNSURE
func prev_valid_command():
	var console_line_text = console_line_edit.text
	if console_line_text.strip_edges() == "":
		return
	var commands = console_line_text.split(" ")
	var next_command = commands[0]
	for com in commands:
		next_command = scope_dict.get(com)
		if not next_command:
			break

func next_valid_command():
	var console_line_text = console_line_edit.text
	if console_line_text.strip_edges() == "":
		return

##

func get_editor_log():
	var editor_log = console_line_edit.get_parent().get_parent().get_parent().get_parent().get_parent().get_parent()
	return editor_log

func get_clear_button():
	var editor_log = get_editor_log()
	var clear_button = editor_log.get_child(2).get_child(1).get_child(0)
	return clear_button

func get_console_text_box():
	var editor_log = get_editor_log()
	var text_box = editor_log.get_child(1).get_child(0)
	return text_box


#region Old plugin.gd Logic


func _add_console_line_edit():
	var filter_check = BottomPanel.get_filter_line_edit()
	if filter_check is not LineEdit:
		print("Filter is not found:")
		print(filter_check)
		return
	filter_line_edit = BottomPanel.get_filter_line_edit()
	var vbox = filter_line_edit.get_parent()
	main_hsplit = HSplitContainer.new()
	main_hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(main_hsplit)
	
	console_line_container = UtilsLocal.ConsoleLineContainer.new()
	filter_line_edit.reparent(main_hsplit)
	main_hsplit.add_child(console_line_container)
	
	console_line_container.apply_styleboxes(filter_line_edit)
	console_line_container.custom_minimum_size.y = filter_line_edit.size.y
	
	os_label = console_line_container.os_label
	os_label.text = OS_LAB_CONSOLE_STR % _accent_color
	console_line_container.console_line_edit.gui_input.connect(_console_gui_input)
	console_line_container.console_button.pressed.connect(_toggle_console)
	console_line_container.console_button.gui_input.connect(_on_button_gui_input)
	
	console_line_edit = console_line_container.console_line_edit
	
	set_var_highlighter()


func _remove_console_line_edit():
	var editor_log_hbox = main_hsplit.get_parent()
	filter_line_edit.reparent(editor_log_hbox)
	filter_line_edit.show()
	
	main_hsplit.queue_free()
	filter_line_edit = null


func _toggle_console():
	var console_line_edit = console_line_container.console_line_edit
	console_line_edit.visible = not console_line_edit.visible
	if console_line_edit.visible:
		main_hsplit.collapsed = false
		console_line_container.console_panel.show()
		console_line_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		console_line_edit.grab_focus()
		if not show_filter:
			filter_line_edit.hide()
	else:
		console_line_container.console_panel.hide()
		filter_line_edit.show()
		console_line_container.size_flags_horizontal = Control.SIZE_SHRINK_END
		main_hsplit.collapsed = true


func _on_button_gui_input(event):
	if event is InputEventMouseButton:
		if not event.pressed:
			return
		if event.button_index == 2:
			var menu_items = _check_menu_items()
			var popup = UtilsRemote.PopupHelper.new(menu_items)
			console_line_container.console_button.add_child(popup)
			popup.item_pressed_parsed_menu_path.connect(_on_popup_pressed)
			popup.position = DisplayServer.mouse_get_position() - Vector2i(15, 15)
			popup.popup()


func _check_menu_items():
	var menu_items = button_right_click_menu_items.duplicate()
	if not console_line_container.console_line_edit.visible:
		menu_items.erase(TOGGLE_FILTER)
		menu_items.erase(OS_MODE)
		menu_items.erase(TOGGLE_OS_LABEL)
	else:
		if not os_mode:
			menu_items.erase(TOGGLE_OS_LABEL)
	
	return menu_items


func _on_popup_pressed(popup_path:String):
	if popup_path == TOGGLE_CONSOLE:
		_toggle_console()
	if popup_path == TOGGLE_FILTER:
		_toggle_filter()
	elif popup_path == OS_MODE:
		toggle_os_mode()
	elif popup_path == TOGGLE_OS_LABEL:
		_toggle_os_label_minimum_size()


func _toggle_filter():
	show_filter = not show_filter
	filter_line_edit.visible = show_filter

func toggle_os_mode() -> void:
	_toggle_os_mode()

func _toggle_os_label_minimum_size() -> void:
	os_label.fit_content = not os_label.fit_content
	if not os_label.fit_content:
		os_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		os_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func toggle_term(commands, args, editor_console):
	if gd_term_instance.visible:
		gd_term_instance.hide()
		gd_term_instance.set_active(false)
	else:
		gd_term_instance.show()
		_get_gd_term().grab_focus()
		gd_term_instance.set_active(true)

func _get_gd_term():
	return gd_term_instance.get_node("term_container/term/GDTerm")

#endregion



### Plugin Exporter Global Classes
const EditorConsole = preload("res://addons/plugin_exporter/src/class/remote/addons/editor_console/src/editor_console.gd")
### Plugin Exporter Global Classes

