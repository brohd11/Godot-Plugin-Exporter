extends RefCounted

const IGNORE_FILES = [".gitignore", ".gitattributes", ".gitmodules", ".git"]

static func scan_for_files(dir:String,file_types:Array, include_dirs=false, ignore_dirs:Array=[], show_ignore=false) -> Array:
	var file_array:Array = []
	var files:Array = []
	
	var dir_access:DirAccess = DirAccess.open(dir)
	if not dir_access:
		return file_array
	dir_access.include_hidden = true
	
	if dir_access.dir_exists_absolute(dir):
		files = dir_access.get_files()
	
	if ".gdignore" in files:
		if not show_ignore:
			return file_array
	
	if include_dirs:
		file_array.append(dir)
	
	var dirs:Array = []
	if dir_access.dir_exists_absolute(dir):
		
		dirs = dir_access.get_directories_at(dir)
		dirs.sort_custom(_case_insensitive_compare)
	
	for d:String in dirs:
		var dir_path:String = dir.path_join(d)
		if dir_path in ignore_dirs:
			continue
		var recur_files:Array = scan_for_files(dir_path,file_types,include_dirs,ignore_dirs,show_ignore)
		file_array.append_array(recur_files)
	
	var ignore_files:Array = IGNORE_FILES
	if show_ignore:
		ignore_files = []
	
	for f:String in files:
		if file_types == []:
			if f in ignore_files:
				continue
			
			var file_path:String = dir.path_join(f)
			file_array.append(file_path)
			continue
		if f.to_lower().get_extension() in file_types:
			var file_path:String = dir.path_join(f)
			file_array.append(file_path)
	
	return file_array


static func scan_for_dirs(dir:String,seperate_stacks:bool=false):
	var folders = [] # seperate stacks to get all directories in a hierachy as a seperate array
	var dir_stacks = [] # then can reverse each array and iterate bottom up for deletion
	if DirAccess.dir_exists_absolute(dir):
		folders = DirAccess.get_directories_at(dir)
	for f in folders:
		var dir_array = []
		var current_dir = dir.path_join(f)
		dir_array.append(current_dir)
		var next_dir_path = dir.path_join(f)
		var recur_dirs = scan_for_dirs(next_dir_path)
		dir_array.append_array(recur_dirs)
		if seperate_stacks:
			dir_stacks.append(dir_array)
		else:
			dir_stacks.append_array(dir_array)
	
	return dir_stacks


static func _case_insensitive_compare(a: String, b: String) -> int:
	var a_lower = a.to_lower()
	var b_lower = b.to_lower()
	if a_lower < b_lower:
		return true
	else:
		return false

static func write_to_json_exported(data:Variant, path:String, export_flag, access=FileAccess.WRITE_READ):
	if export_flag:
		path = path_from_relative(path, true)
	print(path)
	write_to_json(data, path, access)

static func write_to_json(data:Variant,path:String,access=FileAccess.WRITE_READ) -> void:
	var data_string = JSON.stringify(data,"\t")
	var json_file = FileAccess.open(path, access)
	json_file.store_string(data_string)


static func read_from_json(path:String,access=FileAccess.READ) -> Dictionary:
	if not FileAccess.file_exists(path):
		path = path_from_relative(path)
	
	var json_read = JSON.new()
	var json_load = FileAccess.open(path, access)
	if json_load == null:
		print("Couldn't load JSON: ", path)
		return {}
	var json_string = json_load.get_as_text()
	var err = json_read.parse(json_string)
	if err != OK:
		print("Couldn't load JSON, error: ", err)
		return {}
	
	return json_read.data


static func hash_string(text:String):
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	var hash = ctx.finish()
	var hash_encode = hash.hex_encode()
	return hash_encode

static func create_dir(file_path:String):
	if not DirAccess.dir_exists_absolute(file_path):
		DirAccess.make_dir_recursive_absolute(file_path)

static func copy_file(from:String, to:String, overwrite:bool=false) -> Error:
	if not overwrite:
		if FileAccess.file_exists(to):
			return ERR_ALREADY_EXISTS
	var base_dir:String = to.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
	var err = DirAccess.copy_absolute(from, to)
	return err

static func uid_to_path(uid:String):
	if not uid.begins_with("uid://"):
		return uid
	return ResourceUID.get_id_path(ResourceUID.text_to_id(uid))

static func path_to_uid(path:String):
	if path.begins_with("uid://"):
		return path
	var uid = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(path))
	if uid == "uid://<invalid>":
		uid = path
	return uid

static func load_config_file(path:String):
	var config = ConfigFile.new()
	var err = config.load(path)
	if err != OK:
		print(err)
		return
	return config

static func replace_text_in_file(file_path, replace, with):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var lines = []
		while not file.eof_reached():
			var line = file.get_line()
			lines.append(line)
		file.close()
		file = FileAccess.open(file_path, FileAccess.WRITE)  # Open for writing
		if file:
			for line in lines:
				if line.find(replace) > -1:
					line = line.replace(replace, with)
				file.store_line(line)
				
			file.close() 

static func check_scene_root(file_path:String, valid_types:Array) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("Could not open file: " + file_path)
		return false
	while not file.eof_reached():
		var line = file.get_line()
		if not line.find("[node name=") > -1:
			continue
		var first_pass_type = line.get_slice('type="', 1)
		var type = first_pass_type.get_slice('"', 0)
		if not type in valid_types:
			printerr("Scene is not a UI root: " + file_path)
			return false
		else:
			return true
	return false

static func get_relative_path(from_path: String, to_path: String) -> String:
	var from_dir = from_path.get_base_dir()
	var from_parts: PackedStringArray = from_dir.trim_prefix("/").split("/")
	var to_parts: PackedStringArray = to_path.trim_prefix("/").split("/")
	# If a path was just "/", the split results in ["'"], so we clear it.
	if from_parts.size() == 1 and from_parts[0] == "":
		from_parts = []
	if to_parts.size() == 1 and to_parts[0] == "":
		to_parts = []
	# 3. Find the length of the common root path.
	# We iterate while the components of both paths match.
	var common_path_len = 0
	while (common_path_len < from_parts.size() and
		   common_path_len < to_parts.size() and
		   from_parts[common_path_len] == to_parts[common_path_len]):
		common_path_len += 1
	
	var relative_parts: Array = []
	var num_dirs_up = from_parts.size() - common_path_len
	for i in range(num_dirs_up):
		relative_parts.append("..")
	
	var remaining_to_parts = to_parts.slice(common_path_len, to_parts.size())
	relative_parts.append_array(remaining_to_parts)
	
	if relative_parts.is_empty():
		return "."
	else:
		var final_string = ""
		final_string = "/".join(relative_parts)
		return final_string

static func path_from_relative(path_or_name:String, new_file:=false, print_err:=true) -> String: # DEPRECATED
	return get_plugin_exported_path(path_or_name, new_file, print_err)

static func get_plugin_exported_path(path_or_name:String, new_file:=false, print_err:=true) -> String:
	var script_dir = _get_script_dir()
	var file_name = path_or_name.get_file()
	var script_rel_path = script_dir.path_join(file_name)
	var new_path = ""
	if new_file:
		return script_rel_path
	else:
		if FileAccess.file_exists(path_or_name):
			new_path = path_or_name
		else:
			if FileAccess.file_exists(script_rel_path):
				new_path = script_rel_path
			else:
				if print_err:
					print("File doesn't exist: %s - Or relative path: %s" % [path_or_name, script_rel_path])
	
	return new_path

static func relative_file_exists(path_or_name:String) -> bool: # DEPRECATED
	return plugin_exported_file_exists(path_or_name)

static func plugin_exported_file_exists(path_or_name:String) -> bool:
	var dir = _get_script_dir()
	var rel_path = dir.path_join(path_or_name.get_file())
	return FileAccess.file_exists(rel_path)


static func _get_script_dir() -> String:
	var script = new()
	return script.get_script().resource_path.get_base_dir()

static func is_file_in_directory(file_path: String, dir_path: String) -> bool:
	var absolute_file_path = ProjectSettings.globalize_path(file_path)
	var absolute_dir_path = ProjectSettings.globalize_path(dir_path)
	# 2. Ensure the directory path ends with a separator.
	#    This is crucial to prevent false positives where directory names are prefixes
	#    of other directory names (e.g., "folder" and "folder_plus").
	if not absolute_dir_path.ends_with("/"):
		absolute_dir_path += "/"
	# 3. A path cannot be a child of itself.
	if absolute_file_path == absolute_dir_path:
		return false
	# 4. The file path must begin with the fully resolved directory path.
	return absolute_file_path.begins_with(absolute_dir_path)

static func is_dir_in_or_equal_to_dir(file_path: String, dir_path: String) -> bool:
	var absolute_file_path = ProjectSettings.globalize_path(file_path)
	var absolute_dir_path = ProjectSettings.globalize_path(dir_path)
	if not absolute_file_path.ends_with("/"):
		absolute_file_path += "/"
	if not absolute_dir_path.ends_with("/"):
		absolute_dir_path += "/"
	#if absolute_file_path == absolute_dir_path:
		#return true
	return absolute_file_path.begins_with(absolute_dir_path)
	












