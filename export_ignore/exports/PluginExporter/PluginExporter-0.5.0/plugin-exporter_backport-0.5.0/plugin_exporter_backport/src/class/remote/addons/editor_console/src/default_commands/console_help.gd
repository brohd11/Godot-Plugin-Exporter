
const HELP_TEXT = \
"--- Godot Console ---
Enter command to get more info.
--- Available Commands ---
%s"

static func parse(commands:Array, arguments, editor_console):
	var available_commands = editor_console.scope_dict.keys()
	available_commands = "\n".join(available_commands).strip_edges()
	
	print(HELP_TEXT.strip_edges() % available_commands)



### Plugin Exporter Global Classes
const EditorConsole = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/editor_console.gd")
### Plugin Exporter Global Classes

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_console_help = "res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/default_commands/console_help.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
