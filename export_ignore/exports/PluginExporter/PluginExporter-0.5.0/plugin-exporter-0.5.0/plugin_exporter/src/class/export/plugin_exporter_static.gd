extends RefCounted

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd") #>remote
const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")

const ExportFileUtils = UtilsLocal.ExportFileUtils
const ExportFileKeys = ExportFileUtils.ExportFileKeys
const UFile = UtilsRemote.UFile

const ExportData = UtilsLocal.ExportData
const FileParser = UtilsLocal.FileParser

static func export_by_gui(export_config_path:String, include_uid_overide=null, include_import_overide=null):
	var success = export_plugin(export_config_path, include_uid_overide, include_import_overide)
	
	_print_result(success, export_config_path)


static func export_by_name(plugin_dir_name):
	var addon_dir = "res://addons".path_join(plugin_dir_name)
	var export_config_path = addon_dir.path_join("export_ignore/plugin_export.json")
	if not FileAccess.file_exists(export_config_path):
		printerr("Plugin Export config not found at: %s" % addon_dir)
		return
	var success = export_plugin(export_config_path)
	
	_print_result(success, export_config_path)


static func _print_result(success:bool, export_config_path:String):
	var plugin_dir_name = export_config_path.get_base_dir().get_base_dir().get_file()
	var plugin_version = ExportFileUtils.get_version(plugin_dir_name, export_config_path)
	var plugin_name = "%s - %s" % [plugin_dir_name.capitalize(), plugin_version] 
	var accent_color = EditorInterface.get_editor_theme().get_color("accent_color", &"Editor").to_html()
	if success:
		print_rich("'[color=%s]%s[/color]' [color=25c225]exported[/color]" % [accent_color, plugin_name])
	else:
		print_rich("'[color=%s]%s[/color]' [color=b20f0f]export failed[/color]" % [accent_color, plugin_name])


static func export_plugin(export_config_path:String, include_uid_overide=null, include_import_overide=null):
	var plugin_dir_name = export_config_path.get_base_dir().get_base_dir().get_file()
	var plugin_version = ExportFileUtils.get_version(plugin_dir_name, export_config_path)
	var plugin_name = "%s - %s" % [plugin_dir_name.capitalize(), plugin_version] 
	print("Exporting: %s" % plugin_name)
	
	var export_data = ExportData.new(export_config_path)
	if not export_data.data_valid:
		return false
	
	if export_data.pre_script != "":
		if not ExportFileUtils.check_export_script_valid(export_data.pre_script, "pre_export"):
			return false
		ExportFileUtils.run_export_script(export_data.pre_script, "pre_export")
	
	var full_export_path = export_data.full_export_path
	
	var options = export_data.get(ExportFileKeys.options)
	var overwrite = options.get(ExportFileKeys.overwrite, false)
	if overwrite:
		var cleared = _clear_export_dir(full_export_path)
		if not cleared:
			return false
	
	update_git_submodule_details(export_config_path, export_data)
	
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
	
	export_data.include_uid = include_uid
	export_data.include_import = include_import
	
	var count = 0
	for export:ExportData.Export in export_data.exports:
		print("Exporting: export %s" % count)
		export.file_parser.set_export_obj(export)
		export.file_parser.pre_export()
		export.export_files()
		count += 1
	
	if export_data.post_script != "":
		ExportFileUtils.run_export_script(export_data.post_script, "post_export")
	
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
	
	var gitignore_path = full_export_path.path_join(".gitignore")
	var file = FileAccess.open(gitignore_path, FileAccess.WRITE)
	file.store_string("**")
	file.close()
	
	return true
	


static func _clear_export_dir(full_export_path):
	var forbidden_paths = ["res://", "res://addons"]
	for dir in forbidden_paths:
		if full_export_path == dir:
			printerr("Could not clear export dir: %s" % full_export_path)
			printerr("This is so project files are not deleted.")
			printerr("Recommended location: res://addons/my_plugin/export_ignore/exports")
			return false
	
	if not DirAccess.dir_exists_absolute(full_export_path):
		return true
	
	var dir_array_2d:Array = UFile.scan_for_dirs(full_export_path, true)
	for dir_array:Array in dir_array_2d:
		dir_array.reverse()
		for dir in dir_array:
			var dir_access = DirAccess.open(dir)
			dir_access.include_hidden = true
			var files = dir_access.get_files()
			for file in files:
				var path = dir.path_join(file)
				DirAccess.remove_absolute(path)
			
			DirAccess.remove_absolute(dir)
	
	var dir_access = DirAccess.open(full_export_path)
	dir_access.include_hidden = true
	var files = dir_access.get_files()
	for f in files:
		var path = full_export_path.path_join(f)
		DirAccess.remove_absolute(path)
	
	return true


static func update_git_submodule_details(export_config_path, export_data:ExportData=null):
	var check_exit = OS.execute("git", ["--version"])
	if check_exit != 0:
		print("Error accessing git. Skipping git export details file.")
		return
	
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
		for file in export.file_dependencies.keys():
			var dir = file.get_base_dir()
			while dir != "res://":
				var git_path = dir.path_join(".git")
				if FileAccess.file_exists(git_path):
					var lines = _get_git_data(dir, single_export_git_file_lines)
					if lines:
						single_export_git_file_lines.append_array(lines)
					break
				elif DirAccess.dir_exists_absolute(git_path):
					var lines = _get_git_data(dir, single_export_git_file_lines)
					if lines:
						single_export_git_file_lines.append_array(lines)
					break
				else:
					dir = dir.get_base_dir()
		
		git_details_file_lines.append_array(single_export_git_file_lines)
		if single_export_git_file_lines.size() == 0:
			git_details_file_lines.append("\tNo git modules.")
	
	for export in export_data.exports:
		#var first_export = export_data.exports[0] as ExportData.Export
		var file_path = export.export_dir_path.path_join(".export_git_details")
		if not DirAccess.dir_exists_absolute(file_path.get_base_dir()):
			DirAccess.make_dir_recursive_absolute(file_path.get_base_dir())
		
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		for line in git_details_file_lines:
			file.store_line(line)
		file.close()
		

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
	var git_status = _get_git_status(dir)
	if git_status == true:
		lines.append("\t\t*has uncommited changes")
	return lines

static func _get_git_status(dir):
	var args = [
		"-C",
		dir.replace("res://", ""),
		"diff",
		"--quiet",
		"--exit-code"
	]
	var output = []
	var exit_code = OS.execute("git", args, output)
	if exit_code == -1:
		printerr("Error getting git status: %s" % dir)
		return
	
	if exit_code == 0:
		return false
	elif exit_code == 1: #dirty
		return true


static func new_plugin(plugin_dir_name, create_export:=true):
	var new_plugin_path = "res://addons/%s" % plugin_dir_name
	if DirAccess.dir_exists_absolute(new_plugin_path):
		print("Plugin already exists.")
		return
	
	DirAccess.make_dir_recursive_absolute(new_plugin_path)
	var plugin_cap_name = plugin_dir_name.capitalize()
	
	var plugin_gd_path = new_plugin_path.path_join("plugin.gd")
	var file_access = FileAccess.open(plugin_gd_path, FileAccess.WRITE)
	file_access.store_string(_NewPluginText.PLUGIN_GD_TEXT % plugin_cap_name)
	file_access.close()
	
	var plugin_cfg_path = new_plugin_path.path_join("plugin.cfg")
	
	var cfg_file_access = FileAccess.open(plugin_cfg_path, FileAccess.WRITE)
	cfg_file_access.store_string(_NewPluginText.PLUGIN_CFG_TEXT % plugin_cap_name)
	cfg_file_access.close()
	
	print("Created plugin: %s" % plugin_cap_name)
	
	if create_export:
		ExportFileUtils.plugin_init(plugin_dir_name)
	
	EditorInterface.get_resource_filesystem().scan()


class _NewPluginText:
	const PLUGIN_GD_TEXT = \
'@tool
extends EditorPlugin

func _get_plugin_name() -> String:
	return "%s"
func _get_plugin_icon() -> Texture2D:' + \
'\n\treturn EditorInterface.get_base_control().get_theme_icon("Node", &"EditorIcons")' + \
'\nfunc _has_main_screen() -> bool:
	return true

func _enable_plugin() -> void:
	pass

func _disable_plugin() -> void:
	pass

func _enter_tree() -> void:
	pass

func _exit_tree() -> void:
	pass'

	const PLUGIN_CFG_TEXT = \
'[plugin]

name="%s"
description=""
author=""
version="0.0.0"
script="plugin.gd"'

