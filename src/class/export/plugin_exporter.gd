class_name PluginExporter
extends RefCounted

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd") #>remote
const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")

const ExportFileUtils = UtilsLocal.ExportFileUtils
const ExportFileKeys = ExportFileUtils.ExportFileKeys
const USafeEditor = UtilsRemote.USafeEditor
const UFile = UtilsRemote.UFile

const ExportData = UtilsLocal.ExportData
const FileParser = UtilsLocal.FileParser

static func export_by_name(plugin_dir_name):
	var addon_dir = "res://addons".path_join(plugin_dir_name)
	var export_config_path = addon_dir.path_join("export_ignore/plugin_export.json")
	if not FileAccess.file_exists(export_config_path):
		printerr("Plugin Export config not found at: %s" % addon_dir)
		return
	export_plugin(export_config_path)

static func export_plugin(export_config_path, include_uid_overide=null, include_import_overide=null):
	var export_data = ExportData.new(export_config_path)
	if not export_data.data_valid:
		return
	
	update_git_submodule_details(export_config_path, export_data)
	
	var file_parser = FileParser.new()
	file_parser.set_parser_settings(export_data.parser_settings)
	
	
	if export_data.pre_script != "":
		if not ExportFileUtils.check_export_script_valid(export_data.pre_script, "pre_export"):
			return
		ExportFileUtils.run_export_script(export_data.pre_script, "pre_export")
	
	var full_export_path = export_data.full_export_path
	
	var options = export_data.get(ExportFileKeys.options)
	var overwrite = options.get(ExportFileKeys.overwrite, false)
	var include_uid = export_data.include_uid
	var include_import = export_data.include_import
	
	if include_uid_overide != null:
		if include_uid != include_uid_overide:
			print("Overiding 'Include UID': %s -> %s" % [include_uid_overide, not include_uid_overide])
		include_uid = include_uid_overide
	if include_import_overide != null:
		if include_import != include_import_overide:
			print("Overiding 'Include Import': %s -> %s" % [include_import_overide, not include_import_overide])
		include_import = include_import_overide
	
	for export:ExportData.Export in export_data.exports:
		var source = export.source
		var export_dir_path = export.export_dir_path
		
		file_parser.parse_cs.export_obj = export
		file_parser.parse_gd.export_obj = export
		file_parser.parse_tscn.export_obj = export
		
		for local_file_path in export.valid_files_for_transfer:
			var global_file_path = ProjectSettings.globalize_path(local_file_path)
			var remote_file_data = ExportFileUtils.get_remote_file(local_file_path, export)
			var file_data = export.valid_files_for_transfer.get(local_file_path)
			var export_path = file_data.get(ExportFileKeys.to)
			if remote_file_data == null:
				ExportFileUtils.export_file(global_file_path, export_path, include_uid, include_import)
			else:
				ExportFileUtils.export_remote_file(global_file_path, export_path, remote_file_data, include_uid, include_import, file_parser)
	
	
	if export_data.post_script != "":
		ExportFileUtils.run_export_script(export_data.post_script, "post_export")
	
	var files = UFile.scan_for_files(full_export_path, [])
	for file in files:
		var ext = file.get_extension()
		if ext in FileParser.TEXT_FILE_TYPES:
			file_parser.post_export_edit_file(file)
	
	var exported_dirs = DirAccess.get_directories_at(full_export_path)
	for dir in exported_dirs:
		var dir_path = full_export_path.path_join(dir)
		var zip_files = UFile.scan_for_files(dir_path, [], false,[],true)
		ExportFileUtils.write_zip_file(dir_path + ".zip", zip_files)
	
	if UtilsRemote.UFile.is_dir_in_or_equal_to_dir(export_data.export_root, "res://"):
		var gdignore_path = export_data.export_root.path_join(".gdignore")
		if not FileAccess.file_exists(gdignore_path):
			var file = FileAccess.open(gdignore_path, FileAccess.WRITE)
			file.close()
			print("Created .gdignore for in-resource file system export.")
	var plugin_name = export_data.full_export_path.trim_suffix("/").get_file()
	var accent_color = EditorInterface.get_editor_theme().get_color("accent_color", &"Editor").to_html()
	print_rich("'[color=%s]%s[/color]' [color=25c225]exported[/color]" % [accent_color, plugin_name])


static func update_git_submodule_details(export_config_path, export_data:ExportData=null):
	if export_data == null:
		export_data = ExportData.new(export_config_path)
	var git_details_file_lines = []
	var main_repo_path = "res://.git"
	if DirAccess.dir_exists_absolute(main_repo_path):
		var main_repo_lines = _get_git_data("res://", git_details_file_lines, "Main Repo")
		if main_repo_lines:
			var i = 0
			for line in main_repo_lines:
				line = line.trim_prefix("\t")
				main_repo_lines[i] = line
				i += 1
			git_details_file_lines.append_array(main_repo_lines)
	else:
		git_details_file_lines.append("No main repo found.\n")
	for export:ExportData.Export in export_data.exports:
		var single_export_git_file_lines = []
		git_details_file_lines.append("\nExport: " + export.export_folder)
		for file in export.all_remote_files:
			var dir = file.get_base_dir()
			while dir != "res://":
				var git_path = dir.path_join(".git")
				if FileAccess.file_exists(git_path):
					var lines = _get_git_data(dir, single_export_git_file_lines)
					if lines:
						single_export_git_file_lines.append_array(lines)
					break
				elif DirAccess.dir_exists_absolute(git_path):
					var lines = _get_git_data(dir, single_export_git_file_lines, "Repo")
					if lines:
						single_export_git_file_lines.append_array(lines)
				else:
					dir = dir.get_base_dir()
		
		git_details_file_lines.append_array(single_export_git_file_lines)
		if single_export_git_file_lines.size() == 0:
			git_details_file_lines.append("\tNo git modules.")
	
	var first_export = export_data.exports[0] as ExportData.Export
	var file_path = first_export.source.path_join(".export_git_details")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	for line in git_details_file_lines:
		file.store_line(line)

static func _get_git_data(dir, git_file_lines, repo_type="Submodule"):
	var global_dir = ProjectSettings.globalize_path(dir)
	global_dir = global_dir.trim_suffix("/")
	var repo_line = "\t%s: %s" % [repo_type, global_dir.get_file()]
	if repo_line in git_file_lines:
		return
	
	var args = [
		"-C",
		dir.replace("res://", ""),
		"rev-parse",
		"HEAD"
	]
	var output = []
	var exit_code = OS.execute("git", args, output)
	if exit_code == -1:
		printerr("Error getting commit: %s" % dir)
		return
	var commit = output[0].strip_edges()
	if commit == "":
		printerr("Error getting commit: %s" % dir)
		return
	var lines = [
		repo_line,
		"\t\tDir: %s" % dir,
		"\t\tCommit: %s" % commit,
	]
	return lines
