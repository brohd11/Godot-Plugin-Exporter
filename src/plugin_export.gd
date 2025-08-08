@tool
extends Control

const AB_LIB_PATH = "res://addons/modular_browser/plugin/script_libs/ab_lib.gd"
var ab_lib

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd") #>remote
const UConfig = UtilsRemote.UConfig
const UFile = UtilsRemote.UFile
const UTree = UtilsRemote.UTree
const URegex = UtilsRemote.URegex
const USafeEditor = UtilsRemote.USafeEditor
const ConfirmationDialogHandler = UtilsRemote.ConfirmationDialogHandler
const EditorFileDialogHandler = UtilsRemote.EditorFileDialogHandler

const ExportFileUtils = UtilsRemote.ExportFileUtils
const ExportFileKeys = ExportFileUtils.ExportFileKeys

const FileSystem = UtilsRemote.FileSystem
const PopupHelper = UtilsRemote.PopupHelper
const UEditorTheme = UtilsRemote.UEditorTheme
const TreeHelperClass = preload("uid://madlgh38c6lh") #>import tree_helper.gd

const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")
const CopyDeps = UtilsLocal.CopyDeps

const RemoteData = UtilsLocal.ParseBase.RemoteData

const CONFIG_FILE_PATH = "res://addons/plugin_exporter/config/plugin_exporter_config.json"
const EXPORT_TEMPLATE_PATH = "res://addons/plugin_exporter/src/template/plugin_export_template.json" #! dependency
const PRE_POST_TEMPLATE_PATH = "res://addons/plugin_exporter/src/template/pre_post.gd" #! dependency
const TEXT_FILE_TYPES = ["gd", "tscn", "tres"]

@onready var file_path_line = %FilePathLine
@onready var search_line = %SearchLine
@onready var export_tree:Tree = %ExportTree
@onready var file_name_label = %FileNameLabel

@onready var menu_button: MenuButton = %MenuButton
var PMHelper: PopupHelper.MouseHelper #>class_inst
@onready var dock_button: Button = %DockButton


var preload_regex:RegEx
var file_icon

var FileSystemItemDict:Dictionary
var file_data_dict:Dictionary

@onready var uid_check = %UIDCheck
@onready var import_check = %ImportCheck

var first_tree_build := false
var filter_text:String = ""

var TreeHelper: TreeHelperClass #>class_inst
const CALLABLE_KEY = "CALLABLE_KEY"
var menu_button_dict = {
	"Read File":{
		PopupHelper.ParamKeys.ICON_KEY: ["FileAccess"],
		PopupHelper.ParamKeys.TOOL_TIP_KEY: ["Read export file."],
		CALLABLE_KEY: _on_read_file_button_pressed
	},
	"Export":{
		PopupHelper.ParamKeys.ICON_KEY: ["ExternalLink"],
		PopupHelper.ParamKeys.TOOL_TIP_KEY: ["Export files to directory defined in export file."],
		CALLABLE_KEY: _on_export_button_pressed
	},
	"Set File":{
		PopupHelper.ParamKeys.ICON_KEY: ["Folder"],
		PopupHelper.ParamKeys.TOOL_TIP_KEY: ["Choose export json file."],
		CALLABLE_KEY: _on_set_file_button_pressed
	},
	"New File":{
		PopupHelper.ParamKeys.ICON_KEY: ["New"],
		PopupHelper.ParamKeys.TOOL_TIP_KEY: ["Create new export json file."],
		CALLABLE_KEY: _on_new_file_button_pressed
	},
}

var export_root:String
var copy_deps : CopyDeps

var is_mb_panel_flag:=false

func _ready() -> void:
	file_path_line.text_changed.connect(_on_file_line_text_changed)
	search_line.text_changed.connect(_on_search_line_text_changed)
	
	UEditorTheme.set_menu_button_to_editor_theme(menu_button)
	menu_button.pressed.connect(_on_menu_button_pressed)
	PMHelper = PopupHelper.MouseHelper.new(menu_button.get_popup())
	var popup = menu_button.get_popup()
	popup.clear()
	PopupHelper.parse_dict_static(menu_button_dict, popup, _on_menu_button_item_pressed, PMHelper)
	
	preload_regex = URegex.get_preload_path()
	
	copy_deps = CopyDeps.new()
	
	TreeHelper = TreeHelperClass.new(export_tree)
	
	file_icon = EditorInterface.get_editor_theme().get_icon("File", &"EditorIcons")
	
	if not is_part_of_edited_scene():
		UEditorTheme.ThemeSetter.set_theme_setters_in_scene(self)
		menu_button.icon = UEditorTheme.get_icon("Tools")
		search_line.right_icon = UEditorTheme.get_icon("Search")
	
		if not is_mb_panel_flag:
			_post_ready()

func _post_ready():
	FileSystemItemDict = {}
	file_data_dict = {}
	_build_file_data_dict()
	
	if not FileAccess.file_exists(CONFIG_FILE_PATH):
		UFile.write_to_json({}, CONFIG_FILE_PATH)
	else:
		var config_data = UFile.read_from_json(CONFIG_FILE_PATH)
		var last_export = config_data.get("last_export_file", "")
		if FileAccess.file_exists(last_export):
			_set_file_line_text(last_export)
			_set_line_alignment()

func _build_file_data_dict():
	FileSystem.scan_fs_dock(FileSystemItemDict, file_data_dict)

func send_panel_dialog_data(tab_data):
	
	dock_button.hide()
	
	var export_path = tab_data.get("last_export_file")
	if export_path:
		_set_file_line_text(export_path)
		_set_line_alignment()
	
	ab_lib = load("res://addons/modular_browser/plugin/script_libs/ab_lib.gd")
	var HelperInst = ab_lib.get_helper_inst(self)
	
	HelperInst.ABInstSignals.connect_toolbar_info(menu_button, "Plugin export commands.")
	HelperInst.ABInstSignals.connect_toolbar_info(file_path_line, "Export file path, drag file onto this field to load.")
	HelperInst.ABInstSignals.connect_toolbar_info(uid_check, "Include .uid files in export.")
	HelperInst.ABInstSignals.connect_toolbar_info(import_check, "Include .import in export.")
	
	FileSystemItemDict = ab_lib.ABTree.FileSystemDock_item_dict
	file_data_dict = ab_lib.ABTree.res_file_dict


func _on_menu_button_pressed():
	if not is_mb_panel_flag:
		return
	ab_lib.Stat.ui_help.popup_send_toolbar_info(menu_button.get_popup())

func _on_menu_button_item_pressed(id:int, popup:PopupMenu):
	var menu_path = PopupHelper.parse_menu_path(id, popup)
	var data = menu_button_dict.get(menu_path, {})
	var callable = data.get(CALLABLE_KEY)
	if callable:
		callable.call()


func _get_export_data():
	var export_config_path = file_path_line.text
	return ExportFileUtils.get_export_data(export_config_path)

func _get_export_root():
	var export_config_path = file_path_line.text
	return ExportFileUtils.get_export_root(export_config_path)

func _on_file_line_text_changed(new_text):
	_set_line_alignment()

func _on_set_file_button_pressed():
	var dialog = EditorFileDialogHandler.Any.new(self)
	var handled = await dialog.handled
	if handled == dialog.cancel_string:
		return
	
	_set_file_line_text(handled)
	await get_tree().process_frame
	_set_line_alignment()
	file_path_line.caret_column = handled.length()

func _set_file_line_text(new_text):
	file_path_line.text = new_text
	file_path_line.tooltip_text = new_text
	file_name_label.text = new_text.get_file().get_basename()

func _set_line_alignment():
	return
	#var font = file_path_line.get_theme_font("font") as Font
	#var text = file_path_line.text
	#var _size = font.get_string_size(text)
	#if _size.x > file_path_line.size.x:
		#file_path_line.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	#else:
		#file_path_line.alignment = HORIZONTAL_ALIGNMENT_CENTER


func _on_new_file_button_pressed():
	if not FileAccess.file_exists(EXPORT_TEMPLATE_PATH):
		printerr("Export template missing: %s" % EXPORT_TEMPLATE_PATH)
		return
	
	if not FileAccess.file_exists(CONFIG_FILE_PATH):
		UFile.write_to_json({}, CONFIG_FILE_PATH)
	
	var config_data = UFile.read_from_json(CONFIG_FILE_PATH)
	var _export_root = config_data.get("export_root", "")
	if _export_root != "":
		if not _export_root.ends_with("/"):
			_export_root = _export_root + "/"
	
	var root_dialog = EditorFileDialogHandler.Dir.new(self, _export_root)
	root_dialog.dialog.title = "Pick export folder..."
	var root_handled = await root_dialog.handled
	if root_handled == root_dialog.cancel_string:
		return
	
	config_data["export_root"] = root_handled
	UFile.write_to_json(config_data, CONFIG_FILE_PATH)
	
	
	var dialog = EditorFileDialogHandler.Dir.new(self)
	dialog.dialog.title = "Pick plugin folder..."
	var handled = await dialog.handled
	if handled == dialog.cancel_string:
		return
	
	var export_dir:String = ProjectSettings.localize_path(handled)
	var export_ignore_dir = export_dir.path_join("export_ignore")
	if not DirAccess.dir_exists_absolute(export_ignore_dir):
		DirAccess.make_dir_recursive_absolute(export_ignore_dir)
	
	var export_config_path = export_ignore_dir.path_join("plugin_export.json")
	if FileAccess.file_exists(export_config_path):
		var conf = ConfirmationDialogHandler.new("Overwrite: %s?" % export_config_path, self)
		var conf_handled = await conf.handled
		if not conf_handled:
			return
	
	var export_pre_post = export_ignore_dir.path_join("pre_post_export.gd")
	if FileAccess.file_exists(export_pre_post):
		var conf = ConfirmationDialogHandler.new("Overwrite: %s?" % export_pre_post, self)
		var conf_handled = await conf.handled
		if not conf_handled:
			return
	
	DirAccess.copy_absolute(PRE_POST_TEMPLATE_PATH, export_pre_post)
	
	var export_dir_name = export_dir.get_base_dir().get_file()
	var template_data = UFile.read_from_json(EXPORT_TEMPLATE_PATH)
	template_data["export_root"] = root_handled
	var plugin_folder = export_dir_name.capitalize().replace(" ", "")
	template_data["plugin_folder"] = "%s/%s{{version=%s}}" % [plugin_folder, plugin_folder, export_dir_name]
	var export = template_data.get("exports")[0]
	export["source"] = export_dir
	var export_dir_name_dash = export_dir_name.replace("_", "-")
	var export_folder = "%s{{version=%s}}/%s" % [export_dir_name_dash, export_dir_name, export_dir_name]
	#export_folder = export_folder.path_join(export_dir_name)
	export["export_folder"] = export_folder
	var exclude = export.get("exclude")
	exclude["directories"] = [export_ignore_dir]
	
	template_data["pre_script"] = export_pre_post
	template_data["post_script"] = export_pre_post
	
	UFile.write_to_json(template_data, export_config_path)
	EditorInterface.get_resource_filesystem().scan()
	_set_file_line_text(export_config_path)


func _on_read_file_button_pressed():
	#first_tree_build = false
	_write_export_tree()
	first_tree_build = true
	
	_save_last_export_file()

func _save_last_export_file():
	if is_mb_panel_flag:
		var export_config_path = file_path_line.text
		if FileAccess.file_exists(export_config_path):
			_set_file_line_text(export_config_path)
			ab_lib.Stat.ab_panel.write_single_value("last_export_file", export_config_path, name, self)
	else:
		var export_config_path = file_path_line.text
		var config_data = UFile.read_from_json(CONFIG_FILE_PATH)
		config_data["last_export_file"] = export_config_path
		UFile.write_to_json(config_data, CONFIG_FILE_PATH)
		_set_file_line_text(export_config_path)

func _on_export_button_pressed():
	_parse_export_data(false, true)

func _write_export_tree():
	TreeHelper.clear_items()
	TreeHelper.updating = true
	_parse_export_data()
	TreeHelper.updating = false


func _parse_export_data(build_tree=true, write=false):
	export_root = ""
	
	var export_data = _get_export_data()
	if not export_data:
		return
	export_root = _get_export_root()
	if export_root == "":
		return
	var export_config_path = file_path_line.text
	
	var post_script = export_data.get("post_script","")
	if post_script != "":
		if not FileAccess.file_exists(post_script):
			USafeEditor.push_toast("Post script file not found.", 2)
			return
		var loaded_script = load(post_script)
		var post_script_ins = loaded_script.new()
		if not post_script_ins.has_method("post_export"):
			USafeEditor.push_toast("Post script does not have method: post_export.", 2)
		post_script_ins.queue_free()
	
	var pre_script = export_data.get("pre_script","")
	if pre_script != "":
		if not FileAccess.file_exists(pre_script):
			USafeEditor.push_toast("Pre script file not found.", 2)
			return
		var loaded_script = load(pre_script)
		var pre_script_ins = loaded_script.new()
		if not pre_script_ins.has_method("pre_export"):
			USafeEditor.push_toast("Pre script does not have method: pre_export.", 2)
			pre_script_ins.queue_free()
			return
		add_child(pre_script_ins)
		await pre_script_ins.pre_export()
		pre_script_ins.queue_free()
	
	var root_item:TreeItem
	if build_tree:
		root_item = export_tree.create_item()
		var root_name = export_root.get_file()
		if export_root.ends_with("/"):
			root_name = export_root.get_base_dir().get_file()
		root_item.set_text(0, root_name)
		root_item.set_tooltip_text(0, export_root)
		root_item.set_icon(0, TreeHelper.folder_icon)
		root_item.set_icon_modulate(0, TreeHelper.folder_color)
		TreeHelper.parent_item = root_item
	
	var options = export_data.get(ExportFileKeys.options)
	
	var overwrite = options.get(ExportFileKeys.overwrite, false)
	
	var include_uid = options.get(ExportFileKeys.include_uid)
	var include_import = options.get(ExportFileKeys.include_import)
	if include_uid != null:
		if not write:
			uid_check.button_pressed = include_uid
		elif uid_check.button_pressed != include_uid:
			print("Overiding 'Include UID': ", include_uid)
	if include_import != null:
		if not write:
			import_check.button_pressed = include_import
		elif import_check.button_pressed != include_import:
			print("Overiding 'Include Import': ", include_import)
	
	var exports = export_data.get(ExportFileKeys.exports)
	for export in exports:
		var source = export.get(ExportFileKeys.source)
		if not source.ends_with("/"):
			source = source + "/"
		if not DirAccess.dir_exists_absolute(source):
			USafeEditor.push_toast(source + " does not exist.",2)
			_collapse_tree()
			return
		var export_folder:String = export.get(ExportFileKeys.export_folder)
		if export_folder == "":
			export_folder = source.get_base_dir().get_file()
		
		export_folder = ExportFileUtils.replace_version(export_folder)
		if export_folder == "":
			_collapse_tree()
			return
		#if export_folder.ends_with("/"):
			#export_folder = export_folder.erase(export_folder.length()-1)
		if not export_folder.ends_with("/"):
			export_folder = export_folder + "/"
		
		var exclude = export.get(ExportFileKeys.exclude)
		var directories = exclude.get(ExportFileKeys.directories)
		var file_extensions = exclude.get(ExportFileKeys.file_extensions)
		var files = exclude.get(ExportFileKeys.files)
		
		var source_files = UFile.scan_for_files(source, [])
		var export_dir_path = export_root.path_join(export_folder)
		var export_folder_item:TreeItem
		
		if build_tree:
			TreeHelper.parent_item = root_item
			export_folder_item = TreeHelper.new_file_path(export_dir_path, export_root)
		
		var all_remote_files = []
		for file in source_files:
			var local_path = ProjectSettings.localize_path(file)
			var remote_files = _get_remote_file(local_path, source, export_dir_path)
			_add_remote_files_to_array(remote_files, all_remote_files)
		
		var other_transfer_data = {}
		var other_transfers = export.get(ExportFileKeys.other_transfers, [])
		for other in other_transfers:
			var to:String = other.get(ExportFileKeys.to)
			if not to.begins_with(export_dir_path):
				to = export_dir_path.path_join(to)
			var from_files = other.get(ExportFileKeys.from)
			var single_from = false
			if from_files is String:
				if FileAccess.file_exists(from_files):
					from_files = [from_files]
					single_from = true
				elif DirAccess.dir_exists_absolute(from_files):
					var files_at_dir = DirAccess.get_files_at(from_files)
					var file_array = []
					for f in files_at_dir:
						var ext = f.get_extension()
						if ext == "uid" or ext == "import":
							continue
						var path = from_files.path_join(f)
						file_array.append(path)
					from_files = file_array
				else:
					printerr("Path is not file or dir: %s" % from_files)
					return
			elif from_files is Array:
				for file in from_files:
					if not FileAccess.file_exists(file):
						printerr("File doesn't exist, aborting: %s" % file)
						return
			
			if from_files is not Array:
				printerr("Issues with other transfers, destination: %s" % to)
				return
			
			for from in from_files:
				var remote_files = _get_remote_file(from, source, export_dir_path)
				_add_remote_files_to_array(remote_files, all_remote_files)
			if to in other_transfer_data.keys():
				var to_data = other_transfer_data[to]
				var single = to_data.get("single")
				if single:
					printerr("Error with other transfers file, exporting multiple files to single file: %s" % to)
					return
				to_data["from_files"].append_array(from_files)
			else:
				other_transfer_data[to] = {"from_files":from_files, "single":single_from}
			
		
		for file in source_files:
			if file.get_extension() == "uid" or file.get_extension() == "import":
				continue
			var l_path = ProjectSettings.localize_path(file)
			
			var ignore = false
			for d in directories:
				if l_path.find(d) > -1:
					ignore = true
					break
			var file_ext = l_path.get_extension()
			for ext in file_extensions:
				if ext == file_ext:
					ignore = true
					break
			for f in files:
				if f == l_path:
					ignore = true
					break
			if ignore:
				continue
			
			var remote_file_data = _get_remote_file(l_path, source, export_dir_path)
			
			var export_path = l_path.replace(source, export_dir_path)
			
			if build_tree:
				var file_data = file_data_dict.get(l_path)
				var last_item = TreeHelper.new_file_path(export_path, export_root, file_data)
				if not file_data:
					if FileAccess.file_exists(l_path):
						last_item.set_icon(0, file_icon)
						last_item.set_icon_modulate(0, Color.WHITE)
				if remote_file_data != null:
					_tree_remote_file_dependencies(last_item, l_path, export_path, remote_file_data, all_remote_files)
			
			if not write:
				continue
			
			if FileAccess.file_exists(export_path) and not overwrite:
				USafeEditor.push_toast("File exists, aborting: "+export_path, 2)
				_collapse_tree()
				return
			var export_dir = export_path.get_base_dir()
			if file_ext == "" and DirAccess.dir_exists_absolute(l_path):
				export_dir = export_path
			
			if not DirAccess.dir_exists_absolute(export_dir):
				DirAccess.make_dir_recursive_absolute(export_dir)
			
			if FileAccess.file_exists(l_path): # check that it is file vs dir
				if remote_file_data == null:
					_export_file(file, export_path)
				else:
					_export_remote_file(file, export_path, remote_file_data)
		
		#next step
		for to in other_transfer_data.keys():
			var data = other_transfer_data.get(to)
			var from_files = data.get("from_files")
			var single_from = data.get("single")
			for from in from_files:
				if not FileAccess.file_exists(from):
					USafeEditor.push_toast("File_doesn't exist, aborting: " + from, 2)
					_collapse_tree()
					return
				
				var remote_file_data = _get_remote_file(from, source, export_dir_path)
				
				var to_path = to
				if not single_from:
					to_path = to.path_join(from.get_file())
				
				if build_tree:
					var file_data = file_data_dict.get(from)
					var last_item = TreeHelper.new_file_path(to_path, export_root, file_data)
					if not file_data:
						if FileAccess.file_exists(from):
							last_item.set_icon(0, file_icon)
							last_item.set_icon_modulate(0, Color.WHITE)
					
					if remote_file_data != null:
						_tree_remote_file_dependencies(last_item, from, to_path, remote_file_data, all_remote_files)
				
				if not write:
					continue
				
				if FileAccess.file_exists(to_path) and not overwrite:
					USafeEditor.push_toast("File exists, aborting: " + to_path, 2)
					_collapse_tree()
					return
				if remote_file_data == null:
					_export_file(from, to_path)
				else:
					_export_remote_file(from, to_path, remote_file_data)
	
	
	if write:
		if post_script != "":
			var loaded_script = load(post_script)
			var ins = loaded_script.new()
			add_child(ins)
			ins.post_export()
			ins.queue_free()
		
		var files = UFile.scan_for_files(export_root, [])
		#var gd_files = UFile.scan_for_files(export_root, ["gd"])
		var gd_files = []
		for file in files:
			var ext = file.get_extension()
			if ext == "gd":
				gd_files.append(file)
		
		for file in gd_files:
			#print(file)
			_update_file_export_flags(file)
		
		var exported_dirs = DirAccess.get_directories_at(export_root)
		for dir in exported_dirs:
			var dir_path = export_root.path_join(dir)
			var zip_files = UFile.scan_for_files(dir_path, [], false,[],true)
			_write_zip_file(dir_path + ".zip", zip_files)
	
	if build_tree and not first_tree_build:
		_collapse_tree()


func _collapse_tree():
	var root_item = export_tree.get_root()
	root_item.set_collapsed_recursive(true)
	root_item.collapsed = false


func _export_file(from, to, enable_uid_import_export=true):
	var export_uid = uid_check.button_pressed
	var export_import = import_check.button_pressed
	if not enable_uid_import_export:
		export_uid = false
		export_import = false
	
	ExportFileUtils.export_file(from, to, export_uid, export_import)
	
	#var to_dir = to.get_base_dir()
	#if not DirAccess.dir_exists_absolute(to_dir):
		#DirAccess.make_dir_recursive_absolute(to_dir)
	#DirAccess.copy_absolute(from, to)
	#
	#var from_uid = from + ".uid"
	#var to_uid = to + ".uid"
	#if FileAccess.file_exists(from_uid) and uid_check.button_pressed and export_uid:
		#DirAccess.copy_absolute(from_uid, to_uid)
	#var from_import = from + ".import"
	#var to_import = to + ".import"
	#if FileAccess.file_exists(from_import) and import_check.button_pressed and export_uid:
		#DirAccess.copy_absolute(from_import, to_import)


func _export_remote_file(original_from, to, remote_file_data):
	var remote_dir = remote_file_data.get(RemoteData.dir, "")
	if remote_dir == "":
		remote_dir = to.get_base_dir()
	var remote_class = remote_file_data.get(RemoteData.single_class)
	var remote_files = remote_file_data.get(RemoteData.files, [])
	var other_deps = remote_file_data.get(RemoteData.other_deps, [])
	if remote_files != []:
		if remote_class == null:
			_export_file(original_from, to)
			copy_deps.copy_remote_dependencies(true, original_from, to, to, remote_dir)
		else: # allows for remote file to have preloads that will be copied to remote dir, will not be present in final file
			for remote_file in remote_files:
				var to_path = remote_dir.path_join(remote_file.get_file())
				_export_file(remote_file, to_path)
				copy_deps.copy_remote_dependencies(true, remote_file, to_path, to, remote_dir)
	
	if remote_class != null:
		_export_file(remote_class, to, false)
		CopyDeps.write_new_uid(to + ".uid")
		copy_deps.copy_remote_dependencies(true, remote_class, to, to, remote_dir)
	
	if other_deps != []:
		for dep in other_deps:
			var dep_from = dep.get(RemoteData.from)
			var dep_to = dep.get(RemoteData.to)
			_export_file(dep_from, dep_to)

func _update_file_export_flags(file_path):
	if file_path.get_extension() == "gd":
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
	

func _tree_remote_file_dependencies(last_item, last_item_path, export_path, remote_file_data, all_remote_files):
	var remote_class = remote_file_data.get(RemoteData.single_class)
	if remote_class != null:
		_tree_remote_file_single_dependencies(last_item, last_item_path, export_path, remote_file_data, all_remote_files)
	
	var remote_files = remote_file_data.get(RemoteData.files, [])
	if remote_files != []:
		_tree_remote_file_array_dependencies(last_item, last_item_path, export_path, remote_file_data, all_remote_files)
	
	var other_deps = remote_file_data.get(RemoteData.other_deps, [])
	if other_deps != []:
		_tree_remote_other_deps(last_item, last_item_path, export_path, remote_file_data, all_remote_files)
	
	if remote_class == null and remote_files == []:
		push_error("Remote file did not include any files: ")
		push_error(remote_file_data)

func _tree_remote_file_single_dependencies(last_item, last_item_path, export_path, remote_file_data, all_remote_files):
	var remote_class = remote_file_data.get(RemoteData.single_class)
	var remote_dir = remote_file_data.get(RemoteData.dir)
	if remote_dir == "":
		remote_dir = export_path.get_base_dir()
	var remote_file_path = remote_dir.path_join(remote_class.get_file())
	var tool_tip = "Remote: %s" % remote_class
	last_item.set_tooltip_text(0, tool_tip)
	var text = last_item.get_text(0)
	text = "%s (remote: %s)" % [text, remote_class.get_file()]
	last_item.set_text(0, text)
	var dependencies = copy_deps.copy_remote_dependencies(false, remote_class, remote_class, export_path, remote_dir)
	for data in dependencies:
		var from = data.get("from")
		if from in all_remote_files:
			continue
		var to = data.get("to")
		var dependent = data.get(RemoteData.dependent)
		_tree_remote_dependency_item(from, to, dependent)

func _tree_remote_other_deps(last_item, last_item_path, export_path, remote_file_data, all_remote_files):
	var other_dep_array = remote_file_data.get(RemoteData.other_deps)
	var remote_dir = remote_file_data.get(RemoteData.dir)
	for other_dep in other_dep_array:
		var from_path = other_dep.get("from")
		var to_path = other_dep.get("to")
		var file_data = file_data_dict.get(from_path)
		var file_nm = from_path.get_file()
		var remote_item = TreeHelper.new_file_path(to_path, export_root, file_data)
		var remote_text = "%s (remote dependency: %s)" % [file_nm, export_path.get_file()]
		remote_item.set_text(0, remote_text)
		var remote_tool_tip = "Remote: %s\nDependent: %s" % [from_path, last_item_path]
		remote_item.set_tooltip_text(0, remote_tool_tip)
		

func _tree_remote_file_array_dependencies(last_item, last_item_path, export_path, remote_file_data, all_remote_files):
	var remote_file_array = remote_file_data.get(RemoteData.files)
	var remote_dir = remote_file_data.get(RemoteData.dir)
	print(remote_dir)
	for remote_file in remote_file_array:
		var file_data = file_data_dict.get(remote_file)
		var remote_file_nm = remote_file.get_file()
		var remote_to_path = remote_dir.path_join(remote_file_nm)
		var remote_item = TreeHelper.new_file_path(remote_to_path, export_root, file_data)
		var remote_text = "%s (remote dependency: %s)" % [remote_file_nm, export_path.get_file()]
		remote_item.set_text(0, remote_text)
		var remote_tool_tip = "Remote: %s\nDependent: %s" % [remote_file, last_item_path]
		remote_item.set_tooltip_text(0, remote_tool_tip)
		
		var dependencies = copy_deps.copy_remote_dependencies(false, remote_file, remote_file, export_path, remote_dir)
		for data in dependencies:
			var from = data.get("from")
			if from in all_remote_files:
				continue
			var to = data.get("to")
			var dependent = data.get(RemoteData.dependent)
			_tree_remote_dependency_item(from, to, dependent)

func _tree_remote_dependency_item(from, to, dependent):
	if to in TreeHelper.item_dict:
		return
	var d_file_data = file_data_dict.get(from)
	var item = TreeHelper.new_file_path(to, export_root, d_file_data)
	item.set_text(0, "%s (remote dependency: %s)" % [to.get_file(), dependent.get_file()])
	item.set_tooltip_text(0, "Remote: %s\nDependent: %s" % [from, dependent])


static func _write_zip_file(path:String, files):
	var zip = ZIPPacker.new()
	var err = zip.open(path)
	if err != OK:
		return err
	var base_dir = path.get_basename()
	for f in files:
		var f_path:String = f.replace(base_dir, "")
		if f_path.begins_with("/"):
			f_path = f_path.erase(0)
		zip.start_file(f_path)
		var f_content = FileAccess.get_file_as_bytes(f)
		zip.write_file(f_content)
		zip.close_file()
	
	zip.close()
	return OK




func _get_remote_file(path, source, export_dir_path):
	var remote_files = []
	var other_deps = []
	var remote_file_data = {}
	
	if not path.get_extension() in TEXT_FILE_TYPES:
		return
	var file_access = FileAccess.open(path, FileAccess.READ)
	if file_access:
		var remote_dec_line = file_access.get_line()
		if remote_dec_line.find("#! remote") == -1:
			return
		var remote_dir = remote_dec_line.get_slice("#! remote", 1).strip_edges()
		if remote_dir != "":
			remote_dir = remote_dir.replace(source, export_dir_path)
		else:
			remote_dir = path.get_base_dir().replace(source, export_dir_path)
		
		remote_file_data[RemoteData.dir] = remote_dir
		
		while not file_access.eof_reached():
			var line = file_access.get_line()
			if line.find('extends "') > -1:
				var remote_file = line.replace("extends", "").replace('"',"").strip_edges()
				remote_file_data[RemoteData.single_class] = remote_file
				#return remote_file_data
			elif line.find("preload(") > -1:
				var preload_path = UtilsLocal.ParseBase.get_preload_path(line)
				if preload_path != null:
					remote_files.append(preload_path)
			elif line.find("#! remote-dep") > -1 and line.count('"') == 2:
				var dep_index = line.find("#! remote-dep")
				var com_index = line.find("#")
				if com_index < dep_index:
					continue
				var dep_path = line.get_slice('"', 1)
				dep_path = dep_path.get_slice('"', 0)
				var dep_dest = line.get_slice("#! remote-dep", 1).strip_edges()
				if dep_dest == "":
					dep_dest = remote_dir
					if dep_dest == "":
						dep_dest = "current"
				
				if dep_dest == "current":
					dep_dest = path.get_base_dir().replace(source, export_dir_path)
				else:
					if remote_dir == "":
						if dep_dest.find(source) == -1:
							printerr("Dependency destination must be within 'source' folder: %s File: %s" % [dep_dest, dep_path])
							continue
						dep_dest = dep_dest.replace(source, export_dir_path)
				
				dep_dest = dep_dest.path_join(dep_path.get_file())
				
				other_deps.append({"from":dep_path, "to": dep_dest})
		
	remote_file_data[RemoteData.files] = remote_files
	remote_file_data[RemoteData.other_deps] = other_deps
	return remote_file_data


func _add_remote_files_to_array(remote_file_data, all_remote_files):
	if remote_file_data == null:
		return
	var remote_class = remote_file_data.get(RemoteData.single_class)
	var remote_files = remote_file_data.get(RemoteData.files)
	if remote_class != null:
		if not remote_class in all_remote_files:
			all_remote_files.append(remote_class)
	elif remote_files != null:
		for remote_file in remote_files:
			if not remote_file in all_remote_files:
				all_remote_files.append(remote_file)

func _on_search_line_text_changed(new_text):
	filter_text = new_text.to_lower()
	if not TreeHelper:
		return
	
	_update_tree_items()


func _update_tree_items():
	var filtering := filter_text != ""
	var root_dir = _get_export_root()
	var item = export_tree.get_selected()
	TreeHelper.update_tree_items(filtering, _check_filter, root_dir)
	if not filtering:
		if not item:
			return
		TreeHelper.uncollapse_items([item])
		export_tree.set_selected(item, 0)
		export_tree.scroll_to_item(item, true)

func _check_filter(text):
	if UTree.check_filter_split(text, filter_text):
		return true
	return false

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var type = data.get("type")
	if type == "files":
		return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var formatted_array = []
	var files = data.get("files")
	if files.is_empty():
		return
	var file = files[0]
	file_path_line.text = file
