
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
const EditorConsole = preload("res://addons/plugin_exporter/src/class/remote/addons/editor_console/src/editor_console.gd")
### Plugin Exporter Global Classes

