extends RefCounted

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd") #>remote
const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")

const ExportFileUtils = UtilsRemote.ExportFileUtils
const ExportFileKeys = ExportFileUtils.ExportFileKeys
const USafeEditor = UtilsRemote.USafeEditor
const UFile = UtilsRemote.UFile

const FileParser = UtilsLocal.FileParser

static func export_plugin(export_config_path, include_uid_overide=null, include_import_overide=null):
	var export_script_node_parent = EditorInterface.get_base_control()
	
	var export_root = ""
	var file_parser = FileParser.new()
	
	var export_data = ExportFileUtils.get_export_data(export_config_path)
	if not export_data:
		return
	export_root = ExportFileUtils.get_export_root(export_config_path)
	if export_root == "":
		return
	
	var post_script = export_data.get("post_script","")
	if post_script != "":
		if not ExportFileUtils.check_export_script_valid(post_script, "post_export"):
			return
	
	var pre_script = export_data.get("pre_script","")
	if pre_script != "":
		if not ExportFileUtils.check_export_script_valid(pre_script, "pre_export"):
			return
		ExportFileUtils.run_export_script(pre_script, "pre_export")
	
	
	var options = export_data.get(ExportFileKeys.options)
	
	var overwrite = options.get(ExportFileKeys.overwrite, false)
	
	var include_uid = options.get(ExportFileKeys.include_uid, true)
	var include_import = options.get(ExportFileKeys.include_import, true)
	if include_uid_overide != null:
		if include_uid != include_uid_overide:
			print("Overiding 'Include UID': ", include_uid_overide)
		include_uid = include_uid_overide
	
	if include_import_overide != null:
		if include_import != include_import_overide:
			print("Overiding 'Include Import': ", include_import_overide)
		include_import = include_import_overide
	
	var parser_settings = options.get("parser_settings", {})
	file_parser.set_parser_settings(parser_settings)
	
	var exports = export_data.get(ExportFileKeys.exports)
	for export in exports:
		var source = export.get(ExportFileKeys.source)
		if not source.ends_with("/"):
			source = source + "/"
		if not DirAccess.dir_exists_absolute(source):
			USafeEditor.push_toast(source + " does not exist.",2)
			return
		var export_folder:String = export.get(ExportFileKeys.export_folder)
		if export_folder == "":
			export_folder = source.get_base_dir().get_file()
		
		export_folder = ExportFileUtils.replace_version(export_folder, export_config_path)
		if export_folder == "":
			return
		
		if not export_folder.ends_with("/"):
			export_folder = export_folder + "/"
		
		var exclude = export.get(ExportFileKeys.exclude)
		var directories = exclude.get(ExportFileKeys.directories)
		var file_extensions = exclude.get(ExportFileKeys.file_extensions)
		var files = exclude.get(ExportFileKeys.files)
		
		var source_files = UFile.scan_for_files(source, [])
		var export_dir_path = export_root.path_join(export_folder)
		var all_remote_files = ExportFileUtils.get_all_remote_files(source_files, source, export_dir_path)
		
		var other_transfers = export.get(ExportFileKeys.other_transfers, [])
		var other_transfer_data = ExportFileUtils.get_other_transfer_data(other_transfers, source, export_dir_path, all_remote_files)
		
		for file in source_files:
			if file.get_extension() == "uid" or file.get_extension() == "import":
				continue
			
			var l_path = ProjectSettings.localize_path(file)
			if ExportFileUtils.check_ignore(l_path, directories, file_extensions, files):
				continue
			
			var export_path = l_path.replace(source, export_dir_path)
			if FileAccess.file_exists(export_path) and not overwrite:
				USafeEditor.push_toast("File exists, aborting: "+export_path, 2)
				return
			var export_dir = export_path.get_base_dir()
			
			var file_ext = l_path.get_extension()
			if file_ext == "" and DirAccess.dir_exists_absolute(l_path):
				export_dir = export_path
			
			if not DirAccess.dir_exists_absolute(export_dir):
				DirAccess.make_dir_recursive_absolute(export_dir)
			
			if FileAccess.file_exists(l_path): # check that it is file vs dir
				var remote_file_data = ExportFileUtils.get_remote_file(l_path, source, export_dir_path)
				if remote_file_data == null:
					ExportFileUtils.export_file(file, export_path, include_uid, include_import)
				else:
					ExportFileUtils.export_remote_file(file, export_path, remote_file_data, include_uid, include_import, file_parser)
		
		#next step
		for to in other_transfer_data.keys():
			var data = other_transfer_data.get(to)
			var from_files = data.get("from_files")
			var single_from = data.get("single")
			for from in from_files:
				if not FileAccess.file_exists(from):
					USafeEditor.push_toast("File_doesn't exist, aborting: " + from, 2)
					return
				
				var to_path = to
				if not single_from:
					to_path = to.path_join(from.get_file())
				
				if FileAccess.file_exists(to_path) and not overwrite:
					USafeEditor.push_toast("File exists, aborting: " + to_path, 2)
					return
				
				var remote_file_data = ExportFileUtils.get_remote_file(from, source, export_dir_path)
				if remote_file_data == null:
					ExportFileUtils.export_file(from, to_path, include_uid, include_import)
				else:
					ExportFileUtils.export_remote_file(from, to_path, remote_file_data, include_uid, include_import, file_parser)
	
	
	if post_script != "":
		ExportFileUtils.run_export_script(post_script, "post_export")
	
	var files = UFile.scan_for_files(export_root, [])
	for file in files:
		var ext = file.get_extension()
		if ext in FileParser.TEXT_FILE_TYPES:
			file_parser.post_export_edit_file(file)
	
	var exported_dirs = DirAccess.get_directories_at(export_root)
	for dir in exported_dirs:
		var dir_path = export_root.path_join(dir)
		var zip_files = UFile.scan_for_files(dir_path, [], false,[],true)
		ExportFileUtils.write_zip_file(dir_path + ".zip", zip_files)
	
