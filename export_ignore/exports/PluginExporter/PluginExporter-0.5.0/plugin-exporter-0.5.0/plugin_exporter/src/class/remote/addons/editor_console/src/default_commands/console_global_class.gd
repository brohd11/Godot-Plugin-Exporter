extends "res://addons/plugin_exporter/src/class/remote/addons/editor_console/src/class/console_command_base.gd"

const ConsoleScript = UtilsLocal.ConsoleScript

const _CLASS_VALID_MSG = \
"Class valid: %s
" + ConsoleScript.SCRIPT_HELP

static func get_completion(raw_text, commands:Array, args:Array, editor_console) -> Dictionary:
	if commands[0] != "global":
		commands.push_front("global")
	
	var completion_data = {}
	var scope_data = UtilsLocal.get_scope_data()
	var registered_classes = scope_data.get(ScopeDataKeys.global_classes, [])
	var global_class_list = ProjectSettings.get_global_class_list()
	
	var global_class_dict = {}
	for class_dict in global_class_list:
		var _class_name = class_dict.get("class")
		if _class_name not in registered_classes:
			continue
		var path = class_dict.get("path")
		global_class_dict[_class_name] = path
	
	var global_class_names = global_class_dict.keys()
	var c_2
	var has_class = false
	var current_class_name = ""
	if commands.size() >= 2:
		c_2 = commands[1]
		if c_2 in global_class_names:
			has_class = true
			current_class_name = c_2
	
	if commands.size() <= 2 and not has_class:
		if c_2:
			for name in global_class_names:
				if name.to_lower().begins_with(c_2.to_lower()):
					completion_data[name] = {PopupKeys.METADATA_KEY:{ParsePopupKeys.REPLACE_WORD:true}}
		else:
			for name in global_class_names:
				completion_data[name] = {}
			
		return completion_data
	
	if not has_class:
		return {}
	
	var script = load(global_class_dict.get(current_class_name))
	
	if raw_text.find(" -- ") == -1:
		var script_commands = ConsoleScript._get_commands()
		for cmd in script_commands:
			if cmd in commands:
				return {" -- ":{}}
		
		return ConsoleScript.get_valid_commands(commands, script_commands)
	
	var c_3 = commands[2]
	if args.size() == 0:
		if c_3 == ConsoleScript.CALL_COMMAND and raw_text.find(" --") > -1:
			return ConsoleScript.get_method_completions(script, args)
		elif c_3 == ConsoleScript.ARG_COMMAND and raw_text.find(" --") > -1:
			if args.size() == 0:
				return ConsoleScript.get_method_completions(script, args)
	
	if c_3 == ConsoleScript.LIST_COMMAND and raw_text.find(" --") > -1:
		return ConsoleScript.get_list_commands(args)
	
	if raw_text.find(" --") > -1:
		return script.get_completion(raw_text, commands, args, editor_console)
	
	return completion_data


static func parse(commands:Array, arguments:Array, editor_console):
	var c_1 = commands[0]
	if c_1 == "global":
		if commands.size() == 1:
			print("Hit ctrl + space to get global class list with 'global' command.")
			return
		commands.remove_at(0)
		c_1 = commands[0]
	var global_class_script:Script
	var class_list = ProjectSettings.get_global_class_list()
	for class_dict in class_list:
		var _class_name = class_dict.get("class")
		if _class_name == c_1:
			var path = class_dict.get("path")
			global_class_script = load(path)
	
	
	if not global_class_script:
		print("Could not find class: '%s'" % c_1)
		return
	
	if commands.size() == 1:
		print(_CLASS_VALID_MSG % c_1)
		return
	
	var c_2 = commands[1]
	var args = editor_console.tokenizer.get_arg_variables(arguments)
	
	if c_2 == ConsoleScript.CALL_COMMAND:
		ConsoleScript.call_method(global_class_script, args)
	elif c_2 == ConsoleScript.ARG_COMMAND:
		ConsoleScript.list_args(global_class_script, args)
	elif c_2 == ConsoleScript.LIST_COMMAND:
		var script_name = c_1
		ConsoleScript.print_members(c_1, arguments, global_class_script)
		return

