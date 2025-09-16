
var editor_console

var _token_regex:= RegEx.new()

var color_var_ok = "96f442"
var color_var_fail = "cc000c"
var color_var_value = "6d6d6d"

func _init() -> void:
	var pattern = "\"[^\"]*\"|'[^']*'|(\\[(?:[^\\[\\]]|(?1))*\\])|(\\{(?:[^{}]|(?2))*\\})|(\\((?:[^()]|(?3))*\\))|\\S+"
	_token_regex.compile(pattern)
	

func parse_command_string(input_string: String) -> Dictionary:
	var result := {
		"commands": PackedStringArray(),
		"args": PackedStringArray(),
		"display":"",
	}
	var command_str := input_string
	var args_str := ""
	var separator_pos = input_string.find(" -- ")
	if separator_pos != -1:
		command_str = input_string.substr(0, separator_pos).strip_edges()
		args_str = input_string.substr(separator_pos + 4).strip_edges()
	else:
		# If no separator, the whole string is considered commands
		command_str = input_string.strip_edges()
	
	var command_tok_data = _tokenize_string(command_str)
	var arg_tok_data = _tokenize_string(args_str)
	result.commands = command_tok_data.tokens
	result.args = arg_tok_data.tokens
	
	if arg_tok_data.display != "":
		result.display = "%s -- %s" % [command_tok_data.display, arg_tok_data.display]
	else:
		result.display = command_tok_data.display
	
	return result

func _tokenize_string(text: String) -> Dictionary:
	var tokens = PackedStringArray()
	var display_text = ""
	if text.is_empty():
		return {"tokens":tokens, "display":""}
	
	var matches = _token_regex.search_all(text)
	for _match in matches:
		var token = _match.get_string()
		# Check for and remove the surrounding quotes from the captured token
		if (token.begins_with("\"") and token.ends_with("\"")) or \
			(token.begins_with("'") and token.ends_with("'")):
			# This removes the first and last character (the quote)
			token = token.substr(1, token.length() - 2)
		var var_token_check = token
		if token.begins_with("$"):
			var_token_check = _check_variable(token)
			if var_token_check != token:
				display_text += " [color=%s]%s[/color] [color=%s]%s[/color]" % \
				[color_var_ok, token, color_var_value, var_token_check]
			else:
				display_text += " [color=%s]%s[/color] [color=%s]Could not get var[/color]"% \
				[color_var_fail, token, color_var_value]
		elif token.find("<") > -1:
			if editor_console:
				var_token_check = _check_variable(token)
			display_text += " %s" % token
		elif token.find("#") > -1:
			if editor_console:
				var_token_check = _check_variable(token)
			display_text += " %s" % token
		else:
			display_text += " %s" % token
		
		tokens.push_back(var_token_check)
	
	return {
		"tokens": tokens,
		"display": display_text.strip_edges(),
	}


func _check_variable(arg:String):
	if arg.begins_with("$"):
		var variable_callable = editor_console.variable_dict.get(arg)
		if variable_callable:
			var variable = variable_callable.call()
			if variable is String:
				editor_console.working_variable_dict[variable] = variable
				return variable
			else:
				editor_console.working_variable_dict[variable.to_string()] = variable
				return variable.to_string()
	
	
	var exp_idx = arg.find('{#')
	if exp_idx > -1:
		var exp = Expression.new()
		var arg_stripped = arg.replace("'","").replace('"',"").trim_prefix("{#").trim_suffix("}")
		if arg_stripped.find("<") > -1:
			
			pass
		var err = exp.parse(arg_stripped)
		if err == OK:
			var result = exp.execute()
			print(result)
			var type = Var.check_type(arg)
			if type:
				result = Var.string_to_type(result, type)
			editor_console.working_variable_dict[arg] = result
			return arg
	
	var type_str = Var.check_type(arg)
	if type_str:
		var variable = Var.string_to_type(arg, type_str)
		editor_console.working_variable_dict[arg] = variable
		return arg
	
	return arg

func get_arg_variables(args:Array):
	var vars = []
	for arg in args:
		vars.append(get_variable(arg))
	return vars

func get_variable(variable_string):
	var variable = editor_console.working_variable_dict.get(variable_string)
	if variable:
		return variable
	else:
		#printerr("Failed to get variable: %s" % variable_string)
		return variable_string



class Var:
	const NUM_TYPES = ["int", "float"]
	
	static func check_type(arg):
		var type_idx = arg.find("<")
		if type_idx > -1 and arg.find(">") > type_idx:
			var raw_arg = arg.get_slice("<", 0)
			var type = arg.get_slice("<", 1)
			type = type.get_slice(">", 0)
			var variable = Var.string_to_type(raw_arg, type)
			return type
		return
	
	
	static func string_to_type(arg:String, type_str:String):
		if type_str in NUM_TYPES:
			return _string_to_num(arg, type_str)
		if type_str == "b":
			return _string_to_bool(arg)
	
	
	static func _string_to_num(arg:String, type_str:String):
		if type_str == "int":
			return arg.to_int()
		if type_str == "float":
			return arg.to_float()
	
	static func _string_to_bool(arg):
		if arg == "true" or arg == "1":
			return true
		elif arg == "false" or arg == "0":
			return false
		else:
			printerr("Error getting argument: %s" % arg)
			return arg
		



### Plugin Exporter Global Classes
const EditorConsole = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/editor_console.gd")
### Plugin Exporter Global Classes

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_console_tokenizer = "res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/utils/console_tokenizer.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
