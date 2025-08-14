extends RefCounted

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")

const TEXT_FILE_TYPES = ["gd", "tscn", "tres", "cs"]

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


func copy_remote_dependencies(write:bool, remote_file:String, to:String, dependent:String, remote_dir:String="", processed_files={}):
	if remote_file in processed_files: #TODO handle this for files with different names than remote, Think fs_rem vs filesystem case
		#print("Duplicate remote file: %s Dependent: %s" % [remote_file, dependent.get_file()])
		return []
	processed_files[remote_file] = to
	if remote_dir == "":
		remote_dir = to.get_base_dir()
	var valid_text_file = remote_file.get_extension() in TEXT_FILE_TYPES
	var file_access = FileAccess.open(remote_file, FileAccess.READ)
	if not file_access:
		print("Couldn't open file: %s" % remote_file)
		return []
	
	if valid_text_file:
		var first_line = file_access.get_line()
		if first_line.find("#! remote") > -1:
			while not file_access.eof_reached():
				var line = file_access.get_line()
				if line.find("extends") > -1 and line.count('"') == 2:
					var new_remote_file = line.get_slice("extends", 1)
					new_remote_file = new_remote_file.strip_edges().trim_prefix('"').trim_suffix('"')
					if FileAccess.file_exists(new_remote_file):
						remote_file = new_remote_file
						file_access = FileAccess.open(remote_file, FileAccess.READ)
	
	
	file_access.seek(0)
	var ext = remote_file.get_extension()
	var file_lines = []
	var dependencies = {}
	if valid_text_file:
		while not file_access.eof_reached():
			var line = file_access.get_line()
			if ext == "gd":
				line = parse_gd.edit_dep_file(line, to, remote_file, remote_dir, dependencies)
			elif ext == "tscn":
				line = parse_tscn.edit_dep_file(line, to, remote_file, remote_dir, dependencies)
			elif ext == "cs":
				line = parse_cs.edit_dep_file(line, to, remote_file, remote_dir, dependencies)
			
			file_lines.append(line)
	
	
	if write:
		if not DirAccess.dir_exists_absolute(to.get_base_dir()):
			DirAccess.make_dir_recursive_absolute(to.get_base_dir())
		if valid_text_file:
			var file_write = FileAccess.open(to, FileAccess.WRITE)
			for line in file_lines:
				file_write.store_line(line)
		else:
			DirAccess.copy_absolute(remote_file, to)
	
	var all_child_deps = []
	for file_path in dependencies:
		var data = dependencies.get(file_path)
		all_child_deps.append(data)
		var to_path = data.get("to")
		var from_path = data.get("from")
		
		if write:
			if FileAccess.file_exists(to_path):
				continue
			if not DirAccess.dir_exists_absolute(to_path.get_base_dir()):
				DirAccess.make_dir_recursive_absolute(to_path.get_base_dir())
			DirAccess.copy_absolute(from_path, to_path)
			if FileAccess.file_exists(from_path+".uid"):
				var uid_path = to_path + ".uid"
				write_new_uid(uid_path)
		
		
		var child_deps = copy_remote_dependencies(write, from_path, to_path, dependent, remote_dir, processed_files)
		all_child_deps.append_array(child_deps)
	
	return all_child_deps

func post_export_edit_file(file_path:String):
	var ext = file_path.get_extension()
	var file = FileAccess.open(file_path, FileAccess.READ_WRITE)
	if not file:
		printerr("Could not open file: %s" % file_path)
		return
	var file_lines = []
	while not file.eof_reached():
		var line = file.get_line()
		if ext == "gd":
			file_lines.append(parse_gd.post_export_edit_line(line))
		elif ext == "tscn":
			file_lines.append(parse_tscn.post_export_edit_line(line))
		elif ext == "cs":
			file_lines.append(parse_cs.post_export_edit_line(line))
	
	file.seek(0)
	for line in file_lines:
		file.store_line(line)
	
	file.close()

func _update_file_export_flags(file_path):
	var file_access = FileAccess.open(file_path, FileAccess.READ)
	var file_lines = []
	while not file_access.eof_reached():
		var line = file_access.get_line()
		if line.find("const PLUGIN_EXPORTED = false") > -1:
			line = line.replace("const PLUGIN_EXPORTED = false", "const PLUGIN_EXPORTED = true")
		file_lines.append(line)
	
	file_access = FileAccess.open(file_path, FileAccess.WRITE)
	for line in file_lines:
		file_access.store_line(line)


static func write_new_uid(uid_path):
	var id = ResourceUID.create_id()
	var uid = ResourceUID.id_to_text(id)
	var f = FileAccess.open(uid_path, FileAccess.WRITE)
	f.store_string(uid)
