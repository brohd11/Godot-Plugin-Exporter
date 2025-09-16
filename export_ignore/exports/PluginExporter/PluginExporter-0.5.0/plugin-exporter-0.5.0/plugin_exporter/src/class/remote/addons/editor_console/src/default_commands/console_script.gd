extends "res://addons/plugin_exporter/src/class/remote/addons/editor_console/src/class/console_command_base.gd"

const _ARG_CLASS_COLOR_SETTING = "text_editor/theme/highlighting/base_type_color"


const CALL_COMMAND = "call"
const ARG_COMMAND = "args"
const LIST_COMMAND = "list"

const LIST_COMMANDS_OPTIONS = ["--methods", "--signals", "--constants", "--properties",
"--enums", "--inherited", "--lines"]

const SCRIPT_HELP=\
"Call static methods on current script, or create an instance.
call - call method -- <method_name, arg1, arg2, ... >
args - list arguments for method -- <method_name>
list - list members of script -- <list_flags> (--methods, --signals, --constants,\
--properties, --enums, --inherited, --lines)"

static func _get_commands() -> Dictionary: 
	return {
		CALL_COMMAND: {PopupKeys.METADATA_KEY: {ParsePopupKeys.ADD_ARGS:true}},
		ARG_COMMAND: {PopupKeys.METADATA_KEY: {ParsePopupKeys.ADD_ARGS:true}},
		LIST_COMMAND: {PopupKeys.METADATA_KEY: {ParsePopupKeys.ADD_ARGS:true}},
		}


static func get_completion(raw_text:String, commands:Array, args:Array, editor_console) -> Dictionary:
	var completion_data = {}
	var registered = _get_commands()
	
	if raw_text.find(" -- ") == -1:
		for cmd in registered:
			if cmd in commands:
				return {" -- ":{}}
		return get_valid_commands(commands, registered)
	
	if commands.size() > 1:
		var c_2 = commands[1]
		if c_2 == CALL_COMMAND and raw_text.find(" --") > -1:
			var script = EditorInterface.get_script_editor().get_current_script()
			return get_method_completions(script, args)
			
		elif c_2 == ARG_COMMAND and raw_text.find(" --") > -1:
			var script = EditorInterface.get_script_editor().get_current_script()
			if args.size() == 0:
				return get_method_completions(script, args)
		elif c_2 == LIST_COMMAND and raw_text.find(" --") > -1:
			return get_list_commands(args)
	
	return completion_data

static func parse(commands:Array, arguments:Array, editor_console):
	if commands.size() == 1 or UtilsLocal.check_help(commands):
		print(SCRIPT_HELP)
		return
	var script = EditorInterface.get_script_editor().get_current_script()
	var args = editor_console.tokenizer.get_arg_variables(arguments)
	
	var c_1 = commands[0]
	var c_2 = commands[1]
	
	if c_2 == CALL_COMMAND:
		call_method(script, args)
	elif c_2 == ARG_COMMAND:
		list_args(script, args)
	elif c_2 == LIST_COMMAND:
		var script_name = script.resource_path.get_file()
		print_members(script_name, args, script)
		return


static func call_method(script:Script, args:Array):
	if args.size() < 1:
		print("Need method name to call.")
		return
	var method_name = args[0]
	args.remove_at(0)
	if not MiscBackport.has_static_method_compat(method_name, script):
		print("Static method not in script.")
		return
	if args.size() != script.get_method_argument_count(method_name):
		print("Argument count=%s, called with %s." % [script.get_method_argument_count(method_name), args.size()])
		return
	script.callv(method_name, args)


static func list_args(script:Script, args:Array):
	if args.size() < 1:
		print("Need method name to list args.")
		return
	var method_name = args[0]
	if not method_name in script:
		print("Static method not in script.")
		return
	var args_array = []
	var method_list = script.get_script_method_list()
	for method_dict in method_list:
		var name = method_dict.get("name")
		if name != method_name:
			continue
		args_array = method_dict.get("args", [])
		break
	
	if args_array.is_empty():
		print("No args to list.")
		return
	var class_name_color = EditorInterface.get_editor_settings().get_setting(_ARG_CLASS_COLOR_SETTING).to_html()
	var args_strings = []
	for dict in args_array:
		var name = dict.get("name")
		var type = dict.get("type")
		var arg_str = "%s:[color=%s]%s[/color]" % [name, class_name_color, type_string(type)]
		args_strings.append(arg_str)
	
	print_rich("  ".join(args_strings))


static func get_valid_commands(current_commands, command_list):
	var completion_data = {}
	var has_list_command = false
	for cmd in command_list.keys():
		if cmd in current_commands:
			continue
		var metadata = command_list.get(cmd, {})
		completion_data[cmd] = command_list.get(cmd)
	
	return completion_data


static func get_list_commands(current_args:Array):
	var completion_data = {}
	for cmd in LIST_COMMANDS_OPTIONS:
		if cmd not in current_args:
			completion_data[cmd] = {}
	
	return completion_data


static func get_method_completions(script, current_args):
	var completion_data = {}
	var method_list = script.get_script_method_list()
	for method in method_list:
		var name = method.get("name")
		if MiscBackport.has_static_method_compat(name, script):
			completion_data[name] = {}
		if name in current_args:
			return {}
	
	return completion_data


static func print_members(script_name:String, args:Array, script:Script):
	var list_opt_size = LIST_COMMANDS_OPTIONS.size()
	var lines_cmd = LIST_COMMANDS_OPTIONS[list_opt_size - 1]
	var inherited_cmd = LIST_COMMANDS_OPTIONS[list_opt_size - 2]
	var print_lines = lines_cmd in args
	if print_lines:
		var idx = args.find(lines_cmd)
		args.remove_at(idx)
	var inherited = inherited_cmd in args
	if inherited:
		var idx = args.find(inherited_cmd)
		args.remove_at(idx)
	var args_size = args.size()
	if args_size == 0:
		if print_lines or inherited:
			print("'--lines' and '--inherited' should be passed with another argument.")
		else:
			print("Pass arguments for the list command.")
		return
	
	for i in range(args_size):
		var command = args[i]
		if command == lines_cmd or command == inherited_cmd:
			continue
		if command in LIST_COMMANDS_OPTIONS:
			var members = []
			if command == LIST_COMMANDS_OPTIONS[0]: # methods
				if inherited:
					print("Printing class methods: %s" % script_name)
					members = UClassDetail.class_get_all_methods(script)
				else:
					print("Printing script methods: %s" % script_name)
					members = UClassDetail.script_get_all_methods(script)
			elif command == LIST_COMMANDS_OPTIONS[1]: # signals
				if inherited:
					print("Printing class signals: %s" % script_name)
					members = UClassDetail.class_get_all_signals(script)
				else:
					print("Printing script signals: %s" % script_name)
					members = UClassDetail.script_get_all_signals(script)
			elif command == LIST_COMMANDS_OPTIONS[2]: # constants
				if inherited:
					print("Printing class constants: %s" % script_name)
					members = UClassDetail.class_get_all_constants(script)
				else:
					print("Printing script constants: %s" % script_name)
					members = UClassDetail.script_get_all_constants(script)
			elif command == LIST_COMMANDS_OPTIONS[3]: # properties
				if inherited:
					print("Printing class properties: %s" % script_name)
					members = UClassDetail.class_get_all_properties(script)
				else:
					print("Printing script properties: %s" % script_name)
					members = UClassDetail.script_get_all_properties(script)
			elif command == LIST_COMMANDS_OPTIONS[4]: # enums
				if inherited:
					print("Printing class enums: %s" % script_name)
					members = UClassDetail.class_get_all_enums(script)
				else:
					print("Cannot get script enums, no API in ClassDB. Use '--inherited' option.")
					#members = UClassDetail.sc(script)
					pass
			
			if members.is_empty():
				print_rich("\t[color=%s]None in script.[/color]" % EditorConsole.COLOR_VAR_RED)
			else:
				if print_lines:
					for m in members:
						print_rich("\t[color=%s]%s[/color]" % [EditorConsole.COLOR_ACCENT_MUTE, m])
				else:
					print_rich("\t[color=%s]" % EditorConsole.COLOR_ACCENT_MUTE + "  ".join(members) + "[/color]")
			if i < args_size - 1:
				print("")
			continue



### Plugin Exporter Global Classes
const UClassDetail = preload("res://addons/plugin_exporter/src/class/remote/addons/addon_lib/brohd/alib_editor/utils/src/u_class_detail.gd")
### Plugin Exporter Global Classes

