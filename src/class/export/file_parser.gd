extends RefCounted

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")

const ExportFileKeys = UtilsLocal.ExportFileUtils.ExportFileKeys

const TEXT_FILE_TYPES = ["gd", "tscn", "cs"] # TODO add tres support

var parse_gd: UtilsLocal.ParseGD
var parse_tscn: UtilsLocal.ParseTSCN
var parse_cs: UtilsLocal.ParseCS

func _init() -> void:
	parse_gd = UtilsLocal.ParseGD.new()
	parse_tscn = UtilsLocal.ParseTSCN.new()
	parse_cs = UtilsLocal.ParseCS.new()

func set_parser_settings(parser_settings):
	var gd_settings = parser_settings.get("parse_gd", {})
	parse_gd.set_parse_settings(gd_settings)
	var tscn_settings = parser_settings.get("parse_tscn", {})
	parse_tscn.set_parse_settings(tscn_settings)
	var cs_settings = parser_settings.get("parse_cs", {})
	parse_cs.set_parse_settings(cs_settings)

func set_export_obj(export_obj):
	parse_gd.export_obj = export_obj
	parse_cs.export_obj = export_obj
	parse_tscn.export_obj = export_obj

func get_dependencies(file_path:String, all_dependencies:Dictionary, scanned_files:Dictionary):
	var files_to_scan = [file_path]
	while not files_to_scan.is_empty():
		var current_file_path = files_to_scan.pop_front()
		
		if scanned_files.has(current_file_path):
			continue
		scanned_files[current_file_path] = true
		
		var file_deps = {}
		var ext = current_file_path.get_extension()
		if ext == "gd":
			file_deps = parse_gd.get_direct_dependencies(current_file_path)
		elif ext == "cs":
			file_deps = parse_cs.get_direct_dependencies(current_file_path)
		elif ext == "tscn":
			file_deps = parse_tscn.get_direct_dependencies(current_file_path)
		else:
			continue
		
		for path in file_deps.keys():
			var data = file_deps.get(path)
			all_dependencies[path] = {ExportFileKeys.dependent:current_file_path}
			var dep_dir = data.get(ExportFileKeys.dependency_dir)
			if dep_dir != null:
				all_dependencies[path][ExportFileKeys.dependency_dir] = dep_dir
			if not scanned_files.has(path):
				files_to_scan.push_back(path)


func post_export_edit_file(file_path:String):
	var ext = file_path.get_extension()
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("Could not open file: %s" % file_path)
		return
	var file_lines = []
	while not file.eof_reached():
		file_lines.append(file.get_line())
	
	file.close()
	
	var file_lines_edited
	if ext == "gd":
		file_lines_edited = parse_gd.post_export_edit_file(file_path)
	elif ext == "tscn":
		file_lines_edited = parse_tscn.post_export_edit_file(file_path)
	elif ext == "cs":
		file_lines_edited = parse_cs.post_export_edit_file(file_path)
	if file_lines_edited != null:
		file_lines = file_lines_edited
	
	
	var final_file_lines = []
	for line in file_lines:
		if ext == "gd":
			final_file_lines.append(parse_gd.post_export_edit_line(line))
		elif ext == "tscn":
			final_file_lines.append(parse_tscn.post_export_edit_line(line))
		elif ext == "cs":
			final_file_lines.append(parse_cs.post_export_edit_line(line))
		
	
	
	var write_file_access = FileAccess.open(file_path, FileAccess.WRITE)
	for line in final_file_lines:
		write_file_access.store_line(line)
	
	write_file_access.close()

func _update_file_export_flags(file_path):
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	var file_lines = []
	while not file_access.eof_reached():
		var line = file_access.get_line()
		if line.find("const PLUGIN_EXPORTED = true") > -1:
			line = line.replace("const PLUGIN_EXPORTED = true", "const PLUGIN_EXPORTED = true")
		file_lines.append(line)
	
	file_access = FileAccess.open(file_path, FileAccess.WRITE)
	for line in file_lines:
		file_access.store_line(line)


static func write_new_uid(uid_path):
	var id = ResourceUID.create_id()
	var uid = ResourceUID.id_to_text(id)
	var f = FileAccess.open(uid_path, FileAccess.WRITE)
	f.store_string(uid)
