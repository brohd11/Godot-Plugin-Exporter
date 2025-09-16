const UtilsLocal = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/utils/console_utils_local.gd")
const UtilsRemote = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/utils/console_utils_remote.gd")

const PopupKeys = UtilsRemote.PopupHelper.ParamKeys
const ParsePopupKeys = UtilsLocal.ParsePopupKeys
const ECKeys = UtilsLocal.ParsePopupKeys
const ScopeDataKeys = UtilsLocal.ScopeDataKeys
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")

static func register_commands():
	return {}

static func get_completion(raw_text, commands:Array, args:Array, editor_console) -> Dictionary:
	var completion_data = {}
	if commands.size() == 1: ## Basic completion, if script is called, return commands
		return register_commands()
	return completion_data

static func parse(commands:Array, arguments:Array, editor_console):
	if commands.size() == 1 or UtilsLocal.check_help(commands):
		print("Help Message")
		return
	## Basic call template
	var c_2 = commands[1]
	var script_commands = register_commands() 
	var command_data = script_commands.get(c_2)
	if not command_data:
		print("Unrecognized command: %s" % c_2)
		return
	var callable = command_data.get("callable")
	if callable:
		callable.call(commands, arguments, editor_console)



### Plugin Exporter Global Classes
const EditorConsole = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/editor_console.gd")
### Plugin Exporter Global Classes

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_console_command_base = "res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/class/console_command_base.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

