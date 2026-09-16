extends "res://addons/plugin_exporter/src/class/export/parse/parse_base.gd"
## Keep the package's source identities and relocation policy outside the shared optimizer.

const Optimizer = UtilsRemote.GDScriptOptimizer

var _optimizer


func pre_export() -> void:
	var context = Optimizer.Context.new()
	context.set_global_classes(export_obj.export_data.class_list)
	context.removed_globals = export_obj.class_renames
	context.map_path = get_adjusted_path_or_old_renamed
	context.scan_references = _references
	context.injection_header = "### Plugin Exporter Structs"
	var sources = {}
	for key:String in export_obj.files_to_copy:
		var source:String = export_obj.files_to_copy[key].get(KeysData.REPLACE_WITH, key)
		if source.get_extension() == "gd":
			sources[key] = source
	_optimizer = Optimizer.new()
	var result = _optimizer.prepare(sources, context)
	for warning in result.warnings:
		UtilsRemote.UEditor.print_warn("#! struct - " + warning)
	_fail(result.errors)


func _references(path:String) -> Array:
	var paths:Array = []
	for edge in scan_direct_edges(path):
		if edge.to != "":
			paths.append(edge.to)
	var classes:Dictionary = export_obj.export_data.class_list
	var globals:Dictionary = ExportFileUtils._get_global_classes_in_file(path, classes)
	globals.erase("global_class_definition")
	for name in globals:
		if classes.has(name):
			paths.append(classes[name])
	return paths


func post_export_edit_file(file_path:String, file_lines:Variant = null) -> Variant:
	if _optimizer == null:
		return file_lines
	var key:String = export_obj.file_parser.current_file_path_parsing
	if not _optimizer.planned_files().has(key):
		return file_lines
	if file_lines == null:
		file_lines = Array(FileAccess.get_file_as_string(file_path).split("\n"))
	var result = _optimizer.apply(key, file_lines)
	var errors:Array = []
	for error in result.errors:
		errors.append("%s: %s" % [file_path, error])
	_fail(errors)
	return result.lines


func _fail(errors:Array) -> void:
	for error in errors:
		printerr("Plugin Exporter - #! struct - " + error)
	if not errors.is_empty():
		export_obj.invalidate()
