extends "res://addons/plugin_exporter/src/class/remote/addons/editor_console/src/class/console_command_base.gd"

const SCOPE_COMMAND = "scope"

const REG_SCOPE = "reg-scope"
const REG_SET = "reg-set"
const DEREG_SCOPE = "dereg-scope"
const DEREG_SET = "dereg-set"
const RELOAD = "reload"

const GLOBAL_COMMAND = "global-class"

const GLOBAL_REG = "reg"
const GLOBAL_DEREG = "dereg"

static func register_commands() -> Dictionary:
	return {
	SCOPE_COMMAND:{
		"callable": _scope
	},
	GLOBAL_COMMAND:{
		"callable": _global
	}
}

const CFG_HELP = \
"Available commands:
	%s - manage registered commands
	%s - manage global classes that appear in autocomplete"

const _CFG_CMDS = [SCOPE_COMMAND, GLOBAL_COMMAND]

const SCOPE_HELP = \
"Manage commands available to the console.
	%s - register script -- <scope name, script path>
	%s - register script to be scanned for scopes and variables -- <script path>
	%s - deregister scope -- <scope name>
	%s - deregister set -- <script path>
	%s - reload scripts default and manually registered scopes"

const _SCOPE_CMDS = [REG_SCOPE, REG_SET, DEREG_SCOPE, DEREG_SET, RELOAD]

const GLOBAL_HELP = \
"Manage classes that will appear in autocomplete.
	%s - register class -- <class name>
	%s - deregister class -- <class name>"

const _GLOBAL_CMDS = [GLOBAL_REG, GLOBAL_DEREG]

const CLEAR_HELP = \
"Clear ouput text box.
	--history - Clear command history."

static func get_completion(raw_text:String, commands:Array, arguments:Array, editor_console):
	var completion_data = {}
	var registered_commands = register_commands()
	if commands.size() == 1:
		return registered_commands
	var c_2 = commands[1]
	if c_2 == SCOPE_COMMAND:
		return _get_scope_completion(raw_text, commands, arguments, editor_console)
	elif c_2 == GLOBAL_COMMAND:
		return _get_global_completion(raw_text, commands, arguments, editor_console)
	
	return completion_data


static func parse(commands:Array, arguments:Array, editor_console):
	if commands.size() == 1:
		print(CFG_HELP % _CFG_CMDS)
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


static func _scope(commands:Array, arguments:Array, editor_console):
	if commands.size() == 2 or UtilsLocal.check_help(commands):
		print(SCOPE_HELP.strip_edges() % _SCOPE_CMDS)
		return
	var c_3 = commands[2]
	var arg_size = arguments.size()
	if c_3 == REG_SCOPE:
		if arg_size != 2:
			UtilsLocal.pr_arg_size_err(2, arg_size)
			#printerr("Expected 2 arguments, received %s" % arg_size)
			return
		var scope_name = arguments[0]
		var script_path = arguments[1]
		editor_console.register_persistent_scope(scope_name, script_path)
	elif c_3 == REG_SET:
		if arg_size != 1:
			UtilsLocal.pr_arg_size_err(1, arg_size)
			#printerr("Expected 1 arguments, received %s" % arg_size)
			return
		var script_path = arguments[0]
		editor_console.register_persistent_scope_set(script_path)
	elif c_3 == DEREG_SCOPE:
		if arg_size != 1:
			UtilsLocal.pr_arg_size_err(1, arg_size)
			#printerr("Expected 1 arguments, received %s" % arg_size)
			return
		var scope_data = UtilsLocal.get_scope_data()
		var scopes = scope_data.get("scopes", {})
		var scope_name = arguments[0]
		if scope_name not in scopes.keys():
			print("Can't remove this command: %s" % scope_name)
		else:
			editor_console.remove_persistent_scope(scope_name)
	elif c_3 == DEREG_SET:
		if arg_size != 1:
			UtilsLocal.pr_arg_size_err(1, arg_size)
			#printerr("Expected 1 arguments, received %s" % arg_size)
			return
		var script_path = arguments[0]
		editor_console.remove_persistent_scope_set(script_path)
	elif c_3 == RELOAD:
		var success = editor_console._load_default_commands()
		if success:
			print("Reloaded command sets.")

static func _get_scope_completion(raw_text:String, commands:Array, arguments:Array, editor_console):
	var completion_data = {}
	if commands.size() < 3:
		return {
			REG_SCOPE:{ECKeys.METADATA: {ECKeys.ADD_ARGS:true}},
			REG_SET:{ECKeys.METADATA: {ECKeys.ADD_ARGS:true}},
			DEREG_SCOPE:{ECKeys.METADATA: {ECKeys.ADD_ARGS:true}},
			DEREG_SET:{ECKeys.METADATA: {ECKeys.ADD_ARGS:true}},
			RELOAD:{},
		}
	var c_3 = commands[2]
	if raw_text.find(" --") > -1:
		if c_3 == DEREG_SCOPE:
			var scope_data = UtilsLocal.get_scope_data()
			var scopes = scope_data.get(ScopeDataKeys.scopes, {})
			for scope_name in scopes.keys():
				completion_data[scope_name] = {}
			return completion_data
		elif c_3 == DEREG_SET:
			var scope_data = UtilsLocal.get_scope_data()
			var sets = scope_data.get(ScopeDataKeys.sets, [])
			for path in sets:
				completion_data[path] = {}
			return completion_data
	return completion_data


static func _global(commands:Array, arguments:Array, editor_console):
	if commands.size() == 2 or UtilsLocal.check_help(commands):
		print(GLOBAL_HELP % _GLOBAL_CMDS)
		return
	var c_3 = commands[2]
	var arg_size = arguments.size()
	if c_3 == GLOBAL_REG:
		if arg_size != 1:
			UtilsLocal.pr_arg_size_err(1, arg_size)
			return
		var desired_class = arguments[0]
		var global_class_list = UtilsLocal.get_global_class_list()
		if not desired_class in global_class_list:
			print("Class not in global class list: %s" % desired_class)
			return
		var scope_data = UtilsLocal.get_scope_data()
		var registered_classes = scope_data.get(ScopeDataKeys.global_classes, [])
		if desired_class in registered_classes:
			print("Class already registered: %s" % desired_class)
			return
		registered_classes.append(desired_class)
		scope_data[ScopeDataKeys.global_classes] = registered_classes
		UtilsLocal.save_scope_data(scope_data)
	elif c_3 == GLOBAL_DEREG:
		if arg_size != 1:
			UtilsLocal.pr_arg_size_err(1, arg_size)
			return
		var desired_class = arguments[0]
		var scope_data = UtilsLocal.get_scope_data()
		var registered_classes = scope_data.get(ScopeDataKeys.global_classes, [])
		if not desired_class in registered_classes:
			print("Class not registered: %s" % desired_class)
			return
		var idx = registered_classes.find(desired_class)
		registered_classes.remove_at(idx)
		scope_data[ScopeDataKeys.global_classes] = registered_classes
		UtilsLocal.save_scope_data(scope_data)
	

static func _get_global_completion(raw_text:String, commands:Array, arguments:Array, editor_console):
	if commands.size() < 3:
		return {
			GLOBAL_REG: {ECKeys.METADATA:{ECKeys.ADD_ARGS:true}},
			GLOBAL_DEREG: {ECKeys.METADATA:{ECKeys.ADD_ARGS:true}}
		}
	var completions_data = {}
	if not raw_text.find(" --") > -1:
		return completions_data
	
	var c_3 = commands[2]
	var scope_data = UtilsLocal.get_scope_data()
	var global_classes = scope_data.get(ScopeDataKeys.global_classes, [])
	var global_class_list = UtilsLocal.get_global_class_list()
	for _class in global_class_list:
		if c_3 == GLOBAL_REG:
			if not _class in global_classes:
				completions_data[_class] = {}
		elif c_3 == GLOBAL_DEREG:
			if _class in global_classes:
				completions_data[_class] = {}
	return completions_data

static func clear_console(commands:Array, arguments:Array, editor_console):
	if UtilsLocal.check_help(commands):
		print(CLEAR_HELP)
		return
	if commands.size() > 1:
		var c_2 = commands[1]
		if c_2 == "--history":
			editor_console.previous_commands.clear()
	
	var line = editor_console.console_line_edit
	var editor_log = line.get_parent().get_parent().get_parent().get_parent().get_parent().get_parent()
	var clear_button = editor_log.get_child(2).get_child(1).get_child(0)
	var editor_log_containers = editor_log.get_child(2).get_children()
	for item in editor_log_containers:
		if item is not HBoxContainer:
			continue
		var children = item.get_children()
		for c in children:
			var signals = c.get_signal_connection_list("pressed")
			for s in signals:
				var callable = str(s.get("callable", ""))
				if callable == "EditorLog::_clear_request":
					clear_button = c
					break
	
	if not is_instance_valid(clear_button):
		printerr("Could not locate clear button...")
		return
	
	clear_button.pressed.emit()

