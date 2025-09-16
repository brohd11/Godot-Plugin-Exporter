
const EditorConsole = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/editor_console.gd")

const DefaultCommands = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/default_commands/default.gd")
const ConsoleCfg = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/default_commands/console_cfg.gd")
const ConsoleHelp = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/default_commands/console_help.gd")
const ConsoleOS = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/default_commands/console_os.gd")
const ConsoleMisc = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/default_commands/console_misc.gd")

const ConsoleGlobalClass = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/default_commands/console_global_class.gd")
const ConsoleScript = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/default_commands/console_script.gd")

const SyntaxHl = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/utils/console_syntax.gd")

const ConsoleLineContainer = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/utils/console_line_container.gd")
const ConsoleTokenizer = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/utils/console_tokenizer.gd")

const UtilsRemote = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/utils/console_utils_remote.gd")

const EDITOR_CONSOLE_SCOPE_PATH = "res://.addons/editor_console/scope_data.json"

static func get_scope_data():
	return UtilsRemote.UFile.read_from_json(EDITOR_CONSOLE_SCOPE_PATH)

static func save_scope_data(new_data:Dictionary):
	UtilsRemote.UFile.write_to_json(new_data, EDITOR_CONSOLE_SCOPE_PATH)

static func pr_arg_size_err(expected_size:int, arg_size:int):
	printerr("Expected %s arguments, received %s" % [expected_size, arg_size])

class ScopeDataKeys:
	const global_classes = "global_classes"
	const sets = "sets"
	const scopes = "scopes"

class ParsePopupKeys:
	const METADATA = "METADATA_KEY"
	const ADD_ARGS = "add_args"
	const REPLACE_WORD = "replace_word"
	
	pass

static func get_global_class_list() -> Array:
	var class_names_array = []
	var classes = ProjectSettings.get_global_class_list()
	for data in classes:
		var _class = data.get("class")
		class_names_array.append(_class)
	return class_names_array

static func check_help(commands):
	if "-h" in commands or "--help" in commands:
		return true
	return false

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_console_utils_local = "res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/utils/console_utils_local.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
