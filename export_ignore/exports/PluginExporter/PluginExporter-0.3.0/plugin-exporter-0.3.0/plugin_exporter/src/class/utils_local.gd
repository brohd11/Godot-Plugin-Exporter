extends RefCounted

const PluginExporter = preload("res://addons/plugin_exporter/src/class/export/plugin_exporter.gd")
const ExportData = preload("res://addons/plugin_exporter/src/class/export/export_data.gd")
const ExportObj = preload("res://addons/plugin_exporter/src/class/export/export_obj.gd")

### Plugin Exporter Global Classes
const Tokenizer = preload("res://addons/plugin_exporter/src/class/remote/alib_tokenizer.gd")
### Plugin Exporter Global Classes

const FileParser = preload("res://addons/plugin_exporter/src/class/export/file_parser.gd")
const ExportFileUtils = preload("res://addons/plugin_exporter/src/class/export/plugin_exporter_file_utils.gd")

const ParseBase = preload("res://addons/plugin_exporter/src/class/export/parse_base.gd")
const ParseGD = preload("res://addons/plugin_exporter/src/class/export/parse_gd.gd")
const ParseTSCN = preload("res://addons/plugin_exporter/src/class/export/parse_tscn.gd")
const ParseCS = preload("res://addons/plugin_exporter/src/class/export/parse_cs.gd")

const DUMMY_GDIGNORE_FILE = "res://addons/plugin_exporter/src/template/_gdignore.txt"

static func get_global_classes_in_text(line:String, class_list_keys:Array):
	var classes = []
	var line_tokens = Tokenizer.words_only(line)
	for tok in line_tokens:
		if tok in class_list_keys:
			if line.find("class_name ") == -1:
				print(tok)
				classes.append(tok)
	return classes

