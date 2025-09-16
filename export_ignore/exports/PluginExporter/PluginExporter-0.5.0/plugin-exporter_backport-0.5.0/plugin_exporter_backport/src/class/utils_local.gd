extends RefCounted

const PluginExporterStatic = preload("res://addons/plugin_exporter_backport/src/class/export/plugin_exporter_static.gd")
const ExportData = preload("res://addons/plugin_exporter_backport/src/class/export/export_data.gd")
const ExportObj = preload("res://addons/plugin_exporter_backport/src/class/export/export_obj.gd")
const FileParser = preload("res://addons/plugin_exporter_backport/src/class/export/file_parser.gd")
const ExportFileUtils = preload("res://addons/plugin_exporter_backport/src/class/export/plugin_exporter_file_utils.gd")

const ParseBase = preload("res://addons/plugin_exporter_backport/src/class/export/parse/parse_base.gd")
const ParseGD = preload("res://addons/plugin_exporter_backport/src/class/export/parse/parse_gd.gd")
const ParseTSCN = preload("res://addons/plugin_exporter_backport/src/class/export/parse/parse_tscn.gd")
const ParseCS = preload("res://addons/plugin_exporter_backport/src/class/export/parse/parse_cs.gd")
const ParseTres = preload("res://addons/plugin_exporter_backport/src/class/export/parse/parse_tres.gd")

const CompatData = preload("res://addons/plugin_exporter_backport/src/class/export/backport/compat_data.gd")

const DUMMY_GDIGNORE_FILE = "res://addons/plugin_exporter_backport/src/template/_gdignore.txt"

const PARSE_FOLDER_PATH = "res://addons/plugin_exporter_backport/src/class/export/parse"

const CONFIG_FILE_PATH = "res://.godot/addons/plugin_exporter/plugin_exporter_config.json"
const EXPORT_TEMPLATE_PATH = "res://addons/plugin_exporter_backport/src/template/plugin_export_template.json" #! dependency
const PRE_POST_TEMPLATE_PATH = "res://addons/plugin_exporter_backport/src/template/pre_post.gd" #! dependency

static func get_global_classes_in_text(line:String, class_list_keys:Array):
	var classes = []
	var line_tokens = Tokenizer.words_only(line)
	for tok in line_tokens:
		if tok in class_list_keys:
			if line.find("class_name ") == -1:
				if not tok in classes:
					classes.append(tok)
	return classes



### Plugin Exporter Global Classes
const Tokenizer = preload("res://addons/plugin_exporter_backport/src/class/remote/addons/addon_lib/brohd/tokens/alib_tokenizer.gd")
### Plugin Exporter Global Classes

### PLUGIN EXPORTER EDITORINTERFACE BACKPORT
const _EIBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/ei_backport.gd")
### PLUGIN EXPORTER EDITORINTERFACE BACKPORT

### PLUGIN EXPORTER STATIC VAR BACKPORT
const _BackportStaticVar = preload("res://addons/plugin_exporter_backport/src/class/export/backport/sv_backport.gd")
const _BPSV_PATH_utils_local = "res://addons/plugin_exporter_backport/src/class/utils_local.gd"
### PLUGIN EXPORTER STATIC VAR BACKPORT

### PLUGIN EXPORTER MISC BACKPORT
const MiscBackport = preload("res://addons/plugin_exporter_backport/src/class/export/backport/misc_backport_class.gd")
### PLUGIN EXPORTER MISC BACKPORT
