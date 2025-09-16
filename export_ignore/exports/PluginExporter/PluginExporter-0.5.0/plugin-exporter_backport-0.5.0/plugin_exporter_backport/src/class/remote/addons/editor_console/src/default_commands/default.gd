extends "res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/class/console_command_set_base.gd"

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
		"$script-cur-path": func(): return _EIBackport.get_ins().ei.get_script_editor().get_current_script().resource_path,
		"$script-cur": func(): return _EIBackport.get_ins().ei.get_script_editor().get_current_script()
	}

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BPSV_PATH_default = "res://addons/plugin_exporter_backport/src/class/remote/addons/editor_console/src/default_commands/default.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

