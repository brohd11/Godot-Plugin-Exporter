@tool
extends Control

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd") #>remote
const UFile = UtilsRemote.UFile
const UTree = UtilsRemote.UTree

const PluginInit = UtilsLocal.PluginInit
const ExportFileUtils = UtilsLocal.ExportFileUtils
const ExportFileKeys = ExportFileUtils.ExportFileKeys

const FileSystem = UtilsRemote.FileSystem
const PopupHelper = UtilsRemote.PopupHelper
const UEditorTheme = UtilsRemote.UEditorTheme
const TreeHelperClass = preload("uid://madlgh38c6lh") # tree_helper.gd

const UtilsLocal = preload("res://addons/plugin_exporter/src/class/utils_local.gd")
const PluginExporterStatic = UtilsLocal.PluginExporterStatic
const ExportData = UtilsLocal.ExportData
const Export = ExportData.Export
const FileParser = UtilsLocal.FileParser

@onready var file_path_line = %FilePathLine
@onready var search_line = %SearchLine
@onready var export_tree:Tree = %ExportTree
@onready var file_name_label = %FileNameLabel
@onready var menu_button: MenuButton = %MenuButton
@onready var uid_check = %UIDCheck
@onready var import_check = %ImportCheck

@onready var dock_button: Button = %DockButton

var ab_lib # Modular Browser integration

var file_icon
var plugin_icon:Texture2D

var first_tree_build := false
var filter_text:String = ""

var FileSystemItemDict:Dictionary
var file_data_dict:Dictionary

var TreeHelper: TreeHelperClass
var PMHelper: PopupHelper.MouseHelper

const CALLABLE_KEY = "CALLABLE_KEY"
var menu_button_dict = {
	"Read":{
		PopupHelper.ParamKeys.ICON_KEY: ["FileAccess"],
		PopupHelper.ParamKeys.TOOL_TIP_KEY: ["Read export file."],
		CALLABLE_KEY: _on_read_file_button_pressed
	},
	"Export":{
		PopupHelper.ParamKeys.ICON_KEY: ["ExternalLink"],
		PopupHelper.ParamKeys.TOOL_TIP_KEY: ["Export files to directory defined in export file."],
		CALLABLE_KEY: _on_export_button_pressed
	},
	"Open Export Dir":{
		PopupHelper.ParamKeys.ICON_KEY:["ClassList"],
		PopupHelper.ParamKeys.TOOL_TIP_KEY:["Open export dir of current file."],
		CALLABLE_KEY: _on_open_export_dir
	},
	"Set File":{
		PopupHelper.ParamKeys.ICON_KEY: ["Folder"],
		PopupHelper.ParamKeys.TOOL_TIP_KEY: ["Choose export json file."],
		CALLABLE_KEY: _on_set_file_button_pressed
	},
	"Plugin Init":{
		PopupHelper.ParamKeys.ICON_KEY: ["New"],
		PopupHelper.ParamKeys.TOOL_TIP_KEY: ["Create new export json file."],
		CALLABLE_KEY: _on_new_file_button_pressed
	},
}

var full_export_path:String
var is_mb_panel_flag:= false


func _init() -> void:
	plugin_icon = EditorInterface.get_base_control().get_theme_icon("ActionCopy", &"EditorIcons")

func _ready() -> void:
	if is_part_of_edited_scene():
		return
	file_path_line.text_changed.connect(_on_file_line_text_changed)
	search_line.text_changed.connect(_on_search_line_text_changed)
	
	#UEditorTheme.button_set_main_screen_theme_var(dock_button)
	#UEditorTheme.button_set_main_screen_theme_var(menu_button)
	
	UEditorTheme.set_menu_button_to_editor_theme(menu_button)
	menu_button.pressed.connect(_on_menu_button_pressed)
	PMHelper = PopupHelper.MouseHelper.new(menu_button.get_popup())
	var popup = menu_button.get_popup()
	popup.clear()
	PopupHelper.parse_dict_static(menu_button_dict, popup, _on_menu_button_item_pressed, PMHelper)
	
	TreeHelper = TreeHelperClass.new(export_tree, null, null, null, false)
	
	file_icon = EditorInterface.get_editor_theme().get_icon("File", &"EditorIcons")
	plugin_icon = EditorInterface.get_base_control().get_theme_icon("ActionCopy", &"EditorIcons")
	
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

func set_dock_data(dock_data:Dictionary):
	var export_path = dock_data.get("last_export_file")
	if export_path:
		_set_file_line_text(export_path)

func get_dock_data():
	var dock_data = {}
	var file_path = file_path_line.text
	if FileAccess.file_exists(file_path):
		dock_data["last_export_file"] = file_path
	return dock_data

func _build_file_data_dict():
	FileSystem.scan_fs_dock(FileSystemItemDict, file_data_dict)

func send_panel_dialog_data(tab_data):
	dock_button.hide()
	set_dock_data(tab_data)
	
	ab_lib = load("res://addons/modular_browser/plugin/script_libs/ab_lib.gd") #! ignore-remote
	var HelperInst = ab_lib.get_helper_inst(self)
	
	HelperInst.ABInstSignals.connect_toolbar_info(menu_button, "Plugin export commands.")
	HelperInst.ABInstSignals.connect_toolbar_info(file_path_line, "Export file path, drag file onto this field to load.")
	HelperInst.ABInstSignals.connect_toolbar_info(uid_check, "Include .uid files in export.")
	HelperInst.ABInstSignals.connect_toolbar_info(import_check, "Include .import in export.")
	
	FileSystemItemDict = ab_lib.ABTree.FileSystemDock_item_dict
	file_data_dict = ab_lib.ABTree.res_file_dict


func _set_file_line_text(new_text:String) -> void:
	file_path_line.text = new_text
	_set_file_line_labels(new_text)
	
	await get_tree().process_frame
	file_path_line.caret_column = new_text.length()

func _set_file_line_labels(new_text):
	file_path_line.tooltip_text = new_text
	file_name_label.text = new_text.get_file().get_basename()
	
	_set_line_alignment()

func _on_file_line_text_changed(new_text):
	_set_file_line_labels(new_text)

func _set_line_alignment():
	return


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


func _on_set_file_button_pressed():
	var dialog = EditorFileDialogHandler.Any.new(self)
	var handled = await dialog.handled
	if handled == dialog.cancel_string:
		return
	
	handled = ProjectSettings.localize_path(handled)
	_set_file_line_text(handled)

# Used in plugin_exporter.gd
func load_export_file(file_path, read:=false):
	if not FileAccess.file_exists(file_path):
		print("Plugin Exporter: File doesn't exist - ", file_path)
	
	_set_file_line_text(file_path)
	await get_tree().process_frame
	_set_line_alignment()
	
	if read:
		_write_export_tree()
		first_tree_build = true


func _on_new_file_button_pressed():
	var new_file_path = await PluginInit.plugin_init()
	if new_file_path == null:
		return
	_set_file_line_text(new_file_path)

func _on_open_export_dir():
	var export_config_path = file_path_line.text
	PluginExporterStatic.open_export_dir(export_config_path)


func _on_read_file_button_pressed():
	_write_export_tree()
	first_tree_build = true
	
	_save_last_export_file()

func _save_last_export_file():
	var export_config_path = file_path_line.text
	if FileAccess.file_exists(export_config_path):
		if is_mb_panel_flag:
			ab_lib.Stat.ab_panel.write_single_value("last_export_file", export_config_path, name, self)
		_set_file_line_text(export_config_path)

func _on_export_button_pressed():
	if first_tree_build == false:
		_write_export_tree()
		first_tree_build = true
		print("Reading file before export, press again if no errors.")
		return
	
	var export_config_path = file_path_line.text
	var include_uid = uid_check.button_pressed
	var include_import = import_check.button_pressed
	PluginExporterStatic.export_by_gui(export_config_path, include_uid, include_import)


func _write_export_tree():
	TreeHelper.clear_items()
	TreeHelper.updating = true
	_parse_export_data()
	TreeHelper.updating = false


func _parse_export_data():#, write=false):
	var export_config_path = file_path_line.text
	var export_data = ExportData.new(export_config_path)
	if not export_data.data_valid:
		printerr("Issue with export data.")
		_collapse_tree()
		return
	
	full_export_path = export_data.full_export_path
	
	uid_check.button_pressed = export_data.include_uid
	import_check.button_pressed = export_data.include_import
	
	var pre_script = export_data.pre_script
	if pre_script != "":
		ExportFileUtils.run_export_script(pre_script, "pre_export")
	
	# build tree
	var root_item:TreeItem
	root_item = export_tree.create_item()
	var root_name = full_export_path.get_file()
	if full_export_path.ends_with("/"):
		root_name = full_export_path.get_base_dir().get_file()
	root_item.set_text(0, root_name)
	root_item.set_tooltip_text(0, full_export_path)
	root_item.set_icon(0, TreeHelper.folder_icon)
	root_item.set_icon_modulate(0, TreeHelper.folder_color)
	TreeHelper.parent_item = root_item
	# /build tree
	
	for export:Export in export_data.exports:
		var source = export.source
		var export_dir_path = export.export_dir_path
		
		# build tree
		var export_folder_item:TreeItem
		TreeHelper.parent_item = root_item
		export_folder_item = TreeHelper.new_file_path(export_dir_path, full_export_path)
		# /build tree
		
		
		var files_to_copy = export.files_to_copy.keys()
		#files_to_copy.sort() # figure this out later, to sort added files
		for local_file_path in files_to_copy:
			var export_file_data = export.files_to_copy.get(local_file_path)
			var export_path = export_file_data.get(ExportFileKeys.to)
			var replace_with = export_file_data.get(ExportFileKeys.replace_with)
			var dependent = export_file_data.get(ExportFileKeys.dependent)
			var custom_message = export_file_data.get(ExportFileKeys.custom_tree_message)
			#var remote_file_data = ExportFileUtils.get_remote_file(local_file_path, export)
			# build tree
			var file_data = file_data_dict.get(local_file_path)
			var last_item = TreeHelper.new_file_path(export_path, full_export_path, file_data) as TreeItem
			if not file_data:
				if FileAccess.file_exists(local_file_path):
					last_item.set_icon(0, file_icon)
					last_item.set_icon_modulate(0, Color.WHITE)
			
			var text = last_item.get_text(0)
			if custom_message != null:
				var new_text = text + custom_message
				last_item.set_text(0, new_text)
				last_item.set_tooltip_text(0, new_text)
			elif replace_with != null:
				var new_text = text + " <- (remote file: %s)" % replace_with.get_file()
				last_item.set_text(0, new_text)
				var new_tooltip = text + " <- (remote file: %s)" % replace_with
				last_item.set_tooltip_text(0, new_tooltip)
			elif dependent != null:
				var new_text = text + " -> (dependency to: %s)" % dependent.get_file()
				last_item.set_text(0, new_text)
				var new_tooltip = text + " -> (dependency to: %s)" % dependent
				last_item.set_tooltip_text(0, new_tooltip)
			
			if last_item.get_text(0).begins_with("%s"):
				printerr("'%' in file path: ", local_file_path)
		
		for virtual_file_type in export.virtual_files.keys():
			var virtual_file_type_data = export.virtual_files[virtual_file_type]
			for local_file_path in virtual_file_type_data.keys():
				var export_file_data = virtual_file_type_data.get(local_file_path)
				var export_path = export_file_data.get(ExportFileKeys.to)
				var custom_message = export_file_data.get(ExportFileKeys.custom_tree_message)
				var last_item = TreeHelper.new_file_path(export_path, full_export_path) as TreeItem
				last_item.set_icon(0, file_icon)
				last_item.set_icon_modulate(0, Color.WHITE)
				var text = last_item.get_text(0)
				if custom_message != null:
					var new_text = text + custom_message
					last_item.set_text(0, new_text)
					last_item.set_tooltip_text(0, new_text)
			
		# /build tree
	
	
	if not first_tree_build:
		_collapse_tree()



func _collapse_tree():
	var root_item = export_tree.get_root()
	if not root_item:
		return
	root_item.set_collapsed_recursive(true)
	root_item.collapsed = false


func _on_search_line_text_changed(new_text):
	filter_text = new_text.to_lower()
	if not TreeHelper:
		return
	
	_update_tree_items()


func _update_tree_items():
	var filtering := filter_text != ""
	var root_item = export_tree.get_root()
	if not root_item:
		return
	var root_dir = root_item.get_tooltip_text(0)
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
