extends "res://addons/plugin_exporter/src/class/remote/addons/editor_console/src/class/console_command_base.gd"

const UFile = UtilsRemote.UFile

const _OS_LINUX = "Linux"
const _OS_MAC = "macOS"
const _OS_WIN = "Windows"

const EMULATED_COMMANDS = ["cd", "ls"]
const COMMAND_NEED_SCAN = ["rm", "mkdir", "touch"]

static func get_os_string():
	var system = OS.get_name()
	if system == _OS_LINUX:
		var user = OS.get_environment("USER")
		var hostname = OS.get_environment("HOSTNAME")
		hostname = hostname.strip_edges()
		if hostname == "":
			var output = []
			var exit = OS.execute("hostname",[], output)
			hostname = output[0].strip_edges()
			if hostname == "":
				hostname = "linux-pc"
		return "%s@%s" % [user, hostname]
		
	elif system == _OS_WIN:
		var user = OS.get_environment("USERNAME")
		var hostname = OS.get_environment("COMPUTERNAME")
		return "%s@%s" % [user, hostname]
	elif system == _OS_MAC:
		var user = OS.get_environment("USER")
		var hostname = OS.get_environment("HOSTNAME")
		hostname = hostname.strip_edges()
		if hostname == "":
			var output = []
			var exit = OS.execute("hostname",[], output)
			hostname = output[0].strip_edges()
			if hostname == "":
				hostname = "mac"
		return "%s@%s" % [user, hostname]

static func get_os_home_dir():
	var system = OS.get_name()
	if system == _OS_LINUX:
		var home = OS.get_environment("HOME")
		return home
	elif system == _OS_MAC:
		var home = OS.get_environment("HOME")
		return home
	elif system == _OS_WIN:
		var home = OS.get_environment("USERPROFILE")
		return home


static func parse(commands:Array, arguments:Array, editor_console):
	print_rich("%s %s" % [editor_console.os_string, editor_console.last_command])
	
	var command_needs_scan = false
	var result
	var exe = commands[0]
	if exe in EMULATED_COMMANDS:
		result = _emulated_command(commands, arguments, editor_console)
	else:
		result = _execute_wrapper(commands, arguments, editor_console)
	
	var formatted_result = "\n".join(result).strip_edges()
	if formatted_result != "":
		print(formatted_result)
	
	if command_needs_scan:
		EditorInterface.get_resource_filesystem().scan()


static func _emulated_command(commands:Array, arguments:Array, editor_console) -> Array:
	var c_1 = commands[0]
	if c_1 == "ls":
		return _ls(commands, arguments, editor_console)
	elif c_1 == "cd":
		return _cd(commands, arguments, editor_console)
	
	return [""]

static func _ls(commands:Array, arguments:Array, editor_console):
	if commands.size() > 1:
		var c_2 = commands[1]
		if c_2.begins_with("--"):
			_execute_wrapper(commands, arguments, editor_console)
			return [_execute_wrapper(commands, arguments, editor_console)[0]]
	var result = _execute_wrapper(commands, arguments, editor_console)
	var result_string:String = result[0]
	return[_one_line_result(result_string)]
 
static func _cd(commands:Array, arguments:Array, editor_console):
	if commands.size() == 1:
		return [""]
	var c_2 = commands[1]
	if c_2.begins_with("--"):
		_execute_wrapper(commands, arguments, editor_console, true)
		return [""]
	
	c_2 = ProjectSettings.globalize_path(c_2)
	var global_res = ProjectSettings.globalize_path("res://")
	if c_2 == "..":
		editor_console.os_cwd = editor_console.os_cwd.get_base_dir()
		return [""]
	var dir_exists = _check_dir_exists_shell(c_2, editor_console)
	if dir_exists:
		if c_2.begins_with("/"):
			editor_console.os_cwd = c_2
		else:
			editor_console.os_cwd = editor_console.os_cwd.path_join(c_2)
	else:
		if c_2.begins_with("/"):
			return ["Directory does not exist: %s" % c_2]
		else:
			return ["Directory does not exist: %s" % editor_console.os_cwd.path_join(c_2)]
	return [""]

static func _check_dir_exists_shell(dir, editor_console):
	var check_dir_command = []
	var os_name = OS.get_name()
	if os_name == _OS_LINUX or os_name == _OS_MAC:
		check_dir_command = ["test -d '%s' && echo 'true' || echo 'false'" % dir]
	elif os_name == _OS_WIN:
		check_dir_command = ["if exist \"%s\" (echo true) else (echo false)" % dir]
	var result = _execute_wrapper(check_dir_command, [], editor_console)
	return result[0].strip_edges() == "true"

static func _one_line_result(result_string):
	var one_line = result_string.replace("\n", "  ").strip_edges()
	return one_line

static func _execute_wrapper(commands:Array, arguments:Array, editor_console, print_result:=false):
	var combined = " ".join(commands)
	var shell_exe = ""
	var execute_commands = []
	var os_name = OS.get_name()
	if os_name == _OS_LINUX:
		shell_exe = "bash"
		var shell_command = "cd '%s' && %s" % [editor_console.os_cwd, combined]
		execute_commands = ["-c", shell_command]
	elif os_name == _OS_MAC:
		shell_exe = "zsh"
		var shell_command = "cd '%s' && %s" % [editor_console.os_cwd, combined]
		execute_commands = ["-c", shell_command]
	elif os_name == _OS_WIN:
		shell_exe = "cmd.exe"
		var shell_command = 'cd "%s" && %s' % [editor_console.os_cwd, combined]
		execute_commands = ["/C", shell_command]
	
	var output = []
	var exit = OS.execute(shell_exe, execute_commands, output, true)
	if exit == -1:
		var command_string = " ".join(commands).strip_edges()
		printerr("Failed to execute: %s" % command_string)
	if print_result:
		var formatted_result = "\n".join(output).strip_edges()
		if formatted_result != "":
			print(formatted_result)
	
	return output

