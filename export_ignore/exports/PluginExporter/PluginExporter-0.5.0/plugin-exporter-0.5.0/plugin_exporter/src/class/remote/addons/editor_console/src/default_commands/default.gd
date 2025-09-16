extends "res://addons/plugin_exporter/src/class/remote/addons/editor_console/src/class/console_command_set_base.gd"

static func register_scopes():
	return {
		"script": {
			"script": UtilsLocal.ConsoleScript
		},
		"global":{
			"script": UtilsLocal.ConsoleGlobalClass
		},
		"config":{
			"script": UtilsLocal.ConsoleCfg
		},
		"misc":{
			"script":UtilsLocal.ConsoleMisc
		},
	}


static func register_hidden_scopes():
	return {
		"clear":{
			"script": UtilsLocal.ConsoleCfg,
		},
		"help": {
			"script": UtilsLocal.ConsoleHelp,
		},
		"os":{
			"script": UtilsLocal.ConsoleOS
		},
	}


static func register_variables():
	return {
		"$script-cur-path": func(): return EditorInterface.get_script_editor().get_current_script().resource_path,
		"$script-cur": func(): return EditorInterface.get_script_editor().get_current_script()
	}

