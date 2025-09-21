extends RefCounted

const PluginExporterStatic = preload("res://addons/plugin_exporter/src/class/export/plugin_exporter_static.gd")
const ExportData = preload("res://addons/plugin_exporter/src/class/export/export_data.gd")
const ExportObj = preload("res://addons/plugin_exporter/src/class/export/export_obj.gd")
const FileParser = preload("res://addons/plugin_exporter/src/class/export/file_parser.gd")
const ExportFileUtils = preload("res://addons/plugin_exporter/src/class/export/plugin_exporter_file_utils.gd")

const ParseBase = preload("res://addons/plugin_exporter/src/class/export/parse/parse_base.gd")
const ParseGD = preload("res://addons/plugin_exporter/src/class/export/parse/parse_gd.gd")
const ParseTSCN = preload("res://addons/plugin_exporter/src/class/export/parse/parse_tscn.gd")
const ParseCS = preload("res://addons/plugin_exporter/src/class/export/parse/parse_cs.gd")
const ParseTres = preload("res://addons/plugin_exporter/src/class/export/parse/parse_tres.gd")

const Backport = preload("res://addons/plugin_exporter/src/class/export/parse/gd/backport.gd")
const CompatData = preload("res://addons/plugin_exporter/src/class/export/backport/compat_data.gd")

const DUMMY_GDIGNORE_FILE = "res://addons/plugin_exporter/src/template/_gdignore.txt"

const PARSE_FOLDER_PATH = "res://addons/plugin_exporter/src/class/export/parse"

const CONFIG_FILE_PATH = "res://.godot/addons/plugin_exporter/plugin_exporter_config.json" #! ignore-remote
const EXPORT_TEMPLATE_PATH = "res://addons/plugin_exporter/src/template/plugin_export_template.json" #! dependency


static func get_global_classes_in_text(line:String, class_list_keys:Array):
	var classes = []
	var line_tokens = Tokenizer.words_only(line)
	for tok:String in line_tokens:
		if tok in class_list_keys:
			if line.find("class_name ") == -1:
				if not tok in classes:
					classes.append(tok)
	return classes
