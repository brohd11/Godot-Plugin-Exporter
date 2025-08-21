const _ExportData = preload("res://addons/plugin_exporter/src/class/export/export_data.gd")
var export_data: _ExportData
var source:String
var source_files:Array
var valid_files_for_transfer:Dictionary
var global_classes:Dictionary = {}
var remote_dir:String
var export_folder:String
var export_dir_path:String
var exclude_directories:Array
var exclude_file_extensions:Array
var exclude_files:Array
var other_transfers:Array
var other_transfers_data:Dictionary

var all_remote_files:Array
