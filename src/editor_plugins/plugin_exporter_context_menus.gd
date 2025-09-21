extends EditorContextMenuPlugin

const SLOT = EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE

const UtilsRemote = preload("res://addons/plugin_exporter/src/class/utils_remote.gd")
const PopupWrapper = UtilsRemote.PopupWrapper

const DEPENDENCY_TAGS = ["#! dependency", "#! ignore-remote"]

const DEPENDENCY = "Plugin Exporter/Dependency"
const EXPORTED_FLAG = "Plugin Exporter/Exported Flag"
const BACKPORT_FLAG = "Plugin Exporter/Backport Flag"
const IGNORE_REMOTE = "Plugin Exporter/Ignore Remote"


func _popup_menu(paths: PackedStringArray) -> void:
	var script_editor:CodeEdit = Engine.get_main_loop().root.get_node(paths[0]);
	
	var valid_items = get_valid_items(script_editor)
	PopupWrapper.create_context_plugin_items(self, script_editor, valid_items, _on_popup_pressed)


func _on_popup_pressed(script_editor, item_name):
	if item_name == DEPENDENCY:
		add_dep_tag(script_editor)
	elif item_name == IGNORE_REMOTE:
		add_ignore_remote(script_editor)
	elif item_name == EXPORTED_FLAG:
		add_exported_flag(script_editor)
	elif item_name == BACKPORT_FLAG:
		add_backport_flag(script_editor)


static func get_valid_items(script_editor:CodeEdit) -> Dictionary:
	var valid_items = {}
	var first_line = script_editor.get_line(0)
	var line = script_editor.get_caret_line()
	var text = script_editor.get_line(line)
	if text == "":
		valid_items[EXPORTED_FLAG] = {}
		valid_items[BACKPORT_FLAG] = {}
	
	if text.count('"') == 2:
		var valid_dep = true
		for tag in DEPENDENCY_TAGS:
			if text.find(tag) > -1:
				valid_dep = false
		var file_path = text.get_slice('"', 1)
		file_path = file_path.get_slice('"', 0)
		if not FileAccess.file_exists(file_path):
			valid_dep = false
		if valid_dep:
			if first_line.find("#! remote") != -1:
				valid_items[DEPENDENCY] = {}
			else:
				valid_items[IGNORE_REMOTE] = {}
	
	return valid_items


static func add_dep_tag(script_editor):
	var line = script_editor.get_caret_line()
	var text = script_editor.get_line(line)
	script_editor.set_caret_column(text.length())
	script_editor.insert_text_at_caret(" #! dependency")

static func add_ignore_remote(script_editor):
	var line = script_editor.get_caret_line()
	var text = script_editor.get_line(line)
	script_editor.set_caret_column(text.length())
	script_editor.insert_text_at_caret(" #! ignore-remote")

static func add_exported_flag(script_editor):
	var line = script_editor.get_caret_line()
	var text = script_editor.get_line(line)
	script_editor.insert_text_at_caret("const PLUGIN_EXPORTED = false")

static func add_backport_flag(script_editor):
	var line = script_editor.get_caret_line()
	var text = script_editor.get_line(line)
	script_editor.insert_text_at_caret("const BACKPORTED = 100")
