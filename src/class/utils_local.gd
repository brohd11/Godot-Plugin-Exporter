extends RefCounted

const PluginExporter = preload("res://addons/plugin_exporter/src/class/export/plugin_exporter.gd")
const FileParser = preload("res://addons/plugin_exporter/src/class/export/file_parser.gd")

const ParseBase = preload("res://addons/plugin_exporter/src/class/export/parse_base.gd")
const ParseGD = preload("res://addons/plugin_exporter/src/class/export/parse_gd.gd")
const ParseTSCN = preload("res://addons/plugin_exporter/src/class/export/parse_tscn.gd")
const ParseCS = preload("res://addons/plugin_exporter/src/class/export/parse_cs.gd")
